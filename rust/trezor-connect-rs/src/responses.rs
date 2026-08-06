//! Response types for Trezor API methods.
//!
//! These types match the trezor-suite API patterns for consistency.

use serde::{Deserialize, Serialize};

/// Response from get_address.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AddressResponse {
    /// The derivation path as u32 indices
    pub path: Vec<u32>,
    /// The serialized path (e.g., "m/84'/0'/0'/0/0")
    pub serialized_path: String,
    /// The Bitcoin address
    pub address: String,
    /// Address authentication code (hex), used e.g. for SLIP-24 refund and
    /// coin-purchase memos. Only returned by supporting firmware.
    #[serde(default)]
    pub mac: Option<String>,
}

/// Response from get_public_key.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PublicKeyResponse {
    /// The derivation path as u32 indices
    pub path: Vec<u32>,
    /// The serialized path (e.g., "m/84'/0'/0'")
    pub serialized_path: String,
    /// Extended public key (xpub)
    pub xpub: String,
    /// Chain code (hex encoded)
    pub chain_code: String,
    /// Compressed public key (hex encoded)
    pub public_key: String,
    /// Depth in the derivation path
    pub depth: u32,
    /// Fingerprint of the parent key
    pub fingerprint: u32,
    /// Child number
    pub child_num: u32,
    /// Master root fingerprint (from the device's master seed)
    pub root_fingerprint: Option<u32>,
}

/// Response from sign_message.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignedMessageResponse {
    /// Bitcoin address that signed the message
    pub address: String,
    /// Signature (base64 encoded)
    pub signature: String,
}

/// Response from verify_message.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VerifyMessageResponse {
    /// Whether the signature is valid
    pub valid: bool,
}

impl VerifyMessageResponse {
    /// Create a valid response
    pub fn valid() -> Self {
        Self { valid: true }
    }

    /// Create an invalid response
    pub fn invalid() -> Self {
        Self { valid: false }
    }
}

/// Response from sign_tx.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignedTxResponse {
    /// Signatures for each input (hex encoded)
    pub signatures: Vec<String>,
    /// Serialized transaction (hex)
    pub serialized_tx: String,
    /// Transaction ID, computed locally from the verified signed transaction.
    /// `None` when serialization was disabled (`serialize: Some(false)`).
    pub txid: Option<String>,
    /// Per-input serialized witness data (hex), extracted from the verified
    /// signed transaction. `None` entries are non-witness inputs; the outer
    /// `None` means serialization was disabled.
    #[serde(default)]
    pub witnesses: Option<Vec<Option<String>>>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_address_response() {
        let response = AddressResponse {
            path: vec![0x80000054, 0x80000000, 0x80000000, 0, 0],
            serialized_path: "m/84'/0'/0'/0/0".into(),
            address: "bc1qtest".into(),
            mac: None,
        };
        assert_eq!(response.address, "bc1qtest");
    }

    #[test]
    fn test_verify_message_response() {
        assert!(VerifyMessageResponse::valid().valid);
        assert!(!VerifyMessageResponse::invalid().valid);
    }
}
