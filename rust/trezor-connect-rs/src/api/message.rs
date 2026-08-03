//! Sign and verify message API.

use crate::error::Result;

/// Parameters for sign_message
#[derive(Debug, Clone)]
pub struct SignMessageParams {
    /// Derivation path
    pub path: String,
    /// Message to sign
    pub message: String,
    /// Coin name
    pub coin: String,
}

/// Message signature response
#[derive(Debug, Clone)]
pub struct MessageSignature {
    /// Signing address
    pub address: String,
    /// Signature (base64)
    pub signature: String,
}

/// Parameters for verify_message
#[derive(Debug, Clone)]
pub struct VerifyMessageParams {
    /// Address to verify against
    pub address: String,
    /// Signature (base64)
    pub signature: String,
    /// Original message
    pub message: String,
    /// Coin name
    pub coin: String,
}

/// Sign a message.
///
/// **Not implemented**: this standalone function has no device connection.
/// Use [`ConnectedDevice::sign_message()`](crate::connected_device::ConnectedDevice::sign_message)
/// instead.
#[deprecated(note = "Use ConnectedDevice::sign_message() instead")]
pub async fn sign_message(_params: SignMessageParams) -> Result<MessageSignature> {
    Err(crate::error::TrezorError::NotImplemented(
        "api::sign_message; use ConnectedDevice::sign_message",
    ))
}

/// Verify a message signature.
///
/// **Not implemented**: this standalone function has no device connection.
/// Use [`ConnectedDevice::verify_message()`](crate::connected_device::ConnectedDevice::verify_message)
/// instead.
#[deprecated(note = "Use ConnectedDevice::verify_message() instead")]
pub async fn verify_message(_params: VerifyMessageParams) -> Result<bool> {
    Err(crate::error::TrezorError::NotImplemented(
        "api::verify_message; use ConnectedDevice::verify_message",
    ))
}
