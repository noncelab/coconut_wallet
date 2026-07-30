//! UI callback trait for PIN and passphrase input.
//!
//! Provides a mechanism for the host application to handle PIN and passphrase
//! requests from the Trezor device, instead of returning hard errors.

/// Response variants for an `on_passphrase_request` callback.
///
/// Trezor's passphrase protocol distinguishes several cases that a single
/// `Option<String>` return value cannot represent unambiguously: a standard
/// wallet (no passphrase) is `Some("")` to the device, user cancel is `None`,
/// and on-device entry is signalled with no passphrase but `on_device = true`.
/// Modeling them as a typed enum makes the contract self-documenting at the
/// callback boundary.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PassphraseResponse {
    /// User cancelled — aborts the pending operation.
    Cancel,
    /// Standard wallet — no passphrase, equivalent to `Some("")` on the device.
    Standard,
    /// Hidden wallet — derived from the passphrase entered on the host.
    Hidden { value: String },
    /// Enter the passphrase on the Trezor device itself instead of on the host.
    /// The library acks with `on_device = true`, the Trezor shows its own
    /// passphrase keyboard, and the passphrase never touches the host.
    OnDevice,
}

/// Callback trait for handling PIN and passphrase requests from the device.
///
/// Implement this trait to provide PIN/passphrase input from your application's UI.
/// Methods are synchronous because UniFFI does not support async callback interfaces.
///
/// # Example
/// ```ignore
/// use trezor_connect_rs::{TrezorUiCallback, PassphraseResponse};
///
/// struct MyUiCallback;
///
/// impl TrezorUiCallback for MyUiCallback {
///     fn on_pin_request(&self) -> Option<String> {
///         // Show PIN matrix UI, return entered PIN or None to cancel
///         Some("123456".to_string())
///     }
///
///     fn on_passphrase_request(&self, on_device: bool) -> PassphraseResponse {
///         if on_device {
///             // Device wants entry on the Trezor itself; defer to it.
///             PassphraseResponse::OnDevice
///         } else {
///             // Show a passphrase input UI on the host
///             PassphraseResponse::Hidden { value: "my passphrase".to_string() }
///         }
///     }
/// }
/// ```
pub trait TrezorUiCallback: Send + Sync {
    /// Called when the device requests a PIN.
    ///
    /// Return `Some(pin)` with the matrix-encoded PIN, or `None` to cancel.
    fn on_pin_request(&self) -> Option<String>;

    /// Called when the device requests a passphrase.
    ///
    /// `on_device` is `true` when the device asks for the passphrase to be
    /// entered on the Trezor itself (e.g. it is configured for on-device entry);
    /// in that case return [`PassphraseResponse::OnDevice`].
    ///
    /// Return one of:
    /// - [`PassphraseResponse::Cancel`] to abort the operation.
    /// - [`PassphraseResponse::Standard`] for a standard (no-passphrase) wallet.
    /// - [`PassphraseResponse::Hidden`] with the host-entered passphrase to
    ///   open a hidden wallet.
    /// - [`PassphraseResponse::OnDevice`] to have the user type the passphrase
    ///   on the Trezor instead of on the host.
    fn on_passphrase_request(&self, on_device: bool) -> PassphraseResponse;
}
