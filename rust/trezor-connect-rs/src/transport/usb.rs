//! USB transport implementation.
//!
//! Uses the `rusb` crate for cross-platform USB communication.
//!
//! Supports both Protocol V1 (legacy, unencrypted) and THP (Trezor Host Protocol,
//! encrypted) for newer devices like the Safe 7. THP is auto-detected at runtime:
//! a Cancel message is sent via V1 during acquire, and if the device responds with
//! Failure_InvalidProtocol, THP handshake is performed.

use async_trait::async_trait;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::RwLock;

use crate::constants::{
    USB_CHUNK_SIZE, USB_ENDPOINT_IN, USB_ENDPOINT_OUT, USB_INTERFACE_ID, USB_PRODUCT_ID_BOOTLOADER,
    USB_PRODUCT_ID_FIRMWARE, USB_VENDOR_ID, thp_control,
};
use crate::error::{Result, ThpError, TransportError};
use crate::protocol::thp::{
    HandshakeInitResponse, ProtocolThp, encode_ack, encode_channel_allocation_request,
    encode_encrypted_message, encode_handshake_completion_request, encode_handshake_init_request,
    get_handshake_hash, handle_handshake_init, pairing_messages::encode_create_new_session,
    parse_handshake_completion_response, state::ThpHandshakeCredentials,
};
use crate::protocol::v1::ProtocolV1;
use crate::protocol::{Protocol, chunk};
use crate::transport::{DeviceDescriptor, SessionManager, Transport, TransportApi};
use zeroize::Zeroizing;

/// Timeout for USB operations in milliseconds
const USB_TIMEOUT_MS: u64 = 5000;

/// FailureInvalidProtocol code from Trezor protobuf
const FAILURE_INVALID_PROTOCOL: i32 = 17;

/// Holds device handle with detach state
struct OpenDevice {
    handle: rusb::DeviceHandle<rusb::GlobalContext>,
    has_kernel_driver: bool,
}

/// THP device state for a USB device that negotiated THP
struct ThpDeviceState {
    /// THP protocol instance
    protocol: ProtocolThp,
    /// Whether THP handshake is complete
    handshake_complete: bool,
}

/// USB Transport for Trezor devices
pub struct UsbTransport {
    /// Session manager
    sessions: SessionManager,
    /// Open device handles (path -> handle)
    ///
    /// Uses std::sync::RwLock instead of tokio::sync::RwLock because handles
    /// are accessed from within spawn_blocking contexts. Using a tokio lock
    /// inside block_on/spawn_blocking can deadlock if the write lock is held
    /// by a tokio task waiting for a spawn_blocking slot.
    handles: Arc<std::sync::RwLock<HashMap<String, OpenDevice>>>,
    /// Protocol implementation
    protocol: ProtocolV1,
    /// Per-device call serialization locks (path -> mutex).
    /// Ensures only one call() is in-flight per device at a time.
    /// Uses std::sync::Mutex for the outer map (held briefly, never across .await).
    /// Uses tokio::sync::Mutex for per-device lock (held across .await to serialize calls).
    call_locks: Arc<std::sync::Mutex<HashMap<String, Arc<tokio::sync::Mutex<()>>>>>,
    /// THP device states for devices that negotiated THP (path -> state)
    thp_states: Arc<RwLock<HashMap<String, ThpDeviceState>>>,
    /// Pairing credentials registered before the THP state exists
    /// (path -> credentials). Applied when the state is created during the
    /// handshake, so stored credentials can be injected before acquire.
    pending_credentials: Arc<RwLock<HashMap<String, crate::protocol::thp::state::ThpCredentials>>>,
    /// Pairing code callback for THP pairing
    pairing_callback: Option<Arc<dyn Fn() -> String + Send + Sync>>,
    /// Passphrase bound to the THP session at `ThpCreateNewSession` time.
    /// Empty string opens the standard wallet. Ignored when `session_on_device`
    /// is true (the device prompts on its own screen). NFKD-normalized and
    /// wiped from memory on drop.
    session_passphrase: Zeroizing<String>,
    /// When true, the THP session is created with `on_device = true` so the
    /// user enters the passphrase on the Trezor instead of the host.
    session_on_device: bool,
}

impl UsbTransport {
    /// Create a new USB transport
    pub fn new() -> Result<Self> {
        Ok(Self {
            sessions: SessionManager::new(),
            handles: Arc::new(std::sync::RwLock::new(HashMap::new())),
            protocol: ProtocolV1::usb(),
            call_locks: Arc::new(std::sync::Mutex::new(HashMap::new())),
            thp_states: Arc::new(RwLock::new(HashMap::new())),
            pending_credentials: Arc::new(RwLock::new(HashMap::new())),
            pairing_callback: None,
            session_passphrase: Zeroizing::new(String::new()),
            session_on_device: false,
        })
    }

    /// Set the pairing code callback for THP devices.
    pub fn set_pairing_callback(&mut self, callback: Arc<dyn Fn() -> String + Send + Sync>) {
        self.pairing_callback = Some(callback);
    }

    /// Add pairing credentials for a device so the next THP handshake can
    /// reconnect without re-pairing. Safe to call before acquire: the
    /// credentials are held pending and applied when the THP state is
    /// created during the handshake.
    pub async fn add_device_credentials(
        &self,
        path: &str,
        creds: crate::protocol::thp::state::ThpCredentials,
    ) {
        {
            let mut states = self.thp_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state
                    .protocol
                    .state_mut()
                    .add_pairing_credentials(creds.clone());
            }
        }
        self.pending_credentials
            .write()
            .await
            .insert(path.to_string(), creds);
    }

    /// Get pairing credentials for a device (if any), e.g. to persist them
    /// after a successful pairing.
    pub async fn get_device_credentials(
        &self,
        path: &str,
    ) -> Option<crate::protocol::thp::state::ThpCredentials> {
        let states = self.thp_states.read().await;
        states
            .get(path)?
            .protocol
            .state()
            .pairing_credentials()
            .first()
            .cloned()
    }

    /// Set the passphrase bound to the THP session created during acquire.
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

    /// Check if a device has negotiated THP.
    pub async fn has_thp(&self, path: &str) -> bool {
        let states = self.thp_states.read().await;
        states
            .get(path)
            .map(|s| s.handshake_complete)
            .unwrap_or(false)
    }

    /// Find Trezor USB devices
    fn find_devices() -> Result<Vec<rusb::Device<rusb::GlobalContext>>> {
        let devices: Vec<_> = rusb::devices()
            .map_err(|e| TransportError::Usb(e.to_string()))?
            .iter()
            .filter(|d| {
                if let Ok(desc) = d.device_descriptor() {
                    desc.vendor_id() == USB_VENDOR_ID
                        && (desc.product_id() == USB_PRODUCT_ID_FIRMWARE
                            || desc.product_id() == USB_PRODUCT_ID_BOOTLOADER)
                } else {
                    false
                }
            })
            .collect();

        Ok(devices)
    }

    /// Get serial number from device
    fn get_serial_number(device: &rusb::Device<rusb::GlobalContext>) -> Option<String> {
        let desc = device.device_descriptor().ok()?;
        let handle = device.open().ok()?;
        let _timeout = Duration::from_millis(1000);
        handle.read_serial_number_string_ascii(&desc).ok()
    }

    // ========================================================================
    // THP (Trezor Host Protocol) support
    // ========================================================================

    /// Write raw THP data to device, splitting into USB-sized chunks if needed.
    ///
    /// THP messages can exceed the 64-byte USB chunk size. The first chunk
    /// contains the full THP header; subsequent chunks are continuation packets
    /// with a 3-byte header (0x80 | channel[0] | channel[1]).
    async fn write_raw_thp(&self, path: &str, data: &[u8]) -> Result<()> {
        if data.len() <= USB_CHUNK_SIZE {
            let mut padded = vec![0u8; USB_CHUNK_SIZE];
            padded[..data.len()].copy_from_slice(data);
            self.write(path, &padded).await
        } else {
            // Extract channel from first chunk bytes [1..3]
            let channel = if data.len() >= 3 {
                [data[1], data[2]]
            } else {
                [0, 0]
            };

            // First chunk
            let mut first_chunk = vec![0u8; USB_CHUNK_SIZE];
            let first_end = USB_CHUNK_SIZE.min(data.len());
            first_chunk[..first_end].copy_from_slice(&data[..first_end]);
            self.write(path, &first_chunk).await?;

            // Continuation chunks
            let mut offset = first_end;
            while offset < data.len() {
                let mut cont_chunk = vec![0u8; USB_CHUNK_SIZE];
                // Continuation header: 0x80 + channel
                cont_chunk[0] = thp_control::CONTINUATION_PACKET;
                cont_chunk[1] = channel[0];
                cont_chunk[2] = channel[1];

                let cont_data_space = USB_CHUNK_SIZE - 3;
                let end = (offset + cont_data_space).min(data.len());
                cont_chunk[3..3 + (end - offset)].copy_from_slice(&data[offset..end]);
                self.write(path, &cont_chunk).await?;
                offset = end;
            }
            Ok(())
        }
    }

    /// Check if a THP message is an ACK
    fn is_thp_ack(data: &[u8]) -> bool {
        if data.is_empty() {
            return false;
        }
        (data[0] & 0xf7) == thp_control::ACK_MESSAGE
    }

    /// Read a THP response, skipping ACKs and reassembling continuation packets.
    async fn read_thp_response(
        &self,
        path: &str,
        max_attempts: u32,
        expected_channel: Option<&[u8; 2]>,
    ) -> Result<Vec<u8>> {
        for _ in 0..max_attempts {
            let first_chunk = self.read(path).await?;
            if first_chunk.is_empty() {
                continue;
            }

            let ctrl_byte = first_chunk[0];
            let ctrl_type = ctrl_byte & 0xe7;

            log::debug!(
                "[USB-THP] << Received: ctrl=0x{:02x} (type=0x{:02x}), len={}",
                ctrl_byte,
                ctrl_type,
                first_chunk.len()
            );

            // Validate channel if provided
            if let Some(ch) = expected_channel {
                if first_chunk.len() >= 3
                    && ctrl_byte != thp_control::CHANNEL_ALLOCATION_RES
                    && &first_chunk[1..3] != ch
                {
                    log::warn!(
                        "[USB-THP] Channel mismatch: expected {:02x?}, got {:02x?}",
                        ch,
                        &first_chunk[1..3]
                    );
                    continue;
                }
            }

            if Self::is_thp_ack(&first_chunk) {
                log::trace!("[USB-THP] (ACK, waiting for data response...)");
                continue;
            }

            // Check for THP error
            if ctrl_type == thp_control::ERROR {
                let error_code = first_chunk.get(5).copied().unwrap_or(0);
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
                    "THP Error: {} (0x{:02x})",
                    error_name, error_code
                ))
                .into());
            }

            // Check if multi-chunk message
            if first_chunk.len() >= 5 {
                let payload_len = u16::from_be_bytes([first_chunk[3], first_chunk[4]]) as usize;
                let total_needed = 5 + payload_len;

                if total_needed > USB_CHUNK_SIZE {
                    log::debug!(
                        "[USB-THP] Multi-chunk message: need {} bytes, have {}",
                        total_needed,
                        first_chunk.len()
                    );

                    let mut full_data = first_chunk.clone();
                    let mut bytes_remaining = total_needed - first_chunk.len();

                    while bytes_remaining > 0 {
                        let cont_chunk = self.read(path).await?;
                        if cont_chunk.is_empty() {
                            continue;
                        }

                        if Self::is_thp_ack(&cont_chunk) {
                            continue;
                        }

                        // Continuation packet has 3-byte header (ctrl + channel)
                        if (cont_chunk[0] & 0x80) != 0x80 {
                            log::warn!(
                                "[USB-THP] Expected continuation, got ctrl=0x{:02x}",
                                cont_chunk[0]
                            );
                            break;
                        }
                        if cont_chunk.len() > 3 {
                            let cont_data = &cont_chunk[3..];
                            full_data.extend_from_slice(cont_data);
                            bytes_remaining = bytes_remaining.saturating_sub(cont_data.len());
                        }
                    }
                    return Ok(full_data);
                }
            }

            return Ok(first_chunk);
        }
        Err(TransportError::DataTransfer("THP: No response after max attempts".to_string()).into())
    }

    /// Send a Cancel message via V1 and check if device responds with Failure_InvalidProtocol.
    /// Returns true if the device needs THP.
    async fn detect_thp_protocol(&self, path: &str) -> Result<bool> {
        log::debug!("[USB] Sending Cancel message for THP detection...");

        // Encode Cancel (message type 20, empty payload) via Protocol V1
        let cancel_type: u16 = 20; // MessageType::Cancel
        let encoded = self.protocol.encode(cancel_type, &[])?;
        let (_, chunk_header) = self.protocol.get_headers(&encoded);
        let chunks = chunk::create_chunks(&encoded, &chunk_header, USB_CHUNK_SIZE);

        for c in &chunks {
            self.write(path, c).await?;
        }

        // Read response — look for Protocol V1 header
        for _ in 0..20 {
            let chunk = self.read(path).await?;
            if chunk.is_empty() {
                continue;
            }

            // Check for V1 header: 0x3F + 0x23 0x23
            if chunk.len() >= 3 && chunk[0] == 0x3F && chunk[1] == 0x23 && chunk[2] == 0x23 {
                let decoded = self.protocol.decode(&chunk)?;

                // Check if it's a Failure message (type 3)
                if decoded.message_type == 3 {
                    // Parse the Failure protobuf to get the code.
                    // USB chunks are zero-padded and the V1 length field may
                    // include padding, so trim trailing zeros before decoding.
                    let header_size = crate::constants::PROTOCOL_V1_HEADER_SIZE;
                    let available = chunk.len().saturating_sub(header_size);
                    let payload_len = (decoded.length as usize).min(available);
                    let raw_payload = &chunk[header_size..header_size + payload_len];
                    let trimmed_len = raw_payload
                        .iter()
                        .rposition(|&b| b != 0)
                        .map_or(0, |i| i + 1);
                    let payload = &raw_payload[..trimmed_len];

                    if let Ok(failure) =
                        <crate::protos::common::Failure as prost::Message>::decode(payload)
                    {
                        if failure.code == Some(FAILURE_INVALID_PROTOCOL) {
                            log::info!(
                                "[USB] Device responded with Failure_InvalidProtocol — THP detected!"
                            );
                            return Ok(true);
                        }
                        log::debug!(
                            "[USB] Device responded with Failure code={:?}",
                            failure.code
                        );
                    }
                }

                // Any V1 response means device speaks V1
                log::debug!(
                    "[USB] Device responded with V1 message type={}, using V1 protocol",
                    decoded.message_type
                );
                return Ok(false);
            }

            // Non-V1 chunk — might be THP response. Check for THP channel allocation
            // or other THP control bytes that indicate the device expects THP.
            let ctrl = chunk[0] & 0xe7;
            if ctrl == thp_control::CHANNEL_ALLOCATION_RES
                || ctrl == thp_control::ERROR
                || ctrl == thp_control::HANDSHAKE_INIT_RES
            {
                log::info!(
                    "[USB] Device responded with THP control byte 0x{:02x} — THP detected!",
                    chunk[0]
                );
                return Ok(true);
            }
        }

        // No clear response — assume V1
        log::debug!("[USB] No definitive protocol response, defaulting to V1");
        Ok(false)
    }

    /// Perform the full THP handshake for a USB device.
    /// Perform THP handshake with retry for TransportBusy.
    ///
    /// A cancelled or crashed handshake (ours or another host's) leaves the
    /// device's channel occupied until its internal timeout expires
    /// (observed 15-20 seconds on Safe 7 fw 2.10.0), during which new
    /// handshakes fail with `TransportBusy (0x01)`. Retry with exponential
    /// backoff long enough to ride that window out.
    async fn perform_thp_handshake(&self, path: &str) -> Result<()> {
        const MAX_RETRIES: u32 = 6;
        const BASE_DELAY_MS: u64 = 500;

        let mut delay_ms = BASE_DELAY_MS;
        for attempt in 1..=MAX_RETRIES {
            match self.perform_thp_handshake_inner(path).await {
                Ok(()) => return Ok(()),
                Err(e) => {
                    if e.to_string().contains("TransportBusy") && attempt < MAX_RETRIES {
                        log::warn!(
                            "[USB-THP] TransportBusy (attempt {}/{}), retrying in {}ms...",
                            attempt,
                            MAX_RETRIES,
                            delay_ms
                        );
                        // Reset protocol state before retry (keeps pairing
                        // credentials, clears channel/nonces/sync bits).
                        {
                            let mut states = self.thp_states.write().await;
                            if let Some(state) = states.get_mut(path) {
                                state.protocol.state_mut().reset();
                                state.handshake_complete = false;
                            }
                        }
                        tokio::time::sleep(Duration::from_millis(delay_ms)).await;
                        delay_ms *= 2;
                        continue;
                    }
                    return Err(e);
                }
            }
        }
        unreachable!("loop returns on every path")
    }

    async fn perform_thp_handshake_inner(&self, path: &str) -> Result<()> {
        log::info!("[USB-THP] Starting THP handshake...");

        // Step 1: Channel Allocation
        let channel_req = encode_channel_allocation_request();
        log::debug!(
            "[USB-THP] Sending channel allocation request ({} bytes)",
            channel_req.len()
        );
        self.write_raw_thp(path, &channel_req).await?;

        let channel_resp = self.read_thp_response(path, 100, None).await?;
        log::debug!(
            "[USB-THP] Channel response: {:02x?}",
            &channel_resp[..channel_resp.len().min(16)]
        );

        if channel_resp.is_empty() || channel_resp[0] != thp_control::CHANNEL_ALLOCATION_RES {
            return Err(ThpError::HandshakeFailed(format!(
                "Expected channel allocation response, got: 0x{:02x}",
                channel_resp.first().unwrap_or(&0)
            ))
            .into());
        }

        if channel_resp.len() < 15 {
            return Err(ThpError::HandshakeFailed(format!(
                "Channel allocation response too short: {} bytes",
                channel_resp.len()
            ))
            .into());
        }
        let channel: [u8; 2] = [channel_resp[13], channel_resp[14]];
        log::info!(
            "[USB-THP] Allocated channel: {:02x}{:02x}",
            channel[0],
            channel[1]
        );

        // Extract device properties for handshake hash
        let payload_len = u16::from_be_bytes([channel_resp[3], channel_resp[4]]) as usize;
        let props_start = 5 + 8 + 2; // header(5) + nonce(8) + channel(2)
        let props_end = 5 + payload_len - 4; // exclude CRC
        let device_properties = if channel_resp.len() >= props_end {
            channel_resp[props_start..props_end].to_vec()
        } else {
            vec![]
        };

        // Create THP state
        {
            let pending = self.pending_credentials.read().await.get(path).cloned();
            let mut states = self.thp_states.write().await;
            let state = states
                .entry(path.to_string())
                .or_insert_with(|| ThpDeviceState {
                    protocol: ProtocolThp::new(),
                    handshake_complete: false,
                });
            state.protocol.state_mut().set_channel(channel);
            // Apply credentials registered before the state existed, so a
            // stored pairing can be presented during this handshake.
            if let Some(creds) = pending
                && state.protocol.state().pairing_credentials().is_empty()
            {
                state.protocol.state_mut().add_pairing_credentials(creds);
            }
        }

        // Step 2: Handshake Init
        let ephemeral_secret: [u8; 32] = rand::random();
        let (_, host_ephemeral_pubkey) =
            crate::protocol::thp::crypto::keypair_from_secret(&ephemeral_secret);

        let send_bit = {
            let states = self.thp_states.read().await;
            states
                .get(path)
                .map(|s| s.protocol.state().send_bit())
                .unwrap_or(0)
        };

        let init_req = encode_handshake_init_request(
            &channel,
            host_ephemeral_pubkey.as_bytes(),
            false, // try_to_unlock
            send_bit,
        );
        log::debug!("[USB-THP] Sending handshake init request...");
        self.write_raw_thp(path, &init_req).await?;

        // Toggle send_bit
        {
            let mut states = self.thp_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state.protocol.state_mut().update_sync_bit(true);
            }
        }

        let init_resp = self.read_thp_response(path, 100, Some(&channel)).await?;
        log::debug!(
            "[USB-THP] Handshake init response: {} bytes",
            init_resp.len()
        );

        if init_resp.is_empty() || (init_resp[0] & 0xe7) != thp_control::HANDSHAKE_INIT_RES {
            return Err(ThpError::HandshakeFailed(format!(
                "Expected handshake init response, got: 0x{:02x}",
                init_resp.first().unwrap_or(&0)
            ))
            .into());
        }

        // Send ACK
        let ack_bit = (init_resp[0] >> 4) & 1;
        let ack = encode_ack(&channel, ack_bit);
        self.write_raw_thp(path, &ack).await?;

        // Parse handshake init response
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

        // Initialize handshake state with hash
        {
            let mut states = self.thp_states.write().await;
            if let Some(state) = states.get_mut(path) {
                let handshake_hash = get_handshake_hash(&device_properties);
                let mut creds = ThpHandshakeCredentials::default();
                creds.handshake_hash = handshake_hash.to_vec();
                state.protocol.state_mut().set_handshake_credentials(creds);
            }
        }

        let init_response = HandshakeInitResponse {
            trezor_ephemeral_pubkey,
            trezor_encrypted_static_pubkey: trezor_encrypted_static,
            tag,
        };

        // Check for stored credentials for this device (to skip pairing on
        // reconnect). Mirrors the Bluetooth transport; credential matching
        // against the device's static key happens in handle_handshake_init.
        let stored_credential = {
            let states = self.thp_states.read().await;
            let state = states.get(path).ok_or(TransportError::DeviceNotFound)?;
            state
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
        if stored_credential.is_some() {
            log::info!(
                "[USB-THP] Found stored credentials - will attempt reconnection without pairing"
            );
        }

        let completion_req = {
            let mut states = self.thp_states.write().await;
            let state = states.get_mut(path).ok_or(TransportError::DeviceNotFound)?;
            handle_handshake_init(
                state.protocol.state_mut(),
                &init_response,
                &ephemeral_secret,
                false, // try_to_unlock
                stored_credential.as_ref(),
            )?
        };

        // Step 3: Handshake Completion
        let send_bit = {
            let states = self.thp_states.read().await;
            states
                .get(path)
                .map(|s| s.protocol.state().send_bit())
                .unwrap_or(0)
        };

        let comp_req = encode_handshake_completion_request(
            &channel,
            &completion_req.encrypted_host_static_pubkey,
            &completion_req.encrypted_payload,
            send_bit,
        );
        log::debug!("[USB-THP] Sending handshake completion request...");
        self.write_raw_thp(path, &comp_req).await?;

        {
            let mut states = self.thp_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state.protocol.state_mut().update_sync_bit(true);
            }
        }

        log::info!(
            "[USB-THP] Waiting for handshake completion (check Trezor screen if pairing needed)..."
        );
        let comp_resp = self.read_thp_response(path, 600, Some(&channel)).await?;

        // Send ACK
        let ack_bit = (comp_resp[0] >> 4) & 1;
        let ack = encode_ack(&channel, ack_bit);
        self.write_raw_thp(path, &ack).await?;

        let ctrl = comp_resp[0] & 0xe7;
        if ctrl == thp_control::HANDSHAKE_COMP_RES {
            let payload_len = u16::from_be_bytes([comp_resp[3], comp_resp[4]]) as usize;
            let crc_len = 4;

            if comp_resp.len() >= 5 + payload_len && payload_len > crc_len {
                let encrypted_payload = &comp_resp[5..5 + payload_len - crc_len];

                let completion = {
                    let states = self.thp_states.read().await;
                    let state = states.get(path).ok_or(TransportError::DeviceNotFound)?;
                    parse_handshake_completion_response(state.protocol.state(), encrypted_payload)?
                };

                log::info!(
                    "[USB-THP] trezor_state={} (0=needs pairing, 1=paired, 2=autoconnect)",
                    completion.trezor_state
                );

                if completion.trezor_state == 0 {
                    // Device requires pairing
                    log::info!("[USB-THP] Device requires pairing");
                    self.perform_thp_pairing(path, &channel).await?;
                } else {
                    // Device accepted (state=1 or 2) — send ThpEndRequest
                    log::info!("[USB-THP] Device accepted, finalizing connection...");

                    // Mark as paired to enable encrypted messaging
                    {
                        let mut states = self.thp_states.write().await;
                        if let Some(state) = states.get_mut(path) {
                            state.protocol.state_mut().set_is_paired(true);
                        }
                    }

                    let (end_resp_type, _) = self
                        .send_thp_encrypted(
                            path,
                            &channel,
                            crate::constants::thp_message_type::THP_END_REQUEST,
                            &[],
                        )
                        .await?;

                    if end_resp_type == crate::constants::message_type::BUTTON_REQUEST {
                        log::info!("[USB-THP] Device requesting connection confirmation...");
                        let (ack_resp_type, _) = self
                            .send_thp_encrypted(
                                path,
                                &channel,
                                crate::constants::message_type::BUTTON_ACK,
                                &[],
                            )
                            .await?;
                        if ack_resp_type != crate::constants::thp_message_type::THP_END_RESPONSE {
                            return Err(ThpError::HandshakeFailed(format!(
                                "Expected ThpEndResponse after ButtonAck, got: {}",
                                ack_resp_type
                            ))
                            .into());
                        }
                    } else if end_resp_type != crate::constants::thp_message_type::THP_END_RESPONSE
                    {
                        return Err(ThpError::HandshakeFailed(format!(
                            "Expected ThpEndResponse, got: {}",
                            end_resp_type
                        ))
                        .into());
                    }
                }
            }
        }

        // Mark as paired
        {
            let mut states = self.thp_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state.protocol.state_mut().set_is_paired(true);
            }
        }

        // Create THP session
        self.create_thp_session(path, &channel).await?;

        // Mark handshake complete
        {
            let mut states = self.thp_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state.handshake_complete = true;
            }
        }

        log::info!("[USB-THP] THP handshake complete!");
        Ok(())
    }

    /// Perform THP pairing for a USB device.
    /// Mirrors the callback transport's pairing flow.
    async fn perform_thp_pairing(&self, path: &str, channel: &[u8; 2]) -> Result<()> {
        use crate::constants::{message_type, thp_message_type, thp_pairing_method};
        use crate::protocol::thp::pairing::{get_cpace_host_keys, get_shared_secret};
        use crate::protocol::thp::pairing_messages::*;

        log::info!("[USB-THP] Starting pairing flow...");

        // Mark as paired to enable encrypted messaging
        {
            let mut states = self.thp_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state.protocol.state_mut().set_is_paired(true);
            }
        }

        // Step 1: Send ThpPairingRequest
        let pairing_request = encode_pairing_request("trezor-connect-rs", "trezor-connect-rs");
        let (mut resp_type, _) = self
            .send_thp_encrypted(
                path,
                channel,
                thp_message_type::THP_PAIRING_REQUEST,
                &pairing_request,
            )
            .await?;

        // Handle ButtonRequest
        if resp_type == message_type::BUTTON_REQUEST {
            log::info!("[USB-THP] >>> CONFIRM PAIRING ON YOUR TREZOR SCREEN! <<<");
            let (next_type, _) = self
                .send_thp_encrypted(path, channel, message_type::BUTTON_ACK, &[])
                .await?;
            resp_type = next_type;
        }

        if resp_type != thp_message_type::THP_PAIRING_REQUEST_APPROVED {
            return Err(ThpError::PairingFailed(format!(
                "Expected PairingRequestApproved, got: {}",
                resp_type
            ))
            .into());
        }

        // Step 2: Select code entry method
        let select = encode_select_method(thp_pairing_method::CODE_ENTRY);
        let (resp_type, commitment_data) = self
            .send_thp_encrypted(path, channel, thp_message_type::THP_SELECT_METHOD, &select)
            .await?;

        // Generate a single challenge to reuse throughout the pairing flow
        let challenge: [u8; 32] = rand::random();
        let challenge_payload = encode_code_entry_challenge(&challenge);

        // Handle response flow (may get PairingPreparationsFinished or CodeEntryCommitment)
        let commitment_data = if resp_type == thp_message_type::THP_PAIRING_PREPARATIONS_FINISHED {
            let (resp_type, commitment_data) = self
                .send_thp_encrypted(
                    path,
                    channel,
                    thp_message_type::THP_CODE_ENTRY_CHALLENGE,
                    &challenge_payload,
                )
                .await?;
            if resp_type != thp_message_type::THP_CODE_ENTRY_COMMITMENT {
                return Err(ThpError::PairingFailed("Expected commitment".to_string()).into());
            }
            commitment_data
        } else if resp_type == thp_message_type::THP_CODE_ENTRY_COMMITMENT {
            commitment_data
        } else {
            return Err(
                ThpError::PairingFailed(format!("Unexpected response: {}", resp_type)).into(),
            );
        };

        // Decode and store commitment + challenge
        let commitment = decode_code_entry_commitment(&commitment_data)?;
        {
            let mut states = self.thp_states.write().await;
            if let Some(state) = states.get_mut(path) {
                if let Some(creds) = state.protocol.state_mut().handshake_credentials_mut() {
                    creds.handshake_commitment = commitment.clone();
                    creds.code_entry_challenge = challenge.to_vec();
                }
            }
        }

        // Step 3: Get CPACE Trezor pubkey (reuse the same challenge)
        let (resp_type, cpace_data) = self
            .send_thp_encrypted(
                path,
                channel,
                thp_message_type::THP_CODE_ENTRY_CHALLENGE,
                &challenge_payload,
            )
            .await?;

        if resp_type != thp_message_type::THP_CODE_ENTRY_CPACE_TREZOR {
            return Err(ThpError::PairingFailed(format!(
                "Expected CpaceTrezor, got: {}",
                resp_type
            ))
            .into());
        }
        let trezor_cpace_pubkey = decode_cpace_trezor(&cpace_data)?;

        log::info!("[USB-THP] >>> LOOK AT YOUR TREZOR SCREEN! <<<");
        log::info!("[USB-THP] A 6-digit code should be displayed.");

        // Step 4: Get code from user
        let code = if let Some(ref cb) = self.pairing_callback {
            cb()
        } else {
            return Err(ThpError::PairingFailed(
                "No pairing callback set — cannot enter code for USB THP pairing".to_string(),
            )
            .into());
        };
        if code.is_empty() {
            return Err(ThpError::PairingFailed("Pairing cancelled by user".to_string()).into());
        }
        log::info!("[USB-THP] User entered pairing code");

        // Step 5: Generate CPACE keys and send host tag
        let handshake_hash = {
            let states = self.thp_states.read().await;
            let state = states.get(path).ok_or(TransportError::DeviceNotFound)?;
            state
                .protocol
                .state()
                .handshake_credentials()
                .map(|c| c.handshake_hash.clone())
                .unwrap_or_default()
        };

        let cpace_keys = get_cpace_host_keys(code.as_bytes(), &handshake_hash);
        let shared_secret = get_shared_secret(&trezor_cpace_pubkey, &cpace_keys.private_key);
        let tag = &shared_secret[..];

        let cpace_host_tag = encode_cpace_host_tag(&cpace_keys.public_key, tag);
        let (resp_type, secret_data) = self
            .send_thp_encrypted(
                path,
                channel,
                thp_message_type::THP_CODE_ENTRY_CPACE_HOST_TAG,
                &cpace_host_tag,
            )
            .await?;

        if resp_type == message_type::FAILURE {
            return Err(ThpError::PairingFailed("Code verification failed".to_string()).into());
        }
        if resp_type != thp_message_type::THP_CODE_ENTRY_SECRET {
            return Err(
                ThpError::PairingFailed(format!("Expected secret, got {}", resp_type)).into(),
            );
        }

        // Validate the code entry tag
        let secret = decode_code_entry_secret(&secret_data)?;
        {
            let states = self.thp_states.read().await;
            let state = states.get(path).ok_or(TransportError::DeviceNotFound)?;
            if let Some(creds) = state.protocol.state().handshake_credentials() {
                crate::protocol::thp::pairing::validate_code_entry_tag(creds, &code, &secret)?;
                log::info!("[USB-THP] Code entry tag validated!");
            } else {
                return Err(ThpError::StateMissing.into());
            }
        }

        // Step 7: Request credential
        let host_static_pubkey = {
            let states = self.thp_states.read().await;
            states
                .get(path)
                .and_then(|s| s.protocol.state().handshake_credentials())
                .map(|c| c.host_static_public_key.clone())
                .unwrap_or_default()
        };

        let credential_request = encode_credential_request(&host_static_pubkey, false, None);
        let (mut resp_type, mut credential_data) = self
            .send_thp_encrypted(
                path,
                channel,
                thp_message_type::THP_CREDENTIAL_REQUEST,
                &credential_request,
            )
            .await?;

        if resp_type == message_type::BUTTON_REQUEST {
            let (next_type, next_data) = self
                .send_thp_encrypted(path, channel, message_type::BUTTON_ACK, &[])
                .await?;
            resp_type = next_type;
            credential_data = next_data;
        }

        if resp_type != thp_message_type::THP_CREDENTIAL_RESPONSE {
            return Err(ThpError::PairingFailed(format!(
                "Expected CredentialResponse, got: {}",
                resp_type
            ))
            .into());
        }
        log::info!(
            "[USB-THP] Received pairing credential ({} bytes)",
            credential_data.len()
        );

        // Decode and store the credential so future handshakes can reconnect
        // without re-pairing (mirrors the Bluetooth transport).
        match crate::protocol::thp::pairing_messages::decode_credential_response(&credential_data) {
            Ok((trezor_pubkey, credential)) => {
                let mut states = self.thp_states.write().await;
                let state = states.get_mut(path).ok_or(TransportError::DeviceNotFound)?;
                let host_static_private_key = state
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
                state
                    .protocol
                    .state_mut()
                    .set_pairing_credentials(stored_creds);
                log::info!("[USB-THP] Stored pairing credentials for future reconnection");
            }
            Err(e) => {
                log::warn!(
                    "[USB-THP] Could not decode credential response ({}); re-pairing will be required next time",
                    e
                );
            }
        }

        // Step 8: Send ThpEndRequest
        let (end_type, _) = self
            .send_thp_encrypted(path, channel, thp_message_type::THP_END_REQUEST, &[])
            .await?;

        if end_type != thp_message_type::THP_END_RESPONSE {
            return Err(ThpError::PairingFailed(format!(
                "Expected ThpEndResponse, got: {}",
                end_type
            ))
            .into());
        }

        log::info!("[USB-THP] Pairing complete!");
        Ok(())
    }

    /// Create a THP session after handshake+pairing.
    async fn create_thp_session(&self, path: &str, channel: &[u8; 2]) -> Result<()> {
        log::info!("[USB-THP] Creating new THP session...");

        {
            let mut states = self.thp_states.write().await;
            if let Some(state) = states.get_mut(path) {
                let session_id = state.protocol.state_mut().create_new_session_id();
                log::debug!("[USB-THP] Created session ID {}", session_id);
            }
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

        let (mut resp_type, mut resp_data) = self
            .send_thp_encrypted(
                path,
                channel,
                crate::constants::thp_message_type::THP_CREATE_NEW_SESSION,
                &session_payload,
            )
            .await?;

        // The device may emit one or more ButtonRequests before completing —
        // e.g. confirming the passphrase, or showing its on-device keyboard.
        // Acknowledge each until the device returns the final Success/Failure.
        while resp_type == crate::constants::message_type::BUTTON_REQUEST {
            log::debug!("[USB-THP] ThpCreateNewSession: ButtonRequest, acking");
            let (next_type, next_data) = self
                .send_thp_encrypted(
                    path,
                    channel,
                    crate::constants::message_type::BUTTON_ACK,
                    &[],
                )
                .await?;
            resp_type = next_type;
            resp_data = next_data;
        }

        if resp_type == crate::constants::message_type::SUCCESS {
            log::info!("[USB-THP] THP session created successfully!");
            Ok(())
        } else if resp_type == crate::constants::message_type::FAILURE {
            // Decode the device's reason so the failure is actionable.
            let detail = crate::transport::decode_failure_detail(&resp_data);
            log::warn!("[USB-THP] ThpCreateNewSession rejected: {}", detail);
            Err(ThpError::SessionError(format!("ThpCreateNewSession rejected ({})", detail)).into())
        } else {
            Err(ThpError::SessionError(format!("Unexpected response: {}", resp_type)).into())
        }
    }

    /// Send an encrypted THP message and receive the response.
    async fn send_thp_encrypted(
        &self,
        path: &str,
        channel: &[u8; 2],
        message_type: u16,
        data: &[u8],
    ) -> Result<(u16, Vec<u8>)> {
        // Encode encrypted message
        let message = {
            let states = self.thp_states.read().await;
            let state = states.get(path).ok_or(TransportError::DeviceNotFound)?;
            encode_encrypted_message(state.protocol.state(), message_type, data)?
        };

        log::debug!(
            "[USB-THP] Sending encrypted message type {} ({} bytes)",
            message_type,
            message.len()
        );
        self.write_raw_thp(path, &message).await?;

        // Update state
        {
            let mut states = self.thp_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state.protocol.state_mut().update_sync_bit(true);
                state
                    .protocol
                    .state_mut()
                    .update_nonce(true)
                    .map_err(|e| ThpError::EncryptionError(e.to_string()))?;
            }
        }

        // Read response
        let response = self.read_thp_response(path, 300, Some(channel)).await?;

        // Send ACK
        let ack_bit = (response[0] >> 4) & 1;
        let ack = encode_ack(channel, ack_bit);
        self.write_raw_thp(path, &ack).await?;

        // Decrypt response
        let (resp_type, resp_data) = {
            if response.len() < 5 {
                return Err(ThpError::DecryptionError("Response too short".to_string()).into());
            }

            let payload_len = u16::from_be_bytes([response[3], response[4]]) as usize;
            let crc_len = 4;
            let header_len = 5;

            if payload_len <= crc_len || response.len() < header_len + payload_len {
                return Err(ThpError::DecryptionError(format!(
                    "Invalid payload: response_len={}, payload_len={}",
                    response.len(),
                    payload_len
                ))
                .into());
            }

            let encrypted_payload = &response[header_len..header_len + payload_len - crc_len];

            let states = self.thp_states.read().await;
            let state = states.get(path).ok_or(TransportError::DeviceNotFound)?;

            let creds = state
                .protocol
                .state()
                .handshake_credentials()
                .ok_or(ThpError::StateMissing)?;

            let key: [u8; 32] = creds
                .trezor_key
                .clone()
                .try_into()
                .map_err(|_| ThpError::DecryptionError("Invalid key".to_string()))?;

            let recv_nonce = state.protocol.state().recv_nonce();
            let iv = crate::protocol::thp::crypto::get_iv_from_nonce(recv_nonce);

            let decrypted =
                crate::protocol::thp::crypto::aes_gcm_decrypt(&key, &iv, &[], encrypted_payload)?;

            if decrypted.len() < 3 {
                return Err(
                    ThpError::DecryptionError("Decrypted payload too short".to_string()).into(),
                );
            }

            let _session_id = decrypted[0];
            let msg_type = u16::from_be_bytes([decrypted[1], decrypted[2]]);
            let msg_data = decrypted[3..].to_vec();

            (msg_type, msg_data)
        };

        // Update recv state
        {
            let mut states = self.thp_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state.protocol.state_mut().update_sync_bit(false);
                state
                    .protocol
                    .state_mut()
                    .update_nonce(false)
                    .map_err(|e| ThpError::DecryptionError(e.to_string()))?;
            }
        }

        log::debug!(
            "[USB-THP] Received encrypted response type {} ({} bytes)",
            resp_type,
            resp_data.len()
        );
        Ok((resp_type, resp_data))
    }
}

// NOTE: Default impl intentionally omitted. UsbTransport::new() returns Result
// and library code should not panic on initialization failure. Use
// UsbTransport::new() directly and handle the error.

#[async_trait]
impl TransportApi for UsbTransport {
    fn chunk_size(&self) -> usize {
        USB_CHUNK_SIZE
    }

    async fn enumerate(&self) -> Result<Vec<DeviceDescriptor>> {
        let devices = Self::find_devices()?;

        let descriptors: Vec<_> = devices
            .into_iter()
            .filter_map(|d| {
                let desc = d.device_descriptor().ok()?;
                let path = Self::get_serial_number(&d).unwrap_or_else(|| "unknown".to_string());
                Some(DeviceDescriptor {
                    path: path.clone(),
                    vendor_id: desc.vendor_id(),
                    product_id: desc.product_id(),
                    serial_number: Self::get_serial_number(&d),
                    session: self.sessions.get_session(&path),
                })
            })
            .collect();

        Ok(descriptors)
    }

    async fn open(&self, path: &str) -> Result<()> {
        let devices = Self::find_devices()?;

        let device = devices
            .into_iter()
            .find(|d| Self::get_serial_number(d).as_deref() == Some(path))
            .ok_or(TransportError::DeviceNotFound)?;

        log::debug!("[USB] Opening device: {}", path);

        let handle = device
            .open()
            .map_err(|e| TransportError::UnableToOpen(e.to_string()))?;

        // Check if kernel driver is attached and detach if necessary
        let has_kernel_driver = handle
            .kernel_driver_active(USB_INTERFACE_ID)
            .unwrap_or(false);

        if has_kernel_driver {
            log::debug!("[USB] Detaching kernel driver");
            handle.detach_kernel_driver(USB_INTERFACE_ID).map_err(|e| {
                TransportError::UnableToOpen(format!("detach_kernel_driver: {}", e))
            })?;
        }

        // Set active configuration
        log::debug!("[USB] Setting configuration to 1");
        match handle.set_active_configuration(1) {
            Ok(_) => {}
            Err(rusb::Error::Busy) => {
                log::debug!("[USB] Configuration already set (busy)");
            }
            Err(e) => {
                return Err(
                    TransportError::UnableToOpen(format!("set_configuration: {}", e)).into(),
                );
            }
        }

        // Note: Skip device reset - it can invalidate the handle on some platforms
        // and trezor-suite only resets when re-acquiring sessions

        // Claim interface
        log::debug!("[USB] Claiming interface {}", USB_INTERFACE_ID);
        handle
            .claim_interface(USB_INTERFACE_ID)
            .map_err(|e| TransportError::UnableToOpen(format!("claim_interface: {}", e)))?;

        log::debug!("[USB] Interface claimed successfully");

        // Clear any stale data in the device buffer (with iteration and time limits)
        log::debug!("[USB] Clearing stale data...");
        let mut clear_buffer = vec![0u8; USB_CHUNK_SIZE];
        let clear_timeout = Duration::from_millis(100);
        let clear_deadline = Instant::now() + Duration::from_secs(1);
        for _ in 0..100 {
            if Instant::now() >= clear_deadline {
                log::debug!("[USB] Buffer clear deadline reached");
                break;
            }
            match handle.read_interrupt(USB_ENDPOINT_IN, &mut clear_buffer, clear_timeout) {
                Ok(n) if n > 0 => {
                    log::debug!("[USB] Cleared {} stale bytes", n);
                }
                _ => break,
            }
        }
        log::debug!("[USB] Buffer cleared");

        // Store handle
        let mut handles = self
            .handles
            .write()
            .map_err(|e| TransportError::UnableToOpen(format!("lock poisoned: {}", e)))?;
        handles.insert(
            path.to_string(),
            OpenDevice {
                handle,
                has_kernel_driver,
            },
        );

        Ok(())
    }

    async fn close(&self, path: &str) -> Result<()> {
        let mut handles = self
            .handles
            .write()
            .map_err(|e| TransportError::UnableToClose(format!("lock poisoned: {}", e)))?;
        if let Some(open_device) = handles.remove(path) {
            // Release interface
            let _ = open_device.handle.release_interface(USB_INTERFACE_ID);

            // Reattach kernel driver if we detached it
            if open_device.has_kernel_driver {
                let _ = open_device.handle.attach_kernel_driver(USB_INTERFACE_ID);
            }
        }
        Ok(())
    }

    async fn read(&self, path: &str) -> Result<Vec<u8>> {
        let path = path.to_string();
        let handles = self.handles.clone();

        // Use spawn_blocking for synchronous USB operations
        tokio::task::spawn_blocking(move || {
            let handles = handles
                .read()
                .map_err(|e| TransportError::DataTransfer(format!("lock poisoned: {}", e)))?;
            let open_device = handles.get(&path).ok_or(TransportError::DeviceNotFound)?;

            let mut buffer = vec![0u8; USB_CHUNK_SIZE];
            let timeout = Duration::from_millis(USB_TIMEOUT_MS);

            // Retry loop - device may need time to respond
            let mut attempts = 0;
            let max_attempts = 10;
            loop {
                match open_device
                    .handle
                    .read_interrupt(USB_ENDPOINT_IN, &mut buffer, timeout)
                {
                    Ok(bytes_read) if bytes_read > 0 => {
                        buffer.truncate(bytes_read);
                        return Ok(buffer);
                    }
                    Ok(_) => {
                        // Got 0 bytes, retry
                        attempts += 1;
                        if attempts >= max_attempts {
                            return Err(TransportError::DataTransfer(
                                "No data received after retries".to_string(),
                            )
                            .into());
                        }
                        log::debug!(
                            "[USB] read_interrupt got 0 bytes, retrying ({}/{})",
                            attempts,
                            max_attempts
                        );
                        std::thread::sleep(Duration::from_millis(100));
                    }
                    Err(rusb::Error::Timeout) => {
                        attempts += 1;
                        if attempts >= max_attempts {
                            return Err(TransportError::DataTransfer(
                                "Read timeout after retries".to_string(),
                            )
                            .into());
                        }
                        log::debug!(
                            "[USB] read_interrupt timeout, retrying ({}/{})",
                            attempts,
                            max_attempts
                        );
                    }
                    Err(e) => {
                        return Err(TransportError::DataTransfer(e.to_string()).into());
                    }
                }
            }
        })
        .await
        .map_err(|e| TransportError::DataTransfer(e.to_string()))?
    }

    async fn write(&self, path: &str, data: &[u8]) -> Result<()> {
        let path = path.to_string();
        let data = data.to_vec();
        let handles = self.handles.clone();

        log::trace!(
            "[USB] write_interrupt to endpoint 0x{:02x}, {} bytes",
            USB_ENDPOINT_OUT,
            data.len()
        );

        // Use spawn_blocking for synchronous USB operations
        tokio::task::spawn_blocking(move || {
            let handles = handles
                .read()
                .map_err(|e| TransportError::DataTransfer(format!("lock poisoned: {}", e)))?;
            let open_device = handles.get(&path).ok_or(TransportError::DeviceNotFound)?;

            let timeout = Duration::from_millis(USB_TIMEOUT_MS);

            let bytes_written = open_device
                .handle
                .write_interrupt(USB_ENDPOINT_OUT, &data, timeout)
                .map_err(|e| TransportError::DataTransfer(e.to_string()))?;

            log::trace!("[USB] write_interrupt completed: {} bytes", bytes_written);
            Ok(())
        })
        .await
        .map_err(|e| TransportError::DataTransfer(e.to_string()))?
    }
}

#[async_trait]
impl Transport for UsbTransport {
    async fn init(&mut self) -> Result<()> {
        // USB doesn't require initialization
        Ok(())
    }

    async fn enumerate(&self) -> Result<Vec<DeviceDescriptor>> {
        TransportApi::enumerate(self).await
    }

    async fn acquire(&self, path: &str, previous: Option<&str>) -> Result<String> {
        // Check if device is already open
        let needs_open = {
            let handles = self
                .handles
                .read()
                .map_err(|e| TransportError::DataTransfer(format!("lock poisoned: {}", e)))?;
            !handles.contains_key(path)
        };

        if needs_open {
            self.open(path).await?;
        }

        // Detect THP protocol: send Cancel via V1, check for Failure_InvalidProtocol
        let already_thp = self.has_thp(path).await;
        if !already_thp {
            match self.detect_thp_protocol(path).await {
                Ok(true) => {
                    log::info!("[USB] Device needs THP — performing handshake...");
                    self.perform_thp_handshake(path).await?;
                }
                Ok(false) => {
                    log::debug!("[USB] Device uses V1 protocol");
                }
                Err(e) => {
                    // If detection fails, fall back to V1
                    log::warn!("[USB] THP detection failed ({}), falling back to V1", e);
                }
            }
        }

        self.sessions
            .acquire(path, previous)
            .map_err(|e| TransportError::DataTransfer(e.to_string()).into())
    }

    async fn release(&self, session: &str) -> Result<()> {
        if let Some(path) = self.sessions.get_path(session) {
            self.close(&path).await?;

            // Clean up THP state
            {
                let mut states = self.thp_states.write().await;
                states.remove(&path);
            }

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

        // For THP devices, use encrypted messaging
        if self.has_thp(&path).await {
            let channel = {
                let states = self.thp_states.read().await;
                let state = states.get(&path).ok_or(TransportError::DeviceNotFound)?;
                *state.protocol.state().channel()
            };
            log::debug!(
                "[USB-THP] Using THP encrypted call for message type {}",
                message_type
            );
            return self
                .send_thp_encrypted(&path, &channel, message_type, data)
                .await;
        }

        // V1 protocol path
        let encoded = self.protocol.encode(message_type, data)?;

        log::debug!(
            "[USB] call: message_type={}, data_len={}, encoded_len={}",
            message_type,
            data.len(),
            encoded.len()
        );

        // Create chunks
        let (_, chunk_header) = self.protocol.get_headers(&encoded);
        let chunks = chunk::create_chunks(&encoded, &chunk_header, USB_CHUNK_SIZE);

        log::trace!("[USB] Sending {} chunk(s)", chunks.len());

        // Send all chunks
        for (i, c) in chunks.iter().enumerate() {
            log::trace!("[USB] Writing chunk {}: {:02x?}", i, &c[..c.len().min(16)]);
            self.write(&path, c).await?;
        }

        log::trace!("[USB] All chunks sent, waiting for response...");

        // Read response - read chunks until we find Protocol v1 header
        let mut response_chunks = Vec::new();
        let mut first_chunk: Option<Vec<u8>> = None;

        // Read chunks looking for Protocol v1 header (without outer timeout to avoid race)
        for attempt in 0..20 {
            let chunk = self.read(&path).await?;

            if chunk.is_empty() {
                log::trace!("[USB] Read {} returned empty, retrying", attempt);
                continue;
            }

            log::trace!(
                "[USB] Read {} ({} bytes): {:02x?}",
                attempt,
                chunk.len(),
                &chunk[..chunk.len().min(16)]
            );

            // Check for Protocol v1 header: 0x3F (report) + 0x23 0x23 (magic)
            if chunk.len() >= 3 && chunk[0] == 0x3F && chunk[1] == 0x23 && chunk[2] == 0x23 {
                log::trace!("[USB] Found Protocol v1 header");
                first_chunk = Some(chunk);
                break;
            } else {
                // Skip non-Protocol v1 chunks (preamble/device info)
                log::debug!(
                    "[USB] Skipping non-Protocol v1 chunk (first bytes: {:02x} {:02x})",
                    chunk.get(0).unwrap_or(&0),
                    chunk.get(1).unwrap_or(&0)
                );
            }
        }

        let first_chunk = first_chunk.ok_or_else(|| {
            TransportError::DataTransfer("No Protocol v1 header found".to_string())
        })?;

        let decoded = self.protocol.decode(&first_chunk)?;
        log::debug!(
            "[USB] Protocol v1 message: type={}, length={}",
            decoded.message_type,
            decoded.length
        );

        response_chunks.push(first_chunk);

        // Standard Protocol v1 handling
        let header_size = crate::constants::PROTOCOL_V1_HEADER_SIZE;
        let first_payload_size = USB_CHUNK_SIZE - header_size;
        let remaining = if decoded.length as usize > first_payload_size {
            decoded.length as usize - first_payload_size
        } else {
            0
        };

        if remaining > 0 {
            let continuation_payload = USB_CHUNK_SIZE - 1; // 1 byte for magic
            let num_chunks = (remaining + continuation_payload - 1) / continuation_payload;
            log::trace!(
                "[USB] Need {} more chunks for {} remaining bytes",
                num_chunks,
                remaining
            );

            for _i in 0..num_chunks {
                let chunk = self.read(&path).await?;
                response_chunks.push(chunk);
            }
        }

        // Reassemble response
        let payload = chunk::reassemble_chunks(
            &response_chunks,
            header_size,
            1, // Continuation header is 1 byte
            decoded.length as usize,
        )?;

        log::debug!("[USB] Reassembled payload: {} bytes", payload.len());
        Ok((decoded.message_type, payload))
    }

    fn stop(&mut self) {
        // Clear call serialization locks
        if let Ok(mut locks) = self.call_locks.lock() {
            locks.clear();
        }
        // Clear THP states (blocking since stop() is sync)
        // Use try_write to avoid blocking if held elsewhere
        if let Ok(mut states) = self.thp_states.try_write() {
            states.clear();
        }
        // Release all interfaces and reattach kernel drivers before clearing handles
        if let Ok(mut handles) = self.handles.write() {
            for (path, open_device) in handles.drain() {
                log::debug!("[USB] Releasing interface for device: {}", path);
                let _ = open_device.handle.release_interface(USB_INTERFACE_ID);
                if open_device.has_kernel_driver {
                    let _ = open_device.handle.attach_kernel_driver(USB_INTERFACE_ID);
                }
            }
        }
    }
}
