//! Bitcoin network information.

use serde::{Deserialize, Serialize};

/// Bitcoin network type
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum Network {
    #[default]
    Bitcoin,
    Testnet,
    Regtest,
}

impl Network {
    /// Get the coin name for this network
    pub fn coin_name(&self) -> &'static str {
        match self {
            Network::Bitcoin => "Bitcoin",
            Network::Testnet => "Testnet",
            Network::Regtest => "Regtest",
        }
    }

    /// Get the BIP44 coin type
    pub fn coin_type(&self) -> u32 {
        match self {
            Network::Bitcoin => 0,
            Network::Testnet | Network::Regtest => 1,
        }
    }

    /// Get the bech32 HRP (Human-Readable Part)
    pub fn bech32_hrp(&self) -> &'static str {
        match self {
            Network::Bitcoin => "bc",
            Network::Testnet => "tb",
            Network::Regtest => "bcrt",
        }
    }

    /// Get the address version byte (P2PKH)
    pub fn p2pkh_prefix(&self) -> u8 {
        match self {
            Network::Bitcoin => 0x00,
            Network::Testnet | Network::Regtest => 0x6f,
        }
    }

    /// Get the script version byte (P2SH)
    pub fn p2sh_prefix(&self) -> u8 {
        match self {
            Network::Bitcoin => 0x05,
            Network::Testnet | Network::Regtest => 0xc4,
        }
    }

    /// Get the WIF prefix
    pub fn wif_prefix(&self) -> u8 {
        match self {
            Network::Bitcoin => 0x80,
            Network::Testnet | Network::Regtest => 0xef,
        }
    }

    /// Get the xpub version bytes
    pub fn xpub_version(&self) -> u32 {
        match self {
            Network::Bitcoin => 0x0488B21E,
            Network::Testnet | Network::Regtest => 0x043587CF,
        }
    }

    /// Get the xprv version bytes
    pub fn xprv_version(&self) -> u32 {
        match self {
            Network::Bitcoin => 0x0488ADE4,
            Network::Testnet | Network::Regtest => 0x04358394,
        }
    }
}

/// Coin information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CoinInfo {
    /// Coin name
    pub name: String,
    /// Coin shortcut (e.g., "BTC")
    pub shortcut: String,
    /// Network type
    pub network: Network,
    /// Decimals
    pub decimals: u8,
    /// Supports SegWit
    pub segwit: bool,
    /// Supports Taproot
    pub taproot: bool,
    /// Minimum fee per byte
    pub min_fee: u64,
    /// Maximum fee per byte
    pub max_fee: u64,
    /// Default fee per byte
    pub default_fee: u64,
    /// Dust limit in satoshis
    pub dust_limit: u64,
}

impl Default for CoinInfo {
    fn default() -> Self {
        Self {
            name: "Bitcoin".to_string(),
            shortcut: "BTC".to_string(),
            network: Network::Bitcoin,
            decimals: 8,
            segwit: true,
            taproot: true,
            min_fee: 1,
            max_fee: 2000,
            default_fee: 10,
            dust_limit: 546,
        }
    }
}
