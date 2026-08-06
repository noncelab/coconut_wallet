//! Split (send-max) coin selection algorithm.
//!
//! Includes all eligible UTXOs and assigns the remaining balance
//! (after fees and other outputs) to the send-max output.

use super::{CoinSelectInput, CoinSelectOutput, CoinSelectResult};
use crate::compose::{dust, weight};
use crate::types::bitcoin::ScriptType;

/// Minimum confirmations required for coinbase UTXOs.
const COINBASE_MIN_CONFIRMATIONS: u32 = 100;

/// Run the split (send-max) coin selection algorithm.
///
/// 1. Include all eligible UTXOs (filter coinbase < 100 confirmations)
/// 2. Calculate remaining = sum(inputs) - sum(specified_outputs) - fee
/// 3. Assign remaining to the send-max output
/// 4. Verify remaining >= dust_amount
pub fn split(
    inputs: &[CoinSelectInput],
    outputs: &[CoinSelectOutput],
    fee_rate: f64,
    base_fee: u64,
    change_script_type: ScriptType,
    confirmations: &[u32],
    coinbase_flags: &[bool],
) -> CoinSelectResult {
    // Select all eligible inputs
    let mut selected_indices: Vec<usize> = Vec::new();
    let mut selected_types: Vec<ScriptType> = Vec::new();
    let mut input_sum: u64 = 0;

    for (i, input) in inputs.iter().enumerate() {
        // Skip coinbase UTXOs with insufficient confirmations
        let is_coinbase = coinbase_flags.get(i).copied().unwrap_or(false);
        let confs = confirmations.get(i).copied().unwrap_or(0);
        if is_coinbase && confs < COINBASE_MIN_CONFIRMATIONS {
            continue;
        }

        selected_indices.push(input.index);
        selected_types.push(input.script_type);
        input_sum += input.amount;
    }

    if selected_indices.is_empty() {
        return CoinSelectResult::InsufficientFunds;
    }

    // Calculate output sum (excluding send-max outputs)
    let specified_sum: u64 = outputs
        .iter()
        .filter(|o| !o.is_send_max)
        .map(|o| o.amount)
        .sum();

    // All outputs including send-max for weight calculation
    let output_weights: Vec<usize> = outputs.iter().map(|o| o.weight).collect();

    // Calculate fee (weight-based + base_fee for RBF)
    let tx_weight = weight::transaction_weight(&selected_types, &output_weights);
    let fee = weight::calculate_fee(fee_rate, tx_weight) + base_fee;

    if input_sum < specified_sum + fee {
        return CoinSelectResult::InsufficientFunds;
    }

    let remaining = input_sum - specified_sum - fee;

    // Check if remaining is above dust
    let dust_threshold = dust::dust_amount(change_script_type, fee_rate);
    if remaining < dust_threshold {
        return CoinSelectResult::InsufficientFunds;
    }

    CoinSelectResult::SendMax {
        selected_inputs: selected_indices,
        max_amount: remaining,
        fee,
        weight: tx_weight,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::compose::weight::{input_weight, output_weight};

    fn make_input(index: usize, amount: u64) -> CoinSelectInput {
        CoinSelectInput {
            index,
            amount,
            script_type: ScriptType::SpendWitness,
            required: false,
            weight: input_weight(ScriptType::SpendWitness),
        }
    }

    #[test]
    fn test_split_basic() {
        let inputs = vec![make_input(0, 50_000), make_input(1, 80_000)];
        let outputs = vec![CoinSelectOutput {
            amount: 0, // send-max
            weight: output_weight(ScriptType::SpendWitness),
            is_send_max: true,
        }];
        let confs = vec![10, 10];
        let coinbase = vec![false, false];

        match split(
            &inputs,
            &outputs,
            10.0,
            0,
            ScriptType::SpendWitness,
            &confs,
            &coinbase,
        ) {
            CoinSelectResult::SendMax {
                max_amount,
                fee,
                selected_inputs,
                ..
            } => {
                assert_eq!(selected_inputs.len(), 2);
                assert!(max_amount > 0);
                assert_eq!(max_amount + fee, 130_000);
            }
            _ => panic!("Expected SendMax result"),
        }
    }

    #[test]
    fn test_split_filters_coinbase() {
        let inputs = vec![make_input(0, 50_000), make_input(1, 80_000)];
        let outputs = vec![CoinSelectOutput {
            amount: 0,
            weight: output_weight(ScriptType::SpendWitness),
            is_send_max: true,
        }];
        // Second input is coinbase with only 50 confirmations
        let confs = vec![10, 50];
        let coinbase = vec![false, true];

        match split(
            &inputs,
            &outputs,
            10.0,
            0,
            ScriptType::SpendWitness,
            &confs,
            &coinbase,
        ) {
            CoinSelectResult::SendMax {
                selected_inputs,
                max_amount,
                fee,
                ..
            } => {
                // Only first input should be selected
                assert_eq!(selected_inputs.len(), 1);
                assert_eq!(selected_inputs[0], 0);
                assert_eq!(max_amount + fee, 50_000);
            }
            _ => panic!("Expected SendMax result"),
        }
    }

    /// MEDIUM-1: Split should include ALL UTXOs for send-max, including small ones
    /// where the input fee exceeds their value. Send-max means sweep everything.
    #[test]
    fn test_split_includes_small_utxos() {
        let inputs = vec![
            make_input(0, 50_000),
            make_input(1, 80_000),
            make_input(2, 50), // Tiny UTXO — fee to spend exceeds value at 10 sat/vB
        ];
        let outputs = vec![CoinSelectOutput {
            amount: 0,
            weight: output_weight(ScriptType::SpendWitness),
            is_send_max: true,
        }];
        let confs = vec![10, 10, 10];
        let coinbase = vec![false, false, false];

        match split(
            &inputs,
            &outputs,
            10.0,
            0,
            ScriptType::SpendWitness,
            &confs,
            &coinbase,
        ) {
            CoinSelectResult::SendMax {
                selected_inputs,
                max_amount,
                fee,
                ..
            } => {
                // All 3 inputs should be included, even the tiny one
                assert_eq!(
                    selected_inputs.len(),
                    3,
                    "Send-max should include all UTXOs"
                );
                assert_eq!(
                    max_amount + fee,
                    130_050,
                    "Total should equal sum of all inputs"
                );
            }
            _ => panic!("Expected SendMax result"),
        }
    }

    #[test]
    fn test_split_insufficient() {
        let inputs = vec![make_input(0, 100)]; // Very small input
        let outputs = vec![CoinSelectOutput {
            amount: 0,
            weight: output_weight(ScriptType::SpendWitness),
            is_send_max: true,
        }];
        let confs = vec![10];
        let coinbase = vec![false];

        match split(
            &inputs,
            &outputs,
            100.0,
            0,
            ScriptType::SpendWitness,
            &confs,
            &coinbase,
        ) {
            CoinSelectResult::InsufficientFunds => {}
            _ => panic!("Expected insufficient funds"),
        }
    }
}
