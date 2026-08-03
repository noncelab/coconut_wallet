//! Coin selection algorithms.
//!
//! Routes to the appropriate algorithm based on transaction type:
//! - Send-max transactions use the `split` algorithm
//! - Regular transactions try Branch-and-Bound first, falling back to accumulative

pub mod accumulative;
pub mod bnb;
pub mod finalize;
pub mod split;

use crate::types::bitcoin::ScriptType;

/// Input for coin selection with pre-computed weight.
#[derive(Debug, Clone)]
pub struct CoinSelectInput {
    /// Original index in the input array
    pub index: usize,
    /// Amount in satoshis
    pub amount: u64,
    /// Script type of this input
    pub script_type: ScriptType,
    /// Whether this input must be included
    pub required: bool,
    /// Pre-computed input weight
    pub weight: usize,
}

/// Output for coin selection with pre-computed weight.
#[derive(Debug, Clone)]
pub struct CoinSelectOutput {
    /// Amount in satoshis (0 for send-max)
    pub amount: u64,
    /// Pre-computed output weight
    pub weight: usize,
    /// Whether this is a send-max output
    pub is_send_max: bool,
}

/// Result of coin selection.
#[derive(Debug, Clone)]
pub enum CoinSelectResult {
    /// Successfully selected inputs for a fixed-amount transaction.
    Success {
        /// Indices of selected inputs
        selected_inputs: Vec<usize>,
        /// Total fee in satoshis
        fee: u64,
        /// Change amount (0 if no change)
        change_amount: u64,
        /// Whether a change output was added
        has_change: bool,
        /// Total transaction weight
        weight: usize,
    },
    /// Successfully computed send-max amount.
    SendMax {
        /// Indices of selected inputs
        selected_inputs: Vec<usize>,
        /// Maximum sendable amount
        max_amount: u64,
        /// Total fee in satoshis
        fee: u64,
        /// Total transaction weight
        weight: usize,
    },
    /// Not enough funds to cover outputs + fees.
    InsufficientFunds,
}

/// Run coin selection with the appropriate algorithm.
///
/// For send-max outputs, uses the split algorithm.
/// For regular transactions, tries BnB first, then falls back to accumulative.
pub fn coinselect(
    inputs: &[CoinSelectInput],
    outputs: &[CoinSelectOutput],
    fee_rate: f64,
    base_fee: u64,
    change_script_type: ScriptType,
    confirmations: &[u32],
    coinbase_flags: &[bool],
) -> CoinSelectResult {
    let has_send_max = outputs.iter().any(|o| o.is_send_max);

    if has_send_max {
        return split::split(
            inputs,
            outputs,
            fee_rate,
            base_fee,
            change_script_type,
            confirmations,
            coinbase_flags,
        );
    }

    // Try BnB first for exact-match (no change output)
    if let Some(result) =
        bnb::branch_and_bound(inputs, outputs, fee_rate, base_fee, change_script_type)
    {
        return result;
    }

    // Fall back to accumulative (greedy)
    accumulative::accumulative(inputs, outputs, fee_rate, base_fee, change_script_type)
}
