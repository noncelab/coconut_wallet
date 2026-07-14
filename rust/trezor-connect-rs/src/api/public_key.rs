//! Get public key (xpub) API.

use crate::error::Result;
use crate::types::bitcoin::ScriptType;

/// Parameters for get_public_key
#[derive(Debug, Clone)]
pub struct GetPublicKeyParams {
    /// BIP32 derivation path
    pub path: String,
    /// Coin name
    pub coin: String,
    /// Show on device
    pub show_on_trezor: bool,
    /// Script type
    pub script_type: ScriptType,
}

impl Default for GetPublicKeyParams {
    fn default() -> Self {
        Self {
            path: "m/84'/0'/0'".to_string(),
            coin: "Bitcoin".to_string(),
            show_on_trezor: false,
            script_type: ScriptType::SpendWitness,
        }
    }
}

/// Response from get_public_key
#[derive(Debug, Clone)]
pub struct PublicKeyResponse {
    /// Public key in hex
    pub public_key: String,
    /// Extended public key
    pub xpub: String,
    /// SegWit xpub (if applicable)
    pub xpub_segwit: Option<String>,
    /// Chain code in hex
    pub chain_code: String,
    /// Fingerprint
    pub fingerprint: u32,
    /// Depth in BIP32 tree
    pub depth: u8,
    /// Child number
    pub child_num: u32,
    /// Derivation path
    pub path: Vec<u32>,
    /// Serialized path
    pub serialized_path: String,
    /// Master root fingerprint
    pub root_fingerprint: Option<u32>,
}

/// Get public key from the device.
///
/// **Not implemented**: this standalone function has no device connection.
/// Use [`ConnectedDevice::get_public_key()`](crate::connected_device::ConnectedDevice::get_public_key)
/// instead.
#[deprecated(note = "Use ConnectedDevice::get_public_key() instead")]
pub async fn get_public_key(_params: GetPublicKeyParams) -> Result<PublicKeyResponse> {
    Err(crate::error::TrezorError::NotImplemented(
        "api::get_public_key; use ConnectedDevice::get_public_key",
    ))
}
