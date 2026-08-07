//! Parameter types for Trezor API methods.
//!
//! These types match the trezor-suite API patterns for consistency.

use crate::types::bitcoin::{AmountUnit, ScriptType};
use crate::types::network::Network;
use serde::{Deserialize, Serialize};

/// Parameters for getting an address from the device.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct GetAddressParams {
    /// BIP32 path (e.g., "m/84'/0'/0'/0/0")
    pub path: String,
    /// Coin network (default: Bitcoin)
    pub coin: Option<Network>,
    /// Whether to display the address on the device for confirmation
    pub show_on_trezor: bool,
    /// Script type (auto-detected from path if not specified)
    pub script_type: Option<ScriptType>,
    /// Multisig configuration (for multisig addresses)
    pub multisig: Option<MultisigConfig>,
    /// Display the address in chunks of 4 characters on the device
    /// (firmware 2.6.3+)
    pub chunkify: Option<bool>,
    /// Expected address. When set together with `show_on_trezor`, the device
    /// derivation is compared against it before display and
    /// `DeviceError::AddressMismatch` is returned on mismatch.
    pub address: Option<String>,
}

/// Parameters for getting a public key from the device.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct GetPublicKeyParams {
    /// BIP32 path (e.g., "m/84'/0'/0'")
    pub path: String,
    /// Coin network (default: Bitcoin)
    pub coin: Option<Network>,
    /// Whether to display on device for confirmation
    pub show_on_trezor: bool,
    /// Script type (auto-detected from path if not specified)
    pub script_type: Option<ScriptType>,
}

/// Parameters for signing a message.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SignMessageParams {
    /// BIP32 path for the signing key
    pub path: String,
    /// Message to sign
    pub message: String,
    /// Coin network (default: Bitcoin)
    pub coin: Option<Network>,
    /// If true, don't include script type in the signature
    pub no_script_type: bool,
    /// Display the address in chunks of 4 characters on the device
    /// (firmware 2.6.3+)
    pub chunkify: Option<bool>,
}

/// Parameters for verifying a message signature.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct VerifyMessageParams {
    /// Bitcoin address that signed the message
    pub address: String,
    /// Signature (base64 encoded)
    pub signature: String,
    /// Original message
    pub message: String,
    /// Coin network (default: Bitcoin)
    pub coin: Option<Network>,
    /// Display the address in chunks of 4 characters on the device
    /// (firmware 2.6.3+)
    pub chunkify: Option<bool>,
}

/// Multisig configuration.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MultisigConfig {
    /// Required number of signatures (m of n)
    pub m: u32,
    /// List of public keys (HDNode structures)
    pub pubkeys: Vec<MultisigPubkey>,
    /// Signatures (optional, for partially signed transactions)
    pub signatures: Option<Vec<String>>,
}

/// Public key for multisig.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MultisigPubkey {
    /// Node containing the public key
    pub node: Option<HDNodeType>,
    /// Extended public key (xpub)
    pub xpub: Option<String>,
    /// Address derivation path relative to the node
    pub address_n: Vec<u32>,
}

/// HD node type for public key representation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HDNodeType {
    /// Depth in the derivation path
    pub depth: u32,
    /// Fingerprint of the parent key
    pub fingerprint: u32,
    /// Child number
    pub child_num: u32,
    /// Chain code (32 bytes)
    pub chain_code: Vec<u8>,
    /// Public key (33 bytes, compressed)
    pub public_key: Vec<u8>,
}

/// Transaction input for signing.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignTxInput {
    /// Previous transaction hash (hex, 32 bytes)
    pub prev_hash: String,
    /// Previous output index
    pub prev_index: u32,
    /// BIP32 derivation path (e.g., "m/84'/0'/0'/0/0")
    /// For EXTERNAL inputs, this can be empty.
    pub path: String,
    /// Amount in satoshis
    pub amount: u64,
    /// Script type
    pub script_type: ScriptType,
    /// Sequence number. Omitted when unset, so firmware applies its
    /// 0xFFFFFFFF (final) default, matching @trezor/connect. Set 0xFFFFFFFD
    /// to opt in to RBF.
    pub sequence: Option<u32>,
    /// Original transaction hash for RBF replacement (hex encoded)
    pub orig_hash: Option<String>,
    /// Original input index for RBF replacement
    pub orig_index: Option<u32>,
    /// Multisig configuration (for multisig inputs)
    pub multisig: Option<MultisigConfig>,
    /// Script pubkey of the previous output (hex, required for EXTERNAL inputs)
    pub script_pubkey: Option<String>,
    /// Script signature (hex, optional for EXTERNAL inputs)
    pub script_sig: Option<String>,
    /// Witness data (hex, optional for EXTERNAL inputs)
    pub witness: Option<String>,
    /// SLIP-0019 proof of ownership (hex, optional for EXTERNAL inputs)
    pub ownership_proof: Option<String>,
    /// Commitment data for SLIP-0019 proof (hex, optional for EXTERNAL inputs)
    pub commitment_data: Option<String>,
}

/// Transaction output for signing.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignTxOutput {
    /// Destination address (for external outputs)
    pub address: Option<String>,
    /// BIP32 path (for change outputs)
    pub path: Option<String>,
    /// Amount in satoshis
    pub amount: u64,
    /// Script type (for change outputs)
    pub script_type: Option<ScriptType>,
    /// OP_RETURN data (hex encoded, for data outputs)
    pub op_return_data: Option<String>,
    /// Original transaction hash for RBF replacement (hex encoded)
    pub orig_hash: Option<String>,
    /// Original output index for RBF replacement
    pub orig_index: Option<u32>,
    /// Multisig configuration (for multisig outputs)
    pub multisig: Option<MultisigConfig>,
    /// Index of the PaymentRequest containing this output
    pub payment_req_index: Option<u32>,
}

/// Previous transaction data (for non-SegWit input verification).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignTxPrevTx {
    /// Transaction hash (hex encoded)
    pub hash: String,
    /// Transaction version
    pub version: u32,
    /// Lock time
    pub lock_time: u32,
    /// Transaction inputs
    pub inputs: Vec<SignTxPrevTxInput>,
    /// Transaction outputs
    pub outputs: Vec<SignTxPrevTxOutput>,
    /// Extra data (hex encoded, for Zcash/Dash)
    pub extra_data: Option<String>,
}

/// Input of a previous transaction.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignTxPrevTxInput {
    /// Previous transaction hash (hex encoded)
    pub prev_hash: String,
    /// Previous output index
    pub prev_index: u32,
    /// Script signature (hex encoded)
    pub script_sig: String,
    /// Sequence number
    pub sequence: u32,
}

/// Output of a previous transaction.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignTxPrevTxOutput {
    /// Amount in satoshis
    pub amount: u64,
    /// Script pubkey (hex encoded)
    pub script_pubkey: String,
}

/// UnlockPath configuration for unlocking a keychain subtree before signing.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UnlockPath {
    /// Prefix of the BIP-32 path leading to the account (m / purpose')
    pub address_n: Vec<u32>,
    /// MAC returned by a previous UnlockedPathRequest
    pub mac: Option<String>,
}

/// Payment request memo types (SLIP-24).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaymentRequestMemo {
    /// Text memo
    pub text_memo: Option<TextMemo>,
    /// Refund memo
    pub refund_memo: Option<RefundMemo>,
    /// Coin purchase memo
    pub coin_purchase_memo: Option<CoinPurchaseMemo>,
}

/// Text memo for payment request.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TextMemo {
    /// Plain-text note
    pub text: String,
}

/// Refund memo for payment request.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefundMemo {
    /// Refund address
    pub address: String,
    /// BIP-32 path to derive the key
    pub address_n: Vec<u32>,
    /// MAC returned by GetAddress
    pub mac: String,
}

/// Coin purchase memo for payment request.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CoinPurchaseMemo {
    /// SLIP-0044 coin type
    pub coin_type: u32,
    /// Amount as human-readable string (e.g., "0.025 BTC")
    pub amount: String,
    /// Delivery address
    pub address: String,
    /// BIP-32 path to derive the key
    pub address_n: Vec<u32>,
    /// MAC returned by GetAddress
    pub mac: String,
}

/// SLIP-24 payment request.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaymentRequest {
    /// Merchant/recipient name
    pub recipient_name: String,
    /// Nonce used in signature computation (hex encoded)
    pub nonce: Option<String>,
    /// Memos signed as part of the request
    pub memos: Vec<PaymentRequestMemo>,
    /// Sum of external output amounts (little-endian encoded)
    pub amount: Option<u64>,
    /// Trusted party's signature of the payment request digest (hex encoded)
    pub signature: String,
}

/// Parameters for signing a transaction.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SignTxParams {
    /// Transaction inputs
    pub inputs: Vec<SignTxInput>,
    /// Transaction outputs
    pub outputs: Vec<SignTxOutput>,
    /// Coin network (default: Bitcoin)
    pub coin: Option<Network>,
    /// Lock time (default: 0)
    pub lock_time: Option<u32>,
    /// Version (default: 2)
    pub version: Option<u32>,
    /// Previous transactions (for non-SegWit input verification)
    pub prev_txs: Vec<SignTxPrevTx>,
    /// Ignored. This crate has no blockchain backend, so the signed
    /// transaction is never broadcast; `txid` is computed locally instead.
    /// Broadcast through your own chain source.
    #[deprecated(note = "No broadcast backend in this crate; the field is ignored")]
    pub push: Option<bool>,
    /// Display unit on device
    pub amount_unit: Option<AmountUnit>,
    /// Serialize full transaction (default: true)
    pub serialize: Option<bool>,
    /// Chunk address display on device
    pub chunkify: Option<bool>,
    /// Unlock a keychain subtree before signing
    pub unlock_path: Option<UnlockPath>,
    /// SLIP-24 payment requests
    pub payment_requests: Vec<PaymentRequest>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_address_params_default() {
        let params = GetAddressParams::default();
        assert!(params.path.is_empty());
        assert!(!params.show_on_trezor);
        assert!(params.coin.is_none());
        assert!(params.script_type.is_none());
    }

    #[test]
    fn test_sign_message_params() {
        let params = SignMessageParams {
            path: "m/84'/0'/0'/0/0".into(),
            message: "Hello".into(),
            ..Default::default()
        };
        assert_eq!(params.path, "m/84'/0'/0'/0/0");
        assert_eq!(params.message, "Hello");
    }
}
