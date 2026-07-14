//! THP Pairing methods.
//!
//! Implements the various pairing methods supported by THP:
//! - Code Entry: 6-digit code displayed on device
//! - QR Code: Scan QR code from device
//! - NFC: Tap device with NFC tag

use num_bigint::BigUint;
use sha2::{Digest, Sha256, Sha512};
use zeroize::{Zeroize, ZeroizeOnDrop};

use super::crypto::*;
use super::state::{ThpCredentials, ThpHandshakeCredentials, ThpPairingMethod, ThpState};
use crate::error::{Result, ThpError};

/// CPACE host keys for code entry pairing
///
/// Contains a private key that is automatically zeroized on drop
/// to prevent key material from lingering in memory.
#[derive(Debug, Clone, Zeroize, ZeroizeOnDrop)]
pub struct CpaceHostKeys {
    /// Private key
    pub private_key: [u8; 32],
    /// Public key
    pub public_key: [u8; 32],
}

/// Generate CPACE host keys for code entry pairing
///
/// Uses the entered code and handshake hash to derive the generator point
pub fn get_cpace_host_keys(code: &[u8], handshake_hash: &[u8]) -> CpaceHostKeys {
    // Compute pregenerator as first 32 bytes of SHA-512(prefix || code || padding || h || 0x00)
    let prefix = [0x08, 0x43, 0x50, 0x61, 0x63, 0x65, 0x32, 0x35, 0x35, 0x06];
    let padding = {
        let mut p = vec![0x6f];
        p.extend_from_slice(&[0u8; 111]);
        p.push(0x20);
        p
    };

    let mut hasher = Sha512::new();
    hasher.update(&prefix);
    hasher.update(code);
    hasher.update(&padding);
    hasher.update(handshake_hash);
    hasher.update(&[0x00]);

    let sha_output = hasher.finalize();
    let pregenerator: [u8; 32] = sha_output[..32].try_into().unwrap();

    log::debug!("[CPACE] pregenerator derived");

    // Map to curve using elligator2
    let generator = elligator2(&pregenerator);
    log::debug!("[CPACE] generator derived");

    // Generate random private key
    let private_key: [u8; 32] = rand::random();
    log::debug!("[CPACE] private key generated");

    // Compute public key = X25519(private_key, generator)
    let (secret, _) = keypair_from_secret(&private_key);
    let generator_pubkey = x25519_dalek::PublicKey::from(generator);
    let public_key = x25519_dh(&secret, &generator_pubkey);
    log::debug!("[CPACE] public key computed");

    CpaceHostKeys {
        private_key,
        public_key,
    }
}

/// Compute shared secret from CPACE exchange
pub fn get_shared_secret(
    trezor_cpace_pubkey: &[u8; 32],
    host_cpace_privkey: &[u8; 32],
) -> [u8; 32] {
    // shared_secret = X25519(host_private, trezor_public)
    let (secret, _) = keypair_from_secret(host_cpace_privkey);
    let pubkey = x25519_dalek::PublicKey::from(*trezor_cpace_pubkey);
    let shared = x25519_dh(&secret, &pubkey);

    // tag = SHA-256(shared_secret)
    sha256(&shared)
}

/// Validate code entry tag
pub fn validate_code_entry_tag(
    credentials: &ThpHandshakeCredentials,
    displayed_value: &str,
    secret: &[u8],
) -> Result<()> {
    // 1. Assert that handshake commitment = SHA-256(secret)
    let computed_commitment = sha256(secret);
    if computed_commitment.as_slice() != credentials.handshake_commitment.as_slice() {
        return Err(ThpError::PairingFailed("Commitment mismatch".to_string()).into());
    }

    // 2. Assert that value = SHA-256(ThpPairingMethod.CodeEntry || h || secret || challenge) % 1000000
    let mut hasher = Sha256::new();
    hasher.update(&[ThpPairingMethod::CodeEntry as u8]);
    hasher.update(&credentials.handshake_hash);
    hasher.update(secret);
    hasher.update(&credentials.code_entry_challenge);

    let hash = hasher.finalize();

    // Convert full 256-bit hash to big integer and mod 1000000
    // Must use all 32 bytes (not just first 8) to match TypeScript's bigEndianBytesToBigInt
    let value: u64 = (BigUint::from_bytes_be(&hash) % BigUint::from(1_000_000u64))
        .try_into()
        .unwrap();
    let expected_value: u64 = displayed_value
        .parse()
        .map_err(|_| ThpError::PairingFailed("Invalid code format".to_string()))?;

    if value != expected_value {
        return Err(ThpError::PairingFailed(format!(
            "Code mismatch: expected {}, got {}",
            expected_value, value
        ))
        .into());
    }

    Ok(())
}

/// Validate QR code tag
pub fn validate_qr_code_tag(
    credentials: &ThpHandshakeCredentials,
    tag: &[u8],
    secret: &[u8],
) -> Result<()> {
    // Assert that tag = SHA-256(ThpPairingMethod.QrCode || h || secret)[0:16]
    let mut hasher = Sha256::new();
    hasher.update(&[ThpPairingMethod::QrCode as u8]);
    hasher.update(&credentials.handshake_hash);
    hasher.update(secret);

    let calculated_tag = hasher.finalize();

    if tag.len() < 16 || &calculated_tag[..16] != &tag[..16] {
        return Err(ThpError::PairingFailed("QR code tag mismatch".to_string()).into());
    }

    Ok(())
}

/// Validate NFC tag
pub fn validate_nfc_tag(
    credentials: &ThpHandshakeCredentials,
    tag: &[u8],
    nfc_secret: &[u8],
) -> Result<()> {
    // Assert that tag = SHA-256(ThpPairingMethod.NFC || h || secret)[0:16]
    let mut hasher = Sha256::new();
    hasher.update(&[ThpPairingMethod::Nfc as u8]);
    hasher.update(&credentials.handshake_hash);
    hasher.update(nfc_secret);

    let calculated_tag = hasher.finalize();

    if tag.len() < 16 || &calculated_tag[..16] != &tag[..16] {
        return Err(ThpError::PairingFailed("NFC tag mismatch".to_string()).into());
    }

    Ok(())
}

/// Create pairing credentials for storage
pub fn create_pairing_credentials(
    state: &ThpState,
    trezor_static_pubkey: &[u8],
    autoconnect: bool,
) -> Option<ThpCredentials> {
    let creds = state.handshake_credentials()?;

    Some(ThpCredentials {
        host_static_key: hex::encode(&creds.static_key),
        trezor_static_public_key: hex::encode(trezor_static_pubkey),
        credential: hex::encode(&creds.handshake_hash[..16]), // Use first 16 bytes as credential
        autoconnect,
    })
}

/// Find known pairing credentials that match the device
pub fn find_known_credentials<'a>(
    known_credentials: &'a [ThpCredentials],
    trezor_masked_static_pubkey: &[u8],
    trezor_ephemeral_pubkey: &[u8],
) -> Option<&'a ThpCredentials> {
    for cred in known_credentials {
        if let Ok(trezor_static) = hex::decode(&cred.trezor_static_public_key) {
            // Compute expected masked pubkey
            let h = hash_of_two(&trezor_static, trezor_ephemeral_pubkey);
            let trezor_pubkey: [u8; 32] = match trezor_static.try_into() {
                Ok(p) => p,
                Err(_) => continue,
            };
            let (secret, _) = keypair_from_secret(&h);
            let pubkey = x25519_dalek::PublicKey::from(trezor_pubkey);
            let expected_masked = x25519_dh(&secret, &pubkey);

            if expected_masked.as_slice() == trezor_masked_static_pubkey {
                return Some(cred);
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cpace_host_keys() {
        let code = b"123456";
        let handshake_hash = [0u8; 32];

        let keys = get_cpace_host_keys(code, &handshake_hash);

        assert_eq!(keys.private_key.len(), 32);
        assert_eq!(keys.public_key.len(), 32);
    }

    #[test]
    fn test_code_entry_bigint_modulo() {
        // Verify that full 256-bit modulo produces different (correct) results
        // than truncating to first 8 bytes.
        //
        // This hash is chosen so that bytes [8..32] contribute to the modulo result,
        // meaning the old bytes_to_u64_be approach would give the wrong answer.
        let hash: [u8; 32] = [
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // first 8 bytes = 0
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // remaining bytes are non-zero
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
            0xFF, 0xFF,
        ];

        // Old (wrong) approach: only uses first 8 bytes → 0 % 1_000_000 = 0
        let old_value = u64::from_be_bytes(hash[..8].try_into().unwrap()) % 1_000_000;
        assert_eq!(old_value, 0);

        // New (correct) approach: uses all 32 bytes
        let new_value: u64 = (BigUint::from_bytes_be(&hash) % BigUint::from(1_000_000u64))
            .try_into()
            .unwrap();

        // The full 256-bit value is 2^192 - 1 (24 bytes of 0xFF).
        // 2^192 - 1 mod 1_000_000 = 709551615... let's just verify it's NOT zero
        assert_ne!(
            new_value, 0,
            "Full 256-bit modulo should differ from 8-byte truncation"
        );
        assert!(
            new_value < 1_000_000,
            "Result should be a valid 6-digit code"
        );

        // Verify exact value: (2^192 - 1) mod 1_000_000 = 512895
        // (verified with Python: (2**192 - 1) % 1_000_000 == 512895)
        assert_eq!(new_value, 512895);
    }

    #[test]
    fn test_shared_secret() {
        let host_privkey: [u8; 32] = rand::random();
        let trezor_privkey: [u8; 32] = rand::random();

        let (_, host_pubkey) = keypair_from_secret(&host_privkey);
        let (_, trezor_pubkey) = keypair_from_secret(&trezor_privkey);

        let secret1 = get_shared_secret(&trezor_pubkey.to_bytes(), &host_privkey);
        let secret2 = get_shared_secret(&host_pubkey.to_bytes(), &trezor_privkey);

        // Due to SHA-256, both should be the same
        assert_eq!(secret1, secret2);
    }
}
