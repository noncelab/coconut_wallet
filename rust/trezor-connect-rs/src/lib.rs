//! # Trezor Connect
//!
//! A Rust library for communicating with Trezor hardware wallets.
//! Bitcoin-only. Supports USB and Bluetooth connectivity.
//!
//! ## Supported Devices
//!
//! - **Trezor Safe 7** - Bluetooth (THP v2, Noise XX encrypted)
//! - **Trezor Safe 5 / Safe 3 / Model T / Model One** - USB (Protocol v1)
//!
//! ## Feature Flags
//!
//! - `usb` - USB transport via libusb (enabled by default)
//! - `bluetooth` - Bluetooth transport via btleplug (enabled by default)
//! - `os-keychain` - OS-native credential storage for Bluetooth pairing
//!   (macOS Keychain, Windows Credential Manager, Linux Secret Service)
//!
//! ## Quick Start
//!
//! ```rust,no_run
//! use std::sync::Arc;
//! use trezor_connect_rs::{Trezor, GetAddressParams, TrezorUiCallback, PassphraseResponse};
//!
//! /// Implement this trait to handle PIN/passphrase prompts from your UI.
//! struct MyUiCallback;
//! impl TrezorUiCallback for MyUiCallback {
//!     fn on_pin_request(&self) -> Option<String> {
//!         // Show PIN matrix UI, return the entered PIN or None to cancel
//!         Some("123456".to_string())
//!     }
//!     fn on_passphrase_request(&self, _on_device: bool) -> PassphraseResponse {
//!         // Standard wallet (no passphrase). For a hidden wallet, return
//!         // PassphraseResponse::Hidden { value: ... }; to abort, return Cancel.
//!         PassphraseResponse::Standard
//!     }
//! }
//!
//! #[tokio::main]
//! async fn main() -> trezor_connect_rs::Result<()> {
//!     let mut trezor = Trezor::new()
//!         .with_credential_store("~/.trezor-credentials.json")
//!         .with_ui_callback(Arc::new(MyUiCallback))
//!         .build()
//!         .await?;
//!
//!     // Scan for USB and Bluetooth devices
//!     let devices = trezor.scan().await?;
//!     if devices.is_empty() {
//!         return Ok(());
//!     }
//!
//!     let mut device = trezor.connect(&devices[0]).await?;
//!     device.initialize().await?;
//!
//!     let addr = device.get_address(GetAddressParams {
//!         path: "m/84'/0'/0'/0/0".into(),
//!         show_on_trezor: true,
//!         ..Default::default()
//!     }).await?;
//!     println!("Address: {}", addr.address);
//!
//!     device.disconnect().await?;
//!     Ok(())
//! }
//! ```
//!
//! ## Low-Level API
//!
//! For protocol-level access, use [`TrezorClient`] with a transport directly:
//!
//! ```rust,no_run
//! use trezor_connect_rs::{TrezorClient, UsbTransport, Transport};
//!
//! #[tokio::main]
//! async fn main() -> Result<(), Box<dyn std::error::Error>> {
//!     let mut transport = UsbTransport::new()?;
//!     transport.init().await?;
//!
//!     let devices = transport.enumerate().await?;
//!     let mut client = TrezorClient::new(transport);
//!     client.acquire(&devices[0].path).await?;
//!
//!     let features = client.initialize().await?;
//!     println!("Connected to: {}", features.label.as_deref().unwrap_or_default());
//!
//!     client.release().await?;
//!     Ok(())
//! }
//! ```

// Core modules
pub mod api;
pub mod compose;
pub mod constants;
pub mod device;
pub mod error;
pub mod protocol;
pub mod protos;
pub mod transport;
pub mod types;

// High-level API modules
pub mod connected_device;
pub mod credential_store;
pub mod device_info;
pub mod params;
pub mod responses;
pub mod trezor;

// UI callback for PIN/passphrase input
pub mod ui_callback;

// BIP39 passphrase normalization (NFKD), matching `@trezor/connect`
pub(crate) mod passphrase;

// Static session id derivation + wrong-passphrase detection
pub mod session_state;

// PSBT support (always available; the `psbt` feature is a no-op alias)
pub mod psbt;

// Bitcoin helpers shared by validation and verification (crate-internal)
pub(crate) mod bitcoin_utils;

// Post-sign verification of device-returned transactions (crate-internal)
pub(crate) mod tx_verify;

// Re-export error types
pub use error::{Result, TrezorError};

// Re-export high-level API (primary interface)
pub use connected_device::ConnectedDevice;
pub use credential_store::{CredentialStore, StoredCredential};
pub use device_info::{DeviceInfo, TransportType};
pub use params::*;
pub use responses::*;
pub use trezor::{PairingCallback, Trezor, TrezorBuilder};
pub use ui_callback::{PassphraseResponse, TrezorUiCallback};

// Re-export low-level API for advanced users
pub use device::TrezorClient;
pub use transport::Transport;
pub use types::bitcoin::*;
pub use types::network::*;

// Re-export transport types based on features
#[cfg(feature = "usb")]
pub use transport::usb::UsbTransport;

#[cfg(feature = "bluetooth")]
pub use transport::bluetooth::BluetoothTransport;

// Re-export callback transport (always available)
pub use transport::callback::{
    CallbackDeviceInfo, CallbackMessageResult, CallbackReadResult, CallbackResult,
    CallbackTransport, TransportCallback,
};
