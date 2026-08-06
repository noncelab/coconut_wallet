//! Protocol layer for Trezor communication.
//!
//! This module handles encoding and decoding of messages for communication
//! with Trezor devices. Two protocols are supported:
//!
//! - **Protocol v1** - Legacy unencrypted protocol (USB)
//! - **Protocol v2 (THP)** - Encrypted Trezor Host Protocol (Bluetooth/Safe 7)

pub mod chunk;
pub mod thp;
pub mod v1;

use crate::error::Result;

/// Decoded message from the device
#[derive(Debug, Clone)]
pub struct DecodedMessage {
    /// Message type (protobuf message ID)
    pub message_type: u16,
    /// Total length of the payload
    pub length: u32,
    /// Message payload (protobuf-encoded data)
    pub payload: Vec<u8>,
}

/// Protocol trait for encoding/decoding messages
pub trait Protocol: Send + Sync {
    /// Get the chunk size for this protocol
    fn chunk_size(&self) -> usize;

    /// Encode a message with the given type and data
    fn encode(&self, message_type: u16, data: &[u8]) -> Result<Vec<u8>>;

    /// Decode a received buffer into a message header
    fn decode(&self, buffer: &[u8]) -> Result<DecodedMessage>;

    /// Get the message header and continuation chunk header
    fn get_headers(&self, data: &[u8]) -> (Vec<u8>, Vec<u8>);

    /// Check if a buffer is a continuation chunk
    fn is_continuation(&self, buffer: &[u8]) -> bool;
}

/// Protocol version enum
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProtocolVersion {
    /// Protocol v1 (legacy, unencrypted)
    V1,
    /// Protocol v2 (THP, encrypted)
    V2,
}

impl ProtocolVersion {
    /// Get the appropriate chunk size for this protocol version
    pub fn chunk_size(&self, is_bluetooth: bool) -> usize {
        match self {
            ProtocolVersion::V1 => {
                if is_bluetooth {
                    crate::constants::BLE_CHUNK_SIZE
                } else {
                    crate::constants::USB_CHUNK_SIZE
                }
            }
            ProtocolVersion::V2 => crate::constants::BLE_CHUNK_SIZE,
        }
    }
}
