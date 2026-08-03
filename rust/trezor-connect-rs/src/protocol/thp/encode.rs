//! THP message encoding.
//!
//! Encodes messages for the THP protocol (v2).

use super::crypto::*;
use super::state::ThpState;
use crate::constants::{THP_HEADER_SIZE, THP_MESSAGE_LEN_SIZE, thp_control};
use crate::error::{Result, ThpError};

/// Encode a THP message
///
/// For encrypted messages, the payload is encrypted using AES-256-GCM.
/// For handshake messages, the payload is sent as-is.
///
/// The length field includes the payload data (or encrypted data) plus
/// the 4-byte CRC. CRC32 is computed over the entire message (header + payload)
/// and appended at the end.
pub fn encode_thp_message(state: &ThpState, message_type: u16, data: &[u8]) -> Result<Vec<u8>> {
    if state.nonce_exhausted() {
        return Err(
            ThpError::EncryptionError("Nonce exhausted: re-key required".to_string()).into(),
        );
    }

    let channel = state.channel();

    // Determine control byte based on state
    let control_byte = if state.is_paired() {
        // Encrypted message
        let sync_bit = state.send_bit();
        thp_control::ENCRYPTED | (sync_bit << 4)
    } else {
        // During handshake, use appropriate control byte
        // This is a simplified version - real implementation would
        // check the current handshake phase
        thp_control::ENCRYPTED
    };

    // Encrypt payload if paired, otherwise send plaintext
    let payload = if state.is_paired() {
        let creds = state
            .handshake_credentials()
            .ok_or(ThpError::StateMissing)?;

        // Build plaintext with session_id + message_type + data
        let session_id = state.session_id();
        let mut plaintext = Vec::with_capacity(3 + data.len());
        plaintext.push(session_id);
        plaintext.extend_from_slice(&message_type.to_be_bytes());
        plaintext.extend_from_slice(data);

        encrypt_payload(state, &creds.host_key, &plaintext)?
    } else {
        data.to_vec()
    };

    // Length includes payload + CRC
    let length = payload.len() as u16 + CRC_LENGTH as u16;
    let mut message =
        Vec::with_capacity(THP_HEADER_SIZE + THP_MESSAGE_LEN_SIZE + payload.len() + CRC_LENGTH);

    // Header
    message.push(control_byte);
    message.extend_from_slice(channel);

    // Length (big-endian u16)
    message.extend_from_slice(&length.to_be_bytes());

    // Payload
    message.extend_from_slice(&payload);

    // Calculate and append CRC32
    let crc = crate::protocol::thp::crypto::crc32(&message);
    message.extend_from_slice(&crc);

    Ok(message)
}

/// CRC length constant
const CRC_LENGTH: usize = 4;

/// THP default broadcast channel for channel allocation
const THP_DEFAULT_CHANNEL: [u8; 2] = [0xff, 0xff];

/// Encode a channel allocation request
///
/// Format: [magic(1) | channel(2) | len(2) | nonce(8) | crc(4)]
/// Total: 17 bytes
pub fn encode_channel_allocation_request() -> Vec<u8> {
    // Generate random 8-byte nonce
    let nonce: [u8; 8] = rand::random();

    // Length includes nonce + CRC
    let length: u16 = 8 + CRC_LENGTH as u16;

    // Build message without CRC
    let mut message = Vec::with_capacity(5 + 8 + 4);

    // Control byte
    message.push(thp_control::CHANNEL_ALLOCATION_REQ);

    // Channel (0xFFFF for broadcast/allocation request)
    message.extend_from_slice(&THP_DEFAULT_CHANNEL);

    // Length (big-endian)
    message.extend_from_slice(&length.to_be_bytes());

    // Nonce (8 bytes)
    message.extend_from_slice(&nonce);

    // Calculate and append CRC32
    let crc = crate::protocol::thp::crypto::crc32(&message);
    message.extend_from_slice(&crc);

    message
}

/// Encode a handshake init request
///
/// Format: [magic(1) | channel(2) | len(2) | pubkey(32) | try_to_unlock(1) | crc(4)]
pub fn encode_handshake_init_request(
    channel: &[u8; 2],
    host_ephemeral_pubkey: &[u8; 32],
    try_to_unlock: bool,
    send_bit: u8,
) -> Vec<u8> {
    // Length includes pubkey + flag + CRC
    let length: u16 = 32 + 1 + CRC_LENGTH as u16;

    let mut message = Vec::with_capacity(5 + 33 + 4);

    // Control byte with sequence bit
    message.push(thp_control::HANDSHAKE_INIT_REQ | (send_bit << 4));

    // Channel
    message.extend_from_slice(channel);

    // Length (big-endian)
    message.extend_from_slice(&length.to_be_bytes());

    // Payload
    message.extend_from_slice(host_ephemeral_pubkey);
    message.push(try_to_unlock as u8);

    // Calculate and append CRC32
    let crc = crate::protocol::thp::crypto::crc32(&message);
    message.extend_from_slice(&crc);

    message
}

/// Encode a handshake completion request
///
/// Format: [magic(1) | channel(2) | len(2) | encrypted_pubkey | encrypted_payload | crc(4)]
pub fn encode_handshake_completion_request(
    channel: &[u8; 2],
    encrypted_host_static_pubkey: &[u8],
    encrypted_payload: &[u8],
    send_bit: u8,
) -> Vec<u8> {
    let payload_len = encrypted_host_static_pubkey.len() + encrypted_payload.len();
    let length: u16 = payload_len as u16 + CRC_LENGTH as u16;

    let mut message = Vec::with_capacity(5 + payload_len + 4);

    // Control byte with sequence bit
    message.push(thp_control::HANDSHAKE_COMP_REQ | (send_bit << 4));

    // Channel
    message.extend_from_slice(channel);

    // Length (big-endian)
    message.extend_from_slice(&length.to_be_bytes());

    // Payload
    message.extend_from_slice(encrypted_host_static_pubkey);
    message.extend_from_slice(encrypted_payload);

    // Calculate and append CRC32
    let crc = crate::protocol::thp::crypto::crc32(&message);
    message.extend_from_slice(&crc);

    message
}

/// Encode an ACK message
///
/// Format: [magic(1) | channel(2) | len(2) | crc(4)]
pub fn encode_ack(channel: &[u8; 2], ack_bit: u8) -> Vec<u8> {
    // Length is just CRC (no payload)
    let length: u16 = CRC_LENGTH as u16;

    let mut message = Vec::with_capacity(5 + 4);

    // Control byte with ack bit
    message.push(thp_control::ACK_MESSAGE | (ack_bit << 3));

    // Channel
    message.extend_from_slice(channel);

    // Length (big-endian)
    message.extend_from_slice(&length.to_be_bytes());

    // Calculate and append CRC32
    let crc = crate::protocol::thp::crypto::crc32(&message);
    message.extend_from_slice(&crc);

    message
}

/// Encode an encrypted data message
pub fn encode_encrypted_message(
    state: &ThpState,
    protobuf_type: u16,
    protobuf_data: &[u8],
) -> Result<Vec<u8>> {
    let creds = state
        .handshake_credentials()
        .ok_or(ThpError::StateMissing)?;

    let channel = state.channel();
    let sync_bit = state.send_bit();

    // THP encrypted payload format: [session_id: 1 byte][message_type: 2 bytes][protobuf_data]
    let session_id = state.session_id();
    let mut payload = Vec::with_capacity(3 + protobuf_data.len());
    payload.push(session_id);
    payload.extend_from_slice(&protobuf_type.to_be_bytes());
    payload.extend_from_slice(protobuf_data);

    // Encrypt payload
    let encrypted = encrypt_payload(state, &creds.host_key, &payload)?;

    // Length includes encrypted data + CRC
    let length: u16 = encrypted.len() as u16 + CRC_LENGTH as u16;

    // Build final message
    let mut message =
        Vec::with_capacity(THP_HEADER_SIZE + THP_MESSAGE_LEN_SIZE + encrypted.len() + CRC_LENGTH);

    // Control byte
    message.push(thp_control::ENCRYPTED | (sync_bit << 4));

    // Channel
    message.extend_from_slice(channel);

    // Length (big-endian)
    message.extend_from_slice(&length.to_be_bytes());

    // Encrypted payload
    message.extend_from_slice(&encrypted);

    // Calculate and append CRC32
    let crc = crate::protocol::thp::crypto::crc32(&message);
    message.extend_from_slice(&crc);

    Ok(message)
}

/// Encrypt payload using state's send nonce
fn encrypt_payload(state: &ThpState, key: &[u8], plaintext: &[u8]) -> Result<Vec<u8>> {
    let key: [u8; 32] = key
        .try_into()
        .map_err(|_| ThpError::EncryptionError("Invalid key length".to_string()))?;

    let send_nonce = state.send_nonce();
    log::debug!(
        "[THP] Encrypting with send_nonce={}, plaintext={} bytes",
        send_nonce,
        plaintext.len()
    );
    let iv = get_iv_from_nonce(send_nonce);

    // THP uses empty AAD for post-handshake encrypted messages
    let aad: &[u8] = &[];

    aes_gcm_encrypt(&key, &iv, aad, plaintext)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encode_channel_allocation_request() {
        let msg = encode_channel_allocation_request();

        // Total: magic(1) + channel(2) + len(2) + nonce(8) + crc(4) = 17 bytes
        assert_eq!(msg.len(), 17);
        assert_eq!(msg[0], thp_control::CHANNEL_ALLOCATION_REQ);
        assert_eq!(&msg[1..3], &[0xff, 0xff]); // Broadcast channel
        assert_eq!(&msg[3..5], &12u16.to_be_bytes()); // Length = 8 nonce + 4 crc
    }

    #[test]
    fn test_encode_handshake_init_request() {
        let channel = [0x12, 0x34];
        let pubkey = [0u8; 32];

        // Test with send_bit = 0
        let msg = encode_handshake_init_request(&channel, &pubkey, true, 0);

        // Total: magic(1) + channel(2) + len(2) + pubkey(32) + flag(1) + crc(4) = 42 bytes
        assert_eq!(msg.len(), 42);
        assert_eq!(msg[0], thp_control::HANDSHAKE_INIT_REQ);
        assert_eq!(&msg[1..3], &channel);
        assert_eq!(&msg[3..5], &37u16.to_be_bytes()); // Length = 32 + 1 + 4 crc
        assert_eq!(msg[37], 1); // try_to_unlock (before CRC)

        // Test with send_bit = 1
        let msg = encode_handshake_init_request(&channel, &pubkey, true, 1);
        assert_eq!(msg[0], thp_control::HANDSHAKE_INIT_REQ | 0x10); // 0x00 | 0x10 = 0x10
    }

    #[test]
    fn test_encode_ack() {
        let channel = [0xAB, 0xCD];
        let msg = encode_ack(&channel, 1);

        // Total: magic(1) + channel(2) + len(2) + crc(4) = 9 bytes
        assert_eq!(msg.len(), 9);
        assert_eq!(msg[0], thp_control::ACK_MESSAGE | 0x08); // ACK with bit set
        assert_eq!(&msg[1..3], &channel);
        assert_eq!(&msg[3..5], &4u16.to_be_bytes()); // Length = 4 (CRC only)
    }
}
