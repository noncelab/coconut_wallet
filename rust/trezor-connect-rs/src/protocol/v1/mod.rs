//! Protocol v1 (Legacy) implementation.
//!
//! This is the original Trezor protocol used for USB communication.
//! Messages are unencrypted and use a simple framing format.
//!
//! ## Message Format
//!
//! ```text
//! First chunk:
//! [0x3F][0x23][0x23][msg_type:u16 BE][length:u32 BE][payload...]
//!
//! Continuation chunks:
//! [0x3F][payload...]
//!
//! All chunks are padded to exactly chunk_size bytes (64 for USB, 244 for BLE)
//! ```

mod decode;
mod encode;

pub use decode::*;
pub use encode::*;

use crate::constants::{
    BLE_CHUNK_SIZE, PROTOCOL_V1_HEADER_BYTE, PROTOCOL_V1_HEADER_SIZE, PROTOCOL_V1_MAGIC,
    USB_CHUNK_SIZE,
};
use crate::error::Result;
use crate::protocol::{DecodedMessage, Protocol};

/// Protocol v1 implementation
#[derive(Debug, Clone)]
pub struct ProtocolV1 {
    /// Chunk size (64 for USB, 244 for BLE)
    chunk_size: usize,
}

impl ProtocolV1 {
    /// Create a new Protocol v1 instance for USB
    pub fn usb() -> Self {
        Self {
            chunk_size: USB_CHUNK_SIZE,
        }
    }

    /// Create a new Protocol v1 instance for BLE
    pub fn bluetooth() -> Self {
        Self {
            chunk_size: BLE_CHUNK_SIZE,
        }
    }

    /// Create a new Protocol v1 instance with custom chunk size
    pub fn with_chunk_size(chunk_size: usize) -> Self {
        Self { chunk_size }
    }
}

impl Protocol for ProtocolV1 {
    fn chunk_size(&self) -> usize {
        self.chunk_size
    }

    fn encode(&self, message_type: u16, data: &[u8]) -> Result<Vec<u8>> {
        Ok(encode_message(message_type, data))
    }

    fn decode(&self, buffer: &[u8]) -> Result<DecodedMessage> {
        decode_message(buffer)
    }

    fn get_headers(&self, data: &[u8]) -> (Vec<u8>, Vec<u8>) {
        // Message header is the first PROTOCOL_V1_HEADER_SIZE bytes of the encoded data
        let message_header = if data.len() >= PROTOCOL_V1_HEADER_SIZE {
            data[..PROTOCOL_V1_HEADER_SIZE].to_vec()
        } else {
            data.to_vec()
        };

        // Continuation header is just the magic byte
        let chunk_header = vec![PROTOCOL_V1_MAGIC];

        (message_header, chunk_header)
    }

    fn is_continuation(&self, buffer: &[u8]) -> bool {
        if buffer.is_empty() {
            return false;
        }

        // A continuation chunk starts with magic byte but NOT followed by two header bytes
        buffer[0] == PROTOCOL_V1_MAGIC
            && (buffer.len() < 3
                || buffer[1] != PROTOCOL_V1_HEADER_BYTE
                || buffer[2] != PROTOCOL_V1_HEADER_BYTE)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encode_decode_roundtrip() {
        let protocol = ProtocolV1::usb();
        let message_type = 0x0001; // Initialize
        let data = vec![0x01, 0x02, 0x03, 0x04];

        let encoded = protocol.encode(message_type, &data).unwrap();
        let decoded = protocol.decode(&encoded).unwrap();

        assert_eq!(decoded.message_type, message_type);
        assert_eq!(decoded.length as usize, data.len());
        assert_eq!(&decoded.payload[..data.len()], &data[..]);
    }

    #[test]
    fn test_is_continuation() {
        let protocol = ProtocolV1::usb();

        // First chunk (has ## header)
        let first_chunk = [0x3F, 0x23, 0x23, 0x00, 0x01, 0x00, 0x00, 0x00, 0x04];
        assert!(!protocol.is_continuation(&first_chunk));

        // Continuation chunk (just magic byte + data)
        let continuation = [0x3F, 0x01, 0x02, 0x03];
        assert!(protocol.is_continuation(&continuation));
    }
}
