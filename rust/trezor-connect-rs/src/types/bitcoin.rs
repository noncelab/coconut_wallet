//! Bitcoin-specific types.

use serde::{Deserialize, Serialize};

/// Input script type
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[repr(u8)]
pub enum ScriptType {
    /// P2PKH (legacy)
    SpendAddress = 0,
    /// P2SH-P2WPKH (nested SegWit)
    SpendP2SHWitness = 4,
    /// P2WPKH (native SegWit)
    #[default]
    SpendWitness = 3,
    /// P2TR (Taproot)
    SpendTaproot = 5,
    /// Multisig
    SpendMultisig = 1,
    /// External (watch-only)
    External = 2,
}

/// Output script type
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[repr(u8)]
pub enum OutputScriptType {
    /// P2PKH
    #[default]
    PayToAddress = 0,
    /// P2SH
    PayToScriptHash = 1,
    /// P2MS
    PayToMultisig = 2,
    /// OP_RETURN
    PayToOpReturn = 3,
    /// P2WPKH
    PayToWitness = 4,
    /// P2SH-P2WPKH
    PayToP2SHWitness = 5,
    /// P2TR
    PayToTaproot = 6,
}

/// Amount unit for display
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[repr(u8)]
pub enum AmountUnit {
    #[default]
    Bitcoin = 0,
    MilliBitcoin = 1,
    MicroBitcoin = 2,
    Satoshi = 3,
}

/// Account type for discovery
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AccountType {
    /// Legacy (P2PKH) - BIP44
    Legacy,
    /// Nested SegWit (P2SH-P2WPKH) - BIP49
    SegWit,
    /// Native SegWit (P2WPKH) - BIP84
    NativeSegWit,
    /// Taproot (P2TR) - BIP86
    Taproot,
}

impl AccountType {
    /// Get the BIP32 purpose for this account type
    pub fn purpose(&self) -> u32 {
        match self {
            AccountType::Legacy => 44,
            AccountType::SegWit => 49,
            AccountType::NativeSegWit => 84,
            AccountType::Taproot => 86,
        }
    }

    /// Get the script type for this account type
    pub fn script_type(&self) -> ScriptType {
        match self {
            AccountType::Legacy => ScriptType::SpendAddress,
            AccountType::SegWit => ScriptType::SpendP2SHWitness,
            AccountType::NativeSegWit => ScriptType::SpendWitness,
            AccountType::Taproot => ScriptType::SpendTaproot,
        }
    }
}
