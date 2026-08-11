//! Compose transaction API.
//!
//! Provides the precompose interface that takes UTXOs, desired outputs,
//! and fee levels, and returns composed transaction results for each fee level.

use serde::{Deserialize, Serialize};

use crate::compose::sorting::SortingStrategy;
use crate::compose::{
    self, ComposeError, ComposeInput, ComposeOutput as InternalComposeOutput, ComposeRequest,
    ComposeResult,
};
use crate::types::bitcoin::ScriptType;

/// Fee level for precompose.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeeLevel {
    /// Fee rate in sat/vB (as string for JS compatibility)
    pub fee_per_unit: String,
    /// Base fee in satoshis (optional, added to calculated fee)
    pub base_fee: Option<u64>,
    /// Whether to use floor for base fee calculation
    pub floor_base_fee: Option<bool>,
}

/// Account address for precompose.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountAddress {
    /// Bitcoin address
    pub address: String,
    /// BIP32 derivation path
    pub path: String,
    /// Number of transfers (used/unused detection)
    pub transfers: u32,
}

/// Account addresses grouped by type.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountAddresses {
    /// Used external addresses
    pub used: Vec<AccountAddress>,
    /// Unused external addresses
    pub unused: Vec<AccountAddress>,
    /// Change addresses
    pub change: Vec<AccountAddress>,
}

/// Account details for precompose.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComposeAccount {
    /// Account BIP32 path (e.g., "m/84'/0'/0'")
    pub path: String,
    /// Account addresses
    pub addresses: AccountAddresses,
    /// Available UTXOs
    pub utxo: Vec<ComposeUtxo>,
}

/// UTXO for precompose.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComposeUtxo {
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
    /// Whether this UTXO is owned by the account
    pub own: bool,
    /// Whether this UTXO must be included
    pub required: Option<bool>,
}

/// Output specification for precompose (matching JS API).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum PrecomposeOutput {
    /// Payment to a specific address
    #[serde(rename = "payment")]
    Payment { address: String, amount: String },
    /// Payment without address (estimation only)
    #[serde(rename = "payment-noaddress")]
    PaymentNoAddress { amount: String },
    /// Send all remaining funds to an address
    #[serde(rename = "send-max")]
    SendMax { address: String },
    /// Send all remaining funds (no address)
    #[serde(rename = "send-max-noaddress")]
    SendMaxNoAddress,
    /// OP_RETURN data
    #[serde(rename = "opreturn")]
    OpReturn { data_hex: String },
}

/// Parameters for precompose.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrecomposeParams {
    /// Desired outputs
    pub outputs: Vec<PrecomposeOutput>,
    /// Coin name (e.g., "Bitcoin")
    pub coin: String,
    /// Account with UTXOs and addresses
    pub account: ComposeAccount,
    /// Fee levels to evaluate
    pub fee_levels: Vec<FeeLevel>,
    /// Default sequence number
    pub sequence: Option<u32>,
    /// Sorting strategy
    pub sorting_strategy: Option<SortingStrategy>,
}

/// Precomposed transaction result (one per fee level).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum PrecomposedResult {
    /// Successfully composed a sendable transaction
    #[serde(rename = "final")]
    Final {
        total_spent: String,
        fee: String,
        fee_per_byte: String,
        bytes: usize,
        inputs: Vec<PrecomposedInput>,
        outputs: Vec<PrecomposedOutput>,
        outputs_permutation: Vec<usize>,
    },
    /// Non-final result (e.g., send-max estimation)
    #[serde(rename = "nonfinal")]
    NonFinal {
        max: Option<String>,
        total_spent: String,
        fee: String,
        fee_per_byte: String,
        bytes: usize,
    },
    /// Composition failed
    #[serde(rename = "error")]
    Error { error: String },
}

/// Input in a precomposed result.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrecomposedInput {
    pub txid: String,
    pub vout: u32,
    pub amount: String,
    pub address: String,
    pub path: String,
    pub script_type: ScriptType,
}

/// Output in a precomposed result.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum PrecomposedOutput {
    #[serde(rename = "payment")]
    Payment { address: String, amount: String },
    #[serde(rename = "change")]
    Change {
        address: String,
        path: String,
        amount: String,
        script_type: ScriptType,
    },
    #[serde(rename = "opreturn")]
    OpReturn { data_hex: String },
}

/// Convert a `PrecomposedInput` to a `SignTxInput` for device signing.
pub fn precomposed_input_to_sign_input(input: &PrecomposedInput) -> crate::params::SignTxInput {
    crate::params::SignTxInput {
        prev_hash: input.txid.clone(),
        prev_index: input.vout,
        path: input.path.clone(),
        amount: input.amount.parse().unwrap_or(0),
        script_type: input.script_type,
        sequence: None,
        orig_hash: None,
        orig_index: None,
        multisig: None,
        script_pubkey: None,
        script_sig: None,
        witness: None,
        ownership_proof: None,
        commitment_data: None,
    }
}

/// Convert a `PrecomposedOutput` to a `SignTxOutput` for device signing.
pub fn precomposed_output_to_sign_output(
    output: &PrecomposedOutput,
) -> crate::params::SignTxOutput {
    match output {
        PrecomposedOutput::Payment { address, amount } => crate::params::SignTxOutput {
            address: Some(address.clone()),
            path: None,
            amount: amount.parse().unwrap_or(0),
            script_type: None,
            op_return_data: None,
            orig_hash: None,
            orig_index: None,
            multisig: None,
            payment_req_index: None,
        },
        PrecomposedOutput::Change {
            address: _,
            path,
            amount,
            script_type,
        } => crate::params::SignTxOutput {
            address: None,
            path: Some(path.clone()),
            amount: amount.parse().unwrap_or(0),
            script_type: Some(*script_type),
            op_return_data: None,
            orig_hash: None,
            orig_index: None,
            multisig: None,
            payment_req_index: None,
        },
        PrecomposedOutput::OpReturn { data_hex } => crate::params::SignTxOutput {
            address: None,
            path: None,
            amount: 0,
            script_type: None,
            op_return_data: Some(data_hex.clone()),
            orig_hash: None,
            orig_index: None,
            multisig: None,
            payment_req_index: None,
        },
    }
}

/// Convert a Final precomposed result directly into SignTxParams for device signing.
///
/// This combines `precomposed_input_to_sign_input()` and `precomposed_output_to_sign_output()`
/// into a single call. The returned `SignTxParams` has empty `prev_txs` — the caller must
/// provide previous transaction data for non-SegWit inputs.
pub fn precomposed_final_to_sign_params(
    inputs: &[PrecomposedInput],
    outputs: &[PrecomposedOutput],
    coin: Option<crate::types::network::Network>,
) -> crate::params::SignTxParams {
    crate::params::SignTxParams {
        inputs: inputs.iter().map(precomposed_input_to_sign_input).collect(),
        outputs: outputs
            .iter()
            .map(precomposed_output_to_sign_output)
            .collect(),
        coin,
        ..Default::default()
    }
}

/// Infer the script type for an account from its path.
fn infer_change_script_type(account_path: &str) -> ScriptType {
    let parts: Vec<&str> = account_path.split('/').collect();
    if parts.len() >= 2 {
        let purpose = parts[1].trim_end_matches('\'').parse::<u32>().unwrap_or(84);
        match purpose {
            44 => ScriptType::SpendAddress,
            49 => ScriptType::SpendP2SHWitness,
            84 => ScriptType::SpendWitness,
            86 => ScriptType::SpendTaproot,
            _ => ScriptType::SpendWitness,
        }
    } else {
        ScriptType::SpendWitness
    }
}

/// Run precompose for multiple fee levels.
///
/// Returns one `PrecomposedResult` per fee level.
pub fn precompose(params: PrecomposeParams) -> Vec<PrecomposedResult> {
    let change_script_type = infer_change_script_type(&params.account.path);
    let sorting = params.sorting_strategy.unwrap_or_default();

    // Get the first unused change address
    let change_address = params
        .account
        .addresses
        .change
        .iter()
        .find(|a| a.transfers == 0)
        .or(params.account.addresses.change.first());

    params
        .fee_levels
        .iter()
        .map(|level| {
            let fee_rate: f64 = level.fee_per_unit.parse().unwrap_or(0.0);
            if fee_rate <= 0.0 || !fee_rate.is_finite() {
                return PrecomposedResult::Error {
                    error: ComposeError::IncorrectFeeRate.to_string(),
                };
            }

            // Convert UTXOs to ComposeInput — let coin selection algorithms handle input economics
            let inputs: Vec<ComposeInput> = params
                .account
                .utxo
                .iter()
                .map(|u| {
                    let required = u.required.unwrap_or(false);
                    ComposeInput {
                        txid: u.txid.clone(),
                        vout: u.vout,
                        amount: u.amount,
                        address: u.address.clone(),
                        path: u.path.clone(),
                        confirmations: u.confirmations,
                        coinbase: u.coinbase,
                        own: u.own,
                        required,
                        script_type: crate::compose::script_type_from_address(&u.address),
                    }
                })
                .collect();

            // Convert outputs
            let outputs: Vec<InternalComposeOutput> = params
                .outputs
                .iter()
                .map(|o| match o {
                    PrecomposeOutput::Payment { address, amount } => {
                        InternalComposeOutput::Payment {
                            address: address.clone(),
                            amount: amount.parse().unwrap_or(0),
                        }
                    }
                    PrecomposeOutput::PaymentNoAddress { amount } => {
                        InternalComposeOutput::PaymentNoAddress {
                            amount: amount.parse().unwrap_or(0),
                        }
                    }
                    PrecomposeOutput::SendMax { address } => InternalComposeOutput::SendMax {
                        address: address.clone(),
                    },
                    PrecomposeOutput::SendMaxNoAddress => InternalComposeOutput::SendMaxNoAddress,
                    PrecomposeOutput::OpReturn { data_hex } => InternalComposeOutput::OpReturn {
                        data_hex: data_hex.clone(),
                    },
                })
                .collect();

            let base_fee = level.base_fee.unwrap_or(0);

            let request = ComposeRequest {
                inputs,
                outputs,
                fee_rate,
                base_fee,
                change_script_type,
                sorting_strategy: sorting,
                sequence: params.sequence,
            };

            match compose::compose_tx(request) {
                ComposeResult::Final {
                    total_spent,
                    fee,
                    fee_per_byte,
                    bytes,
                    inputs,
                    outputs,
                    outputs_permutation,
                } => {
                    let precomposed_inputs: Vec<PrecomposedInput> = inputs
                        .iter()
                        .map(|i| PrecomposedInput {
                            txid: i.txid.clone(),
                            vout: i.vout,
                            amount: i.amount.to_string(),
                            address: i.address.clone(),
                            path: i.path.clone(),
                            script_type: i.script_type,
                        })
                        .collect();

                    let precomposed_outputs: Vec<PrecomposedOutput> = outputs
                        .iter()
                        .map(|o| match o {
                            compose::ComposedOutput::Payment { address, amount } => {
                                PrecomposedOutput::Payment {
                                    address: address.clone(),
                                    amount: amount.to_string(),
                                }
                            }
                            compose::ComposedOutput::Change {
                                amount,
                                script_type,
                                ..
                            } => {
                                let (addr, path) = change_address
                                    .map(|a| (a.address.clone(), a.path.clone()))
                                    .unwrap_or_default();
                                PrecomposedOutput::Change {
                                    address: addr,
                                    path,
                                    amount: amount.to_string(),
                                    script_type: *script_type,
                                }
                            }
                            compose::ComposedOutput::OpReturn { data_hex } => {
                                PrecomposedOutput::OpReturn {
                                    data_hex: data_hex.clone(),
                                }
                            }
                        })
                        .collect();

                    PrecomposedResult::Final {
                        total_spent: total_spent.to_string(),
                        fee: fee.to_string(),
                        fee_per_byte: fee_per_byte.to_string(),
                        bytes,
                        inputs: precomposed_inputs,
                        outputs: precomposed_outputs,
                        outputs_permutation,
                    }
                }
                ComposeResult::NonFinal {
                    max,
                    total_spent,
                    fee,
                    fee_per_byte,
                    bytes,
                } => PrecomposedResult::NonFinal {
                    max: max.map(|m| m.to_string()),
                    total_spent: total_spent.to_string(),
                    fee: fee.to_string(),
                    fee_per_byte: fee_per_byte.to_string(),
                    bytes,
                },
                ComposeResult::Error(e) => PrecomposedResult::Error {
                    error: e.to_string(),
                },
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    // ========================================================================
    // Test data from mnemonic: "wet sea trial spice sheriff bronze total swift slide near easily inhale"
    // Network: regtest, Account type: BIP84 native segwit (vpub)
    // Data captured from live Electrum query against funded testnet account.
    // ========================================================================

    fn test_account() -> ComposeAccount {
        ComposeAccount {
            path: "m/84'/1'/0'".to_string(),
            addresses: AccountAddresses {
                used: vec![AccountAddress {
                    address: "bcrt1qj2gz3meule5mc4r4knv65vjds3g88rlxs0jlmq".to_string(),
                    path: "m/84'/1'/0'/0/0".to_string(),
                    transfers: 2,
                }],
                unused: vec![
                    AccountAddress {
                        address: "bcrt1qeyn4amkfpuz589f6x7adzclqx98akv6mvzvndp".to_string(),
                        path: "m/84'/1'/0'/0/1".to_string(),
                        transfers: 0,
                    },
                    AccountAddress {
                        address: "bcrt1qfzj453cj7t0k723qu8r08u88jmhz22klpjqpl4".to_string(),
                        path: "m/84'/1'/0'/0/2".to_string(),
                        transfers: 0,
                    },
                ],
                change: vec![
                    AccountAddress {
                        address: "bcrt1q8lahff3lcealxhv2ygde4k08fsy0v5a95020r0".to_string(),
                        path: "m/84'/1'/0'/1/0".to_string(),
                        transfers: 0,
                    },
                    AccountAddress {
                        address: "bcrt1qxs4lm5m202w6ur6lluaesthq5de4v0vq7sqwvv".to_string(),
                        path: "m/84'/1'/0'/1/1".to_string(),
                        transfers: 0,
                    },
                ],
            },
            utxo: vec![
                ComposeUtxo {
                    txid: "559a6e22b4064c6d1dd3e1ec72a0f65e89093924aba760f7d71d6c4f551e99ba"
                        .to_string(),
                    vout: 1,
                    amount: 100_000,
                    address: "bcrt1qj2gz3meule5mc4r4knv65vjds3g88rlxs0jlmq".to_string(),
                    path: "m/84'/1'/0'/0/0".to_string(),
                    confirmations: 3684,
                    coinbase: false,
                    own: true,
                    required: None,
                },
                ComposeUtxo {
                    txid: "0374da2d0896160ba8dd53c1d727431afec2e325663f891308e427c7c3b81cd6"
                        .to_string(),
                    vout: 1,
                    amount: 100_000,
                    address: "bcrt1qj2gz3meule5mc4r4knv65vjds3g88rlxs0jlmq".to_string(),
                    path: "m/84'/1'/0'/0/0".to_string(),
                    confirmations: 3684,
                    coinbase: false,
                    own: true,
                    required: None,
                },
            ],
        }
    }

    fn test_prev_txs() -> Vec<crate::params::SignTxPrevTx> {
        use crate::params::{SignTxPrevTx, SignTxPrevTxInput, SignTxPrevTxOutput};
        vec![
            // prev_tx for UTXO txid=559a6e22...
            SignTxPrevTx {
                hash: "559a6e22b4064c6d1dd3e1ec72a0f65e89093924aba760f7d71d6c4f551e99ba"
                    .to_string(),
                version: 2,
                lock_time: 71691,
                inputs: vec![SignTxPrevTxInput {
                    prev_hash: "0f83ebcb66fe07a1cf9e2331cb12647bef185fd41810a948f951764c9fd7da63"
                        .to_string(),
                    prev_index: 0,
                    script_sig: "".to_string(),
                    sequence: 4294967294,
                }],
                outputs: vec![
                    SignTxPrevTxOutput {
                        amount: 507281,
                        script_pubkey: "0014003ab470c064ddebffd8daffb19a024359654e49".to_string(),
                    },
                    SignTxPrevTxOutput {
                        amount: 100000,
                        script_pubkey: "0014929028ef3cfe69bc5475b4d9aa324d8450738fe6".to_string(),
                    },
                ],
                extra_data: None,
            },
            // prev_tx for UTXO txid=0374da2d...
            SignTxPrevTx {
                hash: "0374da2d0896160ba8dd53c1d727431afec2e325663f891308e427c7c3b81cd6"
                    .to_string(),
                version: 2,
                lock_time: 71691,
                inputs: vec![SignTxPrevTxInput {
                    prev_hash: "92ca73996a1f249f41bf92db3ed225bdb81b1a5b757837691c3fc5afb3d1b991"
                        .to_string(),
                    prev_index: 1,
                    script_sig: "".to_string(),
                    sequence: 4294967294,
                }],
                outputs: vec![
                    SignTxPrevTxOutput {
                        amount: 5079580,
                        script_pubkey: "001450dee61e211dae0004cdefcd4296388a51e61864".to_string(),
                    },
                    SignTxPrevTxOutput {
                        amount: 100000,
                        script_pubkey: "0014929028ef3cfe69bc5475b4d9aa324d8450738fe6".to_string(),
                    },
                ],
                extra_data: None,
            },
        ]
    }

    /// Test that precompose produces a valid Final result using real regtest account data.
    /// No device needed — pure offline composition.
    #[test]
    fn test_precompose_with_real_regtest_data() {
        let params = PrecomposeParams {
            outputs: vec![
                // Send 50,000 sats to the first unused address
                PrecomposeOutput::Payment {
                    address: "bcrt1qeyn4amkfpuz589f6x7adzclqx98akv6mvzvndp".to_string(),
                    amount: "50000".to_string(),
                },
            ],
            coin: "Regtest".to_string(),
            account: test_account(),
            fee_levels: vec![FeeLevel {
                fee_per_unit: "2".to_string(),
                base_fee: None,
                floor_base_fee: None,
            }],
            sequence: None,
            sorting_strategy: Some(SortingStrategy::None),
        };

        let results = precompose(params);
        assert_eq!(results.len(), 1, "Expected one result per fee level");

        match &results[0] {
            PrecomposedResult::Final {
                total_spent,
                fee,
                inputs,
                outputs,
                ..
            } => {
                let total: u64 = total_spent.parse().unwrap();
                let fee_val: u64 = fee.parse().unwrap();

                assert!(fee_val > 0, "Fee should be > 0");
                assert_eq!(total, 50_000 + fee_val, "total_spent = amount + fee");
                assert!(!inputs.is_empty(), "Should have selected inputs");
                assert!(outputs.len() >= 1, "Should have at least one output");

                // Verify inputs are from our real UTXOs
                for input in inputs {
                    assert!(
                        input.txid
                            == "559a6e22b4064c6d1dd3e1ec72a0f65e89093924aba760f7d71d6c4f551e99ba"
                            || input.txid
                                == "0374da2d0896160ba8dd53c1d727431afec2e325663f891308e427c7c3b81cd6",
                        "Input should be from one of our known UTXOs"
                    );
                    assert_eq!(input.script_type, ScriptType::SpendWitness);
                }

                println!(
                    "Compose succeeded: total_spent={}, fee={}, inputs={}, outputs={}",
                    total_spent,
                    fee,
                    inputs.len(),
                    outputs.len()
                );
            }
            PrecomposedResult::Error { error } => panic!("Compose failed: {}", error),
            PrecomposedResult::NonFinal { .. } => panic!("Expected Final result"),
        }
    }

    /// Test that precompose + conversion to SignTxParams produces valid signing parameters.
    /// No device needed — verifies the full compose-to-sign-params pipeline.
    #[test]
    fn test_precompose_to_sign_params_conversion() {
        let params = PrecomposeParams {
            outputs: vec![PrecomposeOutput::Payment {
                address: "bcrt1qeyn4amkfpuz589f6x7adzclqx98akv6mvzvndp".to_string(),
                amount: "50000".to_string(),
            }],
            coin: "Regtest".to_string(),
            account: test_account(),
            fee_levels: vec![FeeLevel {
                fee_per_unit: "2".to_string(),
                base_fee: None,
                floor_base_fee: None,
            }],
            sequence: None,
            sorting_strategy: Some(SortingStrategy::None),
        };

        let results = precompose(params);
        let result = &results[0];

        match result {
            PrecomposedResult::Final {
                inputs, outputs, ..
            } => {
                // Convert to SignTxParams
                let sign_inputs: Vec<crate::params::SignTxInput> =
                    inputs.iter().map(precomposed_input_to_sign_input).collect();
                let sign_outputs: Vec<crate::params::SignTxOutput> = outputs
                    .iter()
                    .map(precomposed_output_to_sign_output)
                    .collect();

                let sign_params = crate::params::SignTxParams {
                    inputs: sign_inputs,
                    outputs: sign_outputs,
                    coin: Some(crate::types::network::Network::Regtest),
                    lock_time: None,
                    version: None,
                    prev_txs: test_prev_txs(),
                    amount_unit: None,
                    serialize: None,
                    chunkify: None,
                    unlock_path: None,
                    payment_requests: vec![],
                    ..Default::default()
                };

                // Validate the constructed params
                assert!(!sign_params.inputs.is_empty());
                assert!(!sign_params.outputs.is_empty());
                assert_eq!(sign_params.prev_txs.len(), 2);

                for input in &sign_params.inputs {
                    assert!(!input.prev_hash.is_empty());
                    assert!(input.amount > 0);
                    assert!(input.path.starts_with("m/84'/1'/0'"));
                    assert_eq!(input.script_type, ScriptType::SpendWitness);
                }

                // Check we have a payment output and possibly a change output
                let has_payment = sign_params.outputs.iter().any(|o| o.address.is_some());
                assert!(has_payment, "Should have at least one payment output");

                // If there's a change output, verify it has a path and script_type
                for output in &sign_params.outputs {
                    if output.path.is_some() {
                        assert!(
                            output.script_type.is_some(),
                            "Change output must have script_type"
                        );
                        assert!(
                            output.path.as_ref().unwrap().starts_with("m/84'/1'/0'/1/"),
                            "Change output path should be on the change chain"
                        );
                    }
                }

                println!(
                    "SignTxParams constructed: {} inputs, {} outputs, {} prev_txs",
                    sign_params.inputs.len(),
                    sign_params.outputs.len(),
                    sign_params.prev_txs.len()
                );
            }
            other => panic!("Expected Final, got {:?}", other),
        }
    }

    /// Test send-max with real regtest data.
    #[test]
    fn test_precompose_send_max_real_data() {
        let params = PrecomposeParams {
            outputs: vec![PrecomposeOutput::SendMax {
                address: "bcrt1qeyn4amkfpuz589f6x7adzclqx98akv6mvzvndp".to_string(),
            }],
            coin: "Regtest".to_string(),
            account: test_account(),
            fee_levels: vec![FeeLevel {
                fee_per_unit: "2".to_string(),
                base_fee: None,
                floor_base_fee: None,
            }],
            sequence: None,
            sorting_strategy: Some(SortingStrategy::None),
        };

        let results = precompose(params);
        match &results[0] {
            PrecomposedResult::Final {
                total_spent,
                fee,
                inputs,
                outputs,
                ..
            } => {
                let total: u64 = total_spent.parse().unwrap();
                let fee_val: u64 = fee.parse().unwrap();

                // Send-max should use all UTXOs (200,000 total)
                assert_eq!(total, 200_000, "Send-max should spend all funds");
                assert_eq!(inputs.len(), 2, "Send-max should use all UTXOs");
                assert_eq!(outputs.len(), 1, "Send-max should have no change output");

                // Verify the output amount = total - fee
                match &outputs[0] {
                    PrecomposedOutput::Payment { amount, .. } => {
                        let amt: u64 = amount.parse().unwrap();
                        assert_eq!(amt, 200_000 - fee_val);
                    }
                    other => panic!("Expected Payment output, got {:?}", other),
                }

                println!(
                    "Send-max: total={}, fee={}, output_amount={}",
                    total,
                    fee_val,
                    total - fee_val
                );
            }
            PrecomposedResult::Error { error } => panic!("Compose failed: {}", error),
            _ => panic!("Expected Final result for send-max"),
        }
    }

    /// Test multiple fee levels with real regtest data.
    #[test]
    fn test_precompose_multiple_fee_levels() {
        let params = PrecomposeParams {
            outputs: vec![PrecomposeOutput::Payment {
                address: "bcrt1qeyn4amkfpuz589f6x7adzclqx98akv6mvzvndp".to_string(),
                amount: "50000".to_string(),
            }],
            coin: "Regtest".to_string(),
            account: test_account(),
            fee_levels: vec![
                FeeLevel {
                    fee_per_unit: "1".to_string(),
                    base_fee: None,
                    floor_base_fee: None,
                },
                FeeLevel {
                    fee_per_unit: "5".to_string(),
                    base_fee: None,
                    floor_base_fee: None,
                },
                FeeLevel {
                    fee_per_unit: "20".to_string(),
                    base_fee: None,
                    floor_base_fee: None,
                },
            ],
            sequence: None,
            sorting_strategy: Some(SortingStrategy::None),
        };

        let results = precompose(params);
        assert_eq!(results.len(), 3);

        let mut prev_fee = 0u64;
        for (i, result) in results.iter().enumerate() {
            match result {
                PrecomposedResult::Final { fee, .. } => {
                    let fee_val: u64 = fee.parse().unwrap();
                    assert!(
                        fee_val > prev_fee,
                        "Fee level {} should be higher than previous",
                        i
                    );
                    prev_fee = fee_val;
                }
                PrecomposedResult::Error { error } => panic!("Fee level {} failed: {}", i, error),
                _ => panic!("Expected Final for fee level {}", i),
            }
        }
    }

    /// Full compose → sign integration test with a live Trezor device.
    ///
    /// Requirements:
    /// - Trezor device connected via USB
    /// - Device loaded with mnemonic: "wet sea trial spice sheriff bronze total swift slide near easily inhale"
    /// - No PIN set (or modify the UI callback below)
    ///
    /// Run with: cargo test --features psbt test_compose_and_sign_with_device -- --ignored --nocapture
    #[tokio::test]
    #[ignore]
    async fn test_compose_and_sign_with_device() {
        use crate::{PassphraseResponse, Trezor, TrezorUiCallback};
        use std::sync::Arc;

        struct TestUiCallback;
        impl TrezorUiCallback for TestUiCallback {
            fn on_pin_request(&self) -> Option<String> {
                println!("PIN requested - returning None (no PIN expected on test device)");
                None
            }
            fn on_passphrase_request(&self, on_device: bool) -> PassphraseResponse {
                if on_device {
                    println!("Passphrase on device requested");
                } else {
                    println!("Passphrase requested - returning Standard (no passphrase)");
                }
                PassphraseResponse::Standard
            }
        }

        // 1. Compose the transaction
        let compose_params = PrecomposeParams {
            outputs: vec![
                // Send 50,000 sats to the first unused address (self-send for safety)
                PrecomposeOutput::Payment {
                    address: "bcrt1qeyn4amkfpuz589f6x7adzclqx98akv6mvzvndp".to_string(),
                    amount: "50000".to_string(),
                },
            ],
            coin: "Regtest".to_string(),
            account: test_account(),
            fee_levels: vec![FeeLevel {
                fee_per_unit: "2".to_string(),
                base_fee: None,
                floor_base_fee: None,
            }],
            sequence: None,
            sorting_strategy: Some(SortingStrategy::None),
        };

        let results = precompose(compose_params);
        let result = &results[0];

        let (inputs, outputs) = match result {
            PrecomposedResult::Final {
                inputs,
                outputs,
                fee,
                total_spent,
                ..
            } => {
                println!(
                    "Composed: total_spent={}, fee={}, inputs={}, outputs={}",
                    total_spent,
                    fee,
                    inputs.len(),
                    outputs.len()
                );
                (inputs, outputs)
            }
            PrecomposedResult::Error { error } => panic!("Compose failed: {}", error),
            _ => panic!("Expected Final result"),
        };

        // 2. Convert compose result to SignTxParams
        let sign_inputs: Vec<crate::params::SignTxInput> =
            inputs.iter().map(precomposed_input_to_sign_input).collect();
        let sign_outputs: Vec<crate::params::SignTxOutput> = outputs
            .iter()
            .map(precomposed_output_to_sign_output)
            .collect();

        let sign_params = crate::params::SignTxParams {
            inputs: sign_inputs,
            outputs: sign_outputs,
            coin: Some(crate::types::network::Network::Regtest),
            lock_time: None,
            version: None,
            prev_txs: test_prev_txs(),
            amount_unit: None,
            serialize: None,
            chunkify: None,
            unlock_path: None,
            payment_requests: vec![],
            ..Default::default()
        };

        println!(
            "SignTxParams: {} inputs, {} outputs, {} prev_txs",
            sign_params.inputs.len(),
            sign_params.outputs.len(),
            sign_params.prev_txs.len()
        );

        // 3. Connect to device and sign
        let mut trezor = Trezor::new()
            .with_ui_callback(Arc::new(TestUiCallback))
            .build()
            .await
            .expect("Failed to build Trezor manager");

        println!("Scanning for devices...");
        let devices = trezor.scan().await.expect("Failed to scan for devices");
        assert!(
            !devices.is_empty(),
            "No Trezor devices found! Connect a device loaded with the test mnemonic."
        );

        println!("Connecting to {}...", devices[0].display_name());
        let mut device = trezor
            .connect(&devices[0])
            .await
            .expect("Failed to connect");

        let features = device
            .initialize()
            .await
            .expect("Failed to initialize device");
        println!(
            "Connected: {}",
            features.label.as_deref().unwrap_or("Unnamed")
        );

        // 4. Sign the transaction
        println!("Signing transaction... Please confirm on device.");
        let signed = device
            .sign_transaction(sign_params)
            .await
            .expect("Failed to sign transaction");

        println!("\nTransaction signed successfully!");
        println!("Signatures: {:?}", signed.signatures);
        println!("Serialized TX ({} bytes):", signed.serialized_tx.len() / 2);
        println!("{}", signed.serialized_tx);

        assert!(
            !signed.signatures.is_empty(),
            "Should have at least one signature"
        );
        assert!(
            !signed.serialized_tx.is_empty(),
            "Should have serialized transaction"
        );

        // Verify each signature is non-empty
        for (i, sig) in signed.signatures.iter().enumerate() {
            assert!(!sig.is_empty(), "Signature {} should be non-empty", i);
        }

        device.disconnect().await.expect("Failed to disconnect");
        println!("Test completed successfully!");
    }

    #[test]
    fn test_precomposed_final_to_sign_params() {
        let params = PrecomposeParams {
            outputs: vec![PrecomposeOutput::Payment {
                address: "bcrt1qeyn4amkfpuz589f6x7adzclqx98akv6mvzvndp".to_string(),
                amount: "50000".to_string(),
            }],
            coin: "Regtest".to_string(),
            account: test_account(),
            fee_levels: vec![FeeLevel {
                fee_per_unit: "2".to_string(),
                base_fee: None,
                floor_base_fee: None,
            }],
            sequence: None,
            sorting_strategy: Some(SortingStrategy::None),
        };

        let results = precompose(params);
        match &results[0] {
            PrecomposedResult::Final {
                inputs, outputs, ..
            } => {
                let sign_params = precomposed_final_to_sign_params(
                    inputs,
                    outputs,
                    Some(crate::types::network::Network::Regtest),
                );

                assert_eq!(sign_params.inputs.len(), inputs.len());
                assert_eq!(sign_params.outputs.len(), outputs.len());
                assert!(
                    sign_params.prev_txs.is_empty(),
                    "prev_txs should be empty by default"
                );
                assert_eq!(
                    sign_params.coin,
                    Some(crate::types::network::Network::Regtest)
                );

                for (sign_input, compose_input) in sign_params.inputs.iter().zip(inputs.iter()) {
                    assert_eq!(sign_input.prev_hash, compose_input.txid);
                    assert_eq!(sign_input.prev_index, compose_input.vout);
                    assert_eq!(sign_input.path, compose_input.path);
                    assert_eq!(sign_input.script_type, compose_input.script_type);
                }
            }
            other => panic!("Expected Final, got {:?}", other),
        }
    }
}
