//! Dust threshold calculation.
//!
//! Determines the minimum output amount that is not considered "dust"
//! by Bitcoin Core relay policy.

use super::weight;
use crate::types::bitcoin::ScriptType;

/// Default dust threshold for Bitcoin (546 satoshis).
const DEFAULT_DUST_THRESHOLD: u64 = 546;

/// Default dust relay fee rate (3 sat/vB, Bitcoin Core default).
const DUST_RELAY_FEE_RATE: f64 = 3.0;

/// Calculate the dust amount for a given output script type and fee rate.
///
/// The dust amount is the maximum of:
/// - The network's dust threshold (546 sats)
/// - The cost to spend the output at the dust relay fee rate
///
/// The cost to spend considers the input weight needed to spend the output.
pub fn dust_amount(output_script_type: ScriptType, fee_rate: f64) -> u64 {
    let effective_rate = effective_dust_rate(fee_rate);
    let spend_weight = weight::input_weight(output_script_type);
    let spend_vbytes = weight::weight_to_vbytes(spend_weight) as f64;
    let spend_cost = (effective_rate * spend_vbytes).ceil() as u64;

    std::cmp::max(DEFAULT_DUST_THRESHOLD, spend_cost)
}

/// Calculate the effective dust relay fee rate.
///
/// Without `longTermFeeRate` support, this always returns DUST_RELAY_FEE_RATE (3 sat/vB),
/// matching Bitcoin Core's default dust relay fee. If `longTermFeeRate` is added in the
/// future, this should return: max(DUST_RELAY_FEE_RATE, min(fee_rate, long_term_fee_rate)).
fn effective_dust_rate(_fee_rate: f64) -> f64 {
    DUST_RELAY_FEE_RATE
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dust_amount_p2wpkh() {
        // At low fee rate, should return the default threshold
        let dust = dust_amount(ScriptType::SpendWitness, 1.0);
        assert_eq!(dust, DEFAULT_DUST_THRESHOLD);
    }

    #[test]
    fn test_dust_amount_p2pkh() {
        let dust = dust_amount(ScriptType::SpendAddress, 1.0);
        assert_eq!(dust, DEFAULT_DUST_THRESHOLD);
    }

    #[test]
    fn test_dust_amount_taproot() {
        let dust = dust_amount(ScriptType::SpendTaproot, 1.0);
        assert_eq!(dust, DEFAULT_DUST_THRESHOLD);
    }
}
