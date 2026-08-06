//! Push/broadcast transaction API.

use crate::error::Result;

/// Parameters for push_transaction
#[derive(Debug, Clone)]
pub struct PushTransactionParams {
    /// Signed transaction hex
    pub tx: String,
    /// Coin name
    pub coin: String,
}

/// Push transaction response
#[derive(Debug, Clone)]
pub struct PushedTransaction {
    /// Transaction ID
    pub txid: String,
}

/// Push a transaction to the network.
///
/// **Not implemented**: this crate has no blockchain backend. Broadcast the
/// signed transaction through your own chain source (e.g. Electrum or
/// Blockbook).
#[deprecated(note = "No blockchain backend in this crate; broadcast externally")]
pub async fn push_transaction(_params: PushTransactionParams) -> Result<PushedTransaction> {
    Err(crate::error::TrezorError::NotImplemented(
        "api::push_transaction; this crate has no blockchain backend",
    ))
}
