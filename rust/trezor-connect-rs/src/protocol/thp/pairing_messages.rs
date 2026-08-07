//! THP Pairing message encoding/decoding.
//!
//! Simple protobuf-style encoding for THP pairing messages.
//! These messages are sent encrypted over the THP channel.

// Constants used by bluetooth.rs, imported here for module organization
use crate::error::{Result, ThpError};

/// Encode a ThpPairingRequest message
/// Fields: host_name (1, string), app_name (2, string)
pub fn encode_pairing_request(host_name: &str, app_name: &str) -> Vec<u8> {
    let mut data = Vec::new();

    // Field 1: host_name (string)
    data.push(0x0a); // field 1, wire type 2 (length-delimited)
    encode_varint(&mut data, host_name.len() as u64);
    data.extend_from_slice(host_name.as_bytes());

    // Field 2: app_name (string)
    data.push(0x12); // field 2, wire type 2 (length-delimited)
    encode_varint(&mut data, app_name.len() as u64);
    data.extend_from_slice(app_name.as_bytes());

    data
}

/// Encode a ThpSelectMethod message
/// Fields: selected_pairing_method (1, enum/varint)
pub fn encode_select_method(method: u8) -> Vec<u8> {
    let mut data = Vec::new();

    // Field 1: selected_pairing_method (varint)
    data.push(0x08); // field 1, wire type 0 (varint)
    data.push(method);

    data
}

/// Encode a ThpCodeEntryChallenge message
/// Fields: challenge (1, bytes)
pub fn encode_code_entry_challenge(challenge: &[u8]) -> Vec<u8> {
    let mut data = Vec::new();

    // Field 1: challenge (bytes)
    data.push(0x0a); // field 1, wire type 2 (length-delimited)
    encode_varint(&mut data, challenge.len() as u64);
    data.extend_from_slice(challenge);

    data
}

/// Encode a ThpCodeEntryCpaceHostTag message
/// Fields: cpace_host_public_key (1, bytes), tag (2, bytes)
pub fn encode_cpace_host_tag(cpace_pubkey: &[u8], tag: &[u8]) -> Vec<u8> {
    let mut data = Vec::new();

    // Field 1: cpace_host_public_key (bytes)
    data.push(0x0a); // field 1, wire type 2
    encode_varint(&mut data, cpace_pubkey.len() as u64);
    data.extend_from_slice(cpace_pubkey);

    // Field 2: tag (bytes)
    data.push(0x12); // field 2, wire type 2
    encode_varint(&mut data, tag.len() as u64);
    data.extend_from_slice(tag);

    data
}

/// Encode a ThpCredentialRequest message
/// Fields: host_static_public_key (1, bytes), autoconnect (2, bool), credential (3, bytes)
pub fn encode_credential_request(
    host_static_pubkey: &[u8],
    autoconnect: bool,
    credential: Option<&[u8]>,
) -> Vec<u8> {
    let mut data = Vec::new();

    // Field 1: host_static_public_key (bytes)
    data.push(0x0a); // field 1, wire type 2
    encode_varint(&mut data, host_static_pubkey.len() as u64);
    data.extend_from_slice(host_static_pubkey);

    // Field 2: autoconnect (bool)
    if autoconnect {
        data.push(0x10); // field 2, wire type 0
        data.push(0x01);
    }

    // Field 3: credential (bytes, optional)
    if let Some(cred) = credential {
        data.push(0x1a); // field 3, wire type 2
        encode_varint(&mut data, cred.len() as u64);
        data.extend_from_slice(cred);
    }

    data
}

/// Decode a ThpCodeEntryCommitment message
/// Returns the commitment bytes
pub fn decode_code_entry_commitment(data: &[u8]) -> Result<Vec<u8>> {
    // Field 1: commitment (bytes)
    if data.len() < 2 {
        return Err(ThpError::PairingFailed("Commitment too short".to_string()).into());
    }

    if data[0] != 0x0a {
        return Err(ThpError::PairingFailed("Invalid commitment field".to_string()).into());
    }

    let (len, offset) = decode_varint(&data[1..])?;
    let start = 1 + offset;
    let end = start + len as usize;

    if data.len() < end {
        return Err(ThpError::PairingFailed("Commitment data truncated".to_string()).into());
    }

    Ok(data[start..end].to_vec())
}

/// Decode a ThpCodeEntryCpaceTrezor message
/// Returns the CPACE public key
pub fn decode_cpace_trezor(data: &[u8]) -> Result<[u8; 32]> {
    // Field 1: cpace_trezor_public_key (bytes)
    if data.len() < 2 {
        return Err(ThpError::PairingFailed("CPACE response too short".to_string()).into());
    }

    if data[0] != 0x0a {
        return Err(ThpError::PairingFailed("Invalid CPACE field".to_string()).into());
    }

    let (len, offset) = decode_varint(&data[1..])?;
    if len != 32 {
        return Err(ThpError::PairingFailed("Invalid CPACE pubkey length".to_string()).into());
    }

    let start = 1 + offset;
    let pubkey: [u8; 32] = data[start..start + 32]
        .try_into()
        .map_err(|_| ThpError::PairingFailed("CPACE pubkey conversion failed".to_string()))?;

    Ok(pubkey)
}

/// Decode a ThpCodeEntrySecret message
/// Returns the secret bytes
pub fn decode_code_entry_secret(data: &[u8]) -> Result<Vec<u8>> {
    // Field 1: secret (bytes)
    if data.len() < 2 {
        return Err(ThpError::PairingFailed("Secret too short".to_string()).into());
    }

    if data[0] != 0x0a {
        return Err(ThpError::PairingFailed("Invalid secret field".to_string()).into());
    }

    let (len, offset) = decode_varint(&data[1..])?;
    let start = 1 + offset;
    let end = start + len as usize;

    if data.len() < end {
        return Err(ThpError::PairingFailed("Secret data truncated".to_string()).into());
    }

    Ok(data[start..end].to_vec())
}

/// Decode a ThpCredentialResponse message
/// Returns (trezor_static_public_key, credential)
pub fn decode_credential_response(data: &[u8]) -> Result<(Vec<u8>, Vec<u8>)> {
    let mut trezor_pubkey = Vec::new();
    let mut credential = Vec::new();
    let mut pos = 0;

    while pos < data.len() {
        let tag = data[pos];
        pos += 1;

        let field_num = tag >> 3;
        let wire_type = tag & 0x07;

        if wire_type != 2 {
            // Skip non-length-delimited fields
            if wire_type == 0 {
                let (_, offset) = decode_varint(&data[pos..])?;
                pos += offset;
            }
            continue;
        }

        let (len, offset) = decode_varint(&data[pos..])?;
        pos += offset;
        let end = pos + len as usize;

        if end > data.len() {
            break;
        }

        match field_num {
            1 => trezor_pubkey = data[pos..end].to_vec(),
            2 => credential = data[pos..end].to_vec(),
            _ => {}
        }

        pos = end;
    }

    if trezor_pubkey.is_empty() || credential.is_empty() {
        return Err(
            ThpError::PairingFailed("Missing credential response fields".to_string()).into(),
        );
    }

    Ok((trezor_pubkey, credential))
}

/// Encode a varint
pub(crate) fn encode_varint(buf: &mut Vec<u8>, mut value: u64) {
    while value >= 0x80 {
        buf.push((value as u8) | 0x80);
        value >>= 7;
    }
    buf.push(value as u8);
}

/// Decode a varint, returns (value, bytes_consumed)
pub(crate) fn decode_varint(data: &[u8]) -> Result<(u64, usize)> {
    let mut value: u64 = 0;
    let mut shift = 0;

    for (i, &byte) in data.iter().enumerate() {
        value |= ((byte & 0x7f) as u64) << shift;
        if byte & 0x80 == 0 {
            return Ok((value, i + 1));
        }
        shift += 7;
        if shift > 63 {
            return Err(ThpError::PairingFailed("Varint too long".to_string()).into());
        }
    }

    Err(ThpError::PairingFailed("Incomplete varint".to_string()).into())
}

/// Encode a ThpCreateNewSession message
/// Fields: passphrase (1, string), on_device (2, bool)
///
/// `passphrase` is genuinely optional: pass `Some("")` for the standard wallet,
/// `Some(value)` for a host-entered hidden wallet, or `None` for on-device entry
/// (`on_device = true`). The passphrase field is omitted entirely when `None` —
/// firmware rejects an empty passphrase combined with `on_device = true`.
pub fn encode_create_new_session(passphrase: Option<&str>, on_device: bool) -> Vec<u8> {
    let mut data = Vec::new();

    // Field 1: passphrase (string) - omitted entirely when None
    if let Some(passphrase) = passphrase {
        data.push(0x0a); // field 1, wire type 2 (length-delimited)
        encode_varint(&mut data, passphrase.len() as u64);
        data.extend_from_slice(passphrase.as_bytes());
    }

    // Field 2: on_device (bool) - only include if true
    if on_device {
        data.push(0x10); // field 2, wire type 0 (varint)
        data.push(0x01);
    }

    data
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::constants::thp_pairing_method;

    #[test]
    fn test_encode_pairing_request() {
        let data = encode_pairing_request("TestHost", "TestApp");
        // Should have field 1 (host_name) and field 2 (app_name)
        assert!(!data.is_empty());
        assert_eq!(data[0], 0x0a); // field 1, wire type 2
    }

    #[test]
    fn test_encode_select_method() {
        let data = encode_select_method(thp_pairing_method::CODE_ENTRY);
        assert_eq!(data, vec![0x08, 0x02]); // field 1 = 2 (CodeEntry)
    }

    #[test]
    fn test_varint_roundtrip() {
        let mut buf = Vec::new();
        encode_varint(&mut buf, 300);
        let (value, _) = decode_varint(&buf).unwrap();
        assert_eq!(value, 300);
    }
}
