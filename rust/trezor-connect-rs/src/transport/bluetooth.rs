//! Bluetooth transport implementation.
//!
//! Uses the `btleplug` crate for cross-platform BLE communication.

use async_trait::async_trait;
use btleplug::api::{Central, Manager as _, Peripheral as _, ScanFilter, WriteType};
use btleplug::platform::{Adapter, Manager, Peripheral};
use futures::StreamExt;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::{Mutex, RwLock};

use crate::constants::{
    BLE_CHARACTERISTIC_RX, BLE_CHARACTERISTIC_TX, BLE_CHUNK_SIZE, BLE_SERVICE_UUID, thp_control,
};
use crate::error::{Result, ThpError, TransportError};
use crate::protocol::thp::{
    HandshakeInitResponse, ProtocolThp, encode_ack, encode_channel_allocation_request,
    encode_encrypted_message, encode_handshake_completion_request, encode_handshake_init_request,
    get_handshake_hash, handle_handshake_init, pairing_messages::encode_create_new_session,
    parse_handshake_completion_response, state::ThpHandshakeCredentials,
};
use crate::protocol::{Protocol, chunk};
use crate::transport::{DeviceDescriptor, SessionManager, Transport, TransportApi};
use zeroize::Zeroizing;

use tokio::sync::mpsc;

use crate::protocol::thp::pairing_messages::decode_varint;

/// Parse a Failure protobuf message to extract the error message
fn parse_failure_message(data: &[u8]) -> String {
    // Failure message has:
    // - Field 1 (0x08): code (varint)
    // - Field 2 (0x12): message (string)
    let mut pos = 0;
    let mut message = String::from("Unknown error");

    while pos < data.len() {
        let tag = data[pos];
        pos += 1;

        let field_num = tag >> 3;
        let wire_type = tag & 0x07;

        if wire_type == 0 {
            // Varint - decode with multi-byte support
            match decode_varint(&data[pos..]) {
                Ok((_, consumed)) => pos += consumed,
                Err(_) => break,
            }
        } else if wire_type == 2 {
            // Length-delimited — length is a varint
            match decode_varint(&data[pos..]) {
                Ok((len_val, consumed)) => {
                    pos += consumed;
                    let len = len_val as usize;
                    if field_num == 2 && pos + len <= data.len() {
                        message = String::from_utf8_lossy(&data[pos..pos + len]).to_string();
                    }
                    pos += len;
                }
                Err(_) => break,
            }
        } else {
            break; // Unknown wire type
        }
    }

    message
}

/// Connected device state
struct ConnectedDevice {
    peripheral: Peripheral,
    /// Whether THP handshake is complete
    handshake_complete: bool,
    /// Per-device THP protocol state (channel, nonces, encryption keys)
    protocol: ProtocolThp,
    /// Receive channel for notifications (wrapped in Mutex for interior mutability)
    rx: Arc<Mutex<mpsc::Receiver<Vec<u8>>>>,
    /// Shutdown signal for the notification handler task
    shutdown_tx: tokio::sync::watch::Sender<bool>,
    /// Counter for BLE write flow control
    write_count: std::sync::atomic::AtomicU32,
}

/// Sync callback for pairing code entry (simpler than async for now)
pub type PairingCodeCallback = Arc<dyn Fn() -> String + Send + Sync>;

/// Bluetooth Transport for Trezor devices (Safe 7)
pub struct BluetoothTransport {
    /// BLE adapter
    adapter: Option<Adapter>,
    /// Session manager
    sessions: SessionManager,
    /// Connected devices (path -> device, each with its own THP protocol state)
    devices: Arc<RwLock<HashMap<String, ConnectedDevice>>>,
    /// Pairing code callback (for code entry pairing)
    pairing_callback: Option<PairingCodeCallback>,
    /// Host name for THP pairing identity
    host_name: String,
    /// Application name for THP pairing identity
    app_name: String,
    /// Per-device call serialization locks (path -> mutex).
    /// Ensures only one call() is in-flight per device at a time.
    call_locks: Arc<std::sync::Mutex<HashMap<String, Arc<tokio::sync::Mutex<()>>>>>,
    /// Passphrase bound to the THP session at `ThpCreateNewSession` time.
    /// Empty string opens the standard wallet. Ignored when `session_on_device`
    /// is true (the device prompts on its own screen). NFKD-normalized and
    /// wiped from memory on drop.
    session_passphrase: Zeroizing<String>,
    /// When true, the THP session is created with `on_device = true` so the
    /// user enters the passphrase on the Trezor instead of the host.
    session_on_device: bool,
}

impl BluetoothTransport {
    /// Create a new Bluetooth transport
    pub async fn new() -> Result<Self> {
        let manager = Manager::new()
            .await
            .map_err(|e| TransportError::Bluetooth(e.to_string()))?;

        let adapters = manager
            .adapters()
            .await
            .map_err(|e| TransportError::Bluetooth(e.to_string()))?;

        let adapter = adapters.into_iter().next();

        Ok(Self {
            adapter,
            sessions: SessionManager::new(),
            devices: Arc::new(RwLock::new(HashMap::new())),
            pairing_callback: None,
            host_name: "trezor-connect-rs".to_string(),
            app_name: "trezor-connect-rs".to_string(),
            call_locks: Arc::new(std::sync::Mutex::new(HashMap::new())),
            session_passphrase: Zeroizing::new(String::new()),
            session_on_device: false,
        })
    }

    /// Set the passphrase bound to the THP session created during connect.
    ///
    /// `passphrase` opens the corresponding hidden wallet (empty = standard).
    /// When `on_device` is true the passphrase is entered on the Trezor itself
    /// and `passphrase` is ignored. The passphrase is NFKD-normalized (matching
    /// `@trezor/connect`) and wiped from memory on drop. Must be called before
    /// the THP session is created.
    pub fn with_session_passphrase(mut self, passphrase: String, on_device: bool) -> Self {
        // Own the caller's `String` in `Zeroizing` immediately so their
        // handed-over copy is wiped on drop, not just the normalized one we keep.
        let passphrase = Zeroizing::new(passphrase);
        self.session_passphrase =
            Zeroizing::new(crate::passphrase::normalize_passphrase(&passphrase));
        self.session_on_device = on_device;
        self
    }

    /// Get or create the per-device call serialization lock.
    fn get_call_lock(&self, path: &str) -> Arc<tokio::sync::Mutex<()>> {
        let mut locks = self.call_locks.lock().expect("call_locks poisoned");
        locks
            .entry(path.to_string())
            .or_insert_with(|| Arc::new(tokio::sync::Mutex::new(())))
            .clone()
    }

    /// Set the pairing code callback.
    ///
    /// This callback is invoked during code entry pairing when the device
    /// displays a 6-digit code that the user must enter.
    pub fn set_pairing_callback(&mut self, callback: PairingCodeCallback) {
        self.pairing_callback = Some(callback);
    }

    /// Set the application identity used during THP pairing.
    pub fn set_app_identity(&mut self, host_name: &str, app_name: &str) {
        self.host_name = host_name.to_string();
        self.app_name = app_name.to_string();
    }

    /// Start scanning for Trezor devices
    pub async fn start_scan(&self) -> Result<()> {
        let adapter = self
            .adapter
            .as_ref()
            .ok_or_else(|| TransportError::Bluetooth("No Bluetooth adapter found".to_string()))?;

        let filter = ScanFilter {
            services: vec![BLE_SERVICE_UUID],
        };

        adapter
            .start_scan(filter)
            .await
            .map_err(|e| TransportError::Bluetooth(e.to_string()))?;

        Ok(())
    }

    /// Stop scanning
    pub async fn stop_scan(&self) -> Result<()> {
        if let Some(adapter) = &self.adapter {
            adapter
                .stop_scan()
                .await
                .map_err(|e| TransportError::Bluetooth(e.to_string()))?;
        }
        Ok(())
    }

    /// Add pairing credentials for a device (must be called after open/connect but before acquire).
    ///
    /// For devices not yet connected, credentials are stored and will be applied
    /// when the device is opened.
    pub async fn add_device_credentials(
        &self,
        path: &str,
        creds: crate::protocol::thp::state::ThpCredentials,
    ) {
        let mut devices = self.devices.write().await;
        if let Some(device) = devices.get_mut(path) {
            device.protocol.state_mut().add_pairing_credentials(creds);
        }
    }

    /// Get pairing credentials for a device (if any).
    pub async fn get_device_credentials(
        &self,
        path: &str,
    ) -> Option<crate::protocol::thp::state::ThpCredentials> {
        let devices = self.devices.read().await;
        devices
            .get(path)?
            .protocol
            .state()
            .pairing_credentials()
            .first()
            .cloned()
    }

    /// Perform THP handshake with device (with retry for TransportBusy)
    async fn perform_thp_handshake(&self, path: &str) -> Result<()> {
        const MAX_RETRIES: u32 = 3;
        const RETRY_DELAY_MS: u64 = 500;

        for attempt in 1..=MAX_RETRIES {
            match self.perform_thp_handshake_inner(path).await {
                Ok(()) => return Ok(()),
                Err(e) => {
                    let error_str = e.to_string();
                    if error_str.contains("TransportBusy") && attempt < MAX_RETRIES {
                        log::warn!(
                            "[BLE] TransportBusy error (attempt {}/{}), retrying in {}ms...",
                            attempt,
                            MAX_RETRIES,
                            RETRY_DELAY_MS
                        );
                        // Reset protocol state before retry
                        {
                            let mut devices = self.devices.write().await;
                            if let Some(device) = devices.get_mut(path) {
                                device.protocol.state_mut().reset();
                            }
                        }
                        tokio::time::sleep(Duration::from_millis(RETRY_DELAY_MS)).await;
                        continue;
                    }
                    return Err(e);
                }
            }
        }
        Err(ThpError::HandshakeFailed("Max retries exceeded".to_string()).into())
    }

    /// Inner handshake implementation
    async fn perform_thp_handshake_inner(&self, path: &str) -> Result<()> {
        log::info!("[BLE] Starting THP handshake...");

        // Step 1: Channel Allocation
        let channel_req = encode_channel_allocation_request();
        log::debug!(
            "[BLE] Sending channel allocation request ({} bytes): {:02x?}",
            channel_req.len(),
            &channel_req
        );
        self.write_raw(path, &channel_req).await?;
        log::debug!("[BLE] Channel allocation request sent, waiting for response...");

        // Read channel allocation response (increase timeout for BLE latency)
        let channel_resp = self
            .read_with_timeout(path, Duration::from_secs(10))
            .await?;
        log::debug!(
            "[BLE] Channel response: {:02x?}",
            &channel_resp[..channel_resp.len().min(16)]
        );

        // Validate CRC on channel allocation response
        Self::validate_crc(&channel_resp)?;

        if channel_resp.is_empty() || channel_resp[0] != thp_control::CHANNEL_ALLOCATION_RES {
            return Err(ThpError::HandshakeFailed(format!(
                "Expected channel allocation response, got: {:02x}",
                channel_resp.get(0).unwrap_or(&0)
            ))
            .into());
        }

        // Channel allocation response format:
        // [magic(1) | header_channel(2) | length(2) | nonce(8) | allocated_channel(2) | properties... | crc(4)]
        // The allocated channel is at payload offset 8 (after the nonce)
        // Payload starts at byte 5, so allocated channel is at bytes 13-14
        if channel_resp.len() < 15 {
            return Err(ThpError::HandshakeFailed(format!(
                "Channel allocation response too short: {} bytes",
                channel_resp.len()
            ))
            .into());
        }
        let channel: [u8; 2] = [channel_resp[13], channel_resp[14]];
        log::info!(
            "[BLE] Received allocated channel: {:02x}{:02x}",
            channel[0],
            channel[1]
        );

        // Extract device properties from channel allocation response
        // Payload starts at byte 5, format: nonce(8) + channel(2) + properties... + crc(4)
        let payload_len = u16::from_be_bytes([channel_resp[3], channel_resp[4]]) as usize;
        let props_start = 5 + 8 + 2; // header(5) + nonce(8) + channel(2)
        let props_end = 5 + payload_len - 4; // header + payload_len - CRC
        let device_properties = if channel_resp.len() >= props_end {
            channel_resp[props_start..props_end].to_vec()
        } else {
            vec![]
        };
        log::debug!(
            "[BLE] Device properties ({} bytes): {:02x?}",
            device_properties.len(),
            &device_properties[..device_properties.len().min(16)]
        );

        // Update protocol state with channel
        {
            let mut devices = self.devices.write().await;
            let device = devices
                .get_mut(path)
                .ok_or(TransportError::DeviceNotFound)?;
            device.protocol.state_mut().set_channel(channel);
        }

        // Store device properties for handshake hash
        let device_properties_for_hash = device_properties.clone();

        // Small delay before handshake init (device may need time after channel allocation)
        tokio::time::sleep(Duration::from_millis(100)).await;

        // Check for stored credentials for this device (to skip pairing on reconnect)
        let stored_credential = {
            let devices = self.devices.read().await;
            let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;
            device
                .protocol
                .state()
                .pairing_credentials()
                .first()
                .and_then(|creds| {
                    let host_key = hex::decode(&creds.host_static_key).ok()?;
                    let trezor_pubkey = hex::decode(&creds.trezor_static_public_key).ok()?;
                    let credential = hex::decode(&creds.credential).ok()?;
                    if host_key.len() == 32 && trezor_pubkey.len() == 32 {
                        let mut key_array = [0u8; 32];
                        key_array.copy_from_slice(&host_key);
                        let mut trezor_array = [0u8; 32];
                        trezor_array.copy_from_slice(&trezor_pubkey);
                        Some(crate::protocol::thp::StoredCredential {
                            host_static_key: key_array,
                            trezor_static_public_key: trezor_array,
                            credential,
                        })
                    } else {
                        None
                    }
                })
        };

        // Match Trezor Suite: try_to_unlock is false by default.
        // Suite only sets it true on retry after ThpDeviceLocked.
        // Stored credentials are used regardless of this flag —
        // credential matching happens in handle_handshake_init.
        let try_to_unlock = false;
        if stored_credential.is_some() {
            log::info!(
                "[BLE] Found stored credentials - will attempt reconnection without pairing"
            );
        }

        // Step 2: Handshake Init
        log::debug!("[BLE] Generating ephemeral keypair...");
        let ephemeral_secret: Zeroizing<[u8; 32]> = Zeroizing::new(rand::random());
        let (_, host_ephemeral_pubkey) =
            crate::protocol::thp::crypto::keypair_from_secret(&ephemeral_secret);

        // Get current send_bit and send handshake init request
        let send_bit = {
            let devices = self.devices.read().await;
            let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;
            device.protocol.state().send_bit()
        };
        log::debug!(
            "[BLE] Sending handshake init request (send_bit={}, try_to_unlock={})...",
            send_bit,
            try_to_unlock
        );
        let init_req = encode_handshake_init_request(
            &channel,
            host_ephemeral_pubkey.as_bytes(),
            try_to_unlock,
            send_bit,
        );
        self.write_raw(path, &init_req).await?;

        // Toggle send_bit after sending
        {
            let mut devices = self.devices.write().await;
            let device = devices
                .get_mut(path)
                .ok_or(TransportError::DeviceNotFound)?;
            device.protocol.state_mut().update_sync_bit(true);
            log::debug!(
                "[BLE] Toggled send_bit to {}",
                device.protocol.state().send_bit()
            );
        }

        // Read handshake init response (skipping ACK)
        let init_resp = self.read_response(path, Duration::from_secs(10)).await?;
        log::debug!(
            "[BLE] Handshake init response: {:02x?}",
            &init_resp[..init_resp.len().min(32)]
        );

        // Check for THP error
        if !init_resp.is_empty() && init_resp[0] == thp_control::ERROR {
            let error_code = init_resp.get(5).copied().unwrap_or(0);
            let error_name = match error_code {
                0x01 => "TransportBusy",
                0x02 => "UnallocatedChannel",
                0x03 => "DecryptionFailed",
                0x05 => "DeviceLocked",
                _ => "Unknown",
            };
            if error_code == 0x05 {
                return Err(ThpError::DeviceLocked.into());
            }
            return Err(ThpError::HandshakeFailed(format!(
                "Device returned THP error: {} (0x{:02x})",
                error_name, error_code
            ))
            .into());
        }

        if init_resp.is_empty() || (init_resp[0] & 0xe7) != thp_control::HANDSHAKE_INIT_RES {
            return Err(ThpError::HandshakeFailed(format!(
                "Expected handshake init response, got: {:02x}",
                init_resp.get(0).unwrap_or(&0)
            ))
            .into());
        }

        // Send ACK for init response
        let ack_bit = (init_resp[0] >> 4) & 1;
        let ack = encode_ack(&channel, ack_bit);
        self.write_raw(path, &ack).await?;
        log::debug!("[BLE] Sent ACK for init response");

        // Small delay to allow device to process before next request
        tokio::time::sleep(Duration::from_millis(100)).await;

        // Parse handshake init response
        // Header is 5 bytes: control(1) + channel(2) + length(2)
        // Then: trezor_ephemeral_pubkey(32) + encrypted_static_pubkey(48) + tag(16)
        if init_resp.len() < 5 + 32 + 48 + 16 {
            return Err(ThpError::HandshakeFailed(format!(
                "Handshake init response too short: {} bytes",
                init_resp.len()
            ))
            .into());
        }

        let payload = &init_resp[5..];
        let trezor_ephemeral_pubkey: [u8; 32] = payload[..32]
            .try_into()
            .map_err(|_| ThpError::HandshakeFailed("Invalid ephemeral pubkey".to_string()))?;
        let trezor_encrypted_static = payload[32..80].to_vec();
        let tag: [u8; 16] = payload[80..96]
            .try_into()
            .map_err(|_| ThpError::HandshakeFailed("Invalid tag".to_string()))?;

        log::debug!(
            "[BLE] Trezor ephemeral pubkey: {} bytes",
            trezor_ephemeral_pubkey.len()
        );

        // Initialize handshake state with device properties from channel allocation
        {
            let mut devices = self.devices.write().await;
            let device = devices
                .get_mut(path)
                .ok_or(TransportError::DeviceNotFound)?;
            let handshake_hash = get_handshake_hash(&device_properties_for_hash);
            log::debug!(
                "[BLE] Initial handshake hash: {} bytes",
                handshake_hash.len()
            );
            let mut creds = ThpHandshakeCredentials::default();
            creds.handshake_hash = handshake_hash.to_vec();
            device.protocol.state_mut().set_handshake_credentials(creds);
        }

        // Handle handshake init response and generate completion request
        let init_response = HandshakeInitResponse {
            trezor_ephemeral_pubkey,
            trezor_encrypted_static_pubkey: trezor_encrypted_static,
            tag,
        };

        let completion_req = {
            let mut devices = self.devices.write().await;
            let device = devices
                .get_mut(path)
                .ok_or(TransportError::DeviceNotFound)?;
            handle_handshake_init(
                device.protocol.state_mut(),
                &init_response,
                &ephemeral_secret,
                try_to_unlock,
                stored_credential.as_ref(),
            )?
        };

        // Step 3: Handshake Completion
        // Get current send_bit (should be 1 after toggling from init)
        let send_bit = {
            let devices = self.devices.read().await;
            let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;
            device.protocol.state().send_bit()
        };
        log::debug!(
            "[BLE] Sending handshake completion request (send_bit={})...",
            send_bit
        );
        let comp_req = encode_handshake_completion_request(
            &channel,
            &completion_req.encrypted_host_static_pubkey,
            &completion_req.encrypted_payload,
            send_bit,
        );
        log::debug!(
            "[BLE] Completion request control byte: 0x{:02x}",
            comp_req[0]
        );
        self.write_raw(path, &comp_req).await?;

        // Toggle send_bit after sending
        {
            let mut devices = self.devices.write().await;
            let device = devices
                .get_mut(path)
                .ok_or(TransportError::DeviceNotFound)?;
            device.protocol.state_mut().update_sync_bit(true);
            log::debug!(
                "[BLE] Toggled send_bit to {}",
                device.protocol.state().send_bit()
            );
        }

        // Read handshake completion response (skipping ACK)
        // Longer timeout as device may show pairing dialog
        log::info!("[BLE] Waiting for handshake completion response...");
        log::warn!("[BLE] ============================================================");
        log::warn!("[BLE] >>> CHECK YOUR TREZOR SCREEN! <<<");
        log::warn!("[BLE] If a pairing confirmation appears, please approve it.");
        log::warn!("[BLE] ============================================================");

        // Very long timeout - device may wait for user confirmation (2 minutes)
        let comp_resp = self.read_response(path, Duration::from_secs(120)).await?;
        log::debug!(
            "[BLE] Handshake completion response: {:02x?}",
            &comp_resp[..comp_resp.len().min(16)]
        );

        if comp_resp.is_empty() {
            return Err(ThpError::HandshakeFailed("Empty completion response".to_string()).into());
        }

        // Send ACK
        let ack_bit = (comp_resp[0] >> 4) & 1;
        let ack = encode_ack(&channel, ack_bit);
        self.write_raw(path, &ack).await?;

        // Check if pairing is required
        let ctrl = comp_resp[0] & 0xe7;
        if ctrl == thp_control::HANDSHAKE_COMP_RES {
            // Extract encrypted payload from response
            // Header: control(1) + channel(2) + length(2) = 5 bytes
            // Payload: length bytes (includes encrypted content + CRC)
            let payload_len = u16::from_be_bytes([comp_resp[3], comp_resp[4]]) as usize;
            let crc_len = 4;

            if comp_resp.len() >= 5 + payload_len && payload_len > crc_len {
                let encrypted_payload = &comp_resp[5..5 + payload_len - crc_len];
                log::debug!(
                    "[BLE] Encrypted completion payload: {} bytes",
                    encrypted_payload.len()
                );

                // Decrypt and parse the completion response
                let completion = {
                    let devices = self.devices.read().await;
                    let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;
                    parse_handshake_completion_response(device.protocol.state(), encrypted_payload)?
                };

                log::info!(
                    "[BLE] Trezor state: {} (0=needs pairing, 1=paired)",
                    completion.trezor_state
                );
                log::info!(
                    "[BLE] Available pairing methods: {:?}",
                    completion.pairing_methods
                );

                if completion.trezor_state == 0 {
                    log::info!("[BLE] Device requires pairing - starting pairing flow");

                    // Use the callback if set, otherwise use stdin
                    let callback = self.pairing_callback.clone();
                    let code_fn = move || -> String {
                        if let Some(ref cb) = callback {
                            cb()
                        } else {
                            // Default to stdin for code entry
                            use std::io::{self, Write};
                            print!("Enter 6-digit code from Trezor: ");
                            io::stdout().flush().unwrap();
                            let mut code = String::new();
                            io::stdin().read_line(&mut code).unwrap();
                            code.trim().to_string()
                        }
                    };

                    // Perform pairing
                    self.perform_pairing(path, code_fn).await?;

                    log::info!("[BLE] Pairing completed successfully");
                } else {
                    // Reconnecting with stored credentials - still need to send ThpEndRequest
                    // to finalize the handshake before creating a session
                    log::info!(
                        "[BLE] Reconnecting with stored credentials - sending ThpEndRequest..."
                    );

                    // Mark as paired first so we can use encrypted messaging
                    {
                        let mut devices = self.devices.write().await;
                        let device = devices
                            .get_mut(path)
                            .ok_or(TransportError::DeviceNotFound)?;
                        device.protocol.state_mut().set_is_paired(true);
                    }

                    let (end_resp_type, _) = self
                        .send_encrypted_message(
                            path,
                            crate::constants::thp_message_type::THP_END_REQUEST,
                            &[],
                        )
                        .await?;

                    // state=1 may trigger a ButtonRequest for connection confirmation on the device
                    if end_resp_type == crate::constants::message_type::BUTTON_REQUEST {
                        log::info!("[BLE] Device requesting connection confirmation...");
                        let (ack_resp_type, _) = self
                            .send_encrypted_message(
                                path,
                                crate::constants::message_type::BUTTON_ACK,
                                &[],
                            )
                            .await?;
                        if ack_resp_type != crate::constants::thp_message_type::THP_END_RESPONSE {
                            return Err(ThpError::PairingFailed(format!(
                                "Expected ThpEndResponse after ButtonACK, got {}",
                                ack_resp_type
                            ))
                            .into());
                        }
                    } else if end_resp_type != crate::constants::thp_message_type::THP_END_RESPONSE
                    {
                        return Err(ThpError::PairingFailed(format!(
                            "Expected ThpEndResponse ({}), got {}",
                            crate::constants::thp_message_type::THP_END_RESPONSE,
                            end_resp_type
                        ))
                        .into());
                    }
                    log::info!("[BLE] ThpEndRequest completed for reconnection");
                }
            } else {
                log::warn!(
                    "[BLE] Completion response too short to decrypt: {} bytes",
                    comp_resp.len()
                );
            }
        }

        // Mark handshake as complete (enables encrypted messaging)
        {
            let mut devices = self.devices.write().await;
            let device = devices
                .get_mut(path)
                .ok_or(TransportError::DeviceNotFound)?;
            device.protocol.state_mut().set_is_paired(true);
        }

        // Create a new THP session on the device
        // This must be done BEFORE using the session for other messages
        self.create_thp_session(path).await?;

        log::info!("[BLE] THP handshake and session creation complete!");
        Ok(())
    }

    /// Create a new THP session on the device.
    ///
    /// This sends ThpCreateNewSession and waits for Success.
    /// Must be called after handshake is complete but before sending other messages.
    async fn create_thp_session(&self, path: &str) -> Result<()> {
        use crate::constants::thp_message_type::THP_CREATE_NEW_SESSION;

        log::info!("[BLE] Creating new THP session...");

        // IMPORTANT: Create session_id=1 BEFORE sending ThpCreateNewSession
        // The session_id is used in the encrypted message header
        {
            let mut devices = self.devices.write().await;
            let device = devices
                .get_mut(path)
                .ok_or(TransportError::DeviceNotFound)?;
            let session_id = device.protocol.state_mut().create_new_session_id();
            log::debug!(
                "[BLE] Created session ID {} for ThpCreateNewSession and future messages",
                session_id
            );
        }

        // Bind the configured passphrase to the session. For on-device entry the
        // passphrase field is omitted (firmware rejects empty-passphrase +
        // on_device); the Trezor then prompts on its own screen. Otherwise an
        // empty passphrase opens the standard wallet and a non-empty one a hidden
        // wallet.
        let passphrase_opt = if self.session_on_device {
            None
        } else {
            Some(self.session_passphrase.as_str())
        };
        let session_payload = encode_create_new_session(passphrase_opt, self.session_on_device);

        log::debug!(
            "[BLE] Sending ThpCreateNewSession (type {}, {} bytes)",
            THP_CREATE_NEW_SESSION,
            session_payload.len()
        );

        let (resp_type, resp_data) = self
            .send_encrypted_message(path, THP_CREATE_NEW_SESSION, &session_payload)
            .await?;

        // Handle response - might need to handle ButtonRequest for passphrase on device
        let (final_type, final_data) = self
            .handle_session_response(path, resp_type, resp_data)
            .await?;

        if final_type == crate::constants::message_type::SUCCESS {
            log::info!("[BLE] THP session created successfully!");
            Ok(())
        } else if final_type == crate::constants::message_type::FAILURE {
            // Decode the device's reason so the failure is actionable.
            let detail = crate::transport::decode_failure_detail(&final_data);
            log::warn!("[BLE] ThpCreateNewSession rejected: {}", detail);
            Err(ThpError::SessionError(format!("ThpCreateNewSession rejected ({})", detail)).into())
        } else {
            Err(ThpError::SessionError(format!(
                "Unexpected response to ThpCreateNewSession: type {}",
                final_type
            ))
            .into())
        }
    }

    /// Handle session response, processing ButtonRequests as needed
    async fn handle_session_response(
        &self,
        path: &str,
        mut resp_type: u16,
        mut resp_data: Vec<u8>,
    ) -> Result<(u16, Vec<u8>)> {
        use crate::constants::message_type::{BUTTON_ACK, BUTTON_REQUEST};

        // Loop to handle ButtonRequests (e.g., for passphrase on device)
        while resp_type == BUTTON_REQUEST {
            log::info!(
                "[BLE] Received ButtonRequest during session creation - confirm on device if needed"
            );

            // Send ButtonAck
            let (next_type, next_data) = self.send_encrypted_message(path, BUTTON_ACK, &[]).await?;

            resp_type = next_type;
            resp_data = next_data;
        }

        Ok((resp_type, resp_data))
    }

    /// Write a single BLE chunk with adaptive flow control.
    ///
    /// Uses WriteWithResponse for the first 8 packets and every 16th packet
    /// thereafter to provide BLE backpressure.
    async fn write_chunk_ble(
        device: &ConnectedDevice,
        rx_char: &btleplug::api::Characteristic,
        chunk: &[u8],
    ) -> Result<()> {
        let count = device
            .write_count
            .fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        let write_type = if count < 8 || count % 16 == 0 {
            WriteType::WithResponse
        } else {
            WriteType::WithoutResponse
        };

        device
            .peripheral
            .write(rx_char, chunk, write_type)
            .await
            .map_err(|e| TransportError::DataTransfer(format!("Write failed: {}", e)))?;

        // Small delay to allow device to process
        tokio::time::sleep(Duration::from_millis(50)).await;
        Ok(())
    }

    /// Write raw data to device (bypassing protocol)
    ///
    /// Data is padded to BLE_CHUNK_SIZE if smaller.
    /// If data exceeds BLE_CHUNK_SIZE, splits into first chunk + continuation
    /// packets with `[0x80, channel[0], channel[1], ...data...]` header.
    async fn write_raw(&self, path: &str, data: &[u8]) -> Result<()> {
        let devices = self.devices.read().await;
        let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;

        let characteristics = device.peripheral.characteristics();
        let rx_char = characteristics
            .iter()
            .find(|c| c.uuid == BLE_CHARACTERISTIC_RX)
            .ok_or_else(|| {
                TransportError::DataTransfer("RX characteristic not found".to_string())
            })?;

        if data.len() <= BLE_CHUNK_SIZE {
            // Single chunk - pad to BLE_CHUNK_SIZE
            let mut padded_data = vec![0u8; BLE_CHUNK_SIZE];
            padded_data[..data.len()].copy_from_slice(data);

            log::debug!(
                "[BLE] Writing {} bytes (padded to {})",
                data.len(),
                padded_data.len()
            );

            Self::write_chunk_ble(device, rx_char, &padded_data).await?;
        } else {
            // Multi-chunk: extract channel from first chunk bytes [1..3]
            let channel = if data.len() >= 3 {
                [data[1], data[2]]
            } else {
                [0, 0]
            };

            log::debug!(
                "[BLE] Multi-chunk write: {} bytes total, chunk_size={}",
                data.len(),
                BLE_CHUNK_SIZE
            );

            // First chunk: first BLE_CHUNK_SIZE bytes, padded
            let first_end = BLE_CHUNK_SIZE.min(data.len());
            let mut first_chunk = vec![0u8; BLE_CHUNK_SIZE];
            first_chunk[..first_end].copy_from_slice(&data[..first_end]);

            Self::write_chunk_ble(device, rx_char, &first_chunk).await?;

            // Continuation chunks: [CONTINUATION_PACKET | channel(2) | data...]
            let cont_header_len = 3;
            let cont_payload_size = BLE_CHUNK_SIZE - cont_header_len;
            let mut offset = first_end;

            while offset < data.len() {
                let end = (offset + cont_payload_size).min(data.len());
                let mut cont_chunk = vec![0u8; BLE_CHUNK_SIZE];
                cont_chunk[0] = thp_control::CONTINUATION_PACKET;
                cont_chunk[1] = channel[0];
                cont_chunk[2] = channel[1];
                let payload_len = end - offset;
                cont_chunk[cont_header_len..cont_header_len + payload_len]
                    .copy_from_slice(&data[offset..end]);

                log::debug!(
                    "[BLE] Writing continuation chunk: {} bytes payload at offset {}",
                    payload_len,
                    offset
                );

                Self::write_chunk_ble(device, rx_char, &cont_chunk).await?;
                offset = end;
            }
        }

        log::debug!("[BLE] Write completed successfully");
        Ok(())
    }

    /// Read with timeout using the notification channel
    async fn read_with_timeout(&self, path: &str, timeout: Duration) -> Result<Vec<u8>> {
        let rx = {
            let devices = self.devices.read().await;
            let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;
            device.rx.clone()
        };

        let mut rx_guard = rx.lock().await;

        match tokio::time::timeout(timeout, rx_guard.recv()).await {
            Ok(Some(data)) => {
                log::trace!("[BLE] Read {} bytes from channel", data.len());
                Ok(data)
            }
            Ok(None) => {
                Err(TransportError::DataTransfer("Notification channel closed".to_string()).into())
            }
            Err(_) => Err(TransportError::DataTransfer("Read timeout".to_string()).into()),
        }
    }

    /// Check if message is an ACK
    fn is_ack(data: &[u8]) -> bool {
        if data.is_empty() {
            return false;
        }
        (data[0] & 0xf7) == thp_control::ACK_MESSAGE
    }

    /// Validate CRC32 on a received THP message.
    ///
    /// The message format is: [header..data | crc(4)]
    /// The CRC is computed over everything before the trailing 4 bytes.
    fn validate_crc(data: &[u8]) -> Result<()> {
        // Minimum message: ctrl(1) + channel(2) + length(2) + crc(4) = 9 bytes
        if data.len() < 9 {
            return Ok(()); // Too short to have CRC, skip validation
        }
        let payload_len = u16::from_be_bytes([data[3], data[4]]) as usize;
        let total_expected = 5 + payload_len; // header(5) + payload (which includes CRC)
        if total_expected > data.len() || payload_len < 4 {
            return Ok(()); // Can't validate incomplete messages
        }
        let crc_offset = 5 + payload_len - 4;
        let message_part = &data[..crc_offset];
        let received_crc = &data[crc_offset..crc_offset + 4];
        let computed_crc = crate::protocol::thp::crypto::crc32(message_part);
        if received_crc != computed_crc {
            return Err(ThpError::DecryptionError(format!(
                "CRC32 mismatch: expected {:02x?}, got {:02x?}",
                computed_crc, received_crc
            ))
            .into());
        }
        Ok(())
    }

    /// Validate that the channel in a received message matches the expected channel.
    fn validate_channel(&self, data: &[u8], expected_channel: &[u8; 2]) -> Result<()> {
        if data.len() < 3 {
            return Ok(());
        }
        // Channel allocation responses use broadcast channel 0xFFFF, skip validation
        if data[0] == thp_control::CHANNEL_ALLOCATION_RES {
            return Ok(());
        }
        let msg_channel = &data[1..3];
        if msg_channel != expected_channel {
            return Err(ThpError::DecryptionError(format!(
                "Channel mismatch: expected {:02x?}, got {:02x?}",
                expected_channel, msg_channel
            ))
            .into());
        }
        Ok(())
    }

    /// Read response, skipping ACKs.
    ///
    /// Validates CRC32 and channel on every received message.
    async fn read_response(&self, path: &str, timeout: Duration) -> Result<Vec<u8>> {
        // Get expected channel for validation (0 if not yet allocated)
        let expected_channel = {
            let devices = self.devices.read().await;
            match devices.get(path) {
                Some(device) => *device.protocol.state().channel(),
                None => [0, 0],
            }
        };

        loop {
            let data = self.read_with_timeout(path, timeout).await?;
            let ctrl_byte = data.get(0).copied().unwrap_or(0);
            let ctrl_type = ctrl_byte & 0xe7;

            log::debug!(
                "[BLE] << Received: ctrl=0x{:02x} (type=0x{:02x}), {} bytes",
                ctrl_byte,
                ctrl_type,
                data.len()
            );

            // Validate CRC32 on the received message
            Self::validate_crc(&data)?;

            // Validate channel matches (skip if channel not yet allocated)
            if expected_channel != [0, 0] {
                self.validate_channel(&data, &expected_channel)?;
            }

            if Self::is_ack(&data) {
                log::trace!("[BLE] (This is an ACK, waiting for actual response...)");
                continue;
            }

            // Check for error message
            if ctrl_type == thp_control::ERROR {
                let error_code = data.get(5).copied().unwrap_or(0);
                let error_name = match error_code {
                    0x01 => "TransportBusy",
                    0x02 => "UnallocatedChannel",
                    0x03 => "DecryptionFailed",
                    0x05 => "DeviceLocked",
                    _ => "Unknown",
                };
                log::error!("[BLE] THP Error: {} (0x{:02x})", error_name, error_code);
            }

            return Ok(data);
        }
    }

    /// Send an encrypted THP message and receive the response
    pub async fn send_encrypted_message(
        &self,
        path: &str,
        message_type: u16,
        data: &[u8],
    ) -> Result<(u16, Vec<u8>)> {
        // Get channel and encode encrypted message
        let (channel, message) = {
            let devices = self.devices.read().await;
            let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;
            let channel = *device.protocol.state().channel();
            let message = encode_encrypted_message(device.protocol.state(), message_type, data)?;
            (channel, message)
        };

        log::debug!(
            "[BLE] Sending encrypted message type {} ({} bytes)",
            message_type,
            message.len()
        );
        self.write_raw(path, &message).await?;

        // Toggle send_bit and increment send_nonce after sending
        {
            let mut devices = self.devices.write().await;
            let device = devices
                .get_mut(path)
                .ok_or(TransportError::DeviceNotFound)?;
            device.protocol.state_mut().update_sync_bit(true);
            device
                .protocol
                .state_mut()
                .update_nonce(true)
                .map_err(|e| ThpError::EncryptionError(e.to_string()))?;
        }

        // Wait for response (skip ACKs)
        let response = self.read_response(path, Duration::from_secs(60)).await?;

        // Send ACK for response
        let ack_bit = (response[0] >> 4) & 1;
        let ack = encode_ack(&channel, ack_bit);
        self.write_raw(path, &ack).await?;

        // Decrypt response - may need to read continuation packets
        let (resp_type, resp_data) = {
            // Check minimum response length first
            if response.len() < 5 {
                return Err(ThpError::DecryptionError(format!(
                    "Response too short: {} bytes, raw: {:02x?}",
                    response.len(),
                    response
                ))
                .into());
            }

            // Extract encrypted payload length from response header
            let payload_len = u16::from_be_bytes([response[3], response[4]]) as usize;
            let crc_len = 4;
            let header_len = 5; // ctrl(1) + channel(2) + length(2)

            log::debug!(
                "[BLE] Response payload_len={}, first chunk has {} bytes",
                payload_len,
                response.len()
            );

            // Calculate how much data we have and need
            let first_chunk_payload = response.len().saturating_sub(header_len);
            let total_needed = payload_len; // Total encrypted payload including CRC

            // Reassemble full payload from multiple chunks if needed
            let mut full_payload = Vec::new();
            full_payload.extend_from_slice(&response[header_len..]);

            // Read continuation packets if needed
            if first_chunk_payload < total_needed {
                log::debug!(
                    "[BLE] Need more data: have {}, need {}",
                    first_chunk_payload,
                    total_needed
                );

                while full_payload.len() < total_needed {
                    // Read next chunk
                    let cont = self.read_response(path, Duration::from_secs(30)).await?;
                    let cont_ctrl = cont.get(0).copied().unwrap_or(0);

                    // Check if it's a continuation packet (0x80 or 0x80 | sync_bit)
                    if (cont_ctrl & 0xe7) != thp_control::CONTINUATION_PACKET {
                        log::warn!(
                            "[BLE] Expected continuation packet, got ctrl=0x{:02x}",
                            cont_ctrl
                        );
                        break;
                    }

                    // Continuation packet format: ctrl(1) + channel(2) + data
                    let cont_header_len = 3;
                    if cont.len() > cont_header_len {
                        full_payload.extend_from_slice(&cont[cont_header_len..]);
                        log::debug!(
                            "[BLE] Read continuation: {} bytes, total now {} bytes",
                            cont.len() - cont_header_len,
                            full_payload.len()
                        );
                    }
                }

                if full_payload.len() < total_needed {
                    return Err(ThpError::DecryptionError(format!(
                        "Incomplete payload: have {}, need {}",
                        full_payload.len(),
                        total_needed
                    ))
                    .into());
                }
            }

            // Now we have the complete encrypted payload (including CRC)
            if payload_len <= crc_len || full_payload.len() < payload_len {
                return Err(ThpError::DecryptionError(format!(
                    "Invalid payload: payload_len={}, full_payload.len()={}",
                    payload_len,
                    full_payload.len()
                ))
                .into());
            }

            // Get protocol state for decryption
            let devices = self.devices.read().await;
            let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;

            // Decrypt using trezor_key
            let creds = device
                .protocol
                .state()
                .handshake_credentials()
                .ok_or(ThpError::StateMissing)?;

            let key: [u8; 32] = creds
                .trezor_key
                .clone()
                .try_into()
                .map_err(|_| ThpError::DecryptionError("Invalid key".to_string()))?;

            // Extract the encrypted payload (without CRC) from full_payload
            let encrypted_payload = &full_payload[..payload_len - crc_len];

            let recv_nonce = device.protocol.state().recv_nonce();
            log::debug!(
                "[BLE] Decrypting with recv_nonce={}, encrypted_payload={} bytes",
                recv_nonce,
                encrypted_payload.len()
            );
            let iv = crate::protocol::thp::crypto::get_iv_from_nonce(recv_nonce);
            // THP uses empty AAD for post-handshake encrypted messages
            let aad: &[u8] = &[];

            let decrypted =
                crate::protocol::thp::crypto::aes_gcm_decrypt(&key, &iv, aad, encrypted_payload)?;

            log::debug!("[BLE] Decrypted {} bytes", decrypted.len());

            // THP encrypted payload format: [session_id: 1 byte][message_type: 2 bytes][protobuf_data]
            if decrypted.len() < 3 {
                return Err(
                    ThpError::DecryptionError("Decrypted payload too short".to_string()).into(),
                );
            }

            let session_id = decrypted[0];
            let msg_type = u16::from_be_bytes([decrypted[1], decrypted[2]]);
            let msg_data = decrypted[3..].to_vec();
            log::debug!(
                "[BLE] Session ID: {}, Message type: {}",
                session_id,
                msg_type
            );

            (msg_type, msg_data)
        };

        // Update recv_bit and recv_nonce after successful decryption
        {
            let mut devices = self.devices.write().await;
            let device = devices
                .get_mut(path)
                .ok_or(TransportError::DeviceNotFound)?;
            device.protocol.state_mut().update_sync_bit(false);
            device
                .protocol
                .state_mut()
                .update_nonce(false)
                .map_err(|e| ThpError::DecryptionError(e.to_string()))?;
        }

        log::debug!(
            "[BLE] Received encrypted response type {} ({} bytes)",
            resp_type,
            resp_data.len()
        );
        Ok((resp_type, resp_data))
    }

    /// Perform the pairing flow
    pub async fn perform_pairing(
        &self,
        path: &str,
        code_callback: impl Fn() -> String,
    ) -> Result<()> {
        use crate::constants::{message_type, thp_message_type, thp_pairing_method};
        use crate::protocol::thp::pairing::{get_cpace_host_keys, get_shared_secret};
        use crate::protocol::thp::pairing_messages::*;

        log::info!("[BLE] Starting pairing flow...");

        // Step 1: Send ThpPairingRequest
        let pairing_request = encode_pairing_request(&self.host_name, &self.app_name);
        log::info!("[BLE] Sending pairing request...");

        let (mut resp_type, _) = self
            .send_encrypted_message(
                path,
                thp_message_type::THP_PAIRING_REQUEST,
                &pairing_request,
            )
            .await?;

        // Handle ButtonRequest - user needs to confirm on device
        if resp_type == message_type::BUTTON_REQUEST {
            log::info!("[BLE] ============================================================");
            log::info!("[BLE] >>> CONFIRM PAIRING ON YOUR TREZOR SCREEN! <<<");
            log::info!("[BLE] ============================================================");

            // Send ButtonAck
            let (next_type, _) = self
                .send_encrypted_message(
                    path,
                    message_type::BUTTON_ACK,
                    &[], // Empty payload for ButtonAck
                )
                .await?;
            resp_type = next_type;
        }

        if resp_type != thp_message_type::THP_PAIRING_REQUEST_APPROVED {
            return Err(ThpError::PairingFailed(format!(
                "Expected ThpPairingRequestApproved ({}), got {}",
                thp_message_type::THP_PAIRING_REQUEST_APPROVED,
                resp_type
            ))
            .into());
        }
        log::info!("[BLE] Pairing request approved by user!");

        // Step 2: Send ThpSelectMethod (CodeEntry)
        let select_method = encode_select_method(thp_pairing_method::CODE_ENTRY);
        log::info!("[BLE] Selecting code entry pairing method...");

        let (resp_type, commitment_data) = self
            .send_encrypted_message(path, thp_message_type::THP_SELECT_METHOD, &select_method)
            .await?;

        // Generate a single challenge to use throughout the pairing flow
        let challenge: [u8; 32] = rand::random();
        let challenge_payload = encode_code_entry_challenge(&challenge);

        // Device may send ThpPairingPreparationsFinished or directly ThpCodeEntryCommitment
        let commitment_data = if resp_type == thp_message_type::THP_PAIRING_PREPARATIONS_FINISHED {
            log::info!("[BLE] Pairing preparations finished!");

            // Send challenge and wait for ThpCodeEntryCommitment
            log::info!("[BLE] Sending code entry challenge...");
            let (resp_type, commitment_data) = self
                .send_encrypted_message(
                    path,
                    thp_message_type::THP_CODE_ENTRY_CHALLENGE,
                    &challenge_payload,
                )
                .await?;

            if resp_type != thp_message_type::THP_CODE_ENTRY_COMMITMENT {
                return Err(ThpError::PairingFailed(format!(
                    "Expected ThpCodeEntryCommitment ({}), got {}",
                    thp_message_type::THP_CODE_ENTRY_COMMITMENT,
                    resp_type
                ))
                .into());
            }
            commitment_data
        } else if resp_type == thp_message_type::THP_CODE_ENTRY_COMMITMENT {
            log::info!("[BLE] Device sent commitment directly after method selection");
            commitment_data
        } else {
            return Err(ThpError::PairingFailed(format!(
                "Expected ThpPairingPreparationsFinished ({}) or ThpCodeEntryCommitment ({}), got {}",
                thp_message_type::THP_PAIRING_PREPARATIONS_FINISHED,
                thp_message_type::THP_CODE_ENTRY_COMMITMENT,
                resp_type
            )).into());
        };

        let commitment = decode_code_entry_commitment(&commitment_data)?;
        log::info!("[BLE] Received code entry commitment");

        // Store commitment and challenge in handshake credentials for later validation
        {
            let mut devices = self.devices.write().await;
            let device = devices
                .get_mut(path)
                .ok_or(TransportError::DeviceNotFound)?;
            if let Some(creds) = device.protocol.state_mut().handshake_credentials_mut() {
                creds.handshake_commitment = commitment.clone();
                creds.code_entry_challenge = challenge.to_vec();
            }
        }

        // Step 3: Send the same challenge again to get CPACE Trezor pubkey
        // (must use the same challenge the commitment was generated against)
        log::info!("[BLE] Sending code entry challenge...");
        let (resp_type, cpace_data) = self
            .send_encrypted_message(
                path,
                thp_message_type::THP_CODE_ENTRY_CHALLENGE,
                &challenge_payload,
            )
            .await?;

        if resp_type != thp_message_type::THP_CODE_ENTRY_CPACE_TREZOR {
            return Err(ThpError::PairingFailed(format!(
                "Expected ThpCodeEntryCpaceTrezor ({}), got {}",
                thp_message_type::THP_CODE_ENTRY_CPACE_TREZOR,
                resp_type
            ))
            .into());
        }
        let trezor_cpace_pubkey = decode_cpace_trezor(&cpace_data)?;

        log::info!("[BLE] Received Trezor CPACE public key");
        log::info!("[BLE] ============================================================");
        log::info!("[BLE] >>> LOOK AT YOUR TREZOR SCREEN! <<<");
        log::info!("[BLE] A 6-digit code should be displayed.");
        log::info!("[BLE] ============================================================");

        // Step 4: Get the code from user
        let code = code_callback();
        log::info!("[BLE] User entered code (len={})", code.len());

        // Step 5: Generate CPACE keys with the code
        let handshake_hash = {
            let devices = self.devices.read().await;
            let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;
            device
                .protocol
                .state()
                .handshake_credentials()
                .map(|c| c.handshake_hash.clone())
                .unwrap_or_default()
        };

        log::debug!("[BLE] CPACE: code len = {}", code.len());
        log::debug!("[BLE] CPACE: handshake_hash len = {}", handshake_hash.len());
        log::debug!(
            "[BLE] CPACE: trezor_cpace_pubkey len = {}",
            trezor_cpace_pubkey.len()
        );

        let cpace_keys = get_cpace_host_keys(code.as_bytes(), &handshake_hash);
        log::debug!("[BLE] CPACE: host_pubkey generated (32 bytes)");

        // Compute shared secret and tag
        // The tag is the FULL 32-byte SHA-256 of the shared secret, not truncated
        let shared_secret = Zeroizing::new(get_shared_secret(
            &trezor_cpace_pubkey,
            &cpace_keys.private_key,
        ));
        log::debug!(
            "[BLE] CPACE: shared_secret derived ({} bytes)",
            shared_secret.len()
        );
        let tag = &shared_secret[..]; // Full 32 bytes as tag

        // Step 6: Send ThpCodeEntryCpaceHostTag
        let cpace_host_tag = encode_cpace_host_tag(&cpace_keys.public_key, tag);
        log::info!("[BLE] Sending CPACE host tag...");

        let (resp_type, secret_data) = self
            .send_encrypted_message(
                path,
                thp_message_type::THP_CODE_ENTRY_CPACE_HOST_TAG,
                &cpace_host_tag,
            )
            .await?;

        if resp_type == message_type::FAILURE {
            // Parse failure message for better error reporting
            let error_msg = parse_failure_message(&secret_data);
            return Err(ThpError::PairingFailed(format!(
                "Code verification failed: {}",
                error_msg
            ))
            .into());
        }

        if resp_type != thp_message_type::THP_CODE_ENTRY_SECRET {
            return Err(ThpError::PairingFailed(format!(
                "Expected ThpCodeEntrySecret ({}), got {}",
                thp_message_type::THP_CODE_ENTRY_SECRET,
                resp_type
            ))
            .into());
        }

        let secret = decode_code_entry_secret(&secret_data)?;
        log::info!("[BLE] Received code entry secret - verifying commitment...");

        // Validate the code entry tag: verify the device's commitment matches the secret
        // and the displayed code matches the expected value derived from the handshake.
        {
            let devices = self.devices.read().await;
            let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;
            if let Some(creds) = device.protocol.state().handshake_credentials() {
                crate::protocol::thp::pairing::validate_code_entry_tag(creds, &code, &secret)?;
                log::info!("[BLE] Code entry tag validated successfully!");
            } else {
                return Err(ThpError::StateMissing.into());
            }
        }

        // Step 7: Send ThpCredentialRequest
        let host_static_pubkey = {
            let devices = self.devices.read().await;
            let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;
            device
                .protocol
                .state()
                .handshake_credentials()
                .map(|c| c.host_static_public_key.clone())
                .unwrap_or_default()
        };

        let credential_request = encode_credential_request(&host_static_pubkey, false, None);
        log::info!("[BLE] Sending credential request...");

        let (resp_type, credential_data) = self
            .send_encrypted_message(
                path,
                thp_message_type::THP_CREDENTIAL_REQUEST,
                &credential_request,
            )
            .await?;

        // Handle ButtonRequest if device needs confirmation
        let (resp_type, credential_data) = if resp_type == message_type::BUTTON_REQUEST {
            log::info!("[BLE] Device requesting confirmation for credential...");
            // Send ButtonAck
            let (next_type, next_data) = self
                .send_encrypted_message(path, message_type::BUTTON_ACK, &[])
                .await?;
            (next_type, next_data)
        } else {
            (resp_type, credential_data)
        };

        // Check for Failure
        if resp_type == message_type::FAILURE {
            let error_msg = parse_failure_message(&credential_data);
            return Err(ThpError::PairingFailed(format!(
                "Credential request failed: {}",
                error_msg
            ))
            .into());
        }

        if resp_type != thp_message_type::THP_CREDENTIAL_RESPONSE {
            return Err(ThpError::PairingFailed(format!(
                "Expected ThpCredentialResponse ({}), got {}",
                thp_message_type::THP_CREDENTIAL_RESPONSE,
                resp_type
            ))
            .into());
        }

        let (trezor_pubkey, credential) = decode_credential_response(&credential_data)?;
        log::info!("[BLE] Received credential response!");
        log::debug!("[BLE] Trezor static pubkey: {} bytes", trezor_pubkey.len());
        log::debug!("[BLE] Credential: {} bytes", credential.len());

        // Store credentials for future reconnection (skip pairing next time)
        {
            let mut devices = self.devices.write().await;
            let device = devices
                .get_mut(path)
                .ok_or(TransportError::DeviceNotFound)?;
            // Get the host static private key from handshake credentials
            let host_static_private_key = device
                .protocol
                .state()
                .handshake_credentials()
                .map(|c| c.static_key.clone())
                .unwrap_or_default();
            let stored_creds = crate::protocol::thp::state::ThpCredentials {
                host_static_key: hex::encode(&host_static_private_key),
                trezor_static_public_key: hex::encode(&trezor_pubkey),
                credential: hex::encode(&credential),
                autoconnect: false,
            };
            // Replace (not append): if a stale stored credential forced this
            // re-pair, appending would leave it first in the list and it
            // would keep being presented and re-saved.
            device
                .protocol
                .state_mut()
                .set_pairing_credentials(stored_creds);
            log::info!("[BLE] Stored pairing credentials for future reconnection");
        }

        // Step 8: Send ThpEndRequest to finalize pairing
        log::info!("[BLE] Sending ThpEndRequest to finalize pairing...");
        let (end_resp_type, _end_data) = self
            .send_encrypted_message(path, thp_message_type::THP_END_REQUEST, &[])
            .await?;

        if end_resp_type != thp_message_type::THP_END_RESPONSE {
            return Err(ThpError::PairingFailed(format!(
                "Expected ThpEndResponse ({}), got {}",
                thp_message_type::THP_END_RESPONSE,
                end_resp_type
            ))
            .into());
        }

        log::info!("[BLE] Received ThpEndResponse - pairing finalized!");

        // Note: is_paired and session creation are handled after pairing returns
        // in perform_thp_handshake_inner's create_thp_session call

        log::info!("[BLE] Pairing flow completed successfully!");
        Ok(())
    }
}

#[async_trait]
impl TransportApi for BluetoothTransport {
    fn chunk_size(&self) -> usize {
        BLE_CHUNK_SIZE
    }

    async fn enumerate(&self) -> Result<Vec<DeviceDescriptor>> {
        let adapter = self
            .adapter
            .as_ref()
            .ok_or_else(|| TransportError::Bluetooth("No Bluetooth adapter found".to_string()))?;

        let peripherals = adapter
            .peripherals()
            .await
            .map_err(|e| TransportError::Bluetooth(e.to_string()))?;

        log::debug!("[BLE] Found {} peripherals during scan", peripherals.len());

        let mut descriptors = Vec::new();

        for peripheral in peripherals {
            if let Ok(Some(props)) = peripheral.properties().await {
                let name = props.local_name.as_deref().unwrap_or("Unknown");
                log::debug!(
                    "[BLE] Peripheral: {} (name: {}, services: {:?})",
                    peripheral.id(),
                    name,
                    props.services
                );

                // Check if this is a Trezor device by service UUID
                let is_trezor = props.services.contains(&BLE_SERVICE_UUID);

                if is_trezor {
                    let path = peripheral.id().to_string();
                    log::info!("[BLE] Found Trezor device: {} ({})", name, path);
                    descriptors.push(DeviceDescriptor {
                        path: path.clone(),
                        vendor_id: 0,
                        product_id: 0,
                        serial_number: props.local_name.clone(),
                        session: self.sessions.get_session(&path),
                    });
                }
            }
        }

        Ok(descriptors)
    }

    async fn open(&self, path: &str) -> Result<()> {
        let adapter = self
            .adapter
            .as_ref()
            .ok_or_else(|| TransportError::Bluetooth("No Bluetooth adapter found".to_string()))?;

        let peripherals = adapter
            .peripherals()
            .await
            .map_err(|e| TransportError::Bluetooth(e.to_string()))?;

        let peripheral = peripherals
            .into_iter()
            .find(|p| p.id().to_string() == path)
            .ok_or(TransportError::DeviceNotFound)?;

        // Connect to device
        peripheral
            .connect()
            .await
            .map_err(|e| TransportError::UnableToOpen(e.to_string()))?;

        // Discover services
        peripheral
            .discover_services()
            .await
            .map_err(|e| TransportError::UnableToOpen(e.to_string()))?;

        // Log all characteristics for debugging
        let all_chars = peripheral.characteristics();
        log::debug!("[BLE] Discovered {} characteristics:", all_chars.len());
        for c in &all_chars {
            log::debug!("[BLE]   - {} properties: {:?}", c.uuid, c.properties);
        }

        // Subscribe to TX characteristic for notifications
        let characteristics = peripheral.characteristics();
        let tx_char = characteristics
            .iter()
            .find(|c| c.uuid == BLE_CHARACTERISTIC_TX)
            .ok_or_else(|| {
                TransportError::UnableToOpen("TX characteristic not found".to_string())
            })?;

        peripheral
            .subscribe(tx_char)
            .await
            .map_err(|e| TransportError::UnableToOpen(e.to_string()))?;

        log::debug!("[BLE] Subscribed to TX notifications");

        // Also subscribe to push notification characteristic (8c000004)
        if let Some(push_char) = characteristics
            .iter()
            .find(|c| c.uuid == crate::constants::BLE_CHARACTERISTIC_PUSH)
        {
            if let Err(e) = peripheral.subscribe(push_char).await {
                log::warn!("[BLE] Failed to subscribe to PUSH notifications: {}", e);
            } else {
                log::debug!("[BLE] Subscribed to PUSH notifications");
            }
        }

        // Create channel for notifications (larger buffer to avoid BLE backpressure)
        let (tx, rx) = mpsc::channel::<Vec<u8>>(256);

        // Create shutdown signal for clean cancellation
        let (shutdown_tx, mut shutdown_rx) = tokio::sync::watch::channel(false);

        // Spawn task to handle notifications
        let peripheral_clone = peripheral.clone();
        tokio::spawn(async move {
            log::debug!("[BLE] Notification handler task started");
            match peripheral_clone.notifications().await {
                Ok(mut stream) => {
                    log::debug!("[BLE] Notification stream created successfully");
                    loop {
                        tokio::select! {
                            notification = stream.next() => {
                                match notification {
                                    Some(notification) => {
                                        // Only process notifications from the TX characteristic (THP data)
                                        if notification.uuid != BLE_CHARACTERISTIC_TX {
                                            log::debug!("[BLE] Ignoring notification from non-TX char: {}",
                                                notification.uuid);
                                            continue;
                                        }

                                        log::debug!("[BLE] Notification received: {} bytes",
                                            notification.value.len());
                                        if tx.send(notification.value).await.is_err() {
                                            log::debug!("[BLE] Notification channel closed");
                                            break;
                                        }
                                    }
                                    None => {
                                        log::debug!("[BLE] Notification stream ended");
                                        break;
                                    }
                                }
                            }
                            _ = shutdown_rx.changed() => {
                                log::debug!("[BLE] Notification handler received shutdown signal");
                                break;
                            }
                        }
                    }
                }
                Err(e) => {
                    log::error!("[BLE] Failed to get notification stream: {}", e);
                }
            }
            log::debug!("[BLE] Notification handler exited");
        });

        // Give notification handler time to start
        tokio::time::sleep(Duration::from_millis(100)).await;

        // Store device with its own THP protocol state
        let mut devices = self.devices.write().await;
        devices.insert(
            path.to_string(),
            ConnectedDevice {
                peripheral,
                handshake_complete: false,
                protocol: ProtocolThp::new(),
                rx: Arc::new(Mutex::new(rx)),
                shutdown_tx,
                write_count: std::sync::atomic::AtomicU32::new(0),
            },
        );

        Ok(())
    }

    async fn close(&self, path: &str) -> Result<()> {
        let mut devices = self.devices.write().await;

        if let Some(device) = devices.remove(path) {
            // Signal the notification handler to stop
            let _ = device.shutdown_tx.send(true);

            device
                .peripheral
                .disconnect()
                .await
                .map_err(|e| TransportError::UnableToClose(e.to_string()))?;
        }

        Ok(())
    }

    async fn read(&self, path: &str) -> Result<Vec<u8>> {
        let rx = {
            let devices = self.devices.read().await;
            let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;
            device.rx.clone()
        };

        let mut rx_guard = rx.lock().await;

        // Wait for next notification from channel
        rx_guard.recv().await.ok_or_else(|| {
            TransportError::DataTransfer("Notification channel closed".to_string()).into()
        })
    }

    async fn write(&self, path: &str, data: &[u8]) -> Result<()> {
        let devices = self.devices.read().await;
        let device = devices.get(path).ok_or(TransportError::DeviceNotFound)?;

        // Find RX characteristic
        let characteristics = device.peripheral.characteristics();
        let rx_char = characteristics
            .iter()
            .find(|c| c.uuid == BLE_CHARACTERISTIC_RX)
            .ok_or_else(|| {
                TransportError::DataTransfer("RX characteristic not found".to_string())
            })?;

        // Write data
        device
            .peripheral
            .write(rx_char, data, WriteType::WithoutResponse)
            .await
            .map_err(|e| TransportError::DataTransfer(e.to_string()))?;

        Ok(())
    }
}

#[async_trait]
impl Transport for BluetoothTransport {
    async fn init(&mut self) -> Result<()> {
        self.start_scan().await?;
        // Give BLE time to discover devices
        log::debug!("[BLE] Scanning for 5 seconds...");
        tokio::time::sleep(std::time::Duration::from_secs(5)).await;
        Ok(())
    }

    async fn enumerate(&self) -> Result<Vec<DeviceDescriptor>> {
        TransportApi::enumerate(self).await
    }

    async fn acquire(&self, path: &str, previous: Option<&str>) -> Result<String> {
        // Open device if not already connected
        let needs_handshake = {
            let devices = self.devices.read().await;
            if !devices.contains_key(path) {
                drop(devices);
                self.open(path).await?;
                true
            } else {
                !devices
                    .get(path)
                    .map(|d| d.handshake_complete)
                    .unwrap_or(false)
            }
        };

        // Perform THP handshake if needed
        if needs_handshake {
            self.perform_thp_handshake(path).await?;

            // Mark handshake as complete
            let mut devices = self.devices.write().await;
            if let Some(device) = devices.get_mut(path) {
                device.handshake_complete = true;
            }
        }

        self.sessions
            .acquire(path, previous)
            .map_err(|e| TransportError::DataTransfer(e.to_string()).into())
    }

    async fn release(&self, session: &str) -> Result<()> {
        if let Some(path) = self.sessions.get_path(session) {
            self.close(&path).await?;
            // Clean up the call lock for this device
            if let Ok(mut locks) = self.call_locks.lock() {
                locks.remove(&path);
            }
        }
        self.sessions
            .release(session)
            .map_err(|e| TransportError::DataTransfer(e.to_string()).into())
    }

    async fn call(&self, session: &str, message_type: u16, data: &[u8]) -> Result<(u16, Vec<u8>)> {
        let path = self
            .sessions
            .get_path(session)
            .ok_or(TransportError::DeviceNotFound)?;

        // Serialize all calls to the same device to prevent interleaved reads/writes
        let lock = self.get_call_lock(&path);
        let _guard = lock.lock().await;

        // Check if THP handshake is complete - if so, use encrypted messaging
        let is_paired = {
            let devices = self.devices.read().await;
            let device = devices
                .get(path.as_str())
                .ok_or(TransportError::DeviceNotFound)?;
            device.protocol.state().is_paired()
        };

        if is_paired {
            // Use THP encrypted messaging
            log::debug!(
                "[BLE] Using THP encrypted call for message type {}",
                message_type
            );
            self.send_encrypted_message(&path, message_type, data).await
        } else {
            // Fall back to unencrypted messaging (for pre-handshake)
            log::debug!(
                "[BLE] Using unencrypted call for message type {}",
                message_type
            );

            let (_encoded, chunks) = {
                let devices = self.devices.read().await;
                let device = devices
                    .get(path.as_str())
                    .ok_or(TransportError::DeviceNotFound)?;
                let encoded = device.protocol.encode(message_type, data)?;
                let (_, chunk_header) = device.protocol.get_headers(&encoded);
                let chunks = chunk::create_chunks(&encoded, &chunk_header, BLE_CHUNK_SIZE);
                (encoded, chunks)
            };

            // Send all chunks
            for c in &chunks {
                self.write(&path, c).await?;
            }

            // Read response
            let first_chunk = self.read(&path).await?;
            let devices = self.devices.read().await;
            let device = devices
                .get(path.as_str())
                .ok_or(TransportError::DeviceNotFound)?;
            let decoded = device.protocol.decode(&first_chunk)?;

            Ok((decoded.message_type, decoded.payload))
        }
    }

    fn stop(&mut self) {
        // Clear call serialization locks
        if let Ok(mut locks) = self.call_locks.lock() {
            locks.clear();
        }
        // Disconnect all devices
        let devices = self.devices.clone();
        tokio::spawn(async move {
            let mut devices = devices.write().await;
            for (_, device) in devices.drain() {
                let _ = device.peripheral.disconnect().await;
            }
        });
    }
}
