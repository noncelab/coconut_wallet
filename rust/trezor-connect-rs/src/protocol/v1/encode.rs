//! Protocol v1 message encoding.
//!
//! Encodes protobuf messages into the Trezor v1 wire format.

use crate::constants::{PROTOCOL_V1_HEADER_BYTE, PROTOCOL_V1_MAGIC};

/// Encode a message with the given type and data into Protocol v1 format.
///
/// The format is:
/// - 1 byte: Magic (0x3F = '?')
/// - 2 bytes: Header (0x23, 0x23 = '##')
/// - 2 bytes: Message type (big-endian u16)
/// - 4 bytes: Data length (big-endian u32)
/// - N bytes: Protobuf data
///
/// # Arguments
///
/// * `message_type` - The protobuf message type ID
/// * `data` - The protobuf-encoded message data
///
/// # Returns
///
/// The encoded message as a byte vector
pub fn encode_message(message_type: u16, data: &[u8]) -> Vec<u8> {
    let data_length = data.len() as u32;

    // Header: magic + ## + message_type + length
    let mut buffer = Vec::with_capacity(9 + data.len());

    // Magic byte
    buffer.push(PROTOCOL_V1_MAGIC);

    // Header bytes (##)
    buffer.push(PROTOCOL_V1_HEADER_BYTE);
    buffer.push(PROTOCOL_V1_HEADER_BYTE);

    // Message type (big-endian u16)
    buffer.extend_from_slice(&message_type.to_be_bytes());

    // Data length (big-endian u32)
    buffer.extend_from_slice(&data_length.to_be_bytes());

    // Protobuf data
    buffer.extend_from_slice(data);

    buffer
}

/// Encode a header for a message with the given type and length.
///
/// This is useful when you need just the header without the payload.
pub fn encode_header(message_type: u16, data_length: u32) -> [u8; 9] {
    let mut header = [0u8; 9];

    header[0] = PROTOCOL_V1_MAGIC;
    header[1] = PROTOCOL_V1_HEADER_BYTE;
    header[2] = PROTOCOL_V1_HEADER_BYTE;

    // Message type (big-endian)
    header[3] = (message_type >> 8) as u8;
    header[4] = message_type as u8;

    // Data length (big-endian)
    header[5] = (data_length >> 24) as u8;
    header[6] = (data_length >> 16) as u8;
    header[7] = (data_length >> 8) as u8;
    header[8] = data_length as u8;

    header
}

/// Get the continuation chunk header (just the magic byte).
pub fn continuation_header() -> [u8; 1] {
    [PROTOCOL_V1_MAGIC]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encode_message() {
        let message_type = 0x0011; // GetPublicKey
        let data = vec![0x08, 0x2C]; // Some protobuf data

        let encoded = encode_message(message_type, &data);

        assert_eq!(encoded[0], 0x3F); // Magic
        assert_eq!(encoded[1], 0x23); // #
        assert_eq!(encoded[2], 0x23); // #
        assert_eq!(encoded[3], 0x00); // Message type high byte
        assert_eq!(encoded[4], 0x11); // Message type low byte
        assert_eq!(encoded[5], 0x00); // Length byte 3
        assert_eq!(encoded[6], 0x00); // Length byte 2
        assert_eq!(encoded[7], 0x00); // Length byte 1
        assert_eq!(encoded[8], 0x02); // Length byte 0
        assert_eq!(&encoded[9..], &data[..]);
    }

    #[test]
    fn test_encode_header() {
        let header = encode_header(0x0011, 100);

        assert_eq!(header[0], 0x3F);
        assert_eq!(header[1], 0x23);
        assert_eq!(header[2], 0x23);
        assert_eq!(header[3], 0x00);
        assert_eq!(header[4], 0x11);
        assert_eq!(header[5], 0x00);
        assert_eq!(header[6], 0x00);
        assert_eq!(header[7], 0x00);
        assert_eq!(header[8], 0x64); // 100 in hex
    }

    #[test]
    fn test_encode_empty_message() {
        let encoded = encode_message(0x0000, &[]);

        assert_eq!(encoded.len(), 9); // Just the header
        assert_eq!(encoded[5..9], [0, 0, 0, 0]); // Length = 0
    }
}
