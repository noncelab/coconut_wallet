//! Constants for Trezor device communication.
//!
//! This module contains USB identifiers, BLE UUIDs, and protocol constants
//! used for communicating with Trezor hardware wallets.

use uuid::Uuid;

// ============================================================================
// USB Constants
// ============================================================================

/// Trezor USB Vendor ID (for T2 and newer devices)
pub const USB_VENDOR_ID: u16 = 0x1209;

/// Trezor WebUSB Bootloader Product ID
pub const USB_PRODUCT_ID_BOOTLOADER: u16 = 0x53c0;

/// Trezor WebUSB Firmware Product ID
pub const USB_PRODUCT_ID_FIRMWARE: u16 = 0x53c1;

/// USB Configuration ID
pub const USB_CONFIGURATION_ID: u8 = 1;

/// USB Interface ID for normal communication
pub const USB_INTERFACE_ID: u8 = 0;

/// USB Endpoint OUT (write to device)
pub const USB_ENDPOINT_OUT: u8 = 0x01;

/// USB Endpoint IN (read from device) - bit 7 set indicates IN direction
pub const USB_ENDPOINT_IN: u8 = 0x81;

/// USB Interface ID for debug link
pub const USB_DEBUGLINK_INTERFACE_ID: u8 = 1;

/// USB Endpoint ID for debug link
pub const USB_DEBUGLINK_ENDPOINT_ID: u8 = 2;

/// USB chunk size (64 bytes)
pub const USB_CHUNK_SIZE: usize = 64;

// ============================================================================
// Bluetooth Constants
// ============================================================================

/// Trezor BLE Service UUID
pub const BLE_SERVICE_UUID: Uuid = uuid::uuid!("8c000001-a59b-4d58-a9ad-073df69fa1b1");

/// Trezor BLE Write (RX) Characteristic UUID - Device receives messages here
pub const BLE_CHARACTERISTIC_RX: Uuid = uuid::uuid!("8c000002-a59b-4d58-a9ad-073df69fa1b1");

/// Trezor BLE Notify (TX) Characteristic UUID - Device sends messages via notifications
pub const BLE_CHARACTERISTIC_TX: Uuid = uuid::uuid!("8c000003-a59b-4d58-a9ad-073df69fa1b1");

/// Trezor BLE Push Notification Characteristic UUID
pub const BLE_CHARACTERISTIC_PUSH: Uuid = uuid::uuid!("8c000004-a59b-4d58-a9ad-073df69fa1b1");

/// Standard BLE Battery Level Characteristic UUID
pub const BLE_CHARACTERISTIC_BATTERY: Uuid = uuid::uuid!("00002a19-0000-1000-8000-00805f9b34fb");

/// BLE MTU (Maximum Transmission Unit)
pub const BLE_MTU: usize = 247;

/// BLE chunk size (MTU - 3 bytes overhead)
pub const BLE_CHUNK_SIZE: usize = 244;

// ============================================================================
// Protocol v1 Constants (Legacy, unencrypted)
// ============================================================================

/// Protocol v1 magic header byte ('?')
pub const PROTOCOL_V1_MAGIC: u8 = 0x3F;

/// Protocol v1 header byte ('#')
pub const PROTOCOL_V1_HEADER_BYTE: u8 = 0x23;

/// Protocol v1 header size (1 magic + 2 header bytes + 2 msg_type + 4 length)
pub const PROTOCOL_V1_HEADER_SIZE: usize = 9;

// ============================================================================
// THP (Trezor Host Protocol) v2 Constants (Encrypted)
// ============================================================================

/// THP header size (1 control_byte + 2 channel)
pub const THP_HEADER_SIZE: usize = 3;

/// THP message length field size
pub const THP_MESSAGE_LEN_SIZE: usize = 2;

/// THP Control Bytes
pub mod thp_control {
    /// Handshake init request
    pub const HANDSHAKE_INIT_REQ: u8 = 0x00;
    /// Handshake init response
    pub const HANDSHAKE_INIT_RES: u8 = 0x01;
    /// Handshake completion request
    pub const HANDSHAKE_COMP_REQ: u8 = 0x02;
    /// Handshake completion response
    pub const HANDSHAKE_COMP_RES: u8 = 0x03;
    /// Encrypted data message
    pub const ENCRYPTED: u8 = 0x04;
    /// Acknowledgment message
    pub const ACK_MESSAGE: u8 = 0x20;
    /// Channel allocation request
    pub const CHANNEL_ALLOCATION_REQ: u8 = 0x40;
    /// Channel allocation response
    pub const CHANNEL_ALLOCATION_RES: u8 = 0x41;
    /// Error message
    pub const ERROR: u8 = 0x42;
    /// Ping message
    pub const PING: u8 = 0x43;
    /// Pong message
    pub const PONG: u8 = 0x44;
    /// Continuation packet
    pub const CONTINUATION_PACKET: u8 = 0x80;
}

/// THP protocol name for Noise XX handshake
pub const THP_PROTOCOL_NAME: &[u8] = b"Noise_XX_25519_AESGCM_SHA256";

/// THP ACK timeout in milliseconds
pub const THP_ACK_TIMEOUT_MS: u64 = 30_000;

/// THP retry attempts limit
pub const THP_RETRY_ATTEMPTS: u32 = 10;

/// Standard Trezor protobuf message types
pub mod message_type {
    /// ButtonRequest - device is waiting for user confirmation
    pub const BUTTON_REQUEST: u16 = 26;
    /// ButtonAck - host acknowledges button request
    pub const BUTTON_ACK: u16 = 27;
    /// Success - device reports a successful operation
    pub const SUCCESS: u16 = 2;
    /// Failure - device reports an error
    pub const FAILURE: u16 = 3;
    /// Features - device capabilities/info
    pub const FEATURES: u16 = 17;
    /// Initialize - initialize the device connection
    pub const INITIALIZE: u16 = 0;
    /// Address - returned Bitcoin address
    pub const ADDRESS: u16 = 30;
}

/// THP Message Types for pairing and session management
pub mod thp_message_type {
    /// Create new session
    pub const THP_CREATE_NEW_SESSION: u16 = 1000;
    /// Pairing request
    pub const THP_PAIRING_REQUEST: u16 = 1008;
    /// Pairing request approved
    pub const THP_PAIRING_REQUEST_APPROVED: u16 = 1009;
    /// Select pairing method
    pub const THP_SELECT_METHOD: u16 = 1010;
    /// Pairing preparations finished
    pub const THP_PAIRING_PREPARATIONS_FINISHED: u16 = 1011;
    /// Credential request
    pub const THP_CREDENTIAL_REQUEST: u16 = 1016;
    /// Credential response
    pub const THP_CREDENTIAL_RESPONSE: u16 = 1017;
    /// End request
    pub const THP_END_REQUEST: u16 = 1018;
    /// End response
    pub const THP_END_RESPONSE: u16 = 1019;
    /// Code entry commitment
    pub const THP_CODE_ENTRY_COMMITMENT: u16 = 1024;
    /// Code entry challenge
    pub const THP_CODE_ENTRY_CHALLENGE: u16 = 1025;
    /// Code entry CPACE Trezor pubkey
    pub const THP_CODE_ENTRY_CPACE_TREZOR: u16 = 1026;
    /// Code entry CPACE host tag
    pub const THP_CODE_ENTRY_CPACE_HOST_TAG: u16 = 1027;
    /// Code entry secret
    pub const THP_CODE_ENTRY_SECRET: u16 = 1028;
    /// QR code tag
    pub const THP_QR_CODE_TAG: u16 = 1032;
    /// QR code secret
    pub const THP_QR_CODE_SECRET: u16 = 1033;
    /// NFC tag host
    pub const THP_NFC_TAG_HOST: u16 = 1040;
    /// NFC tag trezor
    pub const THP_NFC_TAG_TREZOR: u16 = 1041;
}

/// THP Pairing Methods
pub mod thp_pairing_method {
    /// Skip pairing (for testing/development)
    pub const SKIP_PAIRING: u8 = 1;
    /// Code entry pairing
    pub const CODE_ENTRY: u8 = 2;
    /// QR code pairing
    pub const QR_CODE: u8 = 3;
    /// NFC pairing
    pub const NFC: u8 = 4;
}

// ============================================================================
// Timeouts
// ============================================================================

/// Action timeout in milliseconds (for single transport actions)
pub const ACTION_TIMEOUT_MS: u64 = 10_000;

/// Default read timeout in milliseconds
pub const READ_TIMEOUT_MS: u64 = 5_000;

/// Default write timeout in milliseconds
pub const WRITE_TIMEOUT_MS: u64 = 5_000;

/// BLE connection timeout in milliseconds
pub const BLE_CONNECTION_TIMEOUT_MS: u64 = 5_000;

/// BLE stale device timeout in milliseconds (3 seconds)
pub const BLE_STALE_DEVICE_TIMEOUT_MS: u64 = 3_000;

// ============================================================================
// Device Types
// ============================================================================

/// Trezor device types (matching trezord-go)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum DeviceType {
    /// Trezor Model T1 HID mode
    T1Hid = 0,
    /// Trezor Model T1 WebUSB mode
    T1Webusb = 1,
    /// Trezor Model T1 WebUSB bootloader
    T1WebusbBoot = 2,
    /// Trezor Model T2 and newer (Safe 3, Safe 5)
    T2 = 3,
    /// Trezor Model T2 bootloader
    T2Boot = 4,
    /// Trezor emulator
    Emulator = 5,
    /// Trezor Bluetooth device (Safe 7)
    Bluetooth = 6,
}

impl DeviceType {
    /// Check if this device type uses THP (encrypted protocol)
    pub fn uses_thp(&self) -> bool {
        matches!(self, DeviceType::Bluetooth)
    }

    /// Check if this device type is in bootloader mode
    pub fn is_bootloader(&self) -> bool {
        matches!(self, DeviceType::T1WebusbBoot | DeviceType::T2Boot)
    }
}

// ============================================================================
// Bitcoin Constants
// ============================================================================

/// Default coin name
pub const DEFAULT_COIN_NAME: &str = "Bitcoin";

/// Bitcoin BIP44 coin type
pub const BITCOIN_COIN_TYPE: u32 = 0;

/// Bitcoin testnet BIP44 coin type
pub const BITCOIN_TESTNET_COIN_TYPE: u32 = 1;

/// Bitcoin BIP32 purpose for legacy addresses (P2PKH)
pub const BIP44_PURPOSE: u32 = 44;

/// Bitcoin BIP32 purpose for SegWit wrapped addresses (P2SH-P2WPKH)
pub const BIP49_PURPOSE: u32 = 49;

/// Bitcoin BIP32 purpose for native SegWit addresses (P2WPKH)
pub const BIP84_PURPOSE: u32 = 84;

/// Bitcoin BIP32 purpose for Taproot addresses (P2TR)
pub const BIP86_PURPOSE: u32 = 86;

/// Hardened key offset (2^31)
pub const HARDENED_OFFSET: u32 = 0x80000000;

/// Bitcoin dust limit in satoshis. Transactions whose total spendable output
/// value is below this are rejected client-side before reaching the device,
/// matching `@trezor/connect`'s "Total amount is below dust limit" check.
pub const DUST_LIMIT_SATOSHIS: u64 = 546;
