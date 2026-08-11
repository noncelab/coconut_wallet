//! Bitcoin helpers shared by pre-sign validation and post-sign verification.
//!
//! Thin wrappers around the `bitcoin` crate: address parsing with network
//! checks, BIP-32 xpub decoding into the protobuf `HDNodeType` shape, and
//! recomputing the txid of a caller-supplied previous transaction.

use std::str::FromStr;

use bitcoin::absolute::LockTime;
use bitcoin::key::Secp256k1;
use bitcoin::script::PushBytesBuf;
use bitcoin::transaction::Version;
use bitcoin::{
    Address, Amount, OutPoint, PublicKey, ScriptBuf, Sequence, Transaction, TxIn, TxOut, Txid,
    XOnlyPublicKey,
};

use crate::error::{BitcoinError, DeviceError, Result};
use crate::params::{HDNodeType, SignTxPrevTx};
use crate::types::bitcoin::ScriptType;
use crate::types::network::Network;

/// Map the crate's network type onto the `bitcoin` crate's.
pub(crate) fn to_bitcoin_network(network: Network) -> bitcoin::Network {
    match network {
        Network::Bitcoin => bitcoin::Network::Bitcoin,
        Network::Testnet => bitcoin::Network::Testnet,
        Network::Regtest => bitcoin::Network::Regtest,
    }
}

/// Parse an address, require it to belong to `network`, and return its
/// scriptPubKey. Mirrors the address validation `@trezor/connect` performs on
/// external outputs before signing.
pub(crate) fn address_to_script(address: &str, network: Network) -> Result<ScriptBuf> {
    let parsed = Address::from_str(address)
        .map_err(|e| BitcoinError::InvalidAddress(format!("{}: {}", address, e)))?;
    let checked = parsed
        .require_network(to_bitcoin_network(network))
        .map_err(|_| BitcoinError::NetworkMismatch {
            expected: network.coin_name().to_string(),
            actual: format!("address {}", address),
        })?;
    Ok(checked.script_pubkey())
}

/// Decode a base58check xpub into the `HDNodeType` fields the device expects.
///
/// Accepts any BIP-32 version magic (xpub/ypub/zpub/tpub/upub/vpub) since the
/// device only consumes the raw node fields; this matches the JS
/// `convertMultisigPubKey` behavior of decoding the xpub client-side.
pub(crate) fn xpub_to_hd_node_type(xpub: &str) -> Result<HDNodeType> {
    let data = bitcoin::base58::decode_check(xpub)
        .map_err(|e| DeviceError::InvalidInput(format!("Invalid xpub {}: {}", xpub, e)))?;
    if data.len() != 78 {
        return Err(DeviceError::InvalidInput(format!(
            "Invalid xpub {}: expected 78 bytes, got {}",
            xpub,
            data.len()
        ))
        .into());
    }

    let public_key = data[45..78].to_vec();
    if public_key[0] != 0x02 && public_key[0] != 0x03 {
        return Err(DeviceError::InvalidInput(format!(
            "Invalid xpub {}: not a compressed public key (is this an xprv?)",
            xpub
        ))
        .into());
    }

    Ok(HDNodeType {
        depth: data[4] as u32,
        fingerprint: u32::from_be_bytes([data[5], data[6], data[7], data[8]]),
        child_num: u32::from_be_bytes([data[9], data[10], data[11], data[12]]),
        chain_code: data[13..45].to_vec(),
        public_key,
    })
}

/// Derive the scriptPubKey a single-sig output with the given script type and
/// compressed public key must serialize to. Returns `None` for script types
/// that can't be derived from one key (multisig, external), which callers
/// treat as "skip script verification for this output" like JS
/// `deriveOutputScript` does.
pub(crate) fn script_for_pubkey(
    public_key: &[u8],
    script_type: ScriptType,
) -> Result<Option<ScriptBuf>> {
    let pk = PublicKey::from_slice(public_key).map_err(|e| {
        BitcoinError::InvalidTransaction(format!("invalid device public key: {}", e))
    })?;

    let wpkh = || {
        pk.wpubkey_hash().map_err(|_| {
            BitcoinError::InvalidTransaction("device public key is uncompressed".to_string())
        })
    };

    let script = match script_type {
        ScriptType::SpendAddress => Some(ScriptBuf::new_p2pkh(&pk.pubkey_hash())),
        ScriptType::SpendWitness => Some(ScriptBuf::new_p2wpkh(&wpkh()?)),
        ScriptType::SpendP2SHWitness => {
            let redeem = ScriptBuf::new_p2wpkh(&wpkh()?);
            Some(ScriptBuf::new_p2sh(&redeem.script_hash()))
        }
        ScriptType::SpendTaproot => {
            let secp = Secp256k1::verification_only();
            let internal_key = XOnlyPublicKey::from(pk.inner);
            // BIP-86 key-path spend: tweak with an empty merkle root
            Some(ScriptBuf::new_p2tr(&secp, internal_key, None))
        }
        _ => None,
    };
    Ok(script)
}

/// Build the OP_RETURN scriptPubKey for the given data payload.
pub(crate) fn op_return_script(data: &[u8]) -> Result<ScriptBuf> {
    let push = PushBytesBuf::try_from(data.to_vec()).map_err(|_| {
        BitcoinError::InvalidTransaction("OP_RETURN data exceeds push limit".to_string())
    })?;
    Ok(ScriptBuf::new_op_return(&push))
}

/// Rebuild a caller-supplied previous transaction and return its txid
/// (display-order hex). Used to verify that the declared `hash` matches the
/// provided contents, like JS `transformReferencedTransactions` does via
/// `tx.getId()`.
///
/// Returns `None` when the prev tx carries `extra_data` (Zcash/Dash style),
/// since those serialize differently and this crate is Bitcoin-only.
pub(crate) fn compute_prev_txid(prev: &SignTxPrevTx) -> Result<Option<String>> {
    if prev.extra_data.is_some() {
        return Ok(None);
    }

    let input = |i: &crate::params::SignTxPrevTxInput| -> Result<TxIn> {
        let txid = Txid::from_str(&i.prev_hash).map_err(|e| {
            BitcoinError::InvalidTransaction(format!(
                "prev tx {}: invalid input prev_hash {}: {}",
                prev.hash, i.prev_hash, e
            ))
        })?;
        let script_sig = hex::decode(&i.script_sig).map_err(|e| {
            BitcoinError::InvalidTransaction(format!(
                "prev tx {}: invalid input script_sig hex: {}",
                prev.hash, e
            ))
        })?;
        Ok(TxIn {
            previous_output: OutPoint::new(txid, i.prev_index),
            script_sig: ScriptBuf::from_bytes(script_sig),
            sequence: Sequence(i.sequence),
            witness: Default::default(),
        })
    };

    let output = |o: &crate::params::SignTxPrevTxOutput| -> Result<TxOut> {
        let script_pubkey = hex::decode(&o.script_pubkey).map_err(|e| {
            BitcoinError::InvalidTransaction(format!(
                "prev tx {}: invalid output script_pubkey hex: {}",
                prev.hash, e
            ))
        })?;
        Ok(TxOut {
            value: Amount::from_sat(o.amount),
            script_pubkey: ScriptBuf::from_bytes(script_pubkey),
        })
    };

    let tx = Transaction {
        version: Version(prev.version as i32),
        lock_time: LockTime::from_consensus(prev.lock_time),
        input: prev.inputs.iter().map(input).collect::<Result<Vec<_>>>()?,
        output: prev
            .outputs
            .iter()
            .map(output)
            .collect::<Result<Vec<_>>>()?,
    };

    Ok(Some(tx.compute_txid().to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::error::TrezorError;
    use crate::params::{SignTxPrevTxInput, SignTxPrevTxOutput};

    // BIP-32 test vector 1: master key of seed 000102030405060708090a0b0c0d0e0f
    const VECTOR1_MASTER_XPUB: &str = "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8";
    // BIP-32 test vector 1: m/0'/1/2'
    const VECTOR1_M_0H_1_2H_XPUB: &str = "xpub6D4BDPcP2GT577Vvch3R8wDkScZWzQzMMUm3PWbmWvVJrZwQY4VUNgqFJPMM3No2dFDFGTsxxpG5uJh7n7epu4trkrX7x7DogT5Uv6fcLW5";

    #[test]
    fn xpub_decodes_bip32_vector1_master() {
        let node = xpub_to_hd_node_type(VECTOR1_MASTER_XPUB).unwrap();
        assert_eq!(node.depth, 0);
        assert_eq!(node.fingerprint, 0);
        assert_eq!(node.child_num, 0);
        assert_eq!(node.chain_code.len(), 32);
        assert_eq!(node.public_key.len(), 33);
        assert_eq!(
            hex::encode(&node.public_key),
            "0339a36013301597daef41fbe593a02cc513d0b55527ec2df1050e2e8ff49c85c2"
        );
    }

    #[test]
    fn xpub_decodes_bip32_vector1_child() {
        let node = xpub_to_hd_node_type(VECTOR1_M_0H_1_2H_XPUB).unwrap();
        assert_eq!(node.depth, 3);
        // child_num of m/0'/1/2' is 2 hardened
        assert_eq!(node.child_num, 2 + 0x80000000);
        assert_eq!(node.public_key.len(), 33);
    }

    #[test]
    fn xpub_rejects_garbage() {
        assert!(xpub_to_hd_node_type("not-an-xpub").is_err());
        // valid base58check but wrong payload length (a P2PKH address)
        assert!(xpub_to_hd_node_type("1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH").is_err());
    }

    #[test]
    fn address_to_script_accepts_all_types_on_the_right_network() {
        // P2PKH
        assert!(address_to_script("1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH", Network::Bitcoin).is_ok());
        // P2SH
        assert!(address_to_script("3P14159f73E4gFr7JterCCQh9QjiTjiZrG", Network::Bitcoin).is_ok());
        // P2WPKH
        assert!(
            address_to_script(
                "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
                Network::Bitcoin
            )
            .is_ok()
        );
        // P2TR
        assert!(
            address_to_script(
                "bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr",
                Network::Bitcoin
            )
            .is_ok()
        );
        // Testnet bech32
        assert!(
            address_to_script(
                "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
                Network::Testnet
            )
            .is_ok()
        );
        // Regtest bech32
        assert!(
            address_to_script(
                "bcrt1qw508d6qejxtdg4y5r3zarvary0c5xw7kygt080",
                Network::Regtest
            )
            .is_ok()
        );
    }

    #[test]
    fn address_to_script_rejects_wrong_network() {
        let err = address_to_script(
            "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
            Network::Bitcoin,
        )
        .unwrap_err();
        assert!(matches!(
            err,
            TrezorError::Bitcoin(BitcoinError::NetworkMismatch { .. })
        ));
    }

    #[test]
    fn address_to_script_rejects_bad_checksum() {
        assert!(address_to_script("1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMI", Network::Bitcoin).is_err());
        assert!(
            address_to_script(
                "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5",
                Network::Bitcoin
            )
            .is_err()
        );
    }

    #[test]
    fn compute_prev_txid_matches_known_tx() {
        // Genesis-block coinbase transaction of Bitcoin mainnet
        let prev = SignTxPrevTx {
            hash: "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b".into(),
            version: 1,
            lock_time: 0,
            inputs: vec![SignTxPrevTxInput {
                prev_hash: "0000000000000000000000000000000000000000000000000000000000000000"
                    .into(),
                prev_index: 0xffffffff,
                script_sig: "04ffff001d0104455468652054696d65732030332f4a616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f66207365636f6e64206261696c6f757420666f722062616e6b73".into(),
                sequence: 0xffffffff,
            }],
            outputs: vec![SignTxPrevTxOutput {
                amount: 5_000_000_000,
                script_pubkey: "4104678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5fac".into(),
            }],
            extra_data: None,
        };
        let txid = compute_prev_txid(&prev).unwrap().unwrap();
        assert_eq!(txid, prev.hash);
    }

    #[test]
    fn script_for_pubkey_matches_bip173_p2wpkh_vector() {
        // BIP-173 example: P2WPKH of the secp256k1 generator point
        let pubkey =
            hex::decode("0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
                .unwrap();
        let script = script_for_pubkey(&pubkey, ScriptType::SpendWitness)
            .unwrap()
            .unwrap();
        let expected = address_to_script(
            "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            Network::Bitcoin,
        )
        .unwrap();
        assert_eq!(script, expected);
    }

    #[test]
    fn script_for_pubkey_matches_bip86_p2tr_vector() {
        // BIP-86 test vector: account 0, first receiving address
        let pubkey =
            hex::decode("03cc8a4bc64d897bddc5fbc2f670f7a8ba0b386779106cf1223c6fc5d7cd6fc115")
                .unwrap();
        let script = script_for_pubkey(&pubkey, ScriptType::SpendTaproot)
            .unwrap()
            .unwrap();
        let expected = address_to_script(
            "bc1p5cyxnuxmeuwuvkwfem96lqzszd02n6xdcjrs20cac6yqjjwudpxqkedrcr",
            Network::Bitcoin,
        )
        .unwrap();
        assert_eq!(script, expected);
    }

    #[test]
    fn script_for_pubkey_p2pkh_and_nested_segwit_are_consistent() {
        let pubkey =
            hex::decode("0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
                .unwrap();
        let p2pkh = script_for_pubkey(&pubkey, ScriptType::SpendAddress)
            .unwrap()
            .unwrap();
        assert!(p2pkh.is_p2pkh());
        let nested = script_for_pubkey(&pubkey, ScriptType::SpendP2SHWitness)
            .unwrap()
            .unwrap();
        assert!(nested.is_p2sh());
    }

    #[test]
    fn script_for_pubkey_skips_underivable_types() {
        let pubkey =
            hex::decode("0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798")
                .unwrap();
        assert_eq!(
            script_for_pubkey(&pubkey, ScriptType::External).unwrap(),
            None
        );
    }

    #[test]
    fn op_return_script_embeds_data() {
        let script = op_return_script(b"hello").unwrap();
        assert!(script.is_op_return());
    }

    #[test]
    fn compute_prev_txid_skips_extra_data_txs() {
        let prev = SignTxPrevTx {
            hash: "00".repeat(32),
            version: 1,
            lock_time: 0,
            inputs: vec![],
            outputs: vec![],
            extra_data: Some("aabb".into()),
        };
        assert_eq!(compute_prev_txid(&prev).unwrap(), None);
    }
}
