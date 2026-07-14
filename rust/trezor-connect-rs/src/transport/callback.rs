//! Callback-based transport for mobile platforms.
//!
//! This transport uses callbacks for all I/O operations, allowing the native
//! layer (iOS/Android) to handle USB and Bluetooth communication.
//!
//! For USB devices: Uses Protocol V1 (chunk-based, unencrypted)
//! For BLE devices: Uses THP (Trezor Host Protocol - encrypted)
//!
//! NOTE: This module intentionally uses `std::thread::sleep()` instead of
//! `tokio::time::sleep()`. The callback transport runs synchronous FFI calls
//! on a dedicated thread — it is not driven by the tokio async runtime, so
//! blocking the OS thread is correct and expected here.

use async_trait::async_trait;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use zeroize::Zeroizing;

use crate::constants::{PROTOCOL_V1_HEADER_SIZE, thp_control};
use crate::error::{Result, ThpError, TransportError, TrezorError};
use crate::protocol::Protocol;
use crate::protocol::chunk;
use crate::protocol::thp::{
    HandshakeInitResponse, ProtocolThp, StoredCredential, encode_ack,
    encode_channel_allocation_request, encode_encrypted_message,
    encode_handshake_completion_request, encode_handshake_init_request, get_handshake_hash,
    handle_handshake_init, pairing_messages::encode_create_new_session,
    parse_handshake_completion_response, state::ThpHandshakeCredentials,
};
use crate::protocol::v1::ProtocolV1;
use crate::transport::session::SessionManager;
use crate::transport::traits::{DeviceDescriptor, Transport};

/// Callback for pairing code entry
pub type PairingCodeCallback = Arc<dyn Fn() -> String + Send + Sync>;

/// Callback trait for native transport operations.
///
/// This trait must be implemented by the native layer (iOS/Android Kotlin/Swift)
/// to provide the actual USB/Bluetooth I/O operations.
pub trait TransportCallback: Send + Sync {
    /// Enumerate connected devices
    fn enumerate_devices(&self) -> Vec<CallbackDeviceInfo>;

    /// Open a connection to a device
    fn open_device(&self, path: &str) -> CallbackResult;

    /// Close a connection to a device
    fn close_device(&self, path: &str) -> CallbackResult;

    /// Read a chunk of data from the device
    fn read_chunk(&self, path: &str) -> CallbackReadResult;

    /// Write a chunk of data to the device
    fn write_chunk(&self, path: &str, data: &[u8]) -> CallbackResult;

    /// Get the chunk size for a device (64 for USB, 244 for BLE)
    fn get_chunk_size(&self, path: &str) -> u32;

    /// High-level message call for BLE/THP devices.
    ///
    /// For BLE devices that use THP protocol, the native layer handles
    /// encryption/decryption and this method is used for message exchange.
    /// Returns (message_type, raw_protobuf_data).
    ///
    /// Default implementation returns None, meaning the transport should
    /// fall back to chunk-based Protocol V1 communication.
    fn call_message(
        &self,
        path: &str,
        message_type: u16,
        data: &[u8],
    ) -> Option<CallbackMessageResult> {
        // Suppress unused variable warnings
        let _ = (path, message_type, data);
        None // Default: not supported, use chunk-based protocol
    }

    /// Get pairing code from user during BLE THP pairing.
    ///
    /// This is called when the Trezor device displays a 6-digit code
    /// that must be entered to complete Bluetooth pairing.
    ///
    /// Returns the 6-digit code as a string, or empty string to cancel.
    fn get_pairing_code(&self) -> String {
        // Default implementation returns empty string (cancel)
        String::new()
    }

    /// Save THP pairing credentials for a device.
    ///
    /// Called after successful BLE pairing to store credentials for reconnection.
    /// The credential_json is a JSON string containing the serialized ThpCredentials.
    /// The device_id should be a stable identifier for the device (e.g., BLE address).
    ///
    /// Returns true if credentials were saved successfully.
    fn save_thp_credential(&self, device_id: &str, credential_json: &str) -> bool {
        let _ = (device_id, credential_json);
        false // Default: not implemented
    }

    /// Load THP pairing credentials for a device.
    ///
    /// Called before BLE handshake to check for stored credentials.
    /// Returns the JSON string containing ThpCredentials, or None if not found.
    fn load_thp_credential(&self, device_id: &str) -> Option<String> {
        let _ = device_id;
        None // Default: not implemented
    }

    /// Clear THP pairing credentials for a device.
    ///
    /// Called when reconnection with stored credentials fails, to trigger
    /// a fresh pairing flow on retry.
    fn clear_thp_credential(&self, device_id: &str) {
        // Default implementation: save empty credential to clear
        self.save_thp_credential(device_id, "");
    }

    /// Log a debug message to the native debug log.
    ///
    /// Called during THP handshake to forward Rust-level error details
    /// to the native debug UI (e.g., TrezorDebugLog on Android).
    fn log_debug(&self, tag: &str, message: &str) {
        let _ = (tag, message);
        // Default: no-op. Override to capture in native debug log.
    }
}

/// Result from a high-level message call
#[derive(Debug, Clone)]
pub struct CallbackMessageResult {
    /// Whether the call succeeded
    pub success: bool,
    /// Response message type
    pub message_type: u16,
    /// Response protobuf data
    pub data: Vec<u8>,
    /// Error message (empty on success)
    pub error: String,
}

/// Device info returned from callback enumeration
#[derive(Debug, Clone)]
pub struct CallbackDeviceInfo {
    /// Unique path/identifier for this device
    pub path: String,
    /// Transport type: "usb" or "bluetooth"
    pub transport_type: String,
    /// Optional device name
    pub name: Option<String>,
    /// USB Vendor ID (for USB devices)
    pub vendor_id: Option<u16>,
    /// USB Product ID (for USB devices)
    pub product_id: Option<u16>,
}

/// Result from a callback operation
#[derive(Debug, Clone)]
pub struct CallbackResult {
    /// Whether the operation succeeded
    pub success: bool,
    /// Error message (empty on success)
    pub error: String,
}

/// Result from a read callback operation
#[derive(Debug, Clone)]
pub struct CallbackReadResult {
    /// Whether the read succeeded
    pub success: bool,
    /// Data read (empty on failure)
    pub data: Vec<u8>,
    /// Error message (empty on success)
    pub error: String,
}

/// JSON-serializable THP credential for storage
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct StoredCredentialJson {
    /// Host static private key (hex)
    pub host_static_key: String,
    /// Trezor static public key (hex)
    pub trezor_static_public_key: String,
    /// Credential token (hex)
    pub credential: String,
}

impl From<StoredCredentialJson> for StoredCredential {
    fn from(json: StoredCredentialJson) -> Self {
        let host_static_key: [u8; 32] = hex::decode(&json.host_static_key)
            .ok()
            .and_then(|v| v.try_into().ok())
            .unwrap_or([0u8; 32]);
        let trezor_static_public_key: [u8; 32] = hex::decode(&json.trezor_static_public_key)
            .ok()
            .and_then(|v| v.try_into().ok())
            .unwrap_or([0u8; 32]);
        let credential = hex::decode(&json.credential).unwrap_or_default();

        StoredCredential {
            host_static_key,
            trezor_static_public_key,
            credential,
        }
    }
}

impl From<&StoredCredential> for StoredCredentialJson {
    fn from(cred: &StoredCredential) -> Self {
        StoredCredentialJson {
            host_static_key: hex::encode(cred.host_static_key),
            trezor_static_public_key: hex::encode(cred.trezor_static_public_key),
            credential: hex::encode(&cred.credential),
        }
    }
}

/// State for a connected BLE device (THP)
struct BleDeviceState {
    /// THP protocol instance
    protocol: ProtocolThp,
    /// Whether THP handshake is complete
    handshake_complete: bool,
}

/// Callback-based transport for mobile platforms.
///
/// Uses a callback interface for all device I/O operations, allowing
/// native code (iOS/Android) to handle USB and Bluetooth communication.
#[allow(dead_code)]
pub struct CallbackTransport {
    /// The callback implementation provided by native code
    callback: Arc<dyn TransportCallback>,
    /// Session manager for tracking active sessions
    sessions: SessionManager,
    /// Protocol encoder/decoder for USB (V1)
    protocol: ProtocolV1,
    /// Chunk size (determined per device)
    chunk_size: usize,
    /// BLE device states (path -> state)
    ble_states: Arc<RwLock<HashMap<String, BleDeviceState>>>,
    /// Pairing code callback
    pairing_callback: Option<PairingCodeCallback>,
    /// Host name for THP pairing identity
    host_name: String,
    /// Application name for THP pairing identity
    app_name: String,
    /// Cache of transport type from enumerate() (path -> is_bluetooth)
    transport_type_cache: Arc<RwLock<HashMap<String, bool>>>,
    /// Per-device call serialization locks (path -> mutex).
    /// Ensures only one call() is in-flight per device at a time.
    call_locks: Arc<std::sync::Mutex<HashMap<String, Arc<tokio::sync::Mutex<()>>>>>,
    /// Passphrase bound to the THP session at `ThpCreateNewSession` time.
    /// Empty string opens the standard wallet. Ignored when
    /// `session_on_device` is true (the device prompts on its own screen).
    ///
    /// Wrapped in `Zeroizing` so the passphrase buffer is wiped from memory when
    /// the transport is dropped, rather than lingering for the process lifetime.
    session_passphrase: Zeroizing<String>,
    /// When true, the THP session is created with `on_device = true` so the
    /// user enters the passphrase on the Trezor instead of the host.
    session_on_device: bool,
}

impl CallbackTransport {
    /// Create a new CallbackTransport with the given callback implementation
    pub fn new(callback: Arc<dyn TransportCallback>) -> Self {
        Self {
            callback,
            sessions: SessionManager::new(),
            protocol: ProtocolV1::usb(), // Default, will be adjusted per device
            chunk_size: 64,              // Default USB, adjusted on open
            ble_states: Arc::new(RwLock::new(HashMap::new())),
            pairing_callback: None,
            host_name: "trezor-connect-rs".to_string(),
            app_name: "trezor-connect-rs".to_string(),
            transport_type_cache: Arc::new(RwLock::new(HashMap::new())),
            call_locks: Arc::new(std::sync::Mutex::new(HashMap::new())),
            session_passphrase: Zeroizing::new(String::new()),
            session_on_device: false,
        }
    }

    /// Create a CallbackTransport with a specific chunk size
    pub fn with_chunk_size(callback: Arc<dyn TransportCallback>, chunk_size: usize) -> Self {
        Self {
            callback,
            sessions: SessionManager::new(),
            protocol: ProtocolV1::with_chunk_size(chunk_size),
            chunk_size,
            ble_states: Arc::new(RwLock::new(HashMap::new())),
            pairing_callback: None,
            host_name: "trezor-connect-rs".to_string(),
            app_name: "trezor-connect-rs".to_string(),
            transport_type_cache: Arc::new(RwLock::new(HashMap::new())),
            call_locks: Arc::new(std::sync::Mutex::new(HashMap::new())),
            session_passphrase: Zeroizing::new(String::new()),
            session_on_device: false,
        }
    }

    /// Set the passphrase bound to the THP session created during `acquire()`.
    ///
    /// `passphrase` opens the corresponding hidden wallet (empty = standard).
    /// When `on_device` is true the passphrase is entered on the Trezor itself
    /// and `passphrase` is ignored. Must be called before `acquire()`.
    ///
    /// The passphrase is NFKD-normalized (matching `@trezor/connect`) and held
    /// in `Zeroizing` for the transport's lifetime, wiped from memory on drop.
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

    /// Set the pairing code callback for BLE devices
    pub fn set_pairing_callback(&mut self, callback: PairingCodeCallback) {
        self.pairing_callback = Some(callback);
    }

    /// Set the application identity used during THP pairing.
    pub fn with_app_identity(
        mut self,
        host_name: impl Into<String>,
        app_name: impl Into<String>,
    ) -> Self {
        self.host_name = host_name.into();
        self.app_name = app_name.into();
        self
    }

    /// Check if a device completed a THP handshake (BLE or USB-THP).
    pub async fn has_thp(&self, path: &str) -> bool {
        let states = self.ble_states.read().await;
        states
            .get(path)
            .map(|s| s.handshake_complete)
            .unwrap_or(false)
    }

    /// Check if a device needs THP — either a known BLE device or a device
    /// that has already completed a THP handshake (e.g., USB Safe 7).
    async fn needs_thp(&self, path: &str) -> bool {
        // Check if THP was already negotiated
        {
            let states = self.ble_states.read().await;
            if states.contains_key(path) {
                return true;
            }
        }
        // Fall back to BLE detection
        self.is_ble_device(path).await
    }

    /// Heuristic check if a path is a BLE device (fallback when cache misses)
    fn is_ble_device_heuristic(path: &str) -> bool {
        path.starts_with("ble:") || path.contains("bluetooth")
    }

    /// Check if a path is a BLE device, using the enumerate() cache first
    async fn is_ble_device(&self, path: &str) -> bool {
        let cache = self.transport_type_cache.read().await;
        if let Some(&is_ble) = cache.get(path) {
            return is_ble;
        }
        drop(cache);
        Self::is_ble_device_heuristic(path)
    }

    /// Send a Cancel message via V1 and check if device responds with
    /// Failure_InvalidProtocol. Returns true if the device needs THP.
    fn detect_thp_protocol(&self, path: &str) -> Result<bool> {
        log::debug!("[Callback] Sending Cancel message for THP detection on USB device...");

        let chunk_size = self.callback.get_chunk_size(path) as usize;
        let protocol = ProtocolV1::with_chunk_size(chunk_size);

        // Encode Cancel (message type 20, empty payload) via Protocol V1
        let cancel_type: u16 = 20;
        let encoded = protocol.encode(cancel_type, &[])?;
        let (_, chunk_header) = protocol.get_headers(&encoded);
        let chunks = chunk::create_chunks(&encoded, &chunk_header, chunk_size);

        for c in &chunks {
            let result = self.callback.write_chunk(path, c);
            if !result.success {
                return Err(TransportError::DataTransfer(result.error).into());
            }
        }

        // Read response
        for _ in 0..20 {
            let read_result = self.callback.read_chunk(path);
            if !read_result.success || read_result.data.is_empty() {
                std::thread::sleep(std::time::Duration::from_millis(100));
                continue;
            }
            let chunk = &read_result.data;

            // Check for V1 header: 0x3F + 0x23 0x23
            if chunk.len() >= 3 && chunk[0] == 0x3F && chunk[1] == 0x23 && chunk[2] == 0x23 {
                if let Ok(decoded) = protocol.decode(chunk) {
                    // Failure message (type 3)
                    if decoded.message_type == 3 {
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
                            if failure.code == Some(17) {
                                // FailureInvalidProtocol
                                log::info!(
                                    "[Callback] USB device responded with Failure_InvalidProtocol — THP detected!"
                                );
                                return Ok(true);
                            }
                        }
                    }
                }
                // Any other V1 response means device speaks V1
                log::debug!("[Callback] USB device responded with V1 protocol");
                return Ok(false);
            }

            // Non-V1 response — likely THP
            let ctrl = chunk[0] & 0xe7;
            if ctrl == thp_control::CHANNEL_ALLOCATION_RES
                || ctrl == thp_control::ERROR
                || ctrl == thp_control::HANDSHAKE_INIT_RES
            {
                log::info!(
                    "[Callback] USB device responded with THP control byte 0x{:02x} — THP detected!",
                    chunk[0]
                );
                return Ok(true);
            }
        }

        log::debug!("[Callback] No definitive protocol response, defaulting to V1");
        Ok(false)
    }

    /// Write raw data to device (for THP handshake)
    ///
    /// If data exceeds chunk_size, splits into first chunk + continuation packets
    /// with `[0x80, channel[0], channel[1], ...data...]` header.
    fn write_raw(&self, path: &str, data: &[u8]) -> Result<()> {
        let chunk_size = self.callback.get_chunk_size(path) as usize;

        if data.len() <= chunk_size {
            // Single chunk - pad to chunk_size
            let mut padded = vec![0u8; chunk_size];
            padded[..data.len()].copy_from_slice(data);

            log::debug!(
                "[Callback] Writing {} bytes (padded to {}): {:02x?}",
                data.len(),
                padded.len(),
                &padded[..padded.len().min(20)]
            );

            let result = self.callback.write_chunk(path, &padded);
            if !result.success {
                return Err(TransportError::DataTransfer(result.error).into());
            }
        } else {
            // Multi-chunk: extract channel from first chunk bytes [1..3]
            let channel = if data.len() >= 3 {
                [data[1], data[2]]
            } else {
                [0, 0]
            };

            log::debug!(
                "[Callback] Multi-chunk write: {} bytes total, chunk_size={}",
                data.len(),
                chunk_size
            );

            // First chunk: first chunk_size bytes, padded
            let first_end = chunk_size.min(data.len());
            let mut first_chunk = vec![0u8; chunk_size];
            first_chunk[..first_end].copy_from_slice(&data[..first_end]);

            let result = self.callback.write_chunk(path, &first_chunk);
            if !result.success {
                return Err(TransportError::DataTransfer(result.error).into());
            }

            // Continuation chunks: [CONTINUATION_PACKET | channel(2) | data...]
            let cont_header_len = 3; // ctrl(1) + channel(2)
            let cont_payload_size = chunk_size - cont_header_len;
            let mut offset = first_end;

            while offset < data.len() {
                let end = (offset + cont_payload_size).min(data.len());
                let mut cont_chunk = vec![0u8; chunk_size];
                cont_chunk[0] = thp_control::CONTINUATION_PACKET;
                cont_chunk[1] = channel[0];
                cont_chunk[2] = channel[1];
                let payload_len = end - offset;
                cont_chunk[cont_header_len..cont_header_len + payload_len]
                    .copy_from_slice(&data[offset..end]);

                log::debug!(
                    "[Callback] Writing continuation chunk: {} bytes payload at offset {}",
                    payload_len,
                    offset
                );

                let result = self.callback.write_chunk(path, &cont_chunk);
                if !result.success {
                    return Err(TransportError::DataTransfer(result.error).into());
                }
                offset = end;
            }
        }
        Ok(())
    }

    /// Read with timeout (for THP handshake)
    fn read_with_timeout(&self, path: &str, max_attempts: u32) -> Result<Vec<u8>> {
        for attempt in 0..max_attempts {
            let result = self.callback.read_chunk(path);
            if result.success && !result.data.is_empty() {
                log::debug!(
                    "[Callback] Read {} bytes on attempt {}: {:02x?}",
                    result.data.len(),
                    attempt,
                    &result.data[..result.data.len().min(20)]
                );
                return Ok(result.data);
            }
            // Intentional thread::sleep — callback transport runs synchronous
            // FFI calls on a dedicated thread, not on the tokio async runtime.
            std::thread::sleep(std::time::Duration::from_millis(100));
        }
        Err(TransportError::DataTransfer("Read timeout".to_string()).into())
    }

    /// Check if message is an ACK
    fn is_ack(data: &[u8]) -> bool {
        if data.is_empty() {
            return false;
        }
        (data[0] & 0xf7) == thp_control::ACK_MESSAGE
    }

    /// Validate CRC32 on a received THP message.
    fn validate_crc(data: &[u8]) -> Result<()> {
        // Minimum message: ctrl(1) + channel(2) + length(2) + crc(4) = 9 bytes
        if data.len() < 9 {
            return Ok(()); // Too short to have CRC, skip validation
        }
        let payload_len = u16::from_be_bytes([data[3], data[4]]) as usize;
        let total_expected = 5 + payload_len;
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
    fn validate_channel(data: &[u8], expected_channel: &[u8; 2]) -> Result<()> {
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

    /// Read response, skipping ACKs and handling continuation packets (for THP)
    fn read_response(
        &self,
        path: &str,
        max_attempts: u32,
        expected_channel: Option<&[u8; 2]>,
    ) -> Result<Vec<u8>> {
        let chunk_size = self.callback.get_chunk_size(path) as usize;

        for _ in 0..max_attempts {
            let first_chunk = self.read_with_timeout(path, 50)?;
            let ctrl_byte = first_chunk.get(0).copied().unwrap_or(0);
            let ctrl_type = ctrl_byte & 0xe7;

            log::debug!(
                "[Callback] << Received: ctrl=0x{:02x} (type=0x{:02x}), len={}",
                ctrl_byte,
                ctrl_type,
                first_chunk.len()
            );

            // Validate CRC32 on the received message
            Self::validate_crc(&first_chunk)?;

            // Validate channel matches (if provided)
            if let Some(ch) = expected_channel {
                Self::validate_channel(&first_chunk, ch)?;
            }

            if Self::is_ack(&first_chunk) {
                log::trace!("[Callback] (This is an ACK, waiting for actual response...)");
                continue;
            }

            // Check for error message
            if ctrl_type == thp_control::ERROR {
                let error_code = first_chunk.get(5).copied().unwrap_or(0);
                let error_name = match error_code {
                    0x01 => "TransportBusy",
                    0x02 => "UnallocatedChannel",
                    0x03 => "DecryptionFailed",
                    0x05 => "DeviceLocked",
                    _ => "Unknown",
                };
                log::error!(
                    "[Callback] THP Error: {} (0x{:02x})",
                    error_name,
                    error_code
                );
                // DeviceLocked is a distinct, typed state: the device needs to be
                // unlocked before the handshake can proceed. Surfacing it as a
                // dedicated variant lets perform_thp_handshake back off (one
                // try_to_unlock retry) instead of churning the transport.
                if error_code == 0x05 {
                    return Err(ThpError::DeviceLocked.into());
                }
                return Err(ThpError::HandshakeFailed(format!("THP Error: {}", error_name)).into());
            }

            // Check if this is a multi-chunk message
            // THP header: ctrl(1) + channel(2) + length(2) = 5 bytes
            if first_chunk.len() >= 5 {
                let payload_len = u16::from_be_bytes([first_chunk[3], first_chunk[4]]) as usize;
                let total_needed = 5 + payload_len; // header + payload

                if total_needed > chunk_size {
                    // Need to read continuation packets
                    log::debug!(
                        "[Callback] Multi-chunk message: need {} bytes, have {}",
                        total_needed,
                        first_chunk.len()
                    );

                    let mut full_data = first_chunk.clone();
                    let mut bytes_remaining = total_needed - first_chunk.len();

                    // Read continuation packets
                    while bytes_remaining > 0 {
                        let cont_chunk = self.read_with_timeout(path, 50)?;
                        let cont_ctrl = cont_chunk.get(0).copied().unwrap_or(0);

                        // Skip ACKs
                        if Self::is_ack(&cont_chunk) {
                            log::trace!("[Callback] (Continuation: skipping ACK)");
                            continue;
                        }

                        // Check if this is a continuation packet (0x80 bit set)
                        if (cont_ctrl & 0x80) != 0x80 {
                            log::warn!(
                                "[Callback] Expected continuation packet, got ctrl=0x{:02x}",
                                cont_ctrl
                            );
                            // This might be a new message, handle it
                            break;
                        }

                        // Continuation packet format: ctrl(1) + channel(2) + data...
                        // We append only the data portion (skip ctrl + channel)
                        if cont_chunk.len() > 3 {
                            let cont_data = &cont_chunk[3..];
                            full_data.extend_from_slice(cont_data);
                            bytes_remaining = bytes_remaining.saturating_sub(cont_data.len());
                            log::debug!(
                                "[Callback] Read continuation: {} bytes, {} remaining",
                                cont_data.len(),
                                bytes_remaining
                            );
                        }
                    }

                    log::debug!("[Callback] Complete message: {} bytes", full_data.len());
                    return Ok(full_data);
                }
            }

            return Ok(first_chunk);
        }
        Err(TransportError::DataTransfer("No response after max attempts".to_string()).into())
    }

    /// Perform THP handshake for BLE device with automatic retry on errors.
    ///
    /// Retries up to MAX_HANDSHAKE_RETRIES times with stored credentials before
    /// giving up and clearing them. BLE connections are inherently unreliable —
    /// a failed first attempt often leaves the device in a bad state, causing
    /// subsequent crypto errors that are NOT caused by bad credentials.
    ///
    /// Only clears credentials and forces fresh pairing after all retries with
    /// stored credentials are exhausted.
    async fn perform_thp_handshake(&self, path: &str) -> Result<()> {
        const MAX_RETRIES: usize = 3;

        self.callback.log_debug(
            "HANDSHAKE",
            &format!("Starting THP handshake with up to {} retries", MAX_RETRIES),
        );

        for attempt in 0..MAX_RETRIES {
            let msg = format!(
                "Attempt {}/{} with stored credentials",
                attempt + 1,
                MAX_RETRIES
            );
            log::info!("[Callback] {}", msg);
            self.callback.log_debug("HANDSHAKE", &msg);

            // Close and reopen on retries to get a clean BLE connection
            if attempt > 0 {
                log::info!("[Callback] Closing device and reopening for retry...");
                let _ = self.callback.close_device(path);
                {
                    let mut states = self.ble_states.write().await;
                    states.remove(path);
                }
                // Longer delay on later retries to give device time to clean up
                let delay = if attempt >= 2 { 3000 } else { 2000 };
                self.callback.log_debug(
                    "HANDSHAKE",
                    &format!("Waiting {}ms before reopen...", delay),
                );
                std::thread::sleep(std::time::Duration::from_millis(delay));

                let reopen = self.callback.open_device(path);
                if !reopen.success {
                    let msg = format!("Failed to reopen device: {}", reopen.error);
                    log::error!("[Callback] {}", msg);
                    self.callback.log_debug("HANDSHAKE", &msg);
                    return Err(TransportError::DeviceNotFound.into());
                }
            }

            match self.perform_thp_handshake_inner(path, false, false).await {
                Ok(()) => {
                    let msg = format!("Handshake succeeded on attempt {}", attempt + 1);
                    log::info!("[Callback] {}", msg);
                    self.callback.log_debug("HANDSHAKE", &msg);
                    return Ok(());
                }
                Err(e) => {
                    let error_str = e.to_string();
                    let msg = format!("Attempt {} FAILED: {}", attempt + 1, error_str);
                    log::warn!("[Callback] {}", msg);
                    self.callback.log_debug("HANDSHAKE", &msg);

                    // A locked device is NOT a transient transport failure, so it must
                    // not enter the close/sleep/reopen churn loop (that keeps the device
                    // busy — see bitkit-ios#613 / bitkit-android#1030). Suite parity: do
                    // one clean reopen, then a single handshake with try_to_unlock=true so
                    // the *device* prompts the user to unlock. Whatever that attempt
                    // returns — success, or DeviceLocked again if the user declined — is
                    // surfaced to the caller, which owns any further back-off.
                    if matches!(&e, TrezorError::Thp(ThpError::DeviceLocked)) {
                        self.callback.log_debug(
                            "HANDSHAKE",
                            "Device locked — retrying once with try_to_unlock (no reopen churn)",
                        );
                        log::info!(
                            "[Callback] Device locked; retrying handshake once with try_to_unlock=true"
                        );
                        let _ = self.callback.close_device(path);
                        {
                            let mut states = self.ble_states.write().await;
                            states.remove(path);
                        }
                        let reopen = self.callback.open_device(path);
                        if !reopen.success {
                            log::error!(
                                "[Callback] Failed to reopen device for unlock retry: {}",
                                reopen.error
                            );
                            return Err(TransportError::DeviceNotFound.into());
                        }
                        return self.perform_thp_handshake_inner(path, false, true).await;
                    }

                    // If the device explicitly rejected our credential, skip remaining
                    // retries and go straight to fresh pairing. Retrying with the same
                    // credential just wastes device channel slots.
                    if error_str.contains("CredentialRejected") {
                        self.callback.log_debug(
                            "HANDSHAKE",
                            "Credential rejected — skipping to fresh pairing",
                        );
                        break;
                    }

                    // Check if the error is retryable
                    let is_retryable = !error_str.contains("Pairing cancelled by user")
                        && !error_str.contains("Code verification failed")
                        && (error_str.contains("Not connected")
                        || error_str.contains("Data transfer error")
                        || error_str.contains("DecryptionError")
                        || error_str.contains("DecryptionFailed")
                        || error_str.contains("aead::Error")
                        || error_str.contains("SessionError")
                        || error_str.contains("Unexpected response")
                        || error_str.contains("Timed out")
                        || error_str.contains("Pairing failed")
                        // Transient THP errors worth a reopen+retry. DeviceLocked is
                        // deliberately excluded (handled above); the previous broad
                        // `contains("THP Error")` also matched it and drove the churn.
                        || error_str.contains("TransportBusy")
                        || error_str.contains("UnallocatedChannel")
                        || error_str.contains("Read timeout")
                        || error_str.contains("Write failed")
                        || error_str.contains("Device disconnected"));

                    if !is_retryable {
                        self.callback
                            .log_debug("HANDSHAKE", &format!("Non-retryable error: {}", error_str));
                        return Err(e);
                    }
                }
            }
        }

        // All retries with stored credentials failed — clear and do fresh pairing
        self.callback.log_debug(
            "HANDSHAKE",
            "All retries FAILED, clearing credentials for fresh pairing",
        );
        log::warn!(
            "[Callback] All {} attempts with stored credentials failed, clearing credentials and doing fresh pairing",
            MAX_RETRIES
        );
        self.callback.clear_thp_credential(path);
        let _ = self.callback.close_device(path);
        {
            let mut states = self.ble_states.write().await;
            states.remove(path);
        }
        std::thread::sleep(std::time::Duration::from_millis(2000));

        let reopen = self.callback.open_device(path);
        if !reopen.success {
            log::error!(
                "[Callback] Failed to reopen device for fresh pairing: {}",
                reopen.error
            );
            return Err(TransportError::DeviceNotFound.into());
        }

        log::info!("[Callback] Starting fresh pairing (credentials cleared)...");
        self.callback.log_debug(
            "HANDSHAKE",
            "Starting fresh pairing (credentials cleared)...",
        );
        self.perform_thp_handshake_inner(path, true, false).await
    }

    /// Inner THP handshake implementation
    /// - `skip_stored_credentials`: If true, ignore stored credentials and force fresh pairing
    /// - `try_to_unlock`: If true, ask the device to prompt the user to unlock as
    ///   part of the handshake. Suite only sets this on a retry after the device
    ///   reported ThpDeviceLocked.
    async fn perform_thp_handshake_inner(
        &self,
        path: &str,
        skip_stored_credentials: bool,
        try_to_unlock: bool,
    ) -> Result<()> {
        log::info!(
            "[Callback] Starting THP handshake for BLE device (skip_stored_credentials={})...",
            skip_stored_credentials
        );
        self.callback.log_debug(
            "THP",
            &format!(
                "Handshake inner start (skip_stored={})",
                skip_stored_credentials
            ),
        );

        // Try to load stored credentials for reconnection (unless explicitly skipped)
        let stored_credential: Option<StoredCredential> = if skip_stored_credentials {
            log::info!("[Callback] Skipping stored credentials as requested");
            None
        } else {
            self.callback.load_thp_credential(path)
                .and_then(|json| {
                    log::info!("[Callback] Loaded credential JSON ({} bytes) for device", json.len());
                    serde_json::from_str::<StoredCredentialJson>(&json)
                        .map(|c| {
                            log::info!("[Callback] Parsed credential: host_key={}bytes, trezor_key={}bytes, credential={}bytes",
                                c.host_static_key.len(), c.trezor_static_public_key.len(), c.credential.len());
                            c.into()
                        })
                        .map_err(|e| {
                            log::warn!("[Callback] Failed to parse stored credentials: {}", e);
                            e
                        })
                        .ok()
                })
        };

        // Match Trezor Suite: try_to_unlock is false by default and only set
        // true on a retry after the device reported ThpDeviceLocked (see the
        // DeviceLocked branch in perform_thp_handshake). Stored credentials are
        // used regardless of this flag — credential matching happens in
        // handle_handshake_init.
        let has_credentials = stored_credential.is_some();
        self.callback.log_debug(
            "THP",
            &format!(
                "try_to_unlock={}, has_credentials={}",
                try_to_unlock, has_credentials
            ),
        );
        log::info!(
            "[Callback] try_to_unlock = {} (stored credentials {})",
            try_to_unlock,
            if has_credentials {
                "found"
            } else {
                "not found"
            }
        );

        // Step 1: Channel Allocation
        let channel_req = encode_channel_allocation_request();
        self.callback
            .log_debug("THP", "Sending channel allocation request...");
        log::debug!(
            "[Callback] Sending channel allocation request ({} bytes)",
            channel_req.len()
        );
        self.write_raw(path, &channel_req)?;
        self.callback.log_debug(
            "THP",
            "Channel allocation request sent, reading response...",
        );

        let channel_resp = self.read_response(path, 100, None)?;
        log::debug!(
            "[Callback] Channel response: {:02x?}",
            &channel_resp[..channel_resp.len().min(16)]
        );

        if channel_resp.is_empty() || channel_resp[0] != thp_control::CHANNEL_ALLOCATION_RES {
            return Err(ThpError::HandshakeFailed(format!(
                "Expected channel allocation response, got: {:02x}",
                channel_resp.get(0).unwrap_or(&0)
            ))
            .into());
        }

        // Parse channel from response
        if channel_resp.len() < 15 {
            return Err(ThpError::HandshakeFailed(format!(
                "Channel allocation response too short: {} bytes",
                channel_resp.len()
            ))
            .into());
        }
        let channel: [u8; 2] = [channel_resp[13], channel_resp[14]];
        log::info!(
            "[Callback] Received allocated channel: {:02x}{:02x}",
            channel[0],
            channel[1]
        );
        self.callback.log_debug(
            "THP",
            &format!("Channel allocated: {:02x}{:02x}", channel[0], channel[1]),
        );

        // Extract device properties
        let payload_len = u16::from_be_bytes([channel_resp[3], channel_resp[4]]) as usize;
        let props_start = 5 + 8 + 2;
        let props_end = 5 + payload_len - 4;
        let device_properties = if channel_resp.len() >= props_end {
            channel_resp[props_start..props_end].to_vec()
        } else {
            vec![]
        };

        // Create/update BLE state
        {
            let mut states = self.ble_states.write().await;
            let state = states
                .entry(path.to_string())
                .or_insert_with(|| BleDeviceState {
                    protocol: ProtocolThp::new(),
                    handshake_complete: false,
                });
            state.protocol.state_mut().set_channel(channel);
        }

        // Small delay
        std::thread::sleep(std::time::Duration::from_millis(100));

        // Step 2: Handshake Init
        self.callback
            .log_debug("THP", "Sending handshake init request...");
        log::debug!("[Callback] Generating ephemeral keypair...");
        let ephemeral_secret: [u8; 32] = rand::random();
        let (_, host_ephemeral_pubkey) =
            crate::protocol::thp::crypto::keypair_from_secret(&ephemeral_secret);

        let send_bit = {
            let states = self.ble_states.read().await;
            states
                .get(path)
                .map(|s| s.protocol.state().send_bit())
                .unwrap_or(0)
        };

        log::debug!(
            "[Callback] Sending handshake init request (try_to_unlock={})...",
            try_to_unlock
        );
        let init_req = encode_handshake_init_request(
            &channel,
            host_ephemeral_pubkey.as_bytes(),
            try_to_unlock,
            send_bit,
        );
        self.write_raw(path, &init_req)?;

        // Toggle send_bit
        {
            let mut states = self.ble_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state.protocol.state_mut().update_sync_bit(true);
            }
        }

        // Read handshake init response. When try_to_unlock is set the device
        // prompts the user to unlock before replying, so allow the full 60s
        // user-interaction budget instead of the default ~10s.
        self.callback
            .log_debug("THP", "Waiting for handshake init response...");
        let init_read_attempts = if try_to_unlock { 600 } else { 100 };
        let init_resp = self.read_response(path, init_read_attempts, Some(&channel))?;
        self.callback.log_debug(
            "THP",
            &format!("Got handshake init response ({} bytes)", init_resp.len()),
        );
        log::debug!(
            "[Callback] Handshake init response: {:02x?}",
            &init_resp[..init_resp.len().min(32)]
        );

        if init_resp.is_empty() || (init_resp[0] & 0xe7) != thp_control::HANDSHAKE_INIT_RES {
            return Err(ThpError::HandshakeFailed(format!(
                "Expected handshake init response, got: {:02x}",
                init_resp.get(0).unwrap_or(&0)
            ))
            .into());
        }

        // Send ACK
        let ack_bit = (init_resp[0] >> 4) & 1;
        let ack = encode_ack(&channel, ack_bit);
        self.write_raw(path, &ack)?;

        std::thread::sleep(std::time::Duration::from_millis(100));

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

        // Initialize handshake state
        {
            let mut states = self.ble_states.write().await;
            if let Some(state) = states.get_mut(path) {
                let handshake_hash = get_handshake_hash(&device_properties);
                let mut creds = ThpHandshakeCredentials::default();
                creds.handshake_hash = handshake_hash.to_vec();
                state.protocol.state_mut().set_handshake_credentials(creds);
            }
        }

        // Handle handshake init response
        let init_response = HandshakeInitResponse {
            trezor_ephemeral_pubkey,
            trezor_encrypted_static_pubkey: trezor_encrypted_static,
            tag,
        };

        let completion_req = {
            let mut states = self.ble_states.write().await;
            let state = states.get_mut(path).ok_or(TransportError::DeviceNotFound)?;
            handle_handshake_init(
                state.protocol.state_mut(),
                &init_response,
                &ephemeral_secret,
                try_to_unlock,
                stored_credential.as_ref(),
            )?
        };

        // Log whether credential was included in the completion payload.
        // GCM tag alone = 16 bytes; anything larger means a credential was sent.
        let credential_was_sent = completion_req.encrypted_payload.len() > 16;
        self.callback.log_debug(
            "THP",
            &format!(
                "Completion payload: {} bytes (credential_sent={})",
                completion_req.encrypted_payload.len(),
                credential_was_sent
            ),
        );

        // Step 3: Handshake Completion
        let send_bit = {
            let states = self.ble_states.read().await;
            states
                .get(path)
                .map(|s| s.protocol.state().send_bit())
                .unwrap_or(0)
        };

        log::debug!("[Callback] Sending handshake completion request...");
        let comp_req = encode_handshake_completion_request(
            &channel,
            &completion_req.encrypted_host_static_pubkey,
            &completion_req.encrypted_payload,
            send_bit,
        );
        self.write_raw(path, &comp_req)?;

        // Toggle send_bit
        {
            let mut states = self.ble_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state.protocol.state_mut().update_sync_bit(true);
            }
        }

        log::info!("[Callback] ============================================================");
        log::info!("[Callback] >>> CHECK YOUR TREZOR SCREEN! <<<");
        log::info!("[Callback] If a pairing confirmation appears, please approve it.");
        log::info!("[Callback] ============================================================");

        // Read completion response (long timeout for user interaction)
        self.callback
            .log_debug("THP", "Waiting for handshake completion response...");
        let comp_resp = self.read_response(path, 600, Some(&channel))?; // 60 seconds
        self.callback.log_debug(
            "THP",
            &format!(
                "Got handshake completion response ({} bytes)",
                comp_resp.len()
            ),
        );
        log::debug!(
            "[Callback] Handshake completion response: {:02x?}",
            &comp_resp[..comp_resp.len().min(16)]
        );

        // Send ACK
        let ack_bit = (comp_resp[0] >> 4) & 1;
        let ack = encode_ack(&channel, ack_bit);
        self.write_raw(path, &ack)?;

        // Check if pairing is required
        let ctrl = comp_resp[0] & 0xe7;
        if ctrl == thp_control::HANDSHAKE_COMP_RES {
            let payload_len = u16::from_be_bytes([comp_resp[3], comp_resp[4]]) as usize;
            let crc_len = 4;

            if comp_resp.len() >= 5 + payload_len && payload_len > crc_len {
                let encrypted_payload = &comp_resp[5..5 + payload_len - crc_len];

                let completion = {
                    let states = self.ble_states.read().await;
                    let state = states.get(path).ok_or(TransportError::DeviceNotFound)?;
                    parse_handshake_completion_response(state.protocol.state(), encrypted_payload)?
                };

                self.callback.log_debug(
                    "THP",
                    &format!(
                        "trezor_state={} (0=needs pairing, 1=paired, 2=autoconnect)",
                        completion.trezor_state
                    ),
                );
                self.callback.log_debug(
                    "THP",
                    &format!("pairing_methods={:?}", completion.pairing_methods),
                );
                log::info!(
                    "[Callback] Device trezor_state={} (0=needs pairing, 1=paired, 2=autoconnect)",
                    completion.trezor_state
                );
                log::info!(
                    "[Callback] Available pairing methods: {:?}",
                    completion.pairing_methods
                );

                if completion.trezor_state == 0 {
                    if credential_was_sent {
                        // We sent a credential but the device didn't recognize it.
                        // Do NOT attempt pairing in this session — the device may reject it.
                        // Return a specific error so the outer retry loop can skip straight
                        // to fresh pairing with a clean handshake.
                        self.callback.log_debug("THP", "CREDENTIAL REJECTED: sent credential but device returned state=0. Aborting to retry fresh.");
                        log::warn!(
                            "[Callback] Credential rejected by device (state=0 despite sending credential). Will retry fresh."
                        );
                        return Err(ThpError::HandshakeFailed(
                            "CredentialRejected: device returned state=0 despite credential"
                                .to_string(),
                        )
                        .into());
                    }
                    self.callback.log_debug("THP", "Device requires PAIRING (state=0, no credential sent) - starting pairing flow");
                    log::info!("[Callback] Device requires pairing - starting pairing flow");
                    self.perform_pairing(path, &channel).await?;
                } else {
                    // Device accepted stored credentials (state=1: paired, state=2: autoconnect)
                    // Must send ThpEndRequest to finalize connection before session creation
                    // This matches trezor-suite which ALWAYS sends ThpEndRequest regardless of state
                    self.callback.log_debug(
                        "THP",
                        &format!(
                            "Stored credentials ACCEPTED (state={}), finalizing...",
                            completion.trezor_state
                        ),
                    );
                    log::info!(
                        "[Callback] Device recognized stored credentials (state={}), finalizing connection...",
                        completion.trezor_state
                    );

                    // Mark as paired to enable encrypted messaging
                    {
                        let mut states = self.ble_states.write().await;
                        if let Some(state) = states.get_mut(path) {
                            state.protocol.state_mut().set_is_paired(true);
                        }
                    }

                    use crate::constants::thp_message_type;

                    let (end_resp_type, _) = self
                        .send_encrypted_message(
                            path,
                            &channel,
                            thp_message_type::THP_END_REQUEST,
                            &[],
                        )
                        .await?;

                    // state=1 may trigger a ButtonRequest for connection confirmation on the device
                    if end_resp_type == crate::constants::message_type::BUTTON_REQUEST {
                        log::info!("[Callback] Device requesting connection confirmation...");
                        let (ack_resp_type, _) = self
                            .send_encrypted_message(
                                path,
                                &channel,
                                crate::constants::message_type::BUTTON_ACK,
                                &[],
                            )
                            .await?;
                        if ack_resp_type != thp_message_type::THP_END_RESPONSE {
                            return Err(ThpError::HandshakeFailed(format!(
                                "Expected ThpEndResponse after ButtonACK, got: {}",
                                ack_resp_type
                            ))
                            .into());
                        }
                    } else if end_resp_type != thp_message_type::THP_END_RESPONSE {
                        return Err(ThpError::HandshakeFailed(format!(
                            "Expected ThpEndResponse, got: {}",
                            end_resp_type
                        ))
                        .into());
                    }

                    self.callback.log_debug(
                        "THP",
                        "Connection finalized with stored credentials (no re-pairing needed)",
                    );
                    log::info!(
                        "[Callback] Connection finalized with stored credentials (no re-pairing needed)"
                    );
                }
            }
        }

        // Mark as paired
        {
            let mut states = self.ble_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state.protocol.state_mut().set_is_paired(true);
            }
        }

        // Create THP session
        self.callback.log_debug("THP", "Creating THP session...");
        self.create_thp_session(path, &channel).await?;

        self.callback.log_debug("THP", "THP handshake COMPLETE!");
        log::info!("[Callback] THP handshake complete!");

        // Mark handshake as complete
        {
            let mut states = self.ble_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state.handshake_complete = true;
            }
        }

        Ok(())
    }

    /// Send encrypted THP message
    async fn send_encrypted_message(
        &self,
        path: &str,
        channel: &[u8; 2],
        message_type: u16,
        data: &[u8],
    ) -> Result<(u16, Vec<u8>)> {
        // Encode encrypted message
        let message = {
            let states = self.ble_states.read().await;
            let state = states.get(path).ok_or(TransportError::DeviceNotFound)?;
            encode_encrypted_message(state.protocol.state(), message_type, data)?
        };

        log::debug!(
            "[Callback] Sending encrypted message type {} ({} bytes)",
            message_type,
            message.len()
        );
        self.write_raw(path, &message)?;

        // Update state
        {
            let mut states = self.ble_states.write().await;
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
        let response = self.read_response(path, 300, Some(channel))?;

        // Send ACK
        let ack_bit = (response[0] >> 4) & 1;
        let ack = encode_ack(channel, ack_bit);
        self.write_raw(path, &ack)?;

        // Decrypt response
        let (resp_type, resp_data) = {
            if response.len() < 5 {
                log::error!(
                    "[Callback] Response too short: {} bytes, data: {:02x?}",
                    response.len(),
                    &response[..response.len().min(16)]
                );
                return Err(ThpError::DecryptionError("Response too short".to_string()).into());
            }

            let payload_len = u16::from_be_bytes([response[3], response[4]]) as usize;
            let crc_len = 4;
            let header_len = 5;

            log::debug!(
                "[Callback] Response: len={}, payload_len={}, header_len={}, crc_len={}",
                response.len(),
                payload_len,
                header_len,
                crc_len
            );

            if payload_len <= crc_len || response.len() < header_len + payload_len {
                log::error!(
                    "[Callback] Invalid payload: response_len={}, payload_len={}, needed={}, data: {:02x?}",
                    response.len(),
                    payload_len,
                    header_len + payload_len,
                    &response[..response.len().min(32)]
                );
                return Err(ThpError::DecryptionError(format!(
                    "Invalid payload: response_len={}, payload_len={}, needed={}",
                    response.len(),
                    payload_len,
                    header_len + payload_len
                ))
                .into());
            }

            let encrypted_payload = &response[header_len..header_len + payload_len - crc_len];

            let states = self.ble_states.read().await;
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
            let aad: &[u8] = &[];

            let decrypted =
                crate::protocol::thp::crypto::aes_gcm_decrypt(&key, &iv, aad, encrypted_payload)?;

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

        // Update recv_bit and recv_nonce after successful decryption
        {
            let mut states = self.ble_states.write().await;
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
            "[Callback] Received encrypted response type {} ({} bytes)",
            resp_type,
            resp_data.len()
        );
        Ok((resp_type, resp_data))
    }

    /// Perform pairing flow
    async fn perform_pairing(&self, path: &str, channel: &[u8; 2]) -> Result<()> {
        use crate::constants::{message_type, thp_message_type, thp_pairing_method};
        use crate::protocol::thp::pairing::{get_cpace_host_keys, get_shared_secret};
        use crate::protocol::thp::pairing_messages::*;

        log::info!("[Callback] Starting pairing flow...");

        // Mark as paired first to enable encrypted messaging
        {
            let mut states = self.ble_states.write().await;
            if let Some(state) = states.get_mut(path) {
                state.protocol.state_mut().set_is_paired(true);
            }
        }

        // Step 1: Send ThpPairingRequest
        let pairing_request = encode_pairing_request(&self.host_name, &self.app_name);
        log::info!("[Callback] Sending pairing request...");

        let (mut resp_type, _) = self
            .send_encrypted_message(
                path,
                channel,
                thp_message_type::THP_PAIRING_REQUEST,
                &pairing_request,
            )
            .await?;

        // Handle ButtonRequest
        if resp_type == message_type::BUTTON_REQUEST {
            log::info!("[Callback] >>> CONFIRM PAIRING ON YOUR TREZOR SCREEN! <<<");
            let (next_type, _) = self
                .send_encrypted_message(path, channel, message_type::BUTTON_ACK, &[])
                .await?;
            resp_type = next_type;
        }

        if resp_type != thp_message_type::THP_PAIRING_REQUEST_APPROVED {
            return Err(ThpError::PairingFailed(format!(
                "Expected ThpPairingRequestApproved, got {}",
                resp_type
            ))
            .into());
        }
        log::info!("[Callback] Pairing request approved!");

        // Step 2: Select code entry method
        let select_method = encode_select_method(thp_pairing_method::CODE_ENTRY);
        log::info!("[Callback] Selecting code entry pairing method...");

        let (resp_type, commitment_data) = self
            .send_encrypted_message(
                path,
                channel,
                thp_message_type::THP_SELECT_METHOD,
                &select_method,
            )
            .await?;

        // Generate a single challenge to reuse throughout the pairing flow
        // (must use the SAME challenge for both sends, matching bluetooth.rs)
        let challenge: [u8; 32] = rand::random();
        let challenge_payload = encode_code_entry_challenge(&challenge);

        // Handle response flow
        let commitment_data = if resp_type == thp_message_type::THP_PAIRING_PREPARATIONS_FINISHED {
            let (resp_type, commitment_data) = self
                .send_encrypted_message(
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

        // Decode and store commitment + challenge in handshake credentials for later validation
        let commitment = decode_code_entry_commitment(&commitment_data)?;
        {
            let mut states = self.ble_states.write().await;
            if let Some(state) = states.get_mut(path) {
                if let Some(creds) = state.protocol.state_mut().handshake_credentials_mut() {
                    creds.handshake_commitment = commitment.clone();
                    creds.code_entry_challenge = challenge.to_vec();
                }
            }
        }

        // Step 3: Get CPACE Trezor pubkey (reuse the same challenge)
        let (resp_type, cpace_data) = self
            .send_encrypted_message(
                path,
                channel,
                thp_message_type::THP_CODE_ENTRY_CHALLENGE,
                &challenge_payload,
            )
            .await?;

        if resp_type != thp_message_type::THP_CODE_ENTRY_CPACE_TREZOR {
            return Err(ThpError::PairingFailed("Expected CPACE Trezor".to_string()).into());
        }
        let trezor_cpace_pubkey = decode_cpace_trezor(&cpace_data)?;

        log::info!("[Callback] ============================================================");
        log::info!("[Callback] >>> LOOK AT YOUR TREZOR SCREEN! <<<");
        log::info!("[Callback] A 6-digit code should be displayed.");
        log::info!("[Callback] ============================================================");

        // Step 4: Get code from user via callback
        log::info!("[Callback] Waiting for user to enter pairing code...");
        let code = self.callback.get_pairing_code();
        if code.is_empty() {
            return Err(ThpError::PairingFailed("Pairing cancelled by user".to_string()).into());
        }
        log::info!("[Callback] User entered code (len={})", code.len());

        // Give device a moment to stabilize after user interaction
        std::thread::sleep(std::time::Duration::from_millis(200));

        // Step 5: Generate CPACE keys
        let handshake_hash = {
            let states = self.ble_states.read().await;
            states
                .get(path)
                .and_then(|s| s.protocol.state().handshake_credentials())
                .map(|c| c.handshake_hash.clone())
                .unwrap_or_default()
        };

        let cpace_keys = get_cpace_host_keys(code.as_bytes(), &handshake_hash);
        let shared_secret = get_shared_secret(&trezor_cpace_pubkey, &cpace_keys.private_key);
        let tag = &shared_secret[..];

        // Step 6: Send CPACE host tag
        let cpace_host_tag = encode_cpace_host_tag(&cpace_keys.public_key, tag);
        log::info!("[Callback] Sending CPACE host tag...");

        let (resp_type, secret_data) = self
            .send_encrypted_message(
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

        // Validate the code entry tag: verify commitment matches the secret
        // and the displayed code matches the expected value derived from the handshake
        let secret = decode_code_entry_secret(&secret_data)?;
        {
            let states = self.ble_states.read().await;
            let state = states.get(path).ok_or(TransportError::DeviceNotFound)?;
            if let Some(creds) = state.protocol.state().handshake_credentials() {
                crate::protocol::thp::pairing::validate_code_entry_tag(creds, &code, &secret)?;
                log::info!("[Callback] Code entry tag validated successfully!");
            } else {
                return Err(ThpError::StateMissing.into());
            }
        }
        log::info!("[Callback] Code verified!");

        // Step 7: Request credential
        let host_static_pubkey = {
            let states = self.ble_states.read().await;
            states
                .get(path)
                .and_then(|s| s.protocol.state().handshake_credentials())
                .map(|c| c.host_static_public_key.clone())
                .unwrap_or_default()
        };

        let credential_request = encode_credential_request(&host_static_pubkey, false, None);
        log::info!("[Callback] Sending credential request...");

        let (mut resp_type, mut credential_data) = self
            .send_encrypted_message(
                path,
                channel,
                thp_message_type::THP_CREDENTIAL_REQUEST,
                &credential_request,
            )
            .await?;

        if resp_type == message_type::BUTTON_REQUEST {
            let (next_type, next_data) = self
                .send_encrypted_message(path, channel, message_type::BUTTON_ACK, &[])
                .await?;
            resp_type = next_type;
            credential_data = next_data;
        }

        if resp_type != thp_message_type::THP_CREDENTIAL_RESPONSE {
            return Err(ThpError::PairingFailed(format!(
                "Expected credential response, got {}",
                resp_type
            ))
            .into());
        }
        log::info!("[Callback] Received credential!");

        // Parse and save credentials for reconnection
        if let Ok((trezor_static_pubkey, credential)) = decode_credential_response(&credential_data)
        {
            let host_static_key = {
                let states = self.ble_states.read().await;
                states
                    .get(path)
                    .and_then(|s| s.protocol.state().handshake_credentials())
                    .map(|c| c.static_key.clone())
                    .unwrap_or_default()
            };

            if host_static_key.len() == 32 && trezor_static_pubkey.len() == 32 {
                let stored_cred = StoredCredential {
                    host_static_key: host_static_key.try_into().unwrap_or([0u8; 32]),
                    trezor_static_public_key: trezor_static_pubkey.try_into().unwrap_or([0u8; 32]),
                    credential,
                };

                let cred_json = StoredCredentialJson::from(&stored_cred);
                if let Ok(json_str) = serde_json::to_string(&cred_json) {
                    if self.callback.save_thp_credential(path, &json_str) {
                        log::info!("[Callback] Saved THP credentials for future reconnection");
                    } else {
                        log::warn!("[Callback] Failed to save THP credentials");
                    }
                }
            } else {
                log::warn!(
                    "[Callback] Invalid key lengths, not saving credentials: host={}, trezor={}",
                    host_static_key.len(),
                    trezor_static_pubkey.len()
                );
            }
        } else {
            log::warn!("[Callback] Failed to parse credential response, not saving credentials");
        }

        // Step 8: Send ThpEndRequest
        log::info!("[Callback] Sending ThpEndRequest...");
        let (end_resp_type, _) = self
            .send_encrypted_message(path, channel, thp_message_type::THP_END_REQUEST, &[])
            .await?;

        if end_resp_type != thp_message_type::THP_END_RESPONSE {
            return Err(ThpError::PairingFailed("Expected ThpEndResponse".to_string()).into());
        }

        log::info!("[Callback] Pairing completed successfully!");
        Ok(())
    }

    /// Create THP session
    async fn create_thp_session(&self, path: &str, channel: &[u8; 2]) -> Result<()> {
        use crate::constants::thp_message_type::THP_CREATE_NEW_SESSION;

        log::info!("[Callback] Creating new THP session...");

        // Create session ID
        {
            let mut states = self.ble_states.write().await;
            if let Some(state) = states.get_mut(path) {
                let session_id = state.protocol.state_mut().create_new_session_id();
                log::debug!("[Callback] Created session ID {}", session_id);
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
        log::info!(
            "[Callback] ThpCreateNewSession (passphrase_len={}, on_device={})",
            self.session_passphrase.len(),
            self.session_on_device,
        );

        let (mut resp_type, mut resp_data) = self
            .send_encrypted_message(path, channel, THP_CREATE_NEW_SESSION, &session_payload)
            .await?;

        // The device may emit one or more ButtonRequests before completing —
        // e.g. confirming the passphrase, or showing its on-device keyboard.
        // Acknowledge each until the device returns the final Success/Failure.
        while resp_type == crate::constants::message_type::BUTTON_REQUEST {
            log::debug!("[Callback] ThpCreateNewSession: ButtonRequest, acking");
            let (next_type, next_data) = self
                .send_encrypted_message(
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
            log::info!("[Callback] THP session created successfully!");
            Ok(())
        } else if resp_type == crate::constants::message_type::FAILURE {
            // Decode the device's reason so the failure is actionable.
            let detail = crate::transport::decode_failure_detail(&resp_data);
            log::warn!("[Callback] ThpCreateNewSession rejected: {}", detail);
            Err(ThpError::SessionError(format!("ThpCreateNewSession rejected ({})", detail)).into())
        } else {
            Err(ThpError::SessionError(format!("Unexpected response: {}", resp_type)).into())
        }
    }

    /// Send THP encrypted call (for post-handshake communication)
    async fn thp_call(&self, path: &str, message_type: u16, data: &[u8]) -> Result<(u16, Vec<u8>)> {
        let channel = {
            let states = self.ble_states.read().await;
            let state = states.get(path).ok_or(TransportError::DeviceNotFound)?;
            *state.protocol.state().channel()
        };

        self.send_encrypted_message(path, &channel, message_type, data)
            .await
    }
}

#[async_trait]
impl Transport for CallbackTransport {
    async fn init(&mut self) -> Result<()> {
        // No initialization needed for callback transport
        Ok(())
    }

    async fn enumerate(&self) -> Result<Vec<DeviceDescriptor>> {
        let devices = self.callback.enumerate_devices();

        // Populate transport type cache from enumerated device info
        {
            let mut cache = self.transport_type_cache.write().await;
            for d in &devices {
                cache.insert(d.path.clone(), d.transport_type == "bluetooth");
            }
        }

        Ok(devices
            .into_iter()
            .map(|d| DeviceDescriptor {
                path: d.path,
                vendor_id: d.vendor_id.unwrap_or(0x1209), // Trezor vendor ID
                product_id: d.product_id.unwrap_or(0x53c1), // Trezor product ID
                serial_number: None,
                session: None,
            })
            .collect())
    }

    async fn acquire(&self, path: &str, previous: Option<&str>) -> Result<String> {
        // Open the device
        let result = self.callback.open_device(path);
        if !result.success {
            log::error!(
                "[Callback] open_device failed for {}: {}",
                path,
                result.error
            );
            return Err(TransportError::UnableToOpen(if result.error.is_empty() {
                format!("Failed to open device: {}", path)
            } else {
                result.error
            })
            .into());
        }

        let is_ble = self.is_ble_device(path).await;

        // For BLE devices, always perform THP handshake
        if is_ble {
            let needs_handshake = {
                let states = self.ble_states.read().await;
                !states
                    .get(path)
                    .map(|s| s.handshake_complete)
                    .unwrap_or(false)
            };

            if needs_handshake {
                self.perform_thp_handshake(path).await?;
            }
        } else {
            // For USB devices, detect THP via Cancel → Failure_InvalidProtocol
            let already_thp = self.has_thp(path).await;
            if !already_thp {
                match self.detect_thp_protocol(path) {
                    Ok(true) => {
                        log::info!("[Callback] USB device needs THP — performing handshake...");
                        self.perform_thp_handshake(path).await?;
                    }
                    Ok(false) => {
                        log::debug!("[Callback] USB device uses V1 protocol");
                    }
                    Err(e) => {
                        log::warn!(
                            "[Callback] THP detection failed ({}), falling back to V1",
                            e
                        );
                    }
                }
            }
        }

        // Acquire session
        self.sessions
            .acquire(path, previous)
            .map_err(|e| TransportError::DataTransfer(e.to_string()).into())
    }

    async fn release(&self, session: &str) -> Result<()> {
        if let Some(path) = self.sessions.get_path(session) {
            let _ = self.callback.close_device(&path);

            // Clean up BLE state
            let mut states = self.ble_states.write().await;
            states.remove(&path);

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

        // For THP devices (BLE or USB that negotiated THP), use encrypted messaging
        if self.needs_thp(&path).await {
            let is_paired = {
                let states = self.ble_states.read().await;
                states
                    .get(&path)
                    .map(|s| s.protocol.state().is_paired())
                    .unwrap_or(false)
            };

            if is_paired {
                log::debug!(
                    "[Callback] Using THP encrypted call for message type {}",
                    message_type
                );
                return self.thp_call(&path, message_type, data).await;
            } else {
                return Err(TransportError::DataTransfer(
                    "THP device not paired - handshake required".to_string(),
                )
                .into());
            }
        }

        // Try high-level call_message first (for native THP implementations)
        if let Some(result) = self.callback.call_message(&path, message_type, data) {
            log::debug!(
                "[Callback] call_message: message_type={}, data_len={}, success={}",
                message_type,
                data.len(),
                result.success
            );

            if result.success {
                return Ok((result.message_type, result.data));
            } else {
                return Err(TransportError::DataTransfer(result.error).into());
            }
        }

        // Fall back to Protocol V1 chunk-based communication (for USB only)
        log::debug!(
            "[Callback] Using Protocol V1 for USB device, message_type={}",
            message_type
        );

        // Get chunk size for this device
        let chunk_size = self.callback.get_chunk_size(&path) as usize;
        let protocol = ProtocolV1::with_chunk_size(chunk_size);

        // Encode message
        let encoded = protocol.encode(message_type, data)?;

        log::debug!(
            "[Callback] call: message_type={}, data_len={}, encoded_len={}, chunk_size={}",
            message_type,
            data.len(),
            encoded.len(),
            chunk_size
        );

        // Create chunks
        let (_, chunk_header) = protocol.get_headers(&encoded);
        let chunks = chunk::create_chunks(&encoded, &chunk_header, chunk_size);

        log::trace!("[Callback] Sending {} chunk(s)", chunks.len());

        // Send all chunks
        for (i, c) in chunks.iter().enumerate() {
            log::trace!(
                "[Callback] Writing chunk {}: {:02x?}",
                i,
                &c[..c.len().min(16)]
            );
            let result = self.callback.write_chunk(&path, c);
            if !result.success {
                return Err(TransportError::DataTransfer(result.error).into());
            }
        }

        log::trace!("[Callback] All chunks sent, waiting for response...");

        // Read response - look for Protocol v1 header
        let mut response_chunks = Vec::new();
        let mut first_chunk: Option<Vec<u8>> = None;

        // Read chunks looking for Protocol v1 header
        for attempt in 0..20 {
            let read_result = self.callback.read_chunk(&path);
            if !read_result.success {
                log::trace!("[Callback] Read {} failed: {}", attempt, read_result.error);
                continue;
            }

            let chunk = read_result.data;
            if chunk.is_empty() {
                log::trace!("[Callback] Read {} returned empty, retrying", attempt);
                continue;
            }

            log::trace!(
                "[Callback] Read {} ({} bytes): {:02x?}",
                attempt,
                chunk.len(),
                &chunk[..chunk.len().min(16)]
            );

            // Check for Protocol v1 header: 0x3F (report) + 0x23 0x23 (magic)
            if chunk.len() >= 3 && chunk[0] == 0x3F && chunk[1] == 0x23 && chunk[2] == 0x23 {
                log::trace!("[Callback] Found Protocol v1 header");
                first_chunk = Some(chunk);
                break;
            } else {
                log::debug!(
                    "[Callback] Skipping non-Protocol v1 chunk (first bytes: {:02x} {:02x})",
                    chunk.get(0).unwrap_or(&0),
                    chunk.get(1).unwrap_or(&0)
                );
            }
        }

        let first_chunk = first_chunk.ok_or_else(|| {
            TransportError::DataTransfer("No Protocol v1 header found".to_string())
        })?;

        let decoded = protocol.decode(&first_chunk)?;
        log::debug!(
            "[Callback] Protocol v1 message: type={}, length={}",
            decoded.message_type,
            decoded.length
        );

        response_chunks.push(first_chunk);

        // Standard Protocol v1 handling
        let header_size = PROTOCOL_V1_HEADER_SIZE;
        let first_payload_size = chunk_size - header_size;
        let remaining = if decoded.length as usize > first_payload_size {
            decoded.length as usize - first_payload_size
        } else {
            0
        };

        if remaining > 0 {
            let continuation_payload = chunk_size - 1; // 1 byte for magic
            let num_chunks = (remaining + continuation_payload - 1) / continuation_payload;
            log::trace!(
                "[Callback] Need {} more chunks for {} remaining bytes",
                num_chunks,
                remaining
            );

            for _i in 0..num_chunks {
                let read_result = self.callback.read_chunk(&path);
                if !read_result.success {
                    return Err(TransportError::DataTransfer(read_result.error).into());
                }
                response_chunks.push(read_result.data);
            }
        }

        // Reassemble response
        let payload = chunk::reassemble_chunks(
            &response_chunks,
            header_size,
            1, // Continuation header is 1 byte
            decoded.length as usize,
        )?;

        log::debug!("[Callback] Reassembled payload: {} bytes", payload.len());
        Ok((decoded.message_type, payload))
    }

    fn stop(&mut self) {
        // Clear call serialization locks
        if let Ok(mut locks) = self.call_locks.lock() {
            locks.clear();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    struct MockCallback {
        devices: Vec<CallbackDeviceInfo>,
        open_result: Mutex<CallbackResult>,
        read_data: Mutex<Vec<Vec<u8>>>,
        write_calls: Mutex<Vec<Vec<u8>>>,
    }

    impl MockCallback {
        fn new() -> Self {
            Self {
                devices: vec![CallbackDeviceInfo {
                    path: "test-device".to_string(),
                    transport_type: "usb".to_string(),
                    name: Some("Test Trezor".to_string()),
                    vendor_id: Some(0x1209),
                    product_id: Some(0x53c1),
                }],
                open_result: Mutex::new(CallbackResult {
                    success: true,
                    error: String::new(),
                }),
                read_data: Mutex::new(Vec::new()),
                write_calls: Mutex::new(Vec::new()),
            }
        }
    }

    impl TransportCallback for MockCallback {
        fn enumerate_devices(&self) -> Vec<CallbackDeviceInfo> {
            self.devices.clone()
        }

        fn open_device(&self, _path: &str) -> CallbackResult {
            self.open_result.lock().unwrap().clone()
        }

        fn close_device(&self, _path: &str) -> CallbackResult {
            CallbackResult {
                success: true,
                error: String::new(),
            }
        }

        fn read_chunk(&self, _path: &str) -> CallbackReadResult {
            let mut read_data = self.read_data.lock().unwrap();
            if read_data.is_empty() {
                CallbackReadResult {
                    success: false,
                    data: Vec::new(),
                    error: "No data".to_string(),
                }
            } else {
                CallbackReadResult {
                    success: true,
                    data: read_data.remove(0),
                    error: String::new(),
                }
            }
        }

        fn write_chunk(&self, _path: &str, data: &[u8]) -> CallbackResult {
            self.write_calls.lock().unwrap().push(data.to_vec());
            CallbackResult {
                success: true,
                error: String::new(),
            }
        }

        fn get_chunk_size(&self, _path: &str) -> u32 {
            64
        }
    }

    #[tokio::test]
    async fn test_enumerate() {
        let callback = Arc::new(MockCallback::new());
        let transport = CallbackTransport::new(callback);

        let devices = transport.enumerate().await.unwrap();
        assert_eq!(devices.len(), 1);
        assert_eq!(devices[0].path, "test-device");
    }

    #[tokio::test]
    async fn test_acquire_release() {
        let callback = Arc::new(MockCallback::new());
        let mut transport = CallbackTransport::new(callback);
        transport.init().await.unwrap();

        let session = transport.acquire("test-device", None).await.unwrap();
        assert!(!session.is_empty());

        transport.release(&session).await.unwrap();
    }
}
