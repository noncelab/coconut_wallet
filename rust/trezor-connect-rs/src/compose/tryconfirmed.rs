//! Progressive confirmation filtering for coin selection.
//!
//! Tries coin selection with decreasing confirmation requirements,
//! starting from strict and relaxing until a valid solution is found.
//! Trial levels are generated dynamically from configurable thresholds,
//! matching the JS tryconfirmed.ts behavior.

use super::coinselect::{self, CoinSelectInput, CoinSelectOutput, CoinSelectResult};
use crate::types::bitcoin::ScriptType;

/// Minimum confirmations required for coinbase UTXOs regardless of filter.
const COINBASE_MIN_CONFIRMATIONS: u32 = 100;

/// Default minimum confirmations for own UTXOs.
const DEFAULT_OWN_CONFIRMATIONS: u32 = 1;

/// Default minimum confirmations for other (external) UTXOs.
const DEFAULT_OTHER_CONFIRMATIONS: u32 = 6;

/// Confirmation filter configuration.
struct ConfFilter {
    own_min: u32,
    other_min: u32,
}

/// Generate trial filter levels dynamically, matching JS tryconfirmed.ts:
///
/// 1. Keep `other` at its max, decrease `own` from `own` down to 1
/// 2. Keep `own` at 1, decrease `other` from `other - 1` down to 1
/// 3. Allow own unconfirmed: {own: 0, other: 1}
/// 4. Allow all unconfirmed: {own: 0, other: 0}
fn generate_trials(own: u32, other: u32) -> Vec<ConfFilter> {
    let mut trials = Vec::new();

    // Phase 1: decrease own, keep other at max
    for i in (1..=own).rev() {
        trials.push(ConfFilter {
            own_min: i,
            other_min: other,
        });
    }

    // Phase 2: decrease other, keep own at 1
    for i in (1..other).rev() {
        trials.push(ConfFilter {
            own_min: 1,
            other_min: i,
        });
    }

    // Phase 3: allow own unconfirmed, then all unconfirmed
    trials.push(ConfFilter {
        own_min: 0,
        other_min: 1,
    });
    trials.push(ConfFilter {
        own_min: 0,
        other_min: 0,
    });

    trials
}

/// Run coin selection with progressive confirmation filtering.
///
/// Tries decreasing confirmation requirements until a valid solution is found.
/// Required UTXOs bypass confirmation checks.
/// Coinbase UTXOs always require 100 confirmations.
///
/// `own_confirmations` and `other_confirmations` control the starting thresholds.
/// Pass `None` to use defaults (1 for own, 6 for other).
pub fn try_confirmed(
    inputs: &[CoinSelectInput],
    outputs: &[CoinSelectOutput],
    fee_rate: f64,
    base_fee: u64,
    change_script_type: ScriptType,
    confirmations: &[u32],
    is_own: &[bool],
    coinbase_flags: &[bool],
    own_confirmations: Option<u32>,
    other_confirmations: Option<u32>,
) -> CoinSelectResult {
    let own = own_confirmations.unwrap_or(DEFAULT_OWN_CONFIRMATIONS);
    let other = other_confirmations.unwrap_or(DEFAULT_OTHER_CONFIRMATIONS);
    let trials = generate_trials(own, other);

    let mut prev_usable_count: usize = 0;

    for filter in &trials {
        let filtered: Vec<CoinSelectInput> = inputs
            .iter()
            .enumerate()
            .filter(|(i, input)| {
                // Required inputs always pass
                if input.required {
                    return true;
                }

                let confs = confirmations.get(*i).copied().unwrap_or(0);
                let is_coinbase = coinbase_flags.get(*i).copied().unwrap_or(false);

                // Coinbase UTXOs need 100 confirmations regardless
                if is_coinbase && confs < COINBASE_MIN_CONFIRMATIONS {
                    return false;
                }

                let is_own_utxo = is_own.get(*i).copied().unwrap_or(false);
                let min_confs = if is_own_utxo {
                    filter.own_min
                } else {
                    filter.other_min
                };
                confs >= min_confs
            })
            .map(|(_, input)| input.clone())
            .collect();

        if filtered.is_empty() {
            continue;
        }

        // Skip coinselect if the filtered set hasn't grown since the last trial,
        // matching JS tryconfirmed.ts incremental behavior.
        if filtered.len() == prev_usable_count {
            continue;
        }
        prev_usable_count = filtered.len();

        let filtered_confs: Vec<u32> = filtered
            .iter()
            .map(|input| confirmations.get(input.index).copied().unwrap_or(0))
            .collect();
        let filtered_coinbase: Vec<bool> = filtered
            .iter()
            .map(|input| coinbase_flags.get(input.index).copied().unwrap_or(false))
            .collect();

        let result = coinselect::coinselect(
            &filtered,
            outputs,
            fee_rate,
            base_fee,
            change_script_type,
            &filtered_confs,
            &filtered_coinbase,
        );

        match result {
            CoinSelectResult::InsufficientFunds => continue,
            _ => return result,
        }
    }

    CoinSelectResult::InsufficientFunds
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_trials_defaults() {
        let trials = generate_trials(1, 6);
        // Expected: {1,6}, {1,5}, {1,4}, {1,3}, {1,2}, {1,1}, {0,1}, {0,0}
        assert_eq!(trials.len(), 8);
        assert_eq!((trials[0].own_min, trials[0].other_min), (1, 6));
        assert_eq!((trials[1].own_min, trials[1].other_min), (1, 5));
        assert_eq!((trials[5].own_min, trials[5].other_min), (1, 1));
        assert_eq!((trials[6].own_min, trials[6].other_min), (0, 1));
        assert_eq!((trials[7].own_min, trials[7].other_min), (0, 0));
    }

    #[test]
    fn test_generate_trials_custom_own() {
        let trials = generate_trials(3, 6);
        // Expected: {3,6}, {2,6}, {1,6}, {1,5}, {1,4}, {1,3}, {1,2}, {1,1}, {0,1}, {0,0}
        assert_eq!(trials.len(), 10);
        assert_eq!((trials[0].own_min, trials[0].other_min), (3, 6));
        assert_eq!((trials[1].own_min, trials[1].other_min), (2, 6));
        assert_eq!((trials[2].own_min, trials[2].other_min), (1, 6));
        assert_eq!((trials[3].own_min, trials[3].other_min), (1, 5));
        assert_eq!((trials[8].own_min, trials[8].other_min), (0, 1));
        assert_eq!((trials[9].own_min, trials[9].other_min), (0, 0));
    }

    #[test]
    fn test_generate_trials_minimal() {
        let trials = generate_trials(1, 1);
        // Expected: {1,1}, {0,1}, {0,0}
        assert_eq!(trials.len(), 3);
        assert_eq!((trials[0].own_min, trials[0].other_min), (1, 1));
        assert_eq!((trials[1].own_min, trials[1].other_min), (0, 1));
        assert_eq!((trials[2].own_min, trials[2].other_min), (0, 0));
    }
}
