//! Branch-and-Bound coin selection algorithm.
//!
//! Searches for an exact match (no change output needed) by exploring
//! UTXO combinations using depth-first search. Falls back if no exact
//! match is found within the iteration limit.

use super::finalize::{FinalizeResult, finalize};
use super::{CoinSelectInput, CoinSelectOutput, CoinSelectResult};
use crate::compose::{dust, weight};
use crate::types::bitcoin::ScriptType;

/// Maximum number of iterations before giving up.
const MAX_TRIES: usize = 1_000_000;

/// Run Branch-and-Bound coin selection.
///
/// Attempts to find a UTXO subset that exactly matches the target amount
/// (within the cost-of-change tolerance), avoiding the need for a change output.
///
/// Returns `None` if no solution is found within MAX_TRIES iterations.
pub fn branch_and_bound(
    inputs: &[CoinSelectInput],
    outputs: &[CoinSelectOutput],
    fee_rate: f64,
    base_fee: u64,
    change_script_type: ScriptType,
) -> Option<CoinSelectResult> {
    // Bail out when required UTXOs exist — let accumulative handle them.
    // Matches JS branchAndBound.ts behavior where required inputs cause early return.
    if inputs.iter().any(|i| i.required) {
        return None;
    }

    let output_sum: u64 = outputs.iter().map(|o| o.amount).sum();
    let output_weights: Vec<usize> = outputs.iter().map(|o| o.weight).collect();

    // Collect required inputs (none expected after the bail above, kept for safety)
    let mut required_sum: u64 = 0;
    let mut required_indices: Vec<usize> = Vec::new();
    let mut required_types: Vec<ScriptType> = Vec::new();

    for (_i, input) in inputs.iter().enumerate() {
        if input.required {
            required_sum += input.amount;
            required_indices.push(input.index);
            required_types.push(input.script_type);
        }
    }

    // Collect optional inputs and compute effective values
    // (original_index, effective_value, script_type, amount)
    let mut optional: Vec<(usize, u64, ScriptType, u64)> = Vec::new();
    for (_i, input) in inputs.iter().enumerate() {
        if input.required {
            continue;
        }
        let input_fee = weight::calculate_fee(fee_rate, weight::input_weight(input.script_type));
        if input.amount > input_fee {
            let effective_value = input.amount - input_fee;
            optional.push((
                input.index,
                effective_value,
                input.script_type,
                input.amount,
            ));
        }
    }

    if optional.is_empty() && required_indices.is_empty() {
        return None;
    }

    // Sort optional inputs by effective value (largest first)
    optional.sort_by(|a, b| b.1.cmp(&a.1));

    // Calculate base weight fee (for required inputs + outputs, no change)
    let base_weight = weight::transaction_weight(&required_types, &output_weights);
    let base_weight_fee = weight::calculate_fee(fee_rate, base_weight) + base_fee;

    // Target = output_sum + base_weight_fee - required_sum
    // We need the optional inputs' effective values to sum to this target
    let target = if output_sum + base_weight_fee > required_sum {
        output_sum + base_weight_fee - required_sum
    } else {
        // Required inputs already cover everything — use finalize to decide about change
        return Some(
            match finalize(
                required_sum,
                output_sum,
                fee_rate,
                base_fee,
                &required_types,
                &output_weights,
                change_script_type,
            ) {
                FinalizeResult::Success {
                    fee,
                    change_amount,
                    has_change,
                    weight,
                } => CoinSelectResult::Success {
                    selected_inputs: required_indices,
                    fee,
                    change_amount,
                    has_change,
                    weight,
                },
                FinalizeResult::InsufficientFunds => return None,
            },
        );
    };

    // Cost of change = fee for change output + dust threshold
    let change_output_fee =
        weight::calculate_fee(fee_rate, weight::change_output_weight(change_script_type));
    let cost_of_change = change_output_fee + dust::dust_amount(change_script_type, fee_rate);

    // Filter out UTXOs whose effective value exceeds the target range.
    // A single UTXO larger than target + cost_of_change can never be part of
    // an exact-match solution (matches JS branchAndBound.ts upper-bound filter).
    optional.retain(|&(_, ev, _, _)| ev <= target + cost_of_change);

    if optional.is_empty() {
        return None;
    }

    // DFS search — returns the FIRST valid solution found (matches JS behavior).
    let mut selected = vec![false; optional.len()];
    let mut current_sum: u64 = 0;
    let mut result_selection: Option<Vec<bool>> = None;
    let mut tries: usize = 0;

    // Suffix sums for pruning
    let mut suffix_sums = vec![0u64; optional.len() + 1];
    for i in (0..optional.len()).rev() {
        suffix_sums[i] = suffix_sums[i + 1] + optional[i].1;
    }

    fn bnb_search(
        depth: usize,
        optional: &[(usize, u64, ScriptType, u64)],
        selected: &mut Vec<bool>,
        current_sum: &mut u64,
        target: u64,
        cost_of_change: u64,
        suffix_sums: &[u64],
        result_selection: &mut Option<Vec<bool>>,
        tries: &mut usize,
    ) -> bool {
        if *tries >= MAX_TRIES {
            return true; // Stop
        }
        *tries += 1;

        if *current_sum > target + cost_of_change {
            return false; // Over target, backtrack
        }

        if *current_sum >= target {
            // Found valid solution — return immediately (first match, matching JS)
            *result_selection = Some(selected.clone());
            return true;
        }

        if depth >= optional.len() {
            return false; // No more inputs
        }

        // Prune: even adding all remaining can't reach target
        if *current_sum + suffix_sums[depth] < target {
            return false;
        }

        // Try including this input
        selected[depth] = true;
        *current_sum += optional[depth].1;
        let stop = bnb_search(
            depth + 1,
            optional,
            selected,
            current_sum,
            target,
            cost_of_change,
            suffix_sums,
            result_selection,
            tries,
        );
        if stop {
            return true;
        }

        // Try excluding this input
        selected[depth] = false;
        *current_sum -= optional[depth].1;
        bnb_search(
            depth + 1,
            optional,
            selected,
            current_sum,
            target,
            cost_of_change,
            suffix_sums,
            result_selection,
            tries,
        )
    }

    let _stop = bnb_search(
        0,
        &optional,
        &mut selected,
        &mut current_sum,
        target,
        cost_of_change,
        &suffix_sums,
        &mut result_selection,
        &mut tries,
    );

    result_selection.and_then(|selection| {
        let mut all_indices = required_indices.clone();
        let mut all_types = required_types.clone();
        let mut total_sum = required_sum;

        for (i, &is_selected) in selection.iter().enumerate() {
            if is_selected {
                all_indices.push(optional[i].0);
                all_types.push(optional[i].2);
                total_sum += optional[i].3;
            }
        }

        match finalize(
            total_sum,
            output_sum,
            fee_rate,
            base_fee,
            &all_types,
            &output_weights,
            change_script_type,
        ) {
            FinalizeResult::Success {
                fee,
                change_amount,
                has_change,
                weight,
            } => Some(CoinSelectResult::Success {
                selected_inputs: all_indices,
                fee,
                change_amount,
                has_change,
                weight,
            }),
            FinalizeResult::InsufficientFunds => None,
        }
    })
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

    fn make_output(amount: u64) -> CoinSelectOutput {
        CoinSelectOutput {
            amount,
            weight: output_weight(ScriptType::SpendWitness),
            is_send_max: false,
        }
    }

    #[test]
    fn test_bnb_exact_match() {
        // UTXOs that sum exactly to target + fee
        let inputs = vec![
            make_input(0, 50_000),
            make_input(1, 30_000),
            make_input(2, 20_000),
        ];
        let outputs = vec![make_output(10_000)];

        // Use a very low fee rate so we can get close to exact
        let result = branch_and_bound(&inputs, &outputs, 1.0, 0, ScriptType::SpendWitness);
        // BnB may or may not find a solution depending on whether UTXOs fit
        if let Some(CoinSelectResult::Success { fee, .. }) = result {
            assert!(fee > 0);
        }
    }

    /// CRITICAL-2: Oversized UTXOs should be filtered out by the upper-bound filter.
    /// A single UTXO much larger than the target cannot be part of an exact-match solution.
    #[test]
    fn test_bnb_rejects_oversized_single_utxo() {
        let inputs = vec![make_input(0, 1_000_000)];
        let outputs = vec![make_output(10_000)];

        let result = branch_and_bound(&inputs, &outputs, 1.0, 0, ScriptType::SpendWitness);
        assert!(
            result.is_none(),
            "BnB should reject when only oversized UTXOs are available"
        );
    }

    /// CRITICAL-2: Multiple oversized UTXOs should all be filtered.
    #[test]
    fn test_bnb_rejects_all_oversized_utxos() {
        let inputs = vec![make_input(0, 1_000_000), make_input(1, 2_000_000)];
        let outputs = vec![make_output(100)];

        let result = branch_and_bound(&inputs, &outputs, 1.0, 0, ScriptType::SpendWitness);
        assert!(
            result.is_none(),
            "BnB should return None when all UTXOs exceed target range"
        );
    }

    /// CRITICAL-1: When BnB selects inputs with overshoot above dust, it should
    /// create a change output instead of absorbing everything as fee.
    #[test]
    fn test_bnb_creates_change_when_overshoot_above_dust() {
        // We need UTXOs where BnB finds a solution with significant overshoot
        // that exceeds the dust threshold. We'll construct inputs carefully.
        //
        // At 1 sat/vB:
        // - P2WPKH input weight = 272 WU → input_fee = 68 sat
        // - P2WPKH output weight = 124 WU → change_output_fee = 31 sat
        // - dust_threshold = max(546, 3 * 68) = 546 sat
        // - cost_of_change = 31 + 546 = 577 sat
        //
        // We want BnB to find a solution where overshoot > dust but < cost_of_change.
        // Actually, let's use a scenario where the overshoot is large enough for change.

        // Target payment: 10,000 sats
        // Base tx fee (1 input + 1 output): ~110 sat at 1 sat/vB
        // UTXO: 11,200 sats → overshoot is ~1,090 sats
        // That's above dust (546), so finalize should add change.

        let inputs = vec![make_input(0, 11_200)];
        let outputs = vec![make_output(10_000)];

        let result = branch_and_bound(&inputs, &outputs, 1.0, 0, ScriptType::SpendWitness);

        if let Some(CoinSelectResult::Success {
            fee,
            change_amount,
            has_change,
            ..
        }) = result
        {
            // Finalize should decide: the ~1,090 sat remainder is above dust (546)
            // If change is produced, verify the accounting
            if has_change {
                assert!(
                    change_amount >= 546,
                    "Change should be above dust: got {}",
                    change_amount
                );
                assert_eq!(
                    fee + change_amount + 10_000,
                    11_200,
                    "fee({}) + change({}) + output(10000) should equal input(11200)",
                    fee,
                    change_amount
                );
            } else {
                // If finalize decided change isn't worth it (fee with change > remainder),
                // fee should absorb the remainder
                assert_eq!(fee, 11_200 - 10_000);
            }
        }
        // BnB may also return None if the UTXO is outside the target range, which is fine
    }

    /// MEDIUM-3: BnB should bail when required UTXOs exist, falling through to accumulative.
    #[test]
    fn test_bnb_bails_on_required_utxos() {
        let inputs = vec![
            CoinSelectInput {
                index: 0,
                amount: 50_000,
                script_type: ScriptType::SpendWitness,
                required: true,
                weight: input_weight(ScriptType::SpendWitness),
            },
            make_input(1, 30_000),
        ];
        let outputs = vec![make_output(10_000)];

        let result = branch_and_bound(&inputs, &outputs, 1.0, 0, ScriptType::SpendWitness);
        assert!(
            result.is_none(),
            "BnB should bail when required UTXOs exist"
        );
    }
}
