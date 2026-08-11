//! Protocol v1 message decoding.
//!
//! Decodes Trezor v1 wire format messages into their components.

use crate::constants::{PROTOCOL_V1_HEADER_BYTE, PROTOCOL_V1_HEADER_SIZE, PROTOCOL_V1_MAGIC};
use crate::error::{ProtocolError, Result};
use crate::protocol::DecodedMessage;

/// Decode a Protocol v1 message buffer.
///
/// # Arguments
///
/// * `buffer` - The raw message buffer (first chunk)
///
/// # Returns
///
/// A `DecodedMessage` containing the message type, total length, and payload
/// from this chunk. For multi-chunk messages, you'll need to read additional
/// continuation chunks based on the length.
pub fn decode_message(buffer: &[u8]) -> Result<DecodedMessage> {
    // Minimum size is the header
    if buffer.len() < PROTOCOL_V1_HEADER_SIZE {
        return Err(ProtocolError::MessageTooShort {
            expected: PROTOCOL_V1_HEADER_SIZE,
            actual: buffer.len(),
        }
        .into());
    }

    // Verify magic byte
    if buffer[0] != PROTOCOL_V1_MAGIC {
        return Err(ProtocolError::InvalidHeader.into());
    }

    // Verify header bytes (##)
    if buffer[1] != PROTOCOL_V1_HEADER_BYTE || buffer[2] != PROTOCOL_V1_HEADER_BYTE {
        return Err(ProtocolError::InvalidHeader.into());
    }

    // Parse message type (big-endian u16)
    let message_type = u16::from_be_bytes([buffer[3], buffer[4]]);

    // Parse length (big-endian u32)
    let length = u32::from_be_bytes([buffer[5], buffer[6], buffer[7], buffer[8]]);

    // Extract payload (everything after the header)
    let payload = buffer[PROTOCOL_V1_HEADER_SIZE..].to_vec();

    Ok(DecodedMessage {
        message_type,
        length,
        payload,
    })
}

/// Parse just the header from a buffer.
///
/// Returns `(message_type, length)` tuple.
pub fn parse_header(buffer: &[u8]) -> Result<(u16, u32)> {
    if buffer.len() < PROTOCOL_V1_HEADER_SIZE {
        return Err(ProtocolError::MessageTooShort {
            expected: PROTOCOL_V1_HEADER_SIZE,
            actual: buffer.len(),
        }
        .into());
    }

    // Verify header
    if buffer[0] != PROTOCOL_V1_MAGIC
        || buffer[1] != PROTOCOL_V1_HEADER_BYTE
        || buffer[2] != PROTOCOL_V1_HEADER_BYTE
    {
        return Err(ProtocolError::InvalidHeader.into());
    }

    let message_type = u16::from_be_bytes([buffer[3], buffer[4]]);
    let length = u32::from_be_bytes([buffer[5], buffer[6], buffer[7], buffer[8]]);

    Ok((message_type, length))
}

/// Extract payload from a continuation chunk.
///
/// Continuation chunks have format: [0x3F][payload...]
pub fn decode_continuation(buffer: &[u8]) -> Result<&[u8]> {
    if buffer.is_empty() {
        return Err(ProtocolError::MessageTooShort {
            expected: 1,
            actual: 0,
        }
        .into());
    }

    // Verify magic byte
    if buffer[0] != PROTOCOL_V1_MAGIC {
        return Err(ProtocolError::ChunkHeaderMismatch.into());
    }

    // Return payload (skip magic byte)
    Ok(&buffer[1..])
}

/// Validate that a buffer is a valid first chunk header.
pub fn is_valid_header(buffer: &[u8]) -> bool {
    buffer.len() >= PROTOCOL_V1_HEADER_SIZE
        && buffer[0] == PROTOCOL_V1_MAGIC
        && buffer[1] == PROTOCOL_V1_HEADER_BYTE
        && buffer[2] == PROTOCOL_V1_HEADER_BYTE
}

/// Validate that a buffer is a valid continuation chunk.
pub fn is_valid_continuation(buffer: &[u8]) -> bool {
    !buffer.is_empty() && buffer[0] == PROTOCOL_V1_MAGIC
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_decode_message() {
        // Construct a valid message
        let mut buffer = vec![0x3F, 0x23, 0x23]; // Magic + ##
        buffer.extend_from_slice(&0x0011u16.to_be_bytes()); // Message type
        buffer.extend_from_slice(&0x00000005u32.to_be_bytes()); // Length = 5
        buffer.extend_from_slice(&[0x01, 0x02, 0x03, 0x04, 0x05]); // Payload

        let decoded = decode_message(&buffer).unwrap();

        assert_eq!(decoded.message_type, 0x0011);
        assert_eq!(decoded.length, 5);
        assert_eq!(decoded.payload, vec![0x01, 0x02, 0x03, 0x04, 0x05]);
    }

    #[test]
    fn test_decode_message_too_short() {
        let buffer = vec![0x3F, 0x23, 0x23]; // Missing type and length

        let result = decode_message(&buffer);
        assert!(result.is_err());
    }

    #[test]
    fn test_decode_invalid_header() {
        let mut buffer = vec![0x3F, 0x24, 0x23]; // Wrong second byte
        buffer.extend_from_slice(&0x0011u16.to_be_bytes());
        buffer.extend_from_slice(&0x00000000u32.to_be_bytes());

        let result = decode_message(&buffer);
        assert!(result.is_err());
    }

    #[test]
    fn test_decode_continuation() {
        let buffer = vec![0x3F, 0x01, 0x02, 0x03];

        let payload = decode_continuation(&buffer).unwrap();
        assert_eq!(payload, &[0x01, 0x02, 0x03]);
    }

    #[test]
    fn test_parse_header() {
        let mut buffer = vec![0x3F, 0x23, 0x23];
        buffer.extend_from_slice(&0x0055u16.to_be_bytes()); // Message type = 85
        buffer.extend_from_slice(&0x000001F4u32.to_be_bytes()); // Length = 500

        let (msg_type, length) = parse_header(&buffer).unwrap();
        assert_eq!(msg_type, 0x0055);
        assert_eq!(length, 500);
    }

    #[test]
    fn test_is_valid_header() {
        let valid = vec![0x3F, 0x23, 0x23, 0x00, 0x11, 0x00, 0x00, 0x00, 0x00];
        assert!(is_valid_header(&valid));

        let invalid = vec![0x3F, 0x24, 0x23, 0x00, 0x11, 0x00, 0x00, 0x00, 0x00];
        assert!(!is_valid_header(&invalid));
    }
}
