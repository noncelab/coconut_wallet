//! THP (Trezor Host Protocol) v2 implementation.
//!
//! THP is an encrypted protocol used for communication with newer Trezor devices
//! (Safe 7 and later) over Bluetooth. It uses:
//!
//! - **Noise XX pattern** for key exchange
//! - **X25519** for Diffie-Hellman key agreement
//! - **AES-256-GCM** for authenticated encryption
//! - **HKDF** for key derivation
//!
//! ## Protocol Flow
//!
//! 1. Channel Allocation - Request a channel ID from the device
//! 2. Handshake Init - Exchange ephemeral keys
//! 3. Handshake Completion - Exchange static keys
//! 4. Pairing (if required) - Verify device identity
//! 5. Encrypted Communication - All subsequent messages encrypted

pub mod crypto;
pub mod decode;
pub mod encode;
pub mod handshake;
pub mod pairing;
pub mod pairing_messages;
pub mod state;

pub use crypto::*;
pub use decode::*;
pub use encode::*;
pub use handshake::*;
pub use pairing::*;
pub use state::ThpState;

use crate::constants::{BLE_CHUNK_SIZE, THP_HEADER_SIZE, thp_control};
use crate::error::Result;
use crate::protocol::{DecodedMessage, Protocol};

/// THP Protocol v2 implementation
#[derive(Debug)]
pub struct ProtocolThp {
    /// THP session state
    state: ThpState,
    /// Chunk size (typically 244 for BLE)
    chunk_size: usize,
}

impl ProtocolThp {
    /// Create a new THP protocol instance
    pub fn new() -> Self {
        Self {
            state: ThpState::new(),
            chunk_size: BLE_CHUNK_SIZE,
        }
    }

    /// Get a reference to the THP state
    pub fn state(&self) -> &ThpState {
        &self.state
    }

    /// Get a mutable reference to the THP state
    pub fn state_mut(&mut self) -> &mut ThpState {
        &mut self.state
    }

    /// Check if the protocol is in paired state
    pub fn is_paired(&self) -> bool {
        self.state.is_paired()
    }

    /// Reset the protocol state
    pub fn reset(&mut self) {
        self.state.reset();
    }
}

impl Default for ProtocolThp {
    fn default() -> Self {
        Self::new()
    }
}

impl Protocol for ProtocolThp {
    fn chunk_size(&self) -> usize {
        self.chunk_size
    }

    fn encode(&self, message_type: u16, data: &[u8]) -> Result<Vec<u8>> {
        encode_thp_message(&self.state, message_type, data)
    }

    fn decode(&self, buffer: &[u8]) -> Result<DecodedMessage> {
        decode_thp_message(buffer)
    }

    fn get_headers(&self, data: &[u8]) -> (Vec<u8>, Vec<u8>) {
        // THP header is first THP_HEADER_SIZE bytes
        let message_header = if data.len() >= THP_HEADER_SIZE {
            data[..THP_HEADER_SIZE].to_vec()
        } else {
            data.to_vec()
        };

        // Continuation header: continuation control byte + channel
        let channel = self.state.channel();
        let chunk_header = vec![thp_control::CONTINUATION_PACKET, channel[0], channel[1]];

        (message_header, chunk_header)
    }

    fn is_continuation(&self, buffer: &[u8]) -> bool {
        if buffer.is_empty() {
            return false;
        }
        buffer[0] == thp_control::CONTINUATION_PACKET
    }
}

/// Decode control byte to determine message type
pub fn decode_control_byte(ctrl_byte: u8) -> Option<u8> {
    // DATA message types
    let data_type = ctrl_byte & 0xe7;
    match data_type {
        thp_control::HANDSHAKE_INIT_REQ
        | thp_control::HANDSHAKE_INIT_RES
        | thp_control::HANDSHAKE_COMP_REQ
        | thp_control::HANDSHAKE_COMP_RES
        | thp_control::ENCRYPTED => return Some(data_type),
        _ => {}
    }

    // ACK message
    let ack_type = ctrl_byte & 0xf7;
    if ack_type == thp_control::ACK_MESSAGE {
        return Some(ack_type);
    }

    // Unmasked message types
    match ctrl_byte {
        thp_control::CHANNEL_ALLOCATION_REQ
        | thp_control::CHANNEL_ALLOCATION_RES
        | thp_control::PING
        | thp_control::PONG
        | thp_control::ERROR => Some(ctrl_byte),
        _ => None,
    }
}

/// Check if a control byte indicates an ACK is expected for the message
pub fn is_ack_expected(ctrl_byte: u8) -> bool {
    // ACK is expected for data messages (handshake and encrypted)
    let data_type = ctrl_byte & 0xe7;
    matches!(
        data_type,
        thp_control::HANDSHAKE_INIT_REQ
            | thp_control::HANDSHAKE_INIT_RES
            | thp_control::HANDSHAKE_COMP_REQ
            | thp_control::HANDSHAKE_COMP_RES
            | thp_control::ENCRYPTED
    )
}
