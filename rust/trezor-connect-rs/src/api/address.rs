//! Get Bitcoin address API.

use crate::error::Result;
use crate::types::bitcoin::ScriptType;

/// Parameters for get_address
#[derive(Debug, Clone)]
pub struct GetAddressParams {
    /// BIP32 derivation path
    pub path: String,
    /// Coin name
    pub coin: String,
    /// Show address on device
    pub show_on_trezor: bool,
    /// Script type
    pub script_type: ScriptType,
}

impl Default for GetAddressParams {
    fn default() -> Self {
        Self {
            path: "m/84'/0'/0'/0/0".to_string(),
            coin: "Bitcoin".to_string(),
            show_on_trezor: true,
            script_type: ScriptType::SpendWitness,
        }
    }
}

/// Response from get_address
#[derive(Debug, Clone)]
pub struct AddressResponse {
    /// Bitcoin address
    pub address: String,
    /// Derivation path as array
    pub path: Vec<u32>,
    /// Serialized path string
    pub serialized_path: String,
}

/// Get a Bitcoin address from the device.
///
/// **STUB**: This standalone function is not implemented. Use
/// [`ConnectedDevice::get_address()`](crate::connected_device::ConnectedDevice::get_address)
/// instead, which communicates with the actual device via the transport layer.
#[deprecated(note = "Use ConnectedDevice::get_address() instead")]
pub async fn get_address(_params: GetAddressParams) -> Result<AddressResponse> {
    Err(crate::error::TrezorError::NotImplemented(
        "api::get_address; use ConnectedDevice::get_address",
    ))
}
