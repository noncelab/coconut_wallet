//! PSBT conversion utilities for Trezor signing.
//!
//! Converts between Bitcoin PSBTs and the Trezor signing parameter types.
//! Requires the `psbt` feature flag.

use bitcoin::psbt::Psbt;

use crate::error::{DeviceError, Result};
use crate::params::{
    SignTxInput, SignTxOutput, SignTxParams, SignTxPrevTx, SignTxPrevTxInput, SignTxPrevTxOutput,
};
use crate::responses::SignedTxResponse;
use crate::types::bitcoin::ScriptType;
use crate::types::network::Network;

const HARDENED: u32 = 0x80000000;

/// Convert a PSBT (raw bytes) to `SignTxParams` for Trezor signing.
///
/// Extracts inputs, outputs, and previous transactions from the PSBT.
/// For each input, determines the script type from the derivation path purpose.
/// For each output, checks if it's a change output (has BIP32 derivation info)
/// or an external output.
///
/// The `network` parameter controls address derivation and the coin name sent
/// to the device. Use `bitcoin::Network::Bitcoin` for mainnet,
/// `bitcoin::Network::Testnet` for testnet, etc.
pub fn psbt_to_sign_tx_params(
    psbt_bytes: &[u8],
    network: bitcoin::Network,
) -> Result<SignTxParams> {
    let psbt = Psbt::deserialize(psbt_bytes)
        .map_err(|e| DeviceError::InvalidInput(format!("Invalid PSBT: {}", e)))?;

    let unsigned_tx = &psbt.unsigned_tx;

    // Build inputs
    let mut inputs = Vec::with_capacity(unsigned_tx.input.len());
    let mut prev_txs_map = std::collections::HashMap::new();

    for (i, tx_input) in unsigned_tx.input.iter().enumerate() {
        let psbt_input = psbt.inputs.get(i).ok_or_else(|| {
            DeviceError::InvalidInput(format!("PSBT missing input data for index {}", i))
        })?;

        let prev_hash = tx_input.previous_output.txid.to_string();
        let prev_index = tx_input.previous_output.vout;
        let sequence = tx_input.sequence.0;

        // Extract derivation path from bip32_derivation (first key)
        let (path_str, script_type) =
            if let Some((_, (_, derivation))) = psbt_input.bip32_derivation.iter().next() {
                let path = format_derivation_path(derivation);
                let st = infer_script_type_from_path(derivation);
                (path, st)
            } else if let Some((_, (_, derivation))) = psbt_input.tap_key_origins.iter().next() {
                let path = format_derivation_path(&derivation.1);
                (path, ScriptType::SpendTaproot)
            } else {
                ("m/84'/0'/0'/0/0".to_string(), ScriptType::SpendWitness)
            };

        // Extract amount from witness_utxo or non_witness_utxo
        let amount = if let Some(ref witness_utxo) = psbt_input.witness_utxo {
            witness_utxo.value.to_sat()
        } else if let Some(ref non_witness_utxo) = psbt_input.non_witness_utxo {
            non_witness_utxo.output[prev_index as usize].value.to_sat()
        } else {
            return Err(DeviceError::InvalidInput(format!(
                "Input {}: missing both witness_utxo and non_witness_utxo",
                i
            ))
            .into());
        };

        // Extract the full previous transaction for Trezor verification.
        // Trezor requires prev_txs for ALL inputs (including SegWit) to
        // verify input amounts and prevent fee attacks.
        if let Some(ref non_witness_utxo) = psbt_input.non_witness_utxo {
            let txid = tx_input.previous_output.txid.to_string();
            prev_txs_map.entry(txid.clone()).or_insert_with(|| {
                let prev_inputs = non_witness_utxo
                    .input
                    .iter()
                    .map(|inp| SignTxPrevTxInput {
                        prev_hash: inp.previous_output.txid.to_string(),
                        prev_index: inp.previous_output.vout,
                        script_sig: hex::encode(inp.script_sig.as_bytes()),
                        sequence: inp.sequence.0,
                    })
                    .collect();
                let prev_outputs = non_witness_utxo
                    .output
                    .iter()
                    .map(|out| SignTxPrevTxOutput {
                        amount: out.value.to_sat(),
                        script_pubkey: hex::encode(out.script_pubkey.as_bytes()),
                    })
                    .collect();
                SignTxPrevTx {
                    hash: txid,
                    version: non_witness_utxo.version.0 as u32,
                    lock_time: non_witness_utxo.lock_time.to_consensus_u32(),
                    inputs: prev_inputs,
                    outputs: prev_outputs,
                    extra_data: None,
                }
            });
        }

        inputs.push(SignTxInput {
            prev_hash,
            prev_index,
            path: path_str,
            amount,
            script_type,
            sequence: Some(sequence),
            orig_hash: None,
            orig_index: None,
            multisig: None,
            script_pubkey: None,
            script_sig: None,
            witness: None,
            ownership_proof: None,
            commitment_data: None,
        });
    }

    // Build outputs
    let mut outputs = Vec::with_capacity(unsigned_tx.output.len());
    for (i, tx_output) in unsigned_tx.output.iter().enumerate() {
        let psbt_output = psbt.outputs.get(i);

        // Check if this is a change output (has bip32 derivation)
        let is_change = psbt_output
            .map(|o| !o.bip32_derivation.is_empty() || !o.tap_key_origins.is_empty())
            .unwrap_or(false);

        if is_change {
            let psbt_out = psbt_output.unwrap();
            let (path_str, script_type) =
                if let Some((_, (_, derivation))) = psbt_out.bip32_derivation.iter().next() {
                    let path = format_derivation_path(derivation);
                    let st = infer_script_type_from_path(derivation);
                    (path, st)
                } else if let Some((_, (_, derivation))) = psbt_out.tap_key_origins.iter().next() {
                    let path = format_derivation_path(&derivation.1);
                    (path, ScriptType::SpendTaproot)
                } else {
                    unreachable!()
                };

            outputs.push(SignTxOutput {
                address: None,
                path: Some(path_str),
                amount: tx_output.value.to_sat(),
                script_type: Some(script_type),
                op_return_data: None,
                orig_hash: None,
                orig_index: None,
                multisig: None,
                payment_req_index: None,
            });
        } else if tx_output.script_pubkey.is_op_return() {
            // OP_RETURN output
            let data = if tx_output.script_pubkey.len() > 2 {
                // Skip OP_RETURN and push opcode
                hex::encode(&tx_output.script_pubkey.as_bytes()[2..])
            } else {
                String::new()
            };
            outputs.push(SignTxOutput {
                address: None,
                path: None,
                amount: 0,
                script_type: None,
                op_return_data: Some(data),
                orig_hash: None,
                orig_index: None,
                multisig: None,
                payment_req_index: None,
            });
        } else {
            // External output - extract address from script_pubkey
            let address = bitcoin::Address::from_script(&tx_output.script_pubkey, network)
                .map(|a| a.to_string())
                .map_err(|e| {
                    DeviceError::InvalidInput(format!("Output {}: cannot derive address: {}", i, e))
                })?;

            outputs.push(SignTxOutput {
                address: Some(address),
                path: None,
                amount: tx_output.value.to_sat(),
                script_type: None,
                op_return_data: None,
                orig_hash: None,
                orig_index: None,
                multisig: None,
                payment_req_index: None,
            });
        }
    }

    let prev_txs: Vec<SignTxPrevTx> = prev_txs_map.into_values().collect();

    let coin = match network {
        bitcoin::Network::Bitcoin => Network::Bitcoin,
        bitcoin::Network::Testnet | bitcoin::Network::Signet => Network::Testnet,
        bitcoin::Network::Regtest => Network::Regtest,
        _ => Network::Bitcoin,
    };

    Ok(SignTxParams {
        inputs,
        outputs,
        coin: Some(coin),
        lock_time: Some(unsigned_tx.lock_time.to_consensus_u32()),
        version: Some(unsigned_tx.version.0 as u32),
        prev_txs,
        amount_unit: None,
        serialize: None,
        chunkify: None,
        unlock_path: None,
        payment_requests: vec![],
        ..Default::default()
    })
}

/// Apply Trezor signatures back into a PSBT.
///
/// Takes the original PSBT bytes and the signed transaction response,
/// inserting signatures into the PSBT's partial_sigs fields (ECDSA)
/// or tap_key_sig field (Taproot/Schnorr).
pub fn apply_signatures_to_psbt(
    psbt_bytes: &[u8],
    signed_tx: &SignedTxResponse,
) -> Result<Vec<u8>> {
    let mut psbt = Psbt::deserialize(psbt_bytes)
        .map_err(|e| DeviceError::InvalidInput(format!("Invalid PSBT: {}", e)))?;

    for (i, sig_hex) in signed_tx.signatures.iter().enumerate() {
        if sig_hex.is_empty() {
            continue;
        }
        if i >= psbt.inputs.len() {
            break;
        }

        let sig_bytes = hex::decode(sig_hex)
            .map_err(|e| DeviceError::InvalidInput(format!("Invalid signature hex: {}", e)))?;

        if let Some((pubkey, _)) = psbt.inputs[i].bip32_derivation.iter().next() {
            // ECDSA input: insert into partial_sigs
            let pk = bitcoin::PublicKey::new(*pubkey);
            let ecdsa_sig = bitcoin::ecdsa::Signature::from_slice(&sig_bytes).map_err(|e| {
                DeviceError::InvalidInput(format!("Invalid ECDSA signature: {}", e))
            })?;
            psbt.inputs[i].partial_sigs.insert(pk, ecdsa_sig);
        } else if !psbt.inputs[i].tap_key_origins.is_empty() {
            // Taproot input: insert into tap_key_sig
            let tap_sig = bitcoin::taproot::Signature::from_slice(&sig_bytes).map_err(|e| {
                DeviceError::InvalidInput(format!("Invalid Taproot signature: {}", e))
            })?;
            psbt.inputs[i].tap_key_sig = Some(tap_sig);
        }
    }

    Ok(psbt.serialize())
}

/// Format a BIP32 derivation path as a string (e.g., "m/84'/0'/0'/0/0").
fn format_derivation_path(path: &bitcoin::bip32::DerivationPath) -> String {
    let mut result = "m".to_string();
    for child in path.into_iter() {
        if child.is_hardened() {
            result.push_str(&format!("/{}'", u32::from(*child) & !HARDENED));
        } else {
            result.push_str(&format!("/{}", u32::from(*child)));
        }
    }
    result
}

/// Infer script type from derivation path purpose field.
fn infer_script_type_from_path(path: &bitcoin::bip32::DerivationPath) -> ScriptType {
    let first = path.into_iter().next();
    match first {
        Some(child) => {
            let purpose = u32::from(*child) & !HARDENED;
            match purpose {
                44 => ScriptType::SpendAddress,
                49 => ScriptType::SpendP2SHWitness,
                84 => ScriptType::SpendWitness,
                86 => ScriptType::SpendTaproot,
                _ => ScriptType::SpendWitness,
            }
        }
        None => ScriptType::SpendWitness,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_infer_script_type_from_purpose() {
        use bitcoin::bip32::DerivationPath;
        use std::str::FromStr;

        let path = DerivationPath::from_str("m/84'/0'/0'/0/0").unwrap();
        assert_eq!(infer_script_type_from_path(&path), ScriptType::SpendWitness);

        let path = DerivationPath::from_str("m/44'/0'/0'/0/0").unwrap();
        assert_eq!(infer_script_type_from_path(&path), ScriptType::SpendAddress);

        let path = DerivationPath::from_str("m/49'/0'/0'/0/0").unwrap();
        assert_eq!(
            infer_script_type_from_path(&path),
            ScriptType::SpendP2SHWitness
        );

        let path = DerivationPath::from_str("m/86'/0'/0'/0/0").unwrap();
        assert_eq!(infer_script_type_from_path(&path), ScriptType::SpendTaproot);
    }
}
