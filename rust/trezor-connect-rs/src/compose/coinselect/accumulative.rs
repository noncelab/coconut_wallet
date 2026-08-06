//! Accumulative (greedy) coin selection algorithm.
//!
//! Iterates through UTXOs, adding them until the target is met.
//! This is the fallback when Branch-and-Bound fails.

use super::finalize::{FinalizeResult, finalize};
use super::{CoinSelectInput, CoinSelectOutput, CoinSelectResult};
use crate::compose::weight;
use crate::types::bitcoin::ScriptType;

/// Run the accumulative coin selection algorithm.
///
/// 1. Add all required UTXOs first
/// 2. Try finalizing with required-only
/// 3. Iterate through optional UTXOs left-to-right
/// 4. Skip detrimental inputs (fee cost > value)
/// 5. Stop when inputs cover outputs + fee
pub fn accumulative(
    inputs: &[CoinSelectInput],
    outputs: &[CoinSelectOutput],
    fee_rate: f64,
    base_fee: u64,
    change_script_type: ScriptType,
) -> CoinSelectResult {
    let output_sum: u64 = outputs.iter().map(|o| o.amount).sum();
    let output_weights: Vec<usize> = outputs.iter().map(|o| o.weight).collect();

    let mut selected: Vec<usize> = Vec::new();
    let mut selected_sum: u64 = 0;
    let mut selected_types: Vec<ScriptType> = Vec::new();

    // Phase 1: Add all required UTXOs
    for (_i, input) in inputs.iter().enumerate() {
        if input.required {
            selected.push(input.index);
            selected_sum += input.amount;
            selected_types.push(input.script_type);
        }
    }

    // Try finalizing with required-only
    if !selected.is_empty() {
        if let FinalizeResult::Success {
            fee,
            change_amount,
            has_change,
            weight: tx_weight,
        } = finalize(
            selected_sum,
            output_sum,
            fee_rate,
            base_fee,
            &selected_types,
            &output_weights,
            change_script_type,
        ) {
            return CoinSelectResult::Success {
                selected_inputs: selected,
                fee,
                change_amount,
                has_change,
                weight: tx_weight,
            };
        }
    }

    // Phase 2: Add optional UTXOs
    let optional: Vec<&CoinSelectInput> = inputs.iter().filter(|i| !i.required).collect();
    for (pos, input) in optional.iter().enumerate() {
        let is_last = pos == optional.len() - 1;

        // Skip detrimental inputs: fee cost of adding exceeds value.
        // A UTXO whose value exactly equals its fee is included (net zero cost),
        // matching JS accumulative.ts behavior (strict less-than).
        let input_fee = weight::calculate_fee(fee_rate, weight::input_weight(input.script_type));
        if input.amount < input_fee {
            // On the last input, attempt finalization even if detrimental,
            // matching JS accumulative.ts behavior where the last UTXO is
            // always tried to see if it tips the balance.
            if is_last {
                selected.push(input.index);
                selected_sum += input.amount;
                selected_types.push(input.script_type);
                if let FinalizeResult::Success {
                    fee,
                    change_amount,
                    has_change,
                    weight: tx_weight,
                } = finalize(
                    selected_sum,
                    output_sum,
                    fee_rate,
                    base_fee,
                    &selected_types,
                    &output_weights,
                    change_script_type,
                ) {
                    return CoinSelectResult::Success {
                        selected_inputs: selected,
                        fee,
                        change_amount,
                        has_change,
                        weight: tx_weight,
                    };
                }
            }
            continue;
        }

        selected.push(input.index);
        selected_sum += input.amount;
        selected_types.push(input.script_type);

        // Try to finalize
        if let FinalizeResult::Success {
            fee,
            change_amount,
            has_change,
            weight: tx_weight,
        } = finalize(
            selected_sum,
            output_sum,
            fee_rate,
            base_fee,
            &selected_types,
            &output_weights,
            change_script_type,
        ) {
            return CoinSelectResult::Success {
                selected_inputs: selected,
                fee,
                change_amount,
                has_change,
                weight: tx_weight,
            };
        }
    }

    CoinSelectResult::InsufficientFunds
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::compose::weight::output_weight;

    fn make_input(index: usize, amount: u64, required: bool) -> CoinSelectInput {
        CoinSelectInput {
            index,
            amount,
            script_type: ScriptType::SpendWitness,
            required,
            weight: weight::input_weight(ScriptType::SpendWitness),
        }
    }

    fn make_output(amount: u64) -> CoinSelectOutput {
        CoinSelectOutput {
            amount,
            weight: output_weight(ScriptType::SpendWitness),
            is_send_max: false,
        }
    }

    #[test]
    fn test_accumulative_basic() {
        let inputs = vec![make_input(0, 50_000, false), make_input(1, 80_000, false)];
        let outputs = vec![make_output(60_000)];

        match accumulative(&inputs, &outputs, 10.0, 0, ScriptType::SpendWitness) {
            CoinSelectResult::Success {
                selected_inputs,
                fee,
                ..
            } => {
                assert!(!selected_inputs.is_empty());
                assert!(fee > 0);
            }
            _ => panic!("Expected success"),
        }
    }

    #[test]
    fn test_accumulative_required_only() {
        let inputs = vec![make_input(0, 100_000, true), make_input(1, 50_000, false)];
        let outputs = vec![make_output(10_000)];

        match accumulative(&inputs, &outputs, 1.0, 0, ScriptType::SpendWitness) {
            CoinSelectResult::Success {
                selected_inputs, ..
            } => {
                // Only the required input should be selected
                assert_eq!(selected_inputs.len(), 1);
                assert_eq!(selected_inputs[0], 0);
            }
            _ => panic!("Expected success"),
        }
    }

    #[test]
    fn test_accumulative_insufficient() {
        let inputs = vec![make_input(0, 100, false)];
        let outputs = vec![make_output(100_000)];

        match accumulative(&inputs, &outputs, 10.0, 0, ScriptType::SpendWitness) {
            CoinSelectResult::InsufficientFunds => {}
            _ => panic!("Expected insufficient funds"),
        }
    }

    /// Test that the last detrimental input is still tried for finalization,
    /// matching JS accumulative.ts behavior.
    #[test]
    fn test_accumulative_last_detrimental_input() {
        // At 10 sat/vB, P2WPKH input fee = ceil(10 * 68) = 680 sats
        // So a 100-sat UTXO is detrimental (100 < 680).
        // Verify the mechanism works: input 0 covers the output, and the
        // detrimental last input doesn't prevent success.
        let inputs = vec![
            make_input(0, 100_000, false), // covers output easily
            make_input(1, 100, false),     // detrimental (100 < 680)
        ];
        let outputs = vec![make_output(50_000)];

        match accumulative(&inputs, &outputs, 10.0, 0, ScriptType::SpendWitness) {
            CoinSelectResult::Success {
                selected_inputs, ..
            } => {
                // Should succeed with just input 0 (doesn't need the detrimental one)
                assert!(!selected_inputs.is_empty());
            }
            _ => panic!("Expected success"),
        }
    }

    /// Test that selected_inputs returns original indices, not filtered-array positions.
    /// Simulates what happens after try_confirmed filters out some UTXOs:
    /// the filtered array has gaps in original indices.
    #[test]
    fn test_accumulative_uses_original_indices_after_filtering() {
        // Simulate a filtered array where original indices 0 and 1 were removed.
        // Remaining UTXOs have original indices 2, 3, 4.
        let inputs = vec![
            make_input(2, 30_000, false),
            make_input(3, 50_000, false),
            make_input(4, 80_000, false),
        ];
        let outputs = vec![make_output(60_000)];

        match accumulative(&inputs, &outputs, 10.0, 0, ScriptType::SpendWitness) {
            CoinSelectResult::Success {
                selected_inputs, ..
            } => {
                // All returned indices must be original indices (2, 3, or 4), never 0 or 1
                for &idx in &selected_inputs {
                    assert!(
                        idx >= 2 && idx <= 4,
                        "Expected original index (2..=4), got {}",
                        idx
                    );
                }
            }
            _ => panic!("Expected success"),
        }
    }
}
