//! Sign transaction API.
//!
//! Implements the TxRequest/TxAck flow for signing Bitcoin transactions.

use crate::types::bitcoin::ScriptType;

/// Transaction input for signing
#[derive(Debug, Clone)]
pub struct TxInput {
    /// Previous transaction hash (hex, 32 bytes reversed)
    pub prev_hash: Vec<u8>,
    /// Previous output index
    pub prev_index: u32,
    /// BIP32 derivation path (e.g., "m/84'/0'/0'/0/0")
    pub path: Vec<u32>,
    /// Amount in satoshis
    pub amount: u64,
    /// Script type
    pub script_type: ScriptType,
    /// Sequence number (default: 0xFFFFFFFF)
    pub sequence: Option<u32>,
    /// Original transaction hash for RBF replacement
    pub orig_hash: Option<Vec<u8>>,
    /// Original input index for RBF replacement
    pub orig_index: Option<u32>,
}

impl TxInput {
    /// Create a new input from hex hash and path string
    pub fn new(prev_hash_hex: &str, prev_index: u32, path: &str, amount: u64) -> Self {
        let prev_hash = hex::decode(prev_hash_hex).unwrap_or_default();
        let path_vec = crate::types::path::parse_path(path).unwrap_or_default();
        Self {
            prev_hash,
            prev_index,
            path: path_vec,
            amount,
            script_type: ScriptType::SpendWitness,
            sequence: None,
            orig_hash: None,
            orig_index: None,
        }
    }

    /// Set script type
    pub fn with_script_type(mut self, script_type: ScriptType) -> Self {
        self.script_type = script_type;
        self
    }
}

/// Transaction output for signing
#[derive(Debug, Clone)]
pub enum TxOutput {
    /// External output (to address)
    External {
        /// Destination address
        address: String,
        /// Amount in satoshis
        amount: u64,
        /// Original transaction hash for RBF replacement
        orig_hash: Option<Vec<u8>>,
        /// Original output index for RBF replacement
        orig_index: Option<u32>,
    },
    /// Change output (to own address)
    Change {
        /// BIP32 derivation path
        path: Vec<u32>,
        /// Amount in satoshis
        amount: u64,
        /// Script type
        script_type: ScriptType,
        /// Original transaction hash for RBF replacement
        orig_hash: Option<Vec<u8>>,
        /// Original output index for RBF replacement
        orig_index: Option<u32>,
    },
    /// OP_RETURN output
    OpReturn {
        /// Data to embed
        data: Vec<u8>,
        /// Original transaction hash for RBF replacement
        orig_hash: Option<Vec<u8>>,
        /// Original output index for RBF replacement
        orig_index: Option<u32>,
    },
}

impl TxOutput {
    /// Create external output to an address
    pub fn to_address(address: &str, amount: u64) -> Self {
        TxOutput::External {
            address: address.to_string(),
            amount,
            orig_hash: None,
            orig_index: None,
        }
    }

    /// Create change output to own address
    pub fn to_change(path: &str, amount: u64) -> Self {
        let path_vec = crate::types::path::parse_path(path).unwrap_or_default();
        TxOutput::Change {
            path: path_vec,
            amount,
            script_type: ScriptType::SpendWitness,
            orig_hash: None,
            orig_index: None,
        }
    }

    /// Create OP_RETURN output
    pub fn op_return(data: &[u8]) -> Self {
        TxOutput::OpReturn {
            data: data.to_vec(),
            orig_hash: None,
            orig_index: None,
        }
    }
}

/// Previous transaction data (for non-segwit inputs)
#[derive(Debug, Clone)]
pub struct PrevTx {
    /// Transaction hash
    pub hash: Vec<u8>,
    /// Version
    pub version: u32,
    /// Lock time
    pub lock_time: u32,
    /// Inputs
    pub inputs: Vec<PrevTxInput>,
    /// Outputs
    pub outputs: Vec<PrevTxOutput>,
}

/// Previous transaction input
#[derive(Debug, Clone)]
pub struct PrevTxInput {
    /// Previous hash
    pub prev_hash: Vec<u8>,
    /// Previous index
    pub prev_index: u32,
    /// Script signature
    pub script_sig: Vec<u8>,
    /// Sequence
    pub sequence: u32,
}

/// Previous transaction output
#[derive(Debug, Clone)]
pub struct PrevTxOutput {
    /// Amount
    pub amount: u64,
    /// Script pubkey
    pub script_pubkey: Vec<u8>,
}

/// Parameters for sign_transaction
#[derive(Debug, Clone)]
pub struct SignTransactionParams {
    /// Transaction inputs
    pub inputs: Vec<TxInput>,
    /// Transaction outputs
    pub outputs: Vec<TxOutput>,
    /// Coin name (default: "Bitcoin")
    pub coin: String,
    /// Lock time (default: 0)
    pub lock_time: u32,
    /// Version (default: 2)
    pub version: u32,
    /// Previous transactions (needed for non-segwit inputs)
    pub prev_txs: Vec<PrevTx>,
}

impl Default for SignTransactionParams {
    fn default() -> Self {
        Self {
            inputs: vec![],
            outputs: vec![],
            coin: "Bitcoin".to_string(),
            lock_time: 0,
            version: 2,
            prev_txs: vec![],
        }
    }
}

/// Signed transaction result
#[derive(Debug, Clone)]
pub struct SignedTransaction {
    /// Signatures for each input (hex encoded)
    pub signatures: Vec<String>,
    /// Serialized transaction (hex)
    pub serialized_tx: String,
}

impl SignedTransaction {
    /// Get the serialized transaction as bytes
    pub fn to_bytes(&self) -> Vec<u8> {
        hex::decode(&self.serialized_tx).unwrap_or_default()
    }
}
