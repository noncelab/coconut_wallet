//! Auto-generated protobuf types from trezor-firmware.
//!
//! This module contains all the protobuf message types used for
//! communication with Trezor hardware wallets.

#![allow(clippy::all)]
#![allow(missing_docs)]
#![allow(non_camel_case_types)]

/// Core message types and MessageType enum
pub mod messages {
    include!(concat!(env!("OUT_DIR"), "/hw.trezor.messages.rs"));
}

/// Common message types (Success, Failure, ButtonRequest, etc.)
pub mod common {
    include!(concat!(env!("OUT_DIR"), "/hw.trezor.messages.common.rs"));
}

/// Bitcoin-specific message types
pub mod bitcoin {
    include!(concat!(env!("OUT_DIR"), "/hw.trezor.messages.bitcoin.rs"));
}

/// Management message types (Initialize, Features, etc.)
pub mod management {
    include!(concat!(
        env!("OUT_DIR"),
        "/hw.trezor.messages.management.rs"
    ));
}

// Re-export commonly used types
pub use bitcoin::{
    Address, GetAddress, GetOwnershipProof, GetPublicKey, MessageSignature, OwnershipProof,
    PublicKey, SignMessage, SignTx, TxAck, TxInput, TxOutput, TxRequest, VerifyMessage,
};
pub use common::{
    ButtonAck, ButtonRequest, Failure, PassphraseAck, PassphraseRequest, PinMatrixAck,
    PinMatrixRequest, Success,
};
pub use management::{Features, GetFeatures, Initialize, Ping};
pub use messages::MessageType;
