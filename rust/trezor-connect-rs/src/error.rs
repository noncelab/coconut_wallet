//! Error types for the Trezor Connect library.
//!
//! This module defines all error types that can occur during Trezor communication.

use thiserror::Error;

/// Result type alias for Trezor operations.
pub type Result<T> = std::result::Result<T, TrezorError>;

/// Main error type for Trezor operations.
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum TrezorError {
    /// Transport layer error (USB/Bluetooth communication)
    #[error("Transport error: {0}")]
    Transport(#[from] TransportError),

    /// Protocol layer error (encoding/decoding)
    #[error("Protocol error: {0}")]
    Protocol(#[from] ProtocolError),

    /// Device returned an error
    #[error("Device error: {0}")]
    Device(#[from] DeviceError),

    /// THP (Trezor Host Protocol) error
    #[error("THP error: {0}")]
    Thp(#[from] ThpError),

    /// Session management error
    #[error("Session error: {0}")]
    Session(#[from] SessionError),

    /// Bitcoin-specific error
    #[error("Bitcoin error: {0}")]
    Bitcoin(#[from] BitcoinError),

    /// Operation was cancelled
    #[error("Operation cancelled")]
    Cancelled,

    /// Operation timed out
    #[error("Operation timed out")]
    Timeout,

    /// I/O error (file operations)
    #[error("I/O error: {0}")]
    IoError(String),

    /// Functionality that exists in the API surface but is not implemented
    /// in this crate.
    #[error("Not implemented: {0}")]
    NotImplemented(&'static str),
}

/// Transport layer errors.
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum TransportError {
    /// No Trezor device found
    #[error("No Trezor device found")]
    DeviceNotFound,

    /// Device disconnected during operation
    #[error("Device disconnected during operation")]
    DeviceDisconnected,

    /// Unable to open device
    #[error("Unable to open device: {0}")]
    UnableToOpen(String),

    /// Unable to close device
    #[error("Unable to close device: {0}")]
    UnableToClose(String),

    /// Data transfer error
    #[error("Data transfer error: {0}")]
    DataTransfer(String),

    /// USB-specific error
    #[cfg(feature = "usb")]
    #[error("USB error: {0}")]
    Usb(String),

    /// Bluetooth-specific error
    #[cfg(feature = "bluetooth")]
    #[error("Bluetooth error: {0}")]
    Bluetooth(String),

    /// Permission denied
    #[error("Permission denied: {0}")]
    PermissionDenied(String),

    /// Device is busy (already in use)
    #[error("Device is busy")]
    DeviceBusy,
}

/// Protocol layer errors.
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum ProtocolError {
    /// Malformed message
    #[error("Malformed message: {0}")]
    Malformed(String),

    /// Invalid message type
    #[error("Invalid message type: {0}")]
    InvalidMessageType(u16),

    /// Message too short
    #[error("Message too short: expected {expected}, got {actual}")]
    MessageTooShort { expected: usize, actual: usize },

    /// Invalid header
    #[error("Invalid header")]
    InvalidHeader,

    /// Chunk header mismatch
    #[error("Chunk header mismatch")]
    ChunkHeaderMismatch,

    /// Protobuf encoding error
    #[error("Protobuf encode error: {0}")]
    ProtobufEncode(String),

    /// Protobuf decoding error
    #[error("Protobuf decode error: {0}")]
    ProtobufDecode(String),

    /// Unexpected response type
    #[error("Unexpected response type: expected {expected}, got {actual}")]
    UnexpectedResponse { expected: String, actual: String },
}

/// Device errors returned by the Trezor.
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum DeviceError {
    /// Device not connected or session not acquired
    #[error("Device not connected or session not acquired")]
    NotConnected,

    /// Action cancelled on device
    #[error("Action cancelled by user")]
    ActionCancelled,

    /// PIN is required
    #[error("PIN is required")]
    PinRequired,

    /// Invalid PIN entered
    #[error("Invalid PIN")]
    InvalidPin,

    /// PIN entry cancelled
    #[error("PIN entry cancelled")]
    PinCancelled,

    /// Passphrase is required
    #[error("Passphrase is required")]
    PassphraseRequired,

    /// Passphrase entry cancelled
    #[error("Passphrase entry cancelled")]
    PassphraseCancelled,

    /// The device's derived session state did not match the expected state,
    /// i.e. a different passphrase was entered than the one that created the
    /// remembered wallet. Mirrors trezor-suite's `Device_InvalidState`.
    #[error("Passphrase is incorrect (device state mismatch)")]
    InvalidState,

    /// Device is not initialized
    #[error("Device is not initialized")]
    NotInitialized,

    /// Device needs firmware update
    #[error("Device needs firmware update")]
    FirmwareUpdateRequired,

    /// Seed is not backed up
    #[error("Seed is not backed up")]
    SeedNotBackedUp,

    /// Feature not supported
    #[error("Feature not supported: {0}")]
    NotSupported(String),

    /// Device returned failure
    #[error("Device failure: {code:?} - {message}")]
    Failure { code: Option<i32>, message: String },

    /// Device returned error response
    #[error("Device error: code {code} - {message}")]
    DeviceError { code: i32, message: String },

    /// Button request (informational)
    #[error("Button request: {0}")]
    ButtonRequest(String),

    /// Protobuf decode error
    #[error("Protobuf decode error: {0}")]
    ProtobufDecode(String),

    /// Invalid input
    #[error("Invalid input: {0}")]
    InvalidInput(String),

    /// The device returned an address that differs from the expected one.
    /// Mirrors trezor-suite's `Method_AddressNotMatch`.
    #[error(
        "Device address does not match the expected address: expected {expected}, got {actual}"
    )]
    AddressMismatch {
        /// The address the caller expected (or the silent pre-derivation)
        expected: String,
        /// The address the device actually returned
        actual: String,
    },
}

impl DeviceError {
    /// Map a Trezor protocol `Failure` (a `FailureType` code plus message) into
    /// a typed `DeviceError`. Known PIN/action codes become their typed
    /// variants so callers (and downstream FFI consumers) can react to a wrong
    /// PIN, a cancelled PIN entry, etc.; unknown codes fall back to the generic
    /// `DeviceError` so existing behavior is preserved.
    ///
    /// Codes match `FailureType` in `proto/messages-common.proto`.
    pub fn from_failure(code: Option<i32>, message: String) -> Self {
        match code {
            Some(7) => DeviceError::InvalidPin,      // Failure_PinInvalid
            Some(6) => DeviceError::PinCancelled,    // Failure_PinCancelled
            Some(5) => DeviceError::PinRequired,     // Failure_PinExpected
            Some(4) => DeviceError::ActionCancelled, // Failure_ActionCancelled
            other => DeviceError::DeviceError {
                code: other.unwrap_or(0),
                message,
            },
        }
    }
}

/// THP (Trezor Host Protocol) specific errors.
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum ThpError {
    /// Channel allocation failed
    #[error("Channel allocation failed")]
    ChannelAllocationFailed,

    /// Handshake failed
    #[error("Handshake failed: {0}")]
    HandshakeFailed(String),

    /// Device is locked; the THP handshake cannot complete until the user
    /// unlocks the device. Callers should back off and prompt the user to
    /// unlock rather than retrying the transport in a tight loop.
    #[error("THP handshake failed: DeviceLocked")]
    DeviceLocked,

    /// Pairing required
    #[error("Pairing required")]
    PairingRequired,

    /// Pairing failed
    #[error("Pairing failed: {0}")]
    PairingFailed(String),

    /// Invalid credentials
    #[error("Invalid credentials")]
    InvalidCredentials,

    /// Encryption error
    #[error("Encryption error: {0}")]
    EncryptionError(String),

    /// Decryption error
    #[error("Decryption error: {0}")]
    DecryptionError(String),

    /// ACK not received
    #[error("ACK not received")]
    AckNotReceived,

    /// Invalid sync bit
    #[error("Invalid sync bit")]
    InvalidSyncBit,

    /// State missing
    #[error("THP state missing")]
    StateMissing,

    /// Session creation error
    #[error("Session error: {0}")]
    SessionError(String),
}

/// Session management errors.
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum SessionError {
    /// Session not found
    #[error("Session not found")]
    NotFound,

    /// Wrong previous session
    #[error("Wrong previous session")]
    WrongPrevious,

    /// Session already acquired
    #[error("Session already acquired by another client")]
    AlreadyAcquired,

    /// Session expired
    #[error("Session expired")]
    Expired,
}

/// Bitcoin-specific errors.
#[derive(Debug, Error)]
#[non_exhaustive]
pub enum BitcoinError {
    /// Invalid derivation path
    #[error("Invalid derivation path: {0}")]
    InvalidPath(String),

    /// Invalid address
    #[error("Invalid address: {0}")]
    InvalidAddress(String),

    /// Invalid transaction
    #[error("Invalid transaction: {0}")]
    InvalidTransaction(String),

    /// Insufficient funds
    #[error("Insufficient funds")]
    InsufficientFunds,

    /// Invalid signature
    #[error("Invalid signature")]
    InvalidSignature,

    /// Network mismatch
    #[error("Network mismatch: expected {expected}, got {actual}")]
    NetworkMismatch { expected: String, actual: String },
}

// Implement From for common error types

impl From<std::io::Error> for TrezorError {
    fn from(err: std::io::Error) -> Self {
        TrezorError::Transport(TransportError::DataTransfer(err.to_string()))
    }
}

impl From<prost::DecodeError> for ProtocolError {
    fn from(err: prost::DecodeError) -> Self {
        ProtocolError::ProtobufDecode(err.to_string())
    }
}

impl From<prost::EncodeError> for ProtocolError {
    fn from(err: prost::EncodeError) -> Self {
        ProtocolError::ProtobufEncode(err.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn from_failure_maps_pin_invalid() {
        // Failure_PinInvalid = 7 -> wrong PIN entered
        assert!(matches!(
            DeviceError::from_failure(Some(7), "invalid pin".to_string()),
            DeviceError::InvalidPin
        ));
    }

    #[test]
    fn from_failure_maps_pin_cancelled() {
        // Failure_PinCancelled = 6
        assert!(matches!(
            DeviceError::from_failure(Some(6), "cancelled".to_string()),
            DeviceError::PinCancelled
        ));
    }

    #[test]
    fn from_failure_maps_pin_expected() {
        // Failure_PinExpected = 5 -> PIN required
        assert!(matches!(
            DeviceError::from_failure(Some(5), "pin expected".to_string()),
            DeviceError::PinRequired
        ));
    }

    #[test]
    fn from_failure_maps_action_cancelled() {
        // Failure_ActionCancelled = 4
        assert!(matches!(
            DeviceError::from_failure(Some(4), "action cancelled".to_string()),
            DeviceError::ActionCancelled
        ));
    }

    #[test]
    fn from_failure_unknown_code_stays_generic() {
        // Unknown code (e.g. Failure_FirmwareError = 99) falls back to generic,
        // preserving both the code and the message.
        match DeviceError::from_failure(Some(99), "boom".to_string()) {
            DeviceError::DeviceError { code, message } => {
                assert_eq!(code, 99);
                assert_eq!(message, "boom");
            }
            other => panic!("expected generic DeviceError, got {other:?}"),
        }
    }

    #[test]
    fn from_failure_missing_code_stays_generic() {
        match DeviceError::from_failure(None, "no code".to_string()) {
            DeviceError::DeviceError { code, message } => {
                assert_eq!(code, 0);
                assert_eq!(message, "no code");
            }
            other => panic!("expected generic DeviceError, got {other:?}"),
        }
    }

    #[test]
    fn device_locked_wraps_into_thp_error() {
        let err: TrezorError = ThpError::DeviceLocked.into();
        assert!(matches!(err, TrezorError::Thp(ThpError::DeviceLocked)));
    }

    #[test]
    fn device_locked_display_keeps_devicelocked_substring() {
        // bitkit-core (and downstream apps) may still substring-match on
        // "DeviceLocked"; keep that guarantee stable.
        assert!(ThpError::DeviceLocked.to_string().contains("DeviceLocked"));
    }
}
