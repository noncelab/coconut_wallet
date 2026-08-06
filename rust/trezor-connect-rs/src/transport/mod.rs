//! Transport layer for Trezor communication.
//!
//! This module provides abstractions for communicating with Trezor devices
//! over different transports (USB, Bluetooth, Callback).

pub mod callback;
pub mod session;
pub mod traits;

#[cfg(test)]
pub(crate) mod mock;

#[cfg(feature = "usb")]
pub mod usb;

#[cfg(feature = "bluetooth")]
pub mod bluetooth;

pub use callback::*;
pub use session::*;
pub use traits::*;

/// Decode a Trezor `Failure` protobuf payload into a human-readable
/// `code=…, message=…` string for logging and error context.
///
/// Shared by the USB, Bluetooth, and Callback transports so a rejected
/// `ThpCreateNewSession` is reported identically regardless of transport.
/// Falls back to a marker string if the bytes don't decode as a `Failure`.
pub(crate) fn decode_failure_detail(data: &[u8]) -> String {
    use prost::Message;
    crate::protos::common::Failure::decode(data)
        .map(|f| format!("code={:?}, message={}", f.code, f.message()))
        .unwrap_or_else(|_| "undecodable Failure".to_string())
}
