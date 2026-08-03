//! Post-sign verification of the transaction returned by the device.
//!
//! Port of `@trezor/connect`'s `verifyTx` (signtxVerify.ts): the serialized
//! transaction the device hands back is deserialized and cross-checked
//! against the requested inputs/outputs, so a buggy or malicious device
//! cannot silently alter amounts or destination scripts.

use bitcoin::{ScriptBuf, Transaction};

use crate::error::{BitcoinError, Result};
use crate::params::SignTxOutput;

/// Verify the device-returned serialized transaction against the requested
/// outputs and return the parsed transaction.
///
/// Checks, in order:
/// - the transaction deserializes
/// - input count matches the request
/// - output count matches the request
/// - every output amount matches the request (OP_RETURN outputs are 0)
/// - every output script matches its independently derived expectation,
///   where one exists (`None` entries, e.g. multisig outputs, are skipped)
pub(crate) fn verify_signed_tx(
    serialized_tx: &[u8],
    inputs_len: usize,
    outputs: &[SignTxOutput],
    expected_scripts: &[Option<ScriptBuf>],
) -> Result<Transaction> {
    let tx: Transaction = bitcoin::consensus::deserialize(serialized_tx).map_err(|e| {
        BitcoinError::InvalidTransaction(format!("Signed transaction failed to deserialize: {}", e))
    })?;

    if tx.input.len() != inputs_len {
        return Err(BitcoinError::InvalidTransaction(format!(
            "Signed transaction inputs invalid length: expected {}, got {}",
            inputs_len,
            tx.input.len()
        ))
        .into());
    }

    if tx.output.len() != outputs.len() {
        return Err(BitcoinError::InvalidTransaction(format!(
            "Signed transaction outputs invalid length: expected {}, got {}",
            outputs.len(),
            tx.output.len()
        ))
        .into());
    }

    for (i, (requested, actual)) in outputs.iter().zip(tx.output.iter()).enumerate() {
        let expected_amount = if requested.op_return_data.is_some() {
            0
        } else {
            requested.amount
        };
        if actual.value.to_sat() != expected_amount {
            return Err(BitcoinError::InvalidTransaction(format!(
                "Wrong output amount at output {}: requested {}, signed {}",
                i,
                expected_amount,
                actual.value.to_sat()
            ))
            .into());
        }

        if let Some(Some(expected_script)) = expected_scripts.get(i)
            && actual.script_pubkey != *expected_script
        {
            return Err(
                BitcoinError::InvalidTransaction(format!("Output {} scripts differ", i)).into(),
            );
        }
    }

    Ok(tx)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::bitcoin_utils::address_to_script;
    use crate::types::network::Network;
    use bitcoin::absolute::LockTime;
    use bitcoin::transaction::Version;
    use bitcoin::{Amount, OutPoint, Sequence, TxIn, TxOut, Txid};
    use std::str::FromStr;

    const DEST: &str = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4";

    fn dest_script() -> ScriptBuf {
        address_to_script(DEST, Network::Bitcoin).unwrap()
    }

    fn build_tx(outputs: Vec<TxOut>) -> Transaction {
        Transaction {
            version: Version::TWO,
            lock_time: LockTime::ZERO,
            input: vec![TxIn {
                previous_output: OutPoint::new(Txid::from_str(&"aa".repeat(32)).unwrap(), 0),
                script_sig: ScriptBuf::new(),
                sequence: Sequence(0xffffffff),
                witness: Default::default(),
            }],
            output: outputs,
        }
    }

    fn requested_output(amount: u64) -> SignTxOutput {
        SignTxOutput {
            address: Some(DEST.into()),
            path: None,
            amount,
            script_type: None,
            op_return_data: None,
            orig_hash: None,
            orig_index: None,
            multisig: None,
            payment_req_index: None,
        }
    }

    #[test]
    fn accepts_matching_tx_and_returns_it() {
        let tx = build_tx(vec![TxOut {
            value: Amount::from_sat(90_000),
            script_pubkey: dest_script(),
        }]);
        let bytes = bitcoin::consensus::serialize(&tx);

        let verified = verify_signed_tx(
            &bytes,
            1,
            &[requested_output(90_000)],
            &[Some(dest_script())],
        )
        .unwrap();
        assert_eq!(verified.compute_txid(), tx.compute_txid());
    }

    #[test]
    fn rejects_amount_mismatch() {
        let tx = build_tx(vec![TxOut {
            value: Amount::from_sat(80_000),
            script_pubkey: dest_script(),
        }]);
        let bytes = bitcoin::consensus::serialize(&tx);

        let err = verify_signed_tx(
            &bytes,
            1,
            &[requested_output(90_000)],
            &[Some(dest_script())],
        )
        .unwrap_err();
        assert!(err.to_string().contains("Wrong output amount"));
    }

    #[test]
    fn rejects_script_mismatch() {
        let other_script =
            address_to_script("1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH", Network::Bitcoin).unwrap();
        let tx = build_tx(vec![TxOut {
            value: Amount::from_sat(90_000),
            script_pubkey: other_script,
        }]);
        let bytes = bitcoin::consensus::serialize(&tx);

        let err = verify_signed_tx(
            &bytes,
            1,
            &[requested_output(90_000)],
            &[Some(dest_script())],
        )
        .unwrap_err();
        assert!(err.to_string().contains("scripts differ"));
    }

    #[test]
    fn skips_script_check_when_expectation_missing() {
        let other_script =
            address_to_script("1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH", Network::Bitcoin).unwrap();
        let tx = build_tx(vec![TxOut {
            value: Amount::from_sat(90_000),
            script_pubkey: other_script,
        }]);
        let bytes = bitcoin::consensus::serialize(&tx);

        assert!(verify_signed_tx(&bytes, 1, &[requested_output(90_000)], &[None]).is_ok());
    }

    #[test]
    fn rejects_output_count_mismatch() {
        let tx = build_tx(vec![TxOut {
            value: Amount::from_sat(90_000),
            script_pubkey: dest_script(),
        }]);
        let bytes = bitcoin::consensus::serialize(&tx);

        let err = verify_signed_tx(
            &bytes,
            1,
            &[requested_output(90_000), requested_output(10_000)],
            &[Some(dest_script()), None],
        )
        .unwrap_err();
        assert!(err.to_string().contains("outputs invalid length"));
    }

    #[test]
    fn rejects_input_count_mismatch() {
        let tx = build_tx(vec![TxOut {
            value: Amount::from_sat(90_000),
            script_pubkey: dest_script(),
        }]);
        let bytes = bitcoin::consensus::serialize(&tx);

        let err = verify_signed_tx(
            &bytes,
            2,
            &[requested_output(90_000)],
            &[Some(dest_script())],
        )
        .unwrap_err();
        assert!(err.to_string().contains("inputs invalid length"));
    }

    #[test]
    fn rejects_garbage_bytes() {
        assert!(verify_signed_tx(&[0xde, 0xad], 1, &[requested_output(1_000)], &[None]).is_err());
    }

    #[test]
    fn op_return_outputs_expect_zero_amount() {
        let op_return = crate::bitcoin_utils::op_return_script(b"data").unwrap();
        let tx = build_tx(vec![TxOut {
            value: Amount::from_sat(0),
            script_pubkey: op_return.clone(),
        }]);
        let bytes = bitcoin::consensus::serialize(&tx);

        let requested = SignTxOutput {
            address: None,
            path: None,
            amount: 0,
            script_type: None,
            op_return_data: Some(hex::encode(b"data")),
            orig_hash: None,
            orig_index: None,
            multisig: None,
            payment_req_index: None,
        };
        assert!(verify_signed_tx(&bytes, 1, &[requested], &[Some(op_return)]).is_ok());
    }
}
