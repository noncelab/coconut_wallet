//! Finalize coin selection: determine if a change output should be added.
//!
//! After selecting UTXOs that cover the target, this module determines whether
//! to add a change output or absorb the remainder into fees.

use crate::compose::{dust, weight};
use crate::types::bitcoin::ScriptType;

/// Result of finalization.
#[derive(Debug, Clone)]
pub enum FinalizeResult {
    /// Transaction is finalized with these parameters.
    Success {
        /// Total fee in satoshis
        fee: u64,
        /// Change amount (0 if no change output)
        change_amount: u64,
        /// Whether a change output was added
        has_change: bool,
        /// Total transaction weight
        weight: usize,
    },
    /// Not enough funds to cover outputs + fee.
    InsufficientFunds,
}

/// Finalize a coin selection by deciding whether to add a change output.
///
/// # Arguments
/// * `input_sum` - Total value of selected inputs
/// * `output_sum` - Total value of non-change outputs
/// * `fee_rate` - Fee rate in sat/vB
/// * `base_fee` - Base fee in satoshis added to calculated fee (e.g. for RBF)
/// * `input_types` - Script types of selected inputs
/// * `output_weights` - Weights of non-change outputs
/// * `change_script_type` - Script type for the potential change output
pub fn finalize(
    input_sum: u64,
    output_sum: u64,
    fee_rate: f64,
    base_fee: u64,
    input_types: &[ScriptType],
    output_weights: &[usize],
    change_script_type: ScriptType,
) -> FinalizeResult {
    // Calculate fee without change output
    let weight_no_change = weight::transaction_weight(input_types, output_weights);
    let fee_no_change = weight::calculate_fee(fee_rate, weight_no_change) + base_fee;

    if input_sum < output_sum + fee_no_change {
        return FinalizeResult::InsufficientFunds;
    }

    let _remainder = input_sum - output_sum - fee_no_change;

    // Calculate fee with a change output
    let change_weight = weight::change_output_weight(change_script_type);
    let mut output_weights_with_change = output_weights.to_vec();
    output_weights_with_change.push(change_weight);
    let weight_with_change = weight::transaction_weight(input_types, &output_weights_with_change);
    let fee_with_change = weight::calculate_fee(fee_rate, weight_with_change) + base_fee;

    if input_sum < output_sum + fee_with_change {
        // Can't afford the change output, remainder goes to fees
        return FinalizeResult::Success {
            fee: input_sum - output_sum,
            change_amount: 0,
            has_change: false,
            weight: weight_no_change,
        };
    }

    let change_amount = input_sum - output_sum - fee_with_change;
    let dust_threshold = dust::dust_amount(change_script_type, fee_rate);

    if change_amount >= dust_threshold {
        // Add change output
        FinalizeResult::Success {
            fee: fee_with_change,
            change_amount,
            has_change: true,
            weight: weight_with_change,
        }
    } else {
        // Change is dust, absorb into fee
        FinalizeResult::Success {
            fee: input_sum - output_sum,
            change_amount: 0,
            has_change: false,
            weight: weight_no_change,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::compose::weight::output_weight;

    #[test]
    fn test_finalize_with_change() {
        // 100,000 input, 50,000 output, 10 sat/vB
        let input_types = vec![ScriptType::SpendWitness];
        let output_weights = vec![output_weight(ScriptType::SpendWitness)];

        match finalize(
            100_000,
            50_000,
            10.0,
            0,
            &input_types,
            &output_weights,
            ScriptType::SpendWitness,
        ) {
            FinalizeResult::Success {
                fee,
                change_amount,
                has_change,
                ..
            } => {
                assert!(has_change);
                assert!(change_amount > 0);
                assert_eq!(fee + change_amount + 50_000, 100_000);
            }
            _ => panic!("Expected success with change"),
        }
    }

    #[test]
    fn test_finalize_dust_change() {
        // Input barely covers output + fee, change would be dust
        let input_types = vec![ScriptType::SpendWitness];
        let output_weights = vec![output_weight(ScriptType::SpendWitness)];

        // Calculate the exact fee so we can set input_sum to create dust change
        let w = weight::transaction_weight(&input_types, &output_weights);
        let fee = weight::calculate_fee(10.0, w);
        let input_sum = 50_000 + fee + 100; // 100 sat change = dust

        match finalize(
            input_sum,
            50_000,
            10.0,
            0,
            &input_types,
            &output_weights,
            ScriptType::SpendWitness,
        ) {
            FinalizeResult::Success {
                has_change,
                change_amount,
                ..
            } => {
                assert!(!has_change);
                assert_eq!(change_amount, 0);
            }
            _ => panic!("Expected success without change"),
        }
    }

    #[test]
    fn test_finalize_insufficient_funds() {
        let input_types = vec![ScriptType::SpendWitness];
        let output_weights = vec![output_weight(ScriptType::SpendWitness)];

        match finalize(
            1_000,
            50_000,
            10.0,
            0,
            &input_types,
            &output_weights,
            ScriptType::SpendWitness,
        ) {
            FinalizeResult::InsufficientFunds => {}
            _ => panic!("Expected insufficient funds"),
        }
    }
}
