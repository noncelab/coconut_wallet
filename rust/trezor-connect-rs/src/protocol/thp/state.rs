//! THP State management.
//!
//! Manages the cryptographic state for THP communication, including:
//! - Channel ID
//! - Synchronization bits
//! - Nonces for encryption
//! - Encryption keys
//! - Pairing credentials

use serde::{Deserialize, Serialize};
use zeroize::{Zeroize, ZeroizeOnDrop};

/// THP synchronization bit (0 or 1)
pub type SyncBit = u8;

/// THP communication phase
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ThpPhase {
    /// Initial handshake phase
    #[default]
    Handshake,
    /// Pairing in progress
    Pairing,
    /// Successfully paired and ready for communication
    Paired,
}

/// Pairing method supported by THP
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum ThpPairingMethod {
    /// No pairing method selected
    None = 0,
    /// Code entry (6-digit code displayed on device)
    CodeEntry = 2,
    /// QR code scanning
    QrCode = 3,
    /// NFC tap
    Nfc = 4,
}

/// Stored pairing credentials
#[derive(Debug, Clone, Serialize, Deserialize, Zeroize, ZeroizeOnDrop)]
pub struct ThpCredentials {
    /// Host static private key (hex)
    pub host_static_key: String,
    /// Trezor static public key (hex)
    pub trezor_static_public_key: String,
    /// Pairing credential token
    pub credential: String,
    /// Whether to automatically reconnect
    #[zeroize(skip)]
    pub autoconnect: bool,
}

/// Handshake credentials (derived during handshake)
///
/// Contains sensitive cryptographic material (private keys, encryption keys).
/// Automatically zeroized when dropped to prevent key material from lingering in memory.
#[derive(Debug, Clone, Default, Zeroize, ZeroizeOnDrop)]
pub struct ThpHandshakeCredentials {
    /// Supported pairing methods
    #[zeroize(skip)]
    pub pairing_methods: Vec<ThpPairingMethod>,
    /// Running hash of handshake transcript
    pub handshake_hash: Vec<u8>,
    /// Handshake commitment (for code entry)
    pub handshake_commitment: Vec<u8>,
    /// Code entry challenge
    pub code_entry_challenge: Vec<u8>,
    /// Encrypted Trezor static public key
    pub trezor_encrypted_static_pubkey: Vec<u8>,
    /// Encrypted host static public key
    pub host_encrypted_static_pubkey: Vec<u8>,
    /// Host static key (private)
    pub static_key: Vec<u8>,
    /// Host static public key
    pub host_static_public_key: Vec<u8>,
    /// Host encryption key (derived from handshake)
    pub host_key: Vec<u8>,
    /// Trezor encryption key (derived from handshake)
    pub trezor_key: Vec<u8>,
    /// Trezor CPACE public key (for code entry)
    pub trezor_cpace_public_key: Vec<u8>,
}

/// Serializable THP channel state
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThpChannelState {
    /// Channel ID (2 bytes as hex)
    pub channel: String,
    /// Host synchronization bit
    pub send_bit: SyncBit,
    /// Device synchronization bit
    pub recv_bit: SyncBit,
    /// Host acknowledgment bit
    pub send_ack_bit: SyncBit,
    /// Device acknowledgment bit
    pub recv_ack_bit: SyncBit,
    /// Host nonce for encryption
    pub send_nonce: u32,
    /// Device nonce for decryption
    pub recv_nonce: u32,
    /// Expected response types
    pub expected_responses: Vec<u8>,
}

/// THP Protocol state
#[derive(Debug, Default)]
pub struct ThpState {
    /// Current phase
    phase: ThpPhase,
    /// Whether device is paired
    is_paired: bool,
    /// Channel ID (2 bytes)
    channel: [u8; 2],
    /// Host synchronization bit
    send_bit: SyncBit,
    /// Device synchronization bit
    recv_bit: SyncBit,
    /// Host acknowledgment bit
    send_ack_bit: SyncBit,
    /// Device acknowledgment bit
    recv_ack_bit: SyncBit,
    /// Host nonce (incremented for each encrypted message)
    send_nonce: u32,
    /// Device nonce
    recv_nonce: u32,
    /// Whether a nonce has overflowed (requires re-key)
    nonce_exhausted: bool,
    /// Expected response types
    expected_responses: Vec<u8>,
    /// Handshake credentials
    handshake_credentials: Option<ThpHandshakeCredentials>,
    /// Stored pairing credentials
    pairing_credentials: Vec<ThpCredentials>,
    /// Selected pairing method
    selected_method: Option<ThpPairingMethod>,
    /// NFC secret (for NFC pairing)
    nfc_secret: Option<Vec<u8>>,
    /// Session ID
    session_id: u8,
}

impl ThpState {
    /// Create a new THP state
    pub fn new() -> Self {
        Self {
            recv_nonce: 1, // Device nonce starts at 1
            ..Default::default()
        }
    }

    /// Get current phase
    pub fn phase(&self) -> ThpPhase {
        self.phase
    }

    /// Set current phase
    pub fn set_phase(&mut self, phase: ThpPhase) {
        self.phase = phase;
    }

    /// Check if paired
    pub fn is_paired(&self) -> bool {
        self.is_paired
    }

    /// Set paired status
    pub fn set_is_paired(&mut self, paired: bool) {
        self.is_paired = paired;
    }

    /// Get channel ID
    pub fn channel(&self) -> &[u8; 2] {
        &self.channel
    }

    /// Set channel ID
    pub fn set_channel(&mut self, channel: [u8; 2]) {
        self.channel = channel;
    }

    /// Get send synchronization bit
    pub fn send_bit(&self) -> SyncBit {
        self.send_bit
    }

    /// Get receive synchronization bit
    pub fn recv_bit(&self) -> SyncBit {
        self.recv_bit
    }

    /// Get send acknowledgment bit
    pub fn send_ack_bit(&self) -> SyncBit {
        self.send_ack_bit
    }

    /// Get receive acknowledgment bit
    pub fn recv_ack_bit(&self) -> SyncBit {
        self.recv_ack_bit
    }

    /// Get send nonce
    pub fn send_nonce(&self) -> u32 {
        self.send_nonce
    }

    /// Get receive nonce
    pub fn recv_nonce(&self) -> u32 {
        self.recv_nonce
    }

    /// Check if a nonce has been exhausted (requires re-key)
    pub fn nonce_exhausted(&self) -> bool {
        self.nonce_exhausted
    }

    /// Update acknowledgment bit
    pub fn update_ack_bit(&mut self, is_send: bool) {
        if is_send {
            self.send_ack_bit = if self.send_ack_bit > 0 { 0 } else { 1 };
        } else {
            self.recv_ack_bit = if self.recv_ack_bit > 0 { 0 } else { 1 };
        }
    }

    /// Update synchronization bit
    pub fn update_sync_bit(&mut self, is_send: bool) {
        if is_send {
            self.send_bit = if self.send_bit > 0 { 0 } else { 1 };
        } else {
            self.recv_bit = if self.recv_bit > 0 { 0 } else { 1 };
        }
    }

    /// Update nonce.
    ///
    /// Returns `Err` if the nonce would overflow, indicating a re-key
    /// (new handshake) is required to prevent AES-GCM nonce reuse.
    pub fn update_nonce(&mut self, is_send: bool) -> std::result::Result<(), &'static str> {
        if is_send {
            if self.send_nonce >= u32::MAX - 1 {
                return Err("send nonce overflow: re-key required");
            }
            self.send_nonce += 1;
        } else {
            if self.recv_nonce >= u32::MAX - 1 {
                return Err("recv nonce overflow: re-key required");
            }
            self.recv_nonce += 1;
        }
        Ok(())
    }

    /// Get expected responses
    pub fn expected_responses(&self) -> &[u8] {
        &self.expected_responses
    }

    /// Set expected responses
    pub fn set_expected_responses(&mut self, responses: Vec<u8>) {
        self.expected_responses = responses;
    }

    /// Get handshake credentials
    pub fn handshake_credentials(&self) -> Option<&ThpHandshakeCredentials> {
        self.handshake_credentials.as_ref()
    }

    /// Get mutable handshake credentials
    pub fn handshake_credentials_mut(&mut self) -> &mut Option<ThpHandshakeCredentials> {
        &mut self.handshake_credentials
    }

    /// Set handshake credentials
    pub fn set_handshake_credentials(&mut self, creds: ThpHandshakeCredentials) {
        self.handshake_credentials = Some(creds);
    }

    /// Get pairing credentials
    pub fn pairing_credentials(&self) -> &[ThpCredentials] {
        &self.pairing_credentials
    }

    /// Add pairing credentials
    pub fn add_pairing_credentials(&mut self, creds: ThpCredentials) {
        self.pairing_credentials.push(creds);
    }

    /// Replace all pairing credentials with a freshly issued one. Used after
    /// a successful pairing so a stale credential (e.g. one the device
    /// rejected, forcing the re-pair) is not kept in front of the new one.
    pub fn set_pairing_credentials(&mut self, creds: ThpCredentials) {
        self.pairing_credentials.clear();
        self.pairing_credentials.push(creds);
    }

    /// Set pairing method
    pub fn set_pairing_method(&mut self, method: ThpPairingMethod) {
        self.selected_method = Some(method);
    }

    /// Get pairing method
    pub fn pairing_method(&self) -> Option<ThpPairingMethod> {
        self.selected_method
    }

    /// Create a new session ID
    pub fn create_new_session_id(&mut self) -> u8 {
        self.session_id = self.session_id.wrapping_add(1);
        if self.session_id == 0 {
            self.session_id = 1;
        }
        self.session_id
    }

    /// Get session ID
    pub fn session_id(&self) -> u8 {
        self.session_id
    }

    /// Reset state to initial values
    pub fn reset(&mut self) {
        self.phase = ThpPhase::Handshake;
        self.is_paired = false;
        self.channel = [0, 0];
        self.send_bit = 0;
        self.recv_bit = 0;
        self.send_ack_bit = 0;
        self.recv_ack_bit = 0;
        self.send_nonce = 0;
        self.recv_nonce = 1;
        self.nonce_exhausted = false;
        self.expected_responses.clear();
        // Handshake credentials are ZeroizeOnDrop — dropping the old
        // value here triggers zeroization of key material in memory.
        self.handshake_credentials = None;
        self.selected_method = None;
        if let Some(ref mut secret) = self.nfc_secret {
            secret.zeroize();
        }
        self.nfc_secret = None;
        self.session_id = 0;
        // Keep pairing credentials for reconnection
    }

    /// Serialize state for storage
    pub fn serialize(&self) -> ThpChannelState {
        ThpChannelState {
            channel: hex::encode(self.channel),
            send_bit: self.send_bit,
            recv_bit: self.recv_bit,
            send_ack_bit: self.send_ack_bit,
            recv_ack_bit: self.recv_ack_bit,
            send_nonce: self.send_nonce,
            recv_nonce: self.recv_nonce,
            expected_responses: self.expected_responses.clone(),
        }
    }

    /// Deserialize state from storage
    pub fn deserialize(&mut self, state: ThpChannelState) -> Result<(), &'static str> {
        let channel_bytes = hex::decode(&state.channel).map_err(|_| "Invalid channel hex")?;
        if channel_bytes.len() != 2 {
            return Err("Invalid channel length");
        }

        self.channel = [channel_bytes[0], channel_bytes[1]];
        self.send_bit = state.send_bit;
        self.recv_bit = state.recv_bit;
        self.send_ack_bit = state.send_ack_bit;
        self.recv_ack_bit = state.recv_ack_bit;
        self.send_nonce = state.send_nonce;
        self.recv_nonce = state.recv_nonce;
        self.expected_responses = state.expected_responses;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_state() {
        let state = ThpState::new();
        assert_eq!(state.phase(), ThpPhase::Handshake);
        assert!(!state.is_paired());
        assert_eq!(state.send_nonce(), 0);
        assert_eq!(state.recv_nonce(), 1);
    }

    #[test]
    fn test_sync_bits() {
        let mut state = ThpState::new();

        state.update_sync_bit(true);
        assert_eq!(state.send_bit(), 1);

        state.update_sync_bit(true);
        assert_eq!(state.send_bit(), 0);
    }

    #[test]
    fn test_serialization() {
        let mut state = ThpState::new();
        state.set_channel([0x12, 0x34]);
        state.send_nonce = 10;

        let serialized = state.serialize();
        assert_eq!(serialized.channel, "1234");
        assert_eq!(serialized.send_nonce, 10);

        let mut new_state = ThpState::new();
        new_state.deserialize(serialized).unwrap();
        assert_eq!(new_state.channel(), &[0x12, 0x34]);
        assert_eq!(new_state.send_nonce(), 10);
    }

    #[test]
    fn test_nonce_overflow_send() {
        let mut state = ThpState::new();
        state.send_nonce = u32::MAX - 2;

        // Should succeed (nonce becomes MAX - 1)
        assert!(state.update_nonce(true).is_ok());
        assert_eq!(state.send_nonce(), u32::MAX - 1);

        // Should fail at MAX - 1 (would overflow)
        assert!(state.update_nonce(true).is_err());
        // Nonce should not have changed
        assert_eq!(state.send_nonce(), u32::MAX - 1);
    }

    #[test]
    fn test_nonce_overflow_recv() {
        let mut state = ThpState::new();
        state.recv_nonce = u32::MAX - 2;

        // Should succeed
        assert!(state.update_nonce(false).is_ok());
        assert_eq!(state.recv_nonce(), u32::MAX - 1);

        // Should fail
        assert!(state.update_nonce(false).is_err());
        assert_eq!(state.recv_nonce(), u32::MAX - 1);
    }

    #[test]
    fn test_nonce_normal_increment() {
        let mut state = ThpState::new();
        assert_eq!(state.send_nonce(), 0);

        assert!(state.update_nonce(true).is_ok());
        assert_eq!(state.send_nonce(), 1);

        assert!(state.update_nonce(true).is_ok());
        assert_eq!(state.send_nonce(), 2);
    }
}
