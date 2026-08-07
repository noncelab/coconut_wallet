//! Get account info API.

use crate::error::Result;

/// Parameters for get_account_info
#[derive(Debug, Clone)]
pub struct GetAccountInfoParams {
    /// Coin name
    pub coin: String,
    /// Derivation path (optional)
    pub path: Option<String>,
    /// Descriptor (optional)
    pub descriptor: Option<String>,
}

/// UTXO (unspent transaction output)
#[derive(Debug, Clone)]
pub struct Utxo {
    /// Transaction hash
    pub txid: String,
    /// Output index
    pub vout: u32,
    /// Amount in satoshis
    pub amount: u64,
    /// Block height (None if unconfirmed)
    pub height: Option<u32>,
    /// Derivation path
    pub path: String,
}

/// Account information response
#[derive(Debug, Clone)]
pub struct AccountInfo {
    /// Account descriptor
    pub descriptor: String,
    /// Legacy xpub
    pub legacy_xpub: Option<String>,
    /// Balance in satoshis
    pub balance: u64,
    /// Unconfirmed balance
    pub unconfirmed_balance: u64,
    /// UTXOs
    pub utxos: Vec<Utxo>,
    /// Derivation path
    pub path: Option<String>,
}

/// Get account information.
///
/// **Not implemented**: this crate has no blockchain backend. Account data
/// (balances, UTXOs) must be fetched by the caller from their own chain
/// source (e.g. Electrum or Blockbook).
#[deprecated(note = "No blockchain backend in this crate; fetch account data externally")]
pub async fn get_account_info(_params: GetAccountInfoParams) -> Result<AccountInfo> {
    Err(crate::error::TrezorError::NotImplemented(
        "api::get_account_info; this crate has no blockchain backend",
    ))
}
