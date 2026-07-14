//! THP message decoding.
//!
//! Decodes messages from the THP protocol (v2).

use super::crypto::*;
use super::decode_control_byte;
use super::state::ThpState;
use crate::constants::{THP_HEADER_SIZE, THP_MESSAGE_LEN_SIZE, thp_control};
use crate::error::{ProtocolError, Result, ThpError};
use crate::protocol::DecodedMessage;

/// Decode a THP message buffer
///
/// The length field in THP includes the CRC (4 bytes). This function
/// strips the CRC from the returned payload so callers receive only
/// the actual message data.
pub fn decode_thp_message(buffer: &[u8]) -> Result<DecodedMessage> {
    // Minimum size is header + length
    let min_size = THP_HEADER_SIZE + THP_MESSAGE_LEN_SIZE;
    if buffer.len() < min_size {
        return Err(ProtocolError::MessageTooShort {
            expected: min_size,
            actual: buffer.len(),
        }
        .into());
    }

    // Parse control byte
    let control_byte = buffer[0];
    let message_type = decode_control_byte(control_byte)
        .ok_or_else(|| ProtocolError::InvalidMessageType(control_byte as u16))?;

    // Parse channel
    let _channel = [buffer[1], buffer[2]];

    // Parse length (includes CRC)
    let length = u16::from_be_bytes([buffer[3], buffer[4]]) as u32;

    // Extract payload, stripping the 4-byte CRC at the end.
    // Length field includes CRC, so data_len = length - 4.
    let crc_len = 4usize;
    let data_after_header = &buffer[min_size..];
    let payload = if length as usize > crc_len && data_after_header.len() >= length as usize {
        // Strip CRC from end of payload
        data_after_header[..length as usize - crc_len].to_vec()
    } else if data_after_header.len() > crc_len {
        // Best-effort: strip trailing 4 bytes if we have enough data
        data_after_header[..data_after_header.len() - crc_len].to_vec()
    } else {
        // Not enough data for CRC stripping, return as-is
        data_after_header.to_vec()
    };

    Ok(DecodedMessage {
        message_type: message_type as u16,
        length,
        payload,
    })
}

/// Decode and decrypt an encrypted THP message
pub fn decode_encrypted_message(state: &ThpState, buffer: &[u8]) -> Result<(u16, Vec<u8>)> {
    let decoded = decode_thp_message(buffer)?;

    // Get decryption key
    let creds = state
        .handshake_credentials()
        .ok_or(ThpError::StateMissing)?;

    let key: [u8; 32] = creds
        .trezor_key
        .clone()
        .try_into()
        .map_err(|_| ThpError::DecryptionError("Invalid key length".to_string()))?;

    let iv = get_iv_from_nonce(state.recv_nonce());

    // Post-handshake messages use empty AAD, matching encode.rs and the
    // transport implementations (callback.rs, bluetooth.rs).
    let decrypted = aes_gcm_decrypt(&key, &iv, &[], &decoded.payload)?;

    // Parse decrypted payload: [session_id: 1 byte][message_type: 2 bytes BE][protobuf_data]
    if decrypted.len() < 3 {
        return Err(ProtocolError::Malformed("Decrypted payload too short".to_string()).into());
    }

    let _session_id = decrypted[0];
    let protobuf_type = u16::from_be_bytes([decrypted[1], decrypted[2]]);
    let protobuf_data = decrypted[3..].to_vec();

    Ok((protobuf_type, protobuf_data))
}

/// Parse channel allocation response
pub fn parse_channel_allocation_response(buffer: &[u8]) -> Result<[u8; 2]> {
    let decoded = decode_thp_message(buffer)?;

    if decoded.message_type != thp_control::CHANNEL_ALLOCATION_RES as u16 {
        return Err(ProtocolError::UnexpectedResponse {
            expected: "ChannelAllocationResponse".to_string(),
            actual: format!("0x{:02X}", decoded.message_type),
        }
        .into());
    }

    // Channel is in the header
    if buffer.len() < 3 {
        return Err(ProtocolError::Malformed("Response too short".to_string()).into());
    }

    Ok([buffer[1], buffer[2]])
}

/// Parse handshake init response
pub fn parse_handshake_init_response(
    buffer: &[u8],
) -> Result<super::handshake::HandshakeInitResponse> {
    let decoded = decode_thp_message(buffer)?;

    if decoded.message_type != thp_control::HANDSHAKE_INIT_RES as u16 {
        return Err(ProtocolError::UnexpectedResponse {
            expected: "HandshakeInitResponse".to_string(),
            actual: format!("0x{:02X}", decoded.message_type),
        }
        .into());
    }

    // Parse payload: trezor_ephemeral_pubkey (32) + encrypted_static_pubkey (48) + tag (16)
    if decoded.payload.len() < 96 {
        return Err(ProtocolError::Malformed(
            "HandshakeInitResponse payload too short".to_string(),
        )
        .into());
    }

    let trezor_ephemeral_pubkey: [u8; 32] = decoded.payload[..32]
        .try_into()
        .map_err(|_| ProtocolError::Malformed("Invalid ephemeral pubkey".to_string()))?;

    let trezor_encrypted_static_pubkey = decoded.payload[32..80].to_vec();

    let tag: [u8; 16] = decoded.payload[80..96]
        .try_into()
        .map_err(|_| ProtocolError::Malformed("Invalid tag".to_string()))?;

    Ok(super::handshake::HandshakeInitResponse {
        trezor_ephemeral_pubkey,
        trezor_encrypted_static_pubkey,
        tag,
    })
}

/// Decode handshake completion response from raw buffer
pub fn decode_handshake_completion_response(buffer: &[u8]) -> Result<Vec<u8>> {
    let decoded = decode_thp_message(buffer)?;

    if decoded.message_type != thp_control::HANDSHAKE_COMP_RES as u16 {
        return Err(ProtocolError::UnexpectedResponse {
            expected: "HandshakeCompletionResponse".to_string(),
            actual: format!("0x{:02X}", decoded.message_type),
        }
        .into());
    }

    // Return encrypted payload for further processing
    Ok(decoded.payload)
}

/// Parse ACK message
pub fn parse_ack(buffer: &[u8]) -> Result<u8> {
    let decoded = decode_thp_message(buffer)?;

    // Check if it's an ACK (control byte & 0xf7 == 0x20)
    let ack_type = buffer[0] & 0xf7;
    if ack_type != thp_control::ACK_MESSAGE {
        return Err(ProtocolError::UnexpectedResponse {
            expected: "ACK".to_string(),
            actual: format!("0x{:02X}", decoded.message_type),
        }
        .into());
    }

    // Extract ack bit from control byte
    let ack_bit = (buffer[0] >> 3) & 0x01;

    Ok(ack_bit)
}

/// Parse error message
pub fn parse_error(buffer: &[u8]) -> Result<(u8, String)> {
    let decoded = decode_thp_message(buffer)?;

    if decoded.message_type != thp_control::ERROR as u16 {
        return Err(ProtocolError::UnexpectedResponse {
            expected: "Error".to_string(),
            actual: format!("0x{:02X}", decoded.message_type),
        }
        .into());
    }

    // Parse error code and message
    let error_code = if !decoded.payload.is_empty() {
        decoded.payload[0]
    } else {
        0
    };

    let error_message = if decoded.payload.len() > 1 {
        String::from_utf8_lossy(&decoded.payload[1..]).to_string()
    } else {
        "Unknown error".to_string()
    };

    Ok((error_code, error_message))
}

/// Check if buffer contains an ACK message
pub fn is_ack_message(buffer: &[u8]) -> bool {
    if buffer.is_empty() {
        return false;
    }
    (buffer[0] & 0xf7) == thp_control::ACK_MESSAGE
}

/// Check if buffer contains an error message
pub fn is_error_message(buffer: &[u8]) -> bool {
    if buffer.is_empty() {
        return false;
    }
    buffer[0] == thp_control::ERROR
}

/// Get the sync bit from a received message
pub fn get_recv_sync_bit(buffer: &[u8]) -> Option<u8> {
    if buffer.is_empty() {
        return None;
    }

    // Sync bit is in position 4 of control byte for data messages
    let control = buffer[0];
    let data_type = control & 0xe7;

    if matches!(
        data_type,
        thp_control::HANDSHAKE_INIT_RES | thp_control::HANDSHAKE_COMP_RES | thp_control::ENCRYPTED
    ) {
        Some((control >> 4) & 0x01)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_decode_thp_message() {
        let mut buffer = vec![thp_control::CHANNEL_ALLOCATION_RES];
        buffer.extend_from_slice(&[0x12, 0x34]); // Channel
        buffer.extend_from_slice(&[0x00, 0x00]); // Length

        let decoded = decode_thp_message(&buffer).unwrap();
        assert_eq!(
            decoded.message_type,
            thp_control::CHANNEL_ALLOCATION_RES as u16
        );
        assert_eq!(decoded.length, 0);
    }

    #[test]
    fn test_is_ack_message() {
        let ack_buffer = vec![thp_control::ACK_MESSAGE, 0x12, 0x34, 0x00, 0x00];
        assert!(is_ack_message(&ack_buffer));

        let ack_with_bit = vec![thp_control::ACK_MESSAGE | 0x08, 0x12, 0x34, 0x00, 0x00];
        assert!(is_ack_message(&ack_with_bit));

        let not_ack = vec![thp_control::ENCRYPTED, 0x12, 0x34, 0x00, 0x00];
        assert!(!is_ack_message(&not_ack));
    }

    #[test]
    fn test_parse_ack() {
        let ack_buffer = vec![thp_control::ACK_MESSAGE | 0x08, 0x12, 0x34, 0x00, 0x00];
        let ack_bit = parse_ack(&ack_buffer).unwrap();
        assert_eq!(ack_bit, 1);

        let ack_buffer_0 = vec![thp_control::ACK_MESSAGE, 0x12, 0x34, 0x00, 0x00];
        let ack_bit_0 = parse_ack(&ack_buffer_0).unwrap();
        assert_eq!(ack_bit_0, 0);
    }

    #[test]
    fn test_get_recv_sync_bit() {
        let buffer = vec![thp_control::ENCRYPTED | 0x10, 0x12, 0x34, 0x00, 0x00];
        assert_eq!(get_recv_sync_bit(&buffer), Some(1));

        let buffer0 = vec![thp_control::ENCRYPTED, 0x12, 0x34, 0x00, 0x00];
        assert_eq!(get_recv_sync_bit(&buffer0), Some(0));

        let ack = vec![thp_control::ACK_MESSAGE, 0x12, 0x34, 0x00, 0x00];
        assert_eq!(get_recv_sync_bit(&ack), None);
    }

    fn make_test_state(key: &[u8; 32]) -> ThpState {
        use crate::protocol::thp::state::ThpHandshakeCredentials;

        let mut creds = ThpHandshakeCredentials::default();
        creds.trezor_key = key.to_vec();

        let mut state = ThpState::new();
        state.set_handshake_credentials(creds);
        state
    }

    #[test]
    fn test_decode_encrypted_message_session_id_parsing() {
        use crate::protocol::thp::crypto::{aes_gcm_encrypt, get_iv_from_nonce};

        let key = [0x42u8; 32];
        let state = make_test_state(&key);

        // Build plaintext: [session_id=0x05][message_type=0x0100 BE][protobuf_data=0xAA 0xBB]
        let session_id: u8 = 0x05;
        let msg_type: u16 = 0x0100;
        let protobuf_data = vec![0xAA, 0xBB];
        let mut plaintext = vec![session_id];
        plaintext.extend_from_slice(&msg_type.to_be_bytes());
        plaintext.extend_from_slice(&protobuf_data);

        // Encrypt with key, nonce=1 (recv_nonce default)
        let iv = get_iv_from_nonce(state.recv_nonce());
        let ciphertext = aes_gcm_encrypt(&key, &iv, &[], &plaintext).unwrap();

        // Build THP message: [control_byte][channel_hi][channel_lo][length_hi][length_lo][payload][crc(4)]
        // Length field includes ciphertext + CRC
        let control_byte = thp_control::ENCRYPTED;
        let channel = [0x12, 0x34];
        let length = ciphertext.len() as u16 + 4; // +4 for CRC
        let mut buffer = vec![control_byte, channel[0], channel[1]];
        buffer.extend_from_slice(&length.to_be_bytes());
        buffer.extend_from_slice(&ciphertext);
        // Append CRC32 (computed over header + ciphertext)
        let crc = crate::protocol::thp::crypto::crc32(&buffer);
        buffer.extend_from_slice(&crc);

        let (decoded_type, decoded_data) = decode_encrypted_message(&state, &buffer).unwrap();
        assert_eq!(decoded_type, msg_type);
        assert_eq!(decoded_data, protobuf_data);
    }

    #[test]
    fn test_decode_encrypted_message_too_short_plaintext() {
        use crate::protocol::thp::crypto::{aes_gcm_encrypt, get_iv_from_nonce};

        let key = [0x42u8; 32];
        let state = make_test_state(&key);

        // Encrypt only 2 bytes (too short for session_id + message_type)
        let plaintext = vec![0x01, 0x02];
        let iv = get_iv_from_nonce(state.recv_nonce());
        let ciphertext = aes_gcm_encrypt(&key, &iv, &[], &plaintext).unwrap();

        let control_byte = thp_control::ENCRYPTED;
        let length = ciphertext.len() as u16 + 4; // +4 for CRC
        let mut buffer = vec![control_byte, 0x12, 0x34];
        buffer.extend_from_slice(&length.to_be_bytes());
        buffer.extend_from_slice(&ciphertext);
        // Append CRC32
        let crc = crate::protocol::thp::crypto::crc32(&buffer);
        buffer.extend_from_slice(&crc);

        let result = decode_encrypted_message(&state, &buffer);
        assert!(result.is_err());
    }
}
