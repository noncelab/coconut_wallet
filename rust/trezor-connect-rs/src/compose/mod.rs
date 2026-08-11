//! Transaction composition engine.
//!
//! Implements offline pre-compose functionality for Bitcoin transactions,
//! including UTXO selection, fee calculation, change outputs, and sorting.

pub mod coinselect;
pub mod dust;
pub mod sorting;
pub mod tryconfirmed;
pub mod weight;

use crate::types::bitcoin::ScriptType;
use coinselect::{CoinSelectInput, CoinSelectOutput, CoinSelectResult};
use sorting::{SortableInput, SortableOutput, SortingStrategy};

/// Input UTXO for the compose engine.
#[derive(Debug, Clone)]
pub struct ComposeInput {
    /// Transaction ID (hex)
    pub txid: String,
    /// Output index
    pub vout: u32,
    /// Amount in satoshis
    pub amount: u64,
    /// Address this UTXO belongs to
    pub address: String,
    /// BIP32 derivation path
    pub path: String,
    /// Number of confirmations
    pub confirmations: u32,
    /// Whether this is a coinbase output
    pub coinbase: bool,
    /// Whether the UTXO is owned by this account
    pub own: bool,
    /// Whether this UTXO must be included
    pub required: bool,
    /// Script type for this input
    pub script_type: ScriptType,
}

/// Output specification for the compose engine.
#[derive(Debug, Clone)]
pub enum ComposeOutput {
    /// Payment to a specific address with a specific amount.
    Payment { address: String, amount: u64 },
    /// Payment without address (for pre-compose estimation).
    PaymentNoAddress { amount: u64 },
    /// Send all remaining funds to this address.
    SendMax { address: String },
    /// Send all remaining funds (address not yet specified).
    SendMaxNoAddress,
    /// OP_RETURN data output.
    OpReturn { data_hex: String },
}

/// Request for the compose engine.
#[derive(Debug, Clone)]
pub struct ComposeRequest {
    /// Available UTXOs
    pub inputs: Vec<ComposeInput>,
    /// Desired outputs
    pub outputs: Vec<ComposeOutput>,
    /// Fee rate in sat/vB (supports fractional rates, e.g. 1.5)
    pub fee_rate: f64,
    /// Base fee in satoshis (added to calculated fee, e.g. for RBF)
    pub base_fee: u64,
    /// Script type for change outputs
    pub change_script_type: ScriptType,
    /// Sorting strategy
    pub sorting_strategy: SortingStrategy,
    /// Default sequence number
    pub sequence: Option<u32>,
}

/// A selected input in the composition result.
#[derive(Debug, Clone)]
pub struct ComposedInput {
    /// Original index in the input array
    pub index: usize,
    /// Transaction ID (hex)
    pub txid: String,
    /// Output index
    pub vout: u32,
    /// Amount in satoshis
    pub amount: u64,
    /// Address
    pub address: String,
    /// BIP32 path
    pub path: String,
    /// Script type
    pub script_type: ScriptType,
}

/// A composed output in the result.
#[derive(Debug, Clone)]
pub enum ComposedOutput {
    /// Payment to an address.
    Payment { address: String, amount: u64 },
    /// Change output back to own address.
    Change {
        address: String,
        path: String,
        amount: u64,
        script_type: ScriptType,
    },
    /// OP_RETURN data output.
    OpReturn { data_hex: String },
}

/// Result of the compose engine.
#[derive(Debug, Clone)]
pub enum ComposeResult {
    /// Successfully composed a complete transaction.
    Final {
        /// Total amount spent (outputs + fee)
        total_spent: u64,
        /// Fee in satoshis
        fee: u64,
        /// Effective fee rate in sat/vB
        fee_per_byte: f64,
        /// Transaction size in vBytes
        bytes: usize,
        /// Selected inputs
        inputs: Vec<ComposedInput>,
        /// Composed outputs
        outputs: Vec<ComposedOutput>,
        /// Output permutation (maps new position → original index)
        outputs_permutation: Vec<usize>,
    },
    /// Non-final result (e.g., send-max without address).
    NonFinal {
        /// Maximum sendable amount (for send-max)
        max: Option<u64>,
        /// Total amount spent
        total_spent: u64,
        /// Fee in satoshis
        fee: u64,
        /// Effective fee rate in sat/vB
        fee_per_byte: f64,
        /// Transaction size in vBytes
        bytes: usize,
    },
    /// Composition failed.
    Error(ComposeError),
}

/// Error from the compose engine.
#[derive(Debug, Clone)]
pub enum ComposeError {
    /// Not enough funds to cover outputs + fees
    NotEnoughFunds,
    /// No UTXOs provided
    MissingUtxos,
    /// No outputs provided
    MissingOutputs,
    /// Fee rate is zero or invalid
    IncorrectFeeRate,
    /// Invalid UTXO
    IncorrectUtxo(String),
    /// Invalid output
    IncorrectOutput(String),
}

impl std::fmt::Display for ComposeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ComposeError::NotEnoughFunds => write!(f, "Not enough funds"),
            ComposeError::MissingUtxos => write!(f, "No UTXOs provided"),
            ComposeError::MissingOutputs => write!(f, "No outputs provided"),
            ComposeError::IncorrectFeeRate => write!(f, "Incorrect fee rate"),
            ComposeError::IncorrectUtxo(s) => write!(f, "Incorrect UTXO: {}", s),
            ComposeError::IncorrectOutput(s) => write!(f, "Incorrect output: {}", s),
        }
    }
}

/// Infer the output script type from an address for weight estimation.
///
/// - bech32 (bc1q.../tb1q.../bcrt1q...) → P2WPKH
/// - bech32m (bc1p.../tb1p.../bcrt1p...) → P2TR
/// - base58 starting with 3 or 2 → P2SH
/// - base58 starting with 1, m, or n → P2PKH
pub fn script_type_from_address(address: &str) -> ScriptType {
    let addr = address.to_lowercase();
    if addr.starts_with("bc1q") || addr.starts_with("tb1q") || addr.starts_with("bcrt1q") {
        ScriptType::SpendWitness
    } else if addr.starts_with("bc1p") || addr.starts_with("tb1p") || addr.starts_with("bcrt1p") {
        ScriptType::SpendTaproot
    } else if address.starts_with('3') || address.starts_with('2') {
        ScriptType::SpendP2SHWitness
    } else {
        // P2PKH: addresses starting with 1, m, n, or unknown formats
        ScriptType::SpendAddress
    }
}

/// Run the compose engine.
pub fn compose_tx(request: ComposeRequest) -> ComposeResult {
    // Validate inputs
    if request.inputs.is_empty() {
        return ComposeResult::Error(ComposeError::MissingUtxos);
    }
    if request.outputs.is_empty() {
        return ComposeResult::Error(ComposeError::MissingOutputs);
    }
    if request.fee_rate <= 0.0 || !request.fee_rate.is_finite() {
        return ComposeResult::Error(ComposeError::IncorrectFeeRate);
    }

    // Check if any output is send-max
    let has_send_max = request.outputs.iter().any(|o| {
        matches!(
            o,
            ComposeOutput::SendMax { .. } | ComposeOutput::SendMaxNoAddress
        )
    });

    // Check if all outputs have addresses (determines Final vs NonFinal)
    let is_complete = request.outputs.iter().all(|o| {
        matches!(
            o,
            ComposeOutput::Payment { .. }
                | ComposeOutput::SendMax { .. }
                | ComposeOutput::OpReturn { .. }
        )
    });

    // Transform inputs to CoinSelectInput
    let mut cs_inputs: Vec<CoinSelectInput> = request
        .inputs
        .iter()
        .enumerate()
        .map(|(i, input)| CoinSelectInput {
            index: i,
            amount: input.amount,
            script_type: input.script_type,
            required: input.required,
            weight: weight::input_weight(input.script_type),
        })
        .collect();

    // Sort inputs by effective value (descending) for optimal coin selection.
    // This ensures the accumulative algorithm picks the most cost-effective UTXOs first.
    if request.sorting_strategy != SortingStrategy::None {
        cs_inputs.sort_by(|a, b| {
            let score_a =
                a.amount as f64 - weight::calculate_fee(request.fee_rate, a.weight) as f64;
            let score_b =
                b.amount as f64 - weight::calculate_fee(request.fee_rate, b.weight) as f64;
            score_b
                .partial_cmp(&score_a)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then(a.index.cmp(&b.index))
        });
    }

    // Transform outputs to CoinSelectOutput
    let cs_outputs: Vec<CoinSelectOutput> = request
        .outputs
        .iter()
        .map(|output| {
            match output {
                ComposeOutput::Payment { address, amount } => CoinSelectOutput {
                    amount: *amount,
                    weight: weight::output_weight(script_type_from_address(address)),
                    is_send_max: false,
                },
                ComposeOutput::PaymentNoAddress { amount } => CoinSelectOutput {
                    amount: *amount,
                    weight: weight::output_weight(request.change_script_type),
                    is_send_max: false,
                },
                ComposeOutput::SendMax { address } => CoinSelectOutput {
                    amount: 0,
                    weight: weight::output_weight(script_type_from_address(address)),
                    is_send_max: true,
                },
                ComposeOutput::SendMaxNoAddress => CoinSelectOutput {
                    amount: 0,
                    weight: weight::output_weight(request.change_script_type),
                    is_send_max: true,
                },
                ComposeOutput::OpReturn { data_hex } => {
                    let data_len = data_hex.len() / 2; // hex to bytes
                    CoinSelectOutput {
                        amount: 0,
                        weight: weight::op_return_output_weight(data_len),
                        is_send_max: false,
                    }
                }
            }
        })
        .collect();

    // Prepare confirmation data
    let confirmations: Vec<u32> = request.inputs.iter().map(|i| i.confirmations).collect();
    let coinbase_flags: Vec<bool> = request.inputs.iter().map(|i| i.coinbase).collect();

    // Run coin selection:
    // - Send-max bypasses tryConfirmed and uses ALL UTXOs directly via split,
    //   matching the JS behavior where users expect to spend all available funds.
    // - Regular transactions go through tryConfirmed for progressive confirmation filtering.
    let result = if has_send_max {
        coinselect::split::split(
            &cs_inputs,
            &cs_outputs,
            request.fee_rate,
            request.base_fee,
            request.change_script_type,
            &confirmations,
            &coinbase_flags,
        )
    } else {
        let is_own: Vec<bool> = request.inputs.iter().map(|i| i.own).collect();
        tryconfirmed::try_confirmed(
            &cs_inputs,
            &cs_outputs,
            request.fee_rate,
            request.base_fee,
            request.change_script_type,
            &confirmations,
            &is_own,
            &coinbase_flags,
            None,
            None,
        )
    };

    match result {
        CoinSelectResult::InsufficientFunds => ComposeResult::Error(ComposeError::NotEnoughFunds),
        CoinSelectResult::Success {
            selected_inputs,
            fee,
            change_amount,
            has_change,
            weight: tx_weight,
        } => {
            let vbytes = weight::weight_to_vbytes(tx_weight);
            let fee_per_byte = if vbytes > 0 {
                fee as f64 / vbytes as f64
            } else {
                0.0
            };
            let output_sum: u64 = request
                .outputs
                .iter()
                .map(|o| match o {
                    ComposeOutput::Payment { amount, .. }
                    | ComposeOutput::PaymentNoAddress { amount } => *amount,
                    _ => 0,
                })
                .sum();
            let total_spent = output_sum + fee;

            if !is_complete {
                return ComposeResult::NonFinal {
                    max: None,
                    total_spent,
                    fee,
                    fee_per_byte,
                    bytes: vbytes,
                };
            }

            // Build composed inputs
            let composed_inputs: Vec<ComposedInput> = selected_inputs
                .iter()
                .map(|&idx| {
                    let input = &request.inputs[idx];
                    ComposedInput {
                        index: idx,
                        txid: input.txid.clone(),
                        vout: input.vout,
                        amount: input.amount,
                        address: input.address.clone(),
                        path: input.path.clone(),
                        script_type: input.script_type,
                    }
                })
                .collect();

            // Build composed outputs
            let mut composed_outputs: Vec<ComposedOutput> = request
                .outputs
                .iter()
                .map(|o| match o {
                    ComposeOutput::Payment { address, amount } => ComposedOutput::Payment {
                        address: address.clone(),
                        amount: *amount,
                    },
                    ComposeOutput::SendMax { address } => {
                        // For non-send-max results, this shouldn't happen
                        ComposedOutput::Payment {
                            address: address.clone(),
                            amount: 0,
                        }
                    }
                    ComposeOutput::OpReturn { data_hex } => ComposedOutput::OpReturn {
                        data_hex: data_hex.clone(),
                    },
                    _ => unreachable!("Non-final outputs should be caught earlier"),
                })
                .collect();

            // Add change output if needed
            if has_change && change_amount > 0 {
                composed_outputs.push(ComposedOutput::Change {
                    address: String::new(), // Caller fills this
                    path: String::new(),
                    amount: change_amount,
                    script_type: request.change_script_type,
                });
            }

            // Apply sorting
            let mut sortable_inputs: Vec<SortableInput> = composed_inputs
                .iter()
                .enumerate()
                .map(|(i, ci)| SortableInput {
                    index: i,
                    txid: ci.txid.clone(),
                    vout: ci.vout,
                })
                .collect();
            let mut sortable_outputs: Vec<SortableOutput> = composed_outputs
                .iter()
                .enumerate()
                .map(|(i, co)| {
                    let (amount, script_pubkey, is_change) = match co {
                        ComposedOutput::Payment { amount, address } => {
                            (*amount, sorting::address_to_script_pubkey(address), false)
                        }
                        ComposedOutput::Change {
                            amount, address, ..
                        } => (*amount, sorting::address_to_script_pubkey(address), true),
                        ComposedOutput::OpReturn { data_hex } => {
                            (0, sorting::op_return_script_pubkey(data_hex), false)
                        }
                    };
                    SortableOutput {
                        index: i,
                        amount,
                        script_pubkey,
                        is_change,
                    }
                })
                .collect();

            let outputs_permutation = sorting::sort_transaction(
                &mut sortable_inputs,
                &mut sortable_outputs,
                request.sorting_strategy,
            );

            // Reorder inputs and outputs
            let sorted_inputs: Vec<ComposedInput> = sortable_inputs
                .iter()
                .map(|si| composed_inputs[si.index].clone())
                .collect();
            let sorted_outputs: Vec<ComposedOutput> = sortable_outputs
                .iter()
                .map(|so| composed_outputs[so.index].clone())
                .collect();

            ComposeResult::Final {
                total_spent,
                fee,
                fee_per_byte,
                bytes: vbytes,
                inputs: sorted_inputs,
                outputs: sorted_outputs,
                outputs_permutation,
            }
        }
        CoinSelectResult::SendMax {
            selected_inputs,
            max_amount,
            fee,
            weight: tx_weight,
        } => {
            let vbytes = weight::weight_to_vbytes(tx_weight);
            let fee_per_byte = if vbytes > 0 {
                fee as f64 / vbytes as f64
            } else {
                0.0
            };
            let total_spent = max_amount + fee;

            if !is_complete {
                return ComposeResult::NonFinal {
                    max: Some(max_amount),
                    total_spent,
                    fee,
                    fee_per_byte,
                    bytes: vbytes,
                };
            }

            // Build composed inputs
            let composed_inputs: Vec<ComposedInput> = selected_inputs
                .iter()
                .map(|&idx| {
                    let input = &request.inputs[idx];
                    ComposedInput {
                        index: idx,
                        txid: input.txid.clone(),
                        vout: input.vout,
                        amount: input.amount,
                        address: input.address.clone(),
                        path: input.path.clone(),
                        script_type: input.script_type,
                    }
                })
                .collect();

            // Build composed outputs with send-max amount filled in
            let composed_outputs: Vec<ComposedOutput> = request
                .outputs
                .iter()
                .map(|o| match o {
                    ComposeOutput::Payment { address, amount } => ComposedOutput::Payment {
                        address: address.clone(),
                        amount: *amount,
                    },
                    ComposeOutput::SendMax { address } => ComposedOutput::Payment {
                        address: address.clone(),
                        amount: max_amount,
                    },
                    ComposeOutput::OpReturn { data_hex } => ComposedOutput::OpReturn {
                        data_hex: data_hex.clone(),
                    },
                    _ => unreachable!(),
                })
                .collect();

            // Apply sorting
            let mut sortable_inputs: Vec<SortableInput> = composed_inputs
                .iter()
                .enumerate()
                .map(|(i, ci)| SortableInput {
                    index: i,
                    txid: ci.txid.clone(),
                    vout: ci.vout,
                })
                .collect();
            let mut sortable_outputs: Vec<SortableOutput> = composed_outputs
                .iter()
                .enumerate()
                .map(|(i, co)| {
                    let (amount, script_pubkey, is_change) = match co {
                        ComposedOutput::Payment { amount, address } => {
                            (*amount, sorting::address_to_script_pubkey(address), false)
                        }
                        ComposedOutput::Change {
                            amount, address, ..
                        } => (*amount, sorting::address_to_script_pubkey(address), true),
                        ComposedOutput::OpReturn { data_hex } => {
                            (0, sorting::op_return_script_pubkey(data_hex), false)
                        }
                    };
                    SortableOutput {
                        index: i,
                        amount,
                        script_pubkey,
                        is_change,
                    }
                })
                .collect();

            let outputs_permutation = sorting::sort_transaction(
                &mut sortable_inputs,
                &mut sortable_outputs,
                request.sorting_strategy,
            );

            let sorted_inputs: Vec<ComposedInput> = sortable_inputs
                .iter()
                .map(|si| composed_inputs[si.index].clone())
                .collect();
            let sorted_outputs: Vec<ComposedOutput> = sortable_outputs
                .iter()
                .map(|so| composed_outputs[so.index].clone())
                .collect();

            ComposeResult::Final {
                total_spent,
                fee,
                fee_per_byte,
                bytes: vbytes,
                inputs: sorted_inputs,
                outputs: sorted_outputs,
                outputs_permutation,
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_utxo(txid: &str, vout: u32, amount: u64) -> ComposeInput {
        ComposeInput {
            txid: txid.to_string(),
            vout,
            amount,
            address: "bc1qtest".to_string(),
            path: "m/84'/0'/0'/0/0".to_string(),
            confirmations: 10,
            coinbase: false,
            own: true,
            required: false,
            script_type: ScriptType::SpendWitness,
        }
    }

    #[test]
    fn test_compose_basic_payment() {
        let request = ComposeRequest {
            inputs: vec![make_utxo("aaaa", 0, 100_000), make_utxo("bbbb", 1, 200_000)],
            outputs: vec![ComposeOutput::Payment {
                address: "bc1qrecipient".to_string(),
                amount: 50_000,
            }],
            fee_rate: 10.0,
            base_fee: 0,
            change_script_type: ScriptType::SpendWitness,
            sorting_strategy: SortingStrategy::None,
            sequence: None,
        };

        match compose_tx(request) {
            ComposeResult::Final {
                fee,
                total_spent,
                inputs,
                outputs,
                ..
            } => {
                assert!(fee > 0);
                assert_eq!(total_spent, 50_000 + fee);
                assert!(!inputs.is_empty());
                assert!(!outputs.is_empty());
            }
            other => panic!("Expected Final, got {:?}", other),
        }
    }

    #[test]
    fn test_compose_send_max() {
        let request = ComposeRequest {
            inputs: vec![make_utxo("aaaa", 0, 100_000), make_utxo("bbbb", 1, 200_000)],
            outputs: vec![ComposeOutput::SendMax {
                address: "bc1qrecipient".to_string(),
            }],
            fee_rate: 10.0,
            base_fee: 0,
            change_script_type: ScriptType::SpendWitness,
            sorting_strategy: SortingStrategy::None,
            sequence: None,
        };

        match compose_tx(request) {
            ComposeResult::Final {
                fee,
                total_spent,
                inputs,
                outputs,
                ..
            } => {
                assert!(fee > 0);
                assert_eq!(inputs.len(), 2); // All UTXOs used for send-max
                assert_eq!(outputs.len(), 1); // Just the send-max output
                assert_eq!(total_spent, 300_000); // All funds
            }
            other => panic!("Expected Final, got {:?}", other),
        }
    }

    #[test]
    fn test_compose_send_max_no_address() {
        let request = ComposeRequest {
            inputs: vec![make_utxo("aaaa", 0, 100_000)],
            outputs: vec![ComposeOutput::SendMaxNoAddress],
            fee_rate: 10.0,
            base_fee: 0,
            change_script_type: ScriptType::SpendWitness,
            sorting_strategy: SortingStrategy::None,
            sequence: None,
        };

        match compose_tx(request) {
            ComposeResult::NonFinal { max, fee, .. } => {
                assert!(max.is_some());
                assert!(max.unwrap() > 0);
                assert!(fee > 0);
            }
            other => panic!("Expected NonFinal, got {:?}", other),
        }
    }

    #[test]
    fn test_compose_insufficient_funds() {
        let request = ComposeRequest {
            inputs: vec![make_utxo("aaaa", 0, 1_000)],
            outputs: vec![ComposeOutput::Payment {
                address: "bc1qrecipient".to_string(),
                amount: 1_000_000,
            }],
            fee_rate: 10.0,
            base_fee: 0,
            change_script_type: ScriptType::SpendWitness,
            sorting_strategy: SortingStrategy::None,
            sequence: None,
        };

        match compose_tx(request) {
            ComposeResult::Error(ComposeError::NotEnoughFunds) => {}
            other => panic!("Expected NotEnoughFunds, got {:?}", other),
        }
    }

    #[test]
    fn test_compose_empty_inputs() {
        let request = ComposeRequest {
            inputs: vec![],
            outputs: vec![ComposeOutput::Payment {
                address: "bc1q".to_string(),
                amount: 50_000,
            }],
            fee_rate: 10.0,
            base_fee: 0,
            change_script_type: ScriptType::SpendWitness,
            sorting_strategy: SortingStrategy::None,
            sequence: None,
        };

        match compose_tx(request) {
            ComposeResult::Error(ComposeError::MissingUtxos) => {}
            other => panic!("Expected MissingUtxos, got {:?}", other),
        }
    }

    #[test]
    fn test_compose_zero_fee_rate() {
        let request = ComposeRequest {
            inputs: vec![make_utxo("aaaa", 0, 100_000)],
            outputs: vec![ComposeOutput::Payment {
                address: "bc1q".to_string(),
                amount: 50_000,
            }],
            fee_rate: 0.0,
            base_fee: 0,
            change_script_type: ScriptType::SpendWitness,
            sorting_strategy: SortingStrategy::None,
            sequence: None,
        };

        match compose_tx(request) {
            ComposeResult::Error(ComposeError::IncorrectFeeRate) => {}
            other => panic!("Expected IncorrectFeeRate, got {:?}", other),
        }
    }

    #[test]
    fn test_compose_cross_type_output_weight() {
        // Send from P2WPKH account to P2PKH address (1xxx).
        // The output weight should be 136 WU (P2PKH), not 124 WU (P2WPKH).
        let request_p2pkh = ComposeRequest {
            inputs: vec![make_utxo("aaaa", 0, 100_000)],
            outputs: vec![ComposeOutput::Payment {
                address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa".to_string(),
                amount: 50_000,
            }],
            fee_rate: 10.0,
            base_fee: 0,
            change_script_type: ScriptType::SpendWitness,
            sorting_strategy: SortingStrategy::None,
            sequence: None,
        };

        // Same amount to a P2WPKH address (bc1q).
        let request_p2wpkh = ComposeRequest {
            inputs: vec![make_utxo("aaaa", 0, 100_000)],
            outputs: vec![ComposeOutput::Payment {
                address: "bc1qrecipient".to_string(),
                amount: 50_000,
            }],
            fee_rate: 10.0,
            base_fee: 0,
            change_script_type: ScriptType::SpendWitness,
            sorting_strategy: SortingStrategy::None,
            sequence: None,
        };

        let (fee_p2pkh, bytes_p2pkh) = match compose_tx(request_p2pkh) {
            ComposeResult::Final { fee, bytes, .. } => (fee, bytes),
            other => panic!("Expected Final, got {:?}", other),
        };
        let (fee_p2wpkh, bytes_p2wpkh) = match compose_tx(request_p2wpkh) {
            ComposeResult::Final { fee, bytes, .. } => (fee, bytes),
            other => panic!("Expected Final, got {:?}", other),
        };

        // P2PKH output is larger (136 WU) than P2WPKH (124 WU),
        // so the tx sending to P2PKH should be larger and have a higher fee.
        assert!(
            bytes_p2pkh > bytes_p2wpkh,
            "P2PKH output tx ({} vB) should be larger than P2WPKH ({} vB)",
            bytes_p2pkh,
            bytes_p2wpkh
        );
        assert!(
            fee_p2pkh > fee_p2wpkh,
            "P2PKH output fee ({}) should be higher than P2WPKH ({})",
            fee_p2pkh,
            fee_p2wpkh
        );
    }

    #[test]
    fn test_script_type_from_address_inference() {
        // P2WPKH (bech32)
        assert_eq!(
            script_type_from_address("bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"),
            ScriptType::SpendWitness
        );
        // P2TR (bech32m)
        assert_eq!(
            script_type_from_address("bc1ptest"),
            ScriptType::SpendTaproot
        );
        // P2SH (base58 starting with 3)
        assert_eq!(
            script_type_from_address("3J98t1WpEZ73CNmQviecrnyiWrnqRhWNLy"),
            ScriptType::SpendP2SHWitness
        );
        // P2PKH (base58 starting with 1)
        assert_eq!(
            script_type_from_address("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"),
            ScriptType::SpendAddress
        );
        // Testnet P2WPKH
        assert_eq!(
            script_type_from_address("tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"),
            ScriptType::SpendWitness
        );
        // Testnet P2TR
        assert_eq!(
            script_type_from_address("tb1ptest"),
            ScriptType::SpendTaproot
        );
        // Regtest P2WPKH
        assert_eq!(
            script_type_from_address("bcrt1qj2gz3meule5mc4r4knv65vjds3g88rlxs0jlmq"),
            ScriptType::SpendWitness
        );
        // Regtest P2TR
        assert_eq!(
            script_type_from_address("bcrt1ptest"),
            ScriptType::SpendTaproot
        );
    }

    /// MEDIUM-2: Mixed script type UTXOs should get correct per-UTXO weights,
    /// resulting in different fees than if all UTXOs used the account's script type.
    #[test]
    fn test_compose_mixed_input_script_types() {
        // A P2PKH UTXO (weight 592 WU) in a P2WPKH account should be heavier
        // than a P2WPKH UTXO (weight 272 WU).
        let p2pkh_utxo = ComposeInput {
            txid: "aaaa".to_string(),
            vout: 0,
            amount: 100_000,
            address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa".to_string(),
            path: "m/44'/0'/0'/0/0".to_string(),
            confirmations: 10,
            coinbase: false,
            own: true,
            required: false,
            script_type: ScriptType::SpendAddress, // P2PKH
        };

        let p2wpkh_utxo = ComposeInput {
            txid: "bbbb".to_string(),
            vout: 0,
            amount: 100_000,
            address: "bc1qtest".to_string(),
            path: "m/84'/0'/0'/0/0".to_string(),
            confirmations: 10,
            coinbase: false,
            own: true,
            required: false,
            script_type: ScriptType::SpendWitness, // P2WPKH
        };

        // Compose with only the P2PKH UTXO
        let request_p2pkh = ComposeRequest {
            inputs: vec![p2pkh_utxo],
            outputs: vec![ComposeOutput::Payment {
                address: "bc1qrecipient".to_string(),
                amount: 50_000,
            }],
            fee_rate: 10.0,
            base_fee: 0,
            change_script_type: ScriptType::SpendWitness,
            sorting_strategy: SortingStrategy::None,
            sequence: None,
        };

        // Compose with only the P2WPKH UTXO
        let request_p2wpkh = ComposeRequest {
            inputs: vec![p2wpkh_utxo],
            outputs: vec![ComposeOutput::Payment {
                address: "bc1qrecipient".to_string(),
                amount: 50_000,
            }],
            fee_rate: 10.0,
            base_fee: 0,
            change_script_type: ScriptType::SpendWitness,
            sorting_strategy: SortingStrategy::None,
            sequence: None,
        };

        let fee_p2pkh = match compose_tx(request_p2pkh) {
            ComposeResult::Final { fee, .. } => fee,
            other => panic!("Expected Final, got {:?}", other),
        };
        let fee_p2wpkh = match compose_tx(request_p2wpkh) {
            ComposeResult::Final { fee, .. } => fee,
            other => panic!("Expected Final, got {:?}", other),
        };

        // P2PKH input (592 WU) is heavier than P2WPKH (272 WU),
        // so the fee should be higher when spending a P2PKH UTXO
        assert!(
            fee_p2pkh > fee_p2wpkh,
            "P2PKH input fee ({}) should be higher than P2WPKH input fee ({})",
            fee_p2pkh,
            fee_p2wpkh
        );
    }

    /// Test that compose_tx handles filtered inputs correctly:
    /// when some UTXOs are missing from the middle, the selected indices
    /// still point to the correct original UTXOs.
    #[test]
    fn test_compose_with_unconfirmed_utxos_filtering() {
        // Create UTXOs: first two are unconfirmed (0 confs, not own), third is confirmed.
        // try_confirmed should filter out the unconfirmed ones in early rounds
        // and eventually include them. The key thing: returned indices must match
        // the original request.inputs positions.
        let mut utxo_a = make_utxo("aaaa", 0, 20_000);
        utxo_a.confirmations = 0;
        utxo_a.own = false;

        let mut utxo_b = make_utxo("bbbb", 1, 30_000);
        utxo_b.confirmations = 0;
        utxo_b.own = false;

        let utxo_c = make_utxo("cccc", 2, 100_000); // confirmed, own

        let request = ComposeRequest {
            inputs: vec![utxo_a, utxo_b, utxo_c],
            outputs: vec![ComposeOutput::Payment {
                address: "bc1qrecipient".to_string(),
                amount: 50_000,
            }],
            fee_rate: 10.0,
            base_fee: 0,
            change_script_type: ScriptType::SpendWitness,
            sorting_strategy: SortingStrategy::None,
            sequence: None,
        };

        match compose_tx(request) {
            ComposeResult::Final { inputs, .. } => {
                // Verify each selected input's txid matches what we'd expect
                // from the original request at that index
                for input in &inputs {
                    match input.index {
                        0 => assert_eq!(input.txid, "aaaa"),
                        1 => assert_eq!(input.txid, "bbbb"),
                        2 => assert_eq!(input.txid, "cccc"),
                        _ => panic!("Unexpected index {}", input.index),
                    }
                }
            }
            other => panic!("Expected Final, got {:?}", other),
        }
    }
}
