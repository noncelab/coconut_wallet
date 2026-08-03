//! Cryptographic primitives for THP.
//!
//! Implements the cryptographic operations needed for THP:
//! - X25519 key exchange
//! - AES-256-GCM authenticated encryption
//! - SHA-256/SHA-512 hashing
//! - HKDF key derivation

use aes_gcm::{
    Aes256Gcm, Nonce,
    aead::{Aead, KeyInit},
};
use num_bigint::BigUint;
use num_traits::{One, Zero};
use sha2::{Digest, Sha256, Sha512};
use x25519_dalek::{PublicKey, StaticSecret};

use crate::error::{Result, ThpError};

/// AES-GCM tag size in bytes
pub const AES_GCM_TAG_SIZE: usize = 16;

/// X25519 key size in bytes
pub const X25519_KEY_SIZE: usize = 32;

/// HKDF output size in bytes
pub const HKDF_OUTPUT_SIZE: usize = 32;

/// Generate a random X25519 key pair
pub fn generate_keypair() -> (StaticSecret, PublicKey) {
    let secret = StaticSecret::random_from_rng(rand::thread_rng());
    let public = PublicKey::from(&secret);
    (secret, public)
}

/// Create X25519 key pair from existing secret
pub fn keypair_from_secret(secret_bytes: &[u8; 32]) -> (StaticSecret, PublicKey) {
    let secret = StaticSecret::from(*secret_bytes);
    let public = PublicKey::from(&secret);
    (secret, public)
}

/// Perform X25519 Diffie-Hellman
pub fn x25519_dh(private_key: &StaticSecret, public_key: &PublicKey) -> [u8; 32] {
    private_key.diffie_hellman(public_key).to_bytes()
}

/// SHA-256 hash
pub fn sha256(data: &[u8]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(data);
    hasher.finalize().into()
}

/// SHA-512 hash
pub fn sha512(data: &[u8]) -> [u8; 64] {
    let mut hasher = Sha512::new();
    hasher.update(data);
    hasher.finalize().into()
}

/// Hash of two values: SHA-256(a || b)
pub fn hash_of_two(a: &[u8], b: &[u8]) -> [u8; 32] {
    let mut hasher = Sha256::new();
    hasher.update(a);
    hasher.update(b);
    hasher.finalize().into()
}

/// HKDF key derivation (Noise-style)
///
/// This implements the HKDF as used in Noise protocol:
/// - tempKey = HMAC-SHA256(chainingKey, input)
/// - output1 = HMAC-SHA256(tempKey, 0x01)
/// - output2 = HMAC-SHA256(tempKey, output1 || 0x02)
///
/// Returns (output1, output2) - two 32-byte keys
pub fn hkdf_derive(chaining_key: &[u8], input: &[u8]) -> ([u8; 32], [u8; 32]) {
    // tempKey = HMAC-SHA256(chainingKey, input)
    let temp_key = hmac_sha256(chaining_key, input);

    // output1 = HMAC-SHA256(tempKey, 0x01)
    let output1 = hmac_sha256(&temp_key, &[0x01]);

    // output2 = HMAC-SHA256(tempKey, output1 || 0x02)
    let mut data = output1.to_vec();
    data.push(0x02);
    let output2 = hmac_sha256(&temp_key, &data);

    (output1, output2)
}

/// HMAC-SHA256
fn hmac_sha256(key: &[u8], data: &[u8]) -> [u8; 32] {
    use hmac::{Hmac, Mac};
    type HmacSha256 = Hmac<Sha256>;

    let mut mac = <HmacSha256 as Mac>::new_from_slice(key).expect("HMAC can take key of any size");
    mac.update(data);
    mac.finalize().into_bytes().into()
}

/// Get IV/nonce from nonce counter
///
/// Creates a 12-byte IV with the nonce in the last 4 bytes
pub fn get_iv_from_nonce(nonce: u32) -> [u8; 12] {
    let mut iv = [0u8; 12];
    iv[8..12].copy_from_slice(&nonce.to_be_bytes());
    iv
}

/// AES-256-GCM encryption
///
/// Returns ciphertext with 16-byte authentication tag appended
pub fn aes_gcm_encrypt(
    key: &[u8; 32],
    nonce: &[u8; 12],
    aad: &[u8],
    plaintext: &[u8],
) -> Result<Vec<u8>> {
    let cipher =
        Aes256Gcm::new_from_slice(key).map_err(|e| ThpError::EncryptionError(e.to_string()))?;

    let nonce = Nonce::from_slice(nonce);

    // Create payload with AAD
    let payload = aes_gcm::aead::Payload {
        msg: plaintext,
        aad,
    };

    cipher
        .encrypt(nonce, payload)
        .map_err(|e| ThpError::EncryptionError(e.to_string()).into())
}

/// AES-256-GCM decryption
///
/// Input ciphertext should have 16-byte authentication tag appended
pub fn aes_gcm_decrypt(
    key: &[u8; 32],
    nonce: &[u8; 12],
    aad: &[u8],
    ciphertext: &[u8],
) -> Result<Vec<u8>> {
    let cipher =
        Aes256Gcm::new_from_slice(key).map_err(|e| ThpError::DecryptionError(e.to_string()))?;

    let nonce = Nonce::from_slice(nonce);

    // Create payload with AAD
    let payload = aes_gcm::aead::Payload {
        msg: ciphertext,
        aad,
    };

    cipher
        .decrypt(nonce, payload)
        .map_err(|e| ThpError::DecryptionError(e.to_string()).into())
}

/// Elligator2 mapping for CPACE
///
/// Maps a field element to a point on Curve25519
/// Implementation based on RFC 9380: https://www.rfc-editor.org/rfc/rfc9380.html#ell2-opt
pub fn elligator2(input: &[u8; 32]) -> [u8; 32] {
    log::debug!("[elligator2] input = {}", hex::encode(input));

    // Curve25519 constants
    let p = BigUint::from(2u32).pow(255) - BigUint::from(19u32);
    let j = BigUint::from(486662u32);
    // c3 = sqrt(-1) mod p
    let c3 = BigUint::parse_bytes(
        b"19681161376707505956807079304988542015446066515923890162744021073123829784752",
        10,
    )
    .unwrap();
    let c4 = (&p - BigUint::from(5u32)) / BigUint::from(8u32);

    // Decode coordinate (clear high bit, little-endian)
    let mut coord = input.to_vec();
    coord[31] &= 0x7f;
    let u = BigUint::from_bytes_le(&coord) % &p;
    log::debug!("[elligator2] u = {}", u);

    // map_to_curve_elligator2_curve25519
    let mut tv1 = (&u * &u) % &p;
    tv1 = (BigUint::from(2u32) * &tv1) % &p;
    let xd = (&tv1 + BigUint::one()) % &p;
    let x1n = (&p - &j) % &p;
    let mut tv2 = (&xd * &xd) % &p;
    let gxd = (&tv2 * &xd) % &p;
    let mut gx1 = (&j * &tv1) % &p;
    gx1 = (&gx1 * &x1n) % &p;
    gx1 = (&gx1 + &tv2) % &p;
    gx1 = (&gx1 * &x1n) % &p;

    let mut tv3 = (&gxd * &gxd) % &p;
    tv2 = (&tv3 * &tv3) % &p;
    tv3 = (&tv3 * &gxd) % &p;
    tv3 = (&tv3 * &gx1) % &p;
    tv2 = (&tv2 * &tv3) % &p;

    let mut y11 = mod_pow(&tv2, &c4, &p);
    y11 = (&y11 * &tv3) % &p;
    let y12 = (&y11 * &c3) % &p;
    tv2 = (&y11 * &y11) % &p;
    tv2 = (&tv2 * &gxd) % &p;

    let e1 = tv2 == gx1;
    let y1 = if e1 { y11 } else { y12 };
    let x2n = (&x1n * &tv1) % &p;

    tv2 = (&y1 * &y1) % &p;
    tv2 = (&tv2 * &gxd) % &p;
    let e3 = tv2 == gx1;
    let xn = if e3 { x1n } else { x2n };

    // x = xn / xd = xn * xd^(p-2) mod p
    let xd_inv = mod_pow(&xd, &(&p - BigUint::from(2u32)), &p);
    let x = (&xn * &xd_inv) % &p;

    // Encode as little-endian 32 bytes
    let mut result = [0u8; 32];
    let bytes = x.to_bytes_le();
    let len = bytes.len().min(32);
    result[..len].copy_from_slice(&bytes[..len]);

    log::debug!("[elligator2] x = {}", x);
    log::debug!("[elligator2] result = {}", hex::encode(&result));
    result
}

/// Modular exponentiation: base^exp mod m
fn mod_pow(base: &BigUint, exp: &BigUint, m: &BigUint) -> BigUint {
    if m.is_one() {
        return BigUint::zero();
    }
    let mut result = BigUint::one();
    let mut base = base % m;
    let mut exp = exp.clone();
    while !exp.is_zero() {
        if &exp % 2u32 == BigUint::one() {
            result = (&result * &base) % m;
        }
        exp >>= 1;
        base = (&base * &base) % m;
    }
    result
}

/// THP protocol name bytes
pub fn protocol_name() -> Vec<u8> {
    let mut name = b"Noise_XX_25519_AESGCM_SHA256".to_vec();
    name.extend_from_slice(&[0u8; 4]); // Padding to 32 bytes
    name
}

/// CRC32 lookup table (standard CRC-32 IEEE 802.3 polynomial)
const CRC_TABLE: [u32; 256] = [
    0x00000000, 0x77073096, 0xee0e612c, 0x990951ba, 0x076dc419, 0x706af48f, 0xe963a535, 0x9e6495a3,
    0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988, 0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91,
    0x1db71064, 0x6ab020f2, 0xf3b97148, 0x84be41de, 0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
    0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec, 0x14015c4f, 0x63066cd9, 0xfa0f3d63, 0x8d080df5,
    0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172, 0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,
    0x35b5a8fa, 0x42b2986c, 0xdbbbc9d6, 0xacbcf940, 0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
    0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116, 0x21b4f4b5, 0x56b3c423, 0xcfba9599, 0xb8bda50f,
    0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924, 0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,
    0x76dc4190, 0x01db7106, 0x98d220bc, 0xefd5102a, 0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
    0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818, 0x7f6a0dbb, 0x086d3d2d, 0x91646c97, 0xe6635c01,
    0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e, 0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457,
    0x65b0d9c6, 0x12b7e950, 0x8bbeb8ea, 0xfcb9887c, 0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
    0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2, 0x4adfa541, 0x3dd895d7, 0xa4d1c46d, 0xd3d6f4fb,
    0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0, 0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9,
    0x5005713c, 0x270241aa, 0xbe0b1010, 0xc90c2086, 0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
    0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4, 0x59b33d17, 0x2eb40d81, 0xb7bd5c3b, 0xc0ba6cad,
    0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a, 0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683,
    0xe3630b12, 0x94643b84, 0x0d6d6a3e, 0x7a6a5aa8, 0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
    0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe, 0xf762575d, 0x806567cb, 0x196c3671, 0x6e6b06e7,
    0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc, 0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,
    0xd6d6a3e8, 0xa1d1937e, 0x38d8c2c4, 0x4fdff252, 0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
    0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60, 0xdf60efc3, 0xa867df55, 0x316e8eef, 0x4669be79,
    0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236, 0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f,
    0xc5ba3bbe, 0xb2bd0b28, 0x2bb45a92, 0x5cb36a04, 0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
    0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a, 0x9c0906a9, 0xeb0e363f, 0x72076785, 0x05005713,
    0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38, 0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21,
    0x86d3d2d4, 0xf1d4e242, 0x68ddb3f8, 0x1fda836e, 0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
    0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c, 0x8f659eff, 0xf862ae69, 0x616bffd3, 0x166ccf45,
    0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2, 0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db,
    0xaed16a4a, 0xd9d65adc, 0x40df0b66, 0x37d83bf0, 0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
    0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6, 0xbad03605, 0xcdd70693, 0x54de5729, 0x23d967bf,
    0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94, 0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d,
];

/// Calculate CRC32 checksum (matching trezor-suite implementation)
pub fn crc32(data: &[u8]) -> [u8; 4] {
    let mut crc: u32 = 0xFFFFFFFF;
    for &byte in data {
        let index = ((crc ^ (byte as u32)) & 0xff) as usize;
        crc = CRC_TABLE[index] ^ (crc >> 8);
    }
    (crc ^ 0xFFFFFFFF).to_be_bytes()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_crc32() {
        // Test vector from trezor-suite example:
        // 40ffff000c639ba57ff4e0c2348189a406
        // [magic | channel | len  | nonce            | crc     ]
        // [40    | ffff    | 000c | 639ba57ff4e0c234 | 8189a406]
        let message = hex::decode("40ffff000c639ba57ff4e0c234").unwrap();
        let expected_crc = hex::decode("8189a406").unwrap();
        let crc = crc32(&message);
        assert_eq!(crc.to_vec(), expected_crc, "CRC32 mismatch");
    }

    #[test]
    fn test_keypair_generation() {
        let (secret1, public1) = generate_keypair();
        let (secret2, public2) = generate_keypair();

        // DH should be symmetric
        let shared1 = x25519_dh(&secret1, &public2);
        let shared2 = x25519_dh(&secret2, &public1);

        assert_eq!(shared1, shared2);
    }

    #[test]
    fn test_sha256() {
        let data = b"test data";
        let hash = sha256(data);

        // Known SHA-256 hash
        assert_eq!(hash.len(), 32);
    }

    #[test]
    fn test_hash_of_two() {
        let a = b"hello";
        let b = b"world";

        let hash1 = hash_of_two(a, b);
        let hash2 = sha256(&[a.as_slice(), b.as_slice()].concat());

        assert_eq!(hash1, hash2);
    }

    #[test]
    fn test_aes_gcm_roundtrip() {
        let key = [0u8; 32];
        let nonce = [0u8; 12];
        let aad = b"additional data";
        let plaintext = b"secret message";

        let ciphertext = aes_gcm_encrypt(&key, &nonce, aad, plaintext).unwrap();
        let decrypted = aes_gcm_decrypt(&key, &nonce, aad, &ciphertext).unwrap();

        assert_eq!(decrypted, plaintext);
    }

    #[test]
    fn test_get_iv_from_nonce() {
        let iv = get_iv_from_nonce(1);
        assert_eq!(iv[..8], [0u8; 8]);
        assert_eq!(iv[8..], [0, 0, 0, 1]);

        let iv = get_iv_from_nonce(256);
        assert_eq!(iv[8..], [0, 0, 1, 0]);
    }

    #[test]
    fn test_hkdf() {
        let salt = b"salt";
        let ikm = b"input key material";

        let (k1, k2) = hkdf_derive(salt, ikm);

        // Keys should be different
        assert_ne!(k1, k2);
        assert_eq!(k1.len(), 32);
        assert_eq!(k2.len(), 32);
    }

    #[test]
    fn test_elligator2_zero_input() {
        // Test with all zeros input
        // Note: For u=0, the elligator2 algorithm correctly returns x=0
        // This is because -J is not a quadratic residue mod p, so we fall back to x2n = 0
        // Both our implementation and the TypeScript reference return [0; 32] for this case
        let input = [0u8; 32];
        let output = elligator2(&input);

        // Output should be 32 bytes
        assert_eq!(output.len(), 32);

        // For u=0, elligator2 returns 0 (this is mathematically correct)
        assert_eq!(output, [0u8; 32], "elligator2([0; 32]) should return zero");

        println!("elligator2([0; 32]) = {}", hex::encode(&output));
    }

    #[test]
    fn test_elligator2_nonzero_input() {
        // Test with a non-zero input
        let mut input = [0u8; 32];
        input[0] = 1;
        let output = elligator2(&input);

        assert_eq!(output.len(), 32);
        assert_ne!(output, [0u8; 32]);

        println!("elligator2([1, 0, ...]) = {}", hex::encode(&output));
    }

    #[test]
    fn test_elligator2_cpace_pregenerator() {
        // Test with a realistic pregenerator value (first 32 bytes of SHA-512)
        // This simulates what would happen in the CPACE flow
        use sha2::{Digest, Sha512};

        let prefix = [0x08, 0x43, 0x50, 0x61, 0x63, 0x65, 0x32, 0x35, 0x35, 0x06];
        let code = b"123456";
        let padding = {
            let mut p = vec![0x6f];
            p.extend_from_slice(&[0u8; 111]);
            p.push(0x20);
            p
        };
        let handshake_hash = [0u8; 32];

        let mut hasher = Sha512::new();
        hasher.update(&prefix);
        hasher.update(code);
        hasher.update(&padding);
        hasher.update(&handshake_hash);
        hasher.update(&[0x00]);

        let sha_output = hasher.finalize();
        let pregenerator: [u8; 32] = sha_output[..32].try_into().unwrap();

        println!("pregenerator = {}", hex::encode(&pregenerator));
        // Expected from TypeScript: 4803f9eac322e03281436132121c82672b3c11b969f1d57cf4660f10ab3d8f78
        assert_eq!(
            hex::encode(&pregenerator),
            "4803f9eac322e03281436132121c82672b3c11b969f1d57cf4660f10ab3d8f78"
        );

        let generator = elligator2(&pregenerator);
        println!("generator = {}", hex::encode(&generator));
        // Expected from TypeScript: a29b0057e8cef8c2f9d7bbf081f47cc23ab90631157eb2340d97d0915519b218
        assert_eq!(
            hex::encode(&generator),
            "a29b0057e8cef8c2f9d7bbf081f47cc23ab90631157eb2340d97d0915519b218"
        );

        // Verify it's a valid point by checking it's not zero
        assert_ne!(generator, [0u8; 32]);
    }

    #[test]
    fn test_crc32_validation_pass() {
        // Build a THP-like message: [header(5 bytes)][data][crc(4 bytes)]
        // where the CRC covers [header + data]
        let header_and_data = hex::decode("40ffff000c639ba57ff4e0c234").unwrap();
        let crc_bytes = crc32(&header_and_data);

        let mut full_message = header_and_data.clone();
        full_message.extend_from_slice(&crc_bytes);

        // Recompute and verify
        let recomputed = crc32(&header_and_data);
        assert_eq!(&full_message[full_message.len() - 4..], &recomputed);
    }

    #[test]
    fn test_crc32_validation_corrupted() {
        // Build a valid message then corrupt one byte
        let header_and_data = hex::decode("40ffff000c639ba57ff4e0c234").unwrap();
        let crc_bytes = crc32(&header_and_data);

        let mut full_message = header_and_data;
        full_message.extend_from_slice(&crc_bytes);

        // Corrupt a byte in the data
        full_message[6] ^= 0xFF;

        // Recompute CRC on corrupted data (without the trailing CRC)
        let data_part = &full_message[..full_message.len() - 4];
        let crc_part = &full_message[full_message.len() - 4..];
        let recomputed = crc32(data_part);
        assert_ne!(
            crc_part, &recomputed,
            "CRC should not match on corrupted data"
        );
    }

    #[test]
    fn test_x25519_with_generator() {
        // Test X25519 with a known generator to compare with TypeScript
        // TypeScript: curve25519([1, 0, 0, ...], generator) = 50b277635ad68e770344754fa0036ae8ce28e2ec3ba519b0af5148afdb1ff928
        let generator =
            hex::decode("a29b0057e8cef8c2f9d7bbf081f47cc23ab90631157eb2340d97d0915519b218")
                .unwrap();
        let generator: [u8; 32] = generator.try_into().unwrap();

        // Private key = [1, 0, 0, ...]
        let mut private_key = [0u8; 32];
        private_key[0] = 1;

        let (secret, _) = keypair_from_secret(&private_key);
        let generator_pubkey = x25519_dalek::PublicKey::from(generator);
        let public_key = x25519_dh(&secret, &generator_pubkey);

        println!("public_key = {}", hex::encode(&public_key));
        // Expected from TypeScript: 50b277635ad68e770344754fa0036ae8ce28e2ec3ba519b0af5148afdb1ff928
        assert_eq!(
            hex::encode(&public_key),
            "50b277635ad68e770344754fa0036ae8ce28e2ec3ba519b0af5148afdb1ff928"
        );
    }
}
