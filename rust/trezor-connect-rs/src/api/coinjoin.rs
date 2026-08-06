//! CoinJoin authorization API.

use crate::error::Result;
use crate::types::bitcoin::ScriptType;

/// Parameters for authorize_coinjoin
#[derive(Debug, Clone)]
pub struct AuthorizeCoinJoinParams {
    /// Derivation path
    pub path: String,
    /// Coordinator URL
    pub coordinator: String,
    /// Maximum rounds
    pub max_rounds: u32,
    /// Maximum coordinator fee rate
    pub max_coordinator_fee_rate: u32,
    /// Maximum fee per kvB
    pub max_fee_per_kvbyte: u32,
    /// Coin name
    pub coin: String,
    /// Script type
    pub script_type: ScriptType,
}

/// Authorize a CoinJoin session.
///
/// **Not implemented**: the AuthorizeCoinJoin protobuf exists but no device
/// flow is wired up yet.
#[deprecated(note = "Not implemented; returns an error")]
pub async fn authorize_coinjoin(_params: AuthorizeCoinJoinParams) -> Result<()> {
    Err(crate::error::TrezorError::NotImplemented(
        "api::authorize_coinjoin",
    ))
}

/// Cancel CoinJoin authorization.
///
/// **Not implemented**: the CancelAuthorization protobuf exists but no device
/// flow is wired up yet.
#[deprecated(note = "Not implemented; returns an error")]
pub async fn cancel_coinjoin_authorization() -> Result<()> {
    Err(crate::error::TrezorError::NotImplemented(
        "api::cancel_coinjoin_authorization",
    ))
}

/// Parameters for get_ownership_id
#[derive(Debug, Clone)]
pub struct GetOwnershipIdParams {
    /// Derivation path
    pub path: String,
    /// Coin name
    pub coin: String,
    /// Script type
    pub script_type: ScriptType,
}

/// Ownership ID response
#[derive(Debug, Clone)]
pub struct OwnershipId {
    /// Ownership ID (hex)
    pub ownership_id: String,
}

/// Get ownership ID.
///
/// **Not implemented**: the GetOwnershipId protobuf exists but no device
/// flow is wired up yet.
#[deprecated(note = "Not implemented; returns an error")]
pub async fn get_ownership_id(_params: GetOwnershipIdParams) -> Result<OwnershipId> {
    Err(crate::error::TrezorError::NotImplemented(
        "api::get_ownership_id",
    ))
}

/// Parameters for get_ownership_proof
#[derive(Debug, Clone)]
pub struct GetOwnershipProofParams {
    /// Derivation path
    pub path: String,
    /// Coin name
    pub coin: String,
    /// Script type
    pub script_type: ScriptType,
    /// Commitment data
    pub commitment_data: Option<String>,
}

/// Ownership proof response
#[derive(Debug, Clone)]
pub struct OwnershipProof {
    /// Ownership proof (hex)
    pub ownership_proof: String,
}

/// Get ownership proof.
///
/// **Not implemented**: the GetOwnershipProof protobuf exists but no device
/// flow is wired up yet.
#[deprecated(note = "Not implemented; returns an error")]
pub async fn get_ownership_proof(_params: GetOwnershipProofParams) -> Result<OwnershipProof> {
    Err(crate::error::TrezorError::NotImplemented(
        "api::get_ownership_proof",
    ))
}
