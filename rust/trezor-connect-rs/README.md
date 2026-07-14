# trezor-connect-rs

A Rust library for communicating with Trezor hardware wallets. Bitcoin-only. Supports USB and Bluetooth connectivity.

## Features

- **USB** (Protocol v1) - Trezor Safe 5, Safe 3, Model T, Model One
- **Bluetooth** (THP v2, Noise XX encrypted) - Trezor Safe 7
- **Bitcoin operations** - address generation, transaction signing, message signing/verification, xpub derivation
- **Credential persistence** - file-based or OS keychain, for skipping Bluetooth re-pairing

## Requirements

- Tokio async runtime
- USB: libusb (or platform equivalent)
- Bluetooth: platform BLE support (btleplug)

## Installation

```toml
[dependencies]
trezor-connect-rs = "0.4.0"
```

### Feature Flags

| Feature | Default | Description |
|---------|---------|-------------|
| `usb` | Yes | USB transport via libusb |
| `bluetooth` | Yes | Bluetooth transport via btleplug |
| `os-keychain` | No | OS-native credential storage (macOS Keychain, Windows Credential Manager, Linux Secret Service) |

```toml
# Default: USB + Bluetooth
trezor-connect-rs = "0.4"

# USB only (e.g., for iOS where libusb isn't available)
trezor-connect-rs = { version = "0.4", default-features = false, features = ["usb"] }

# Bluetooth only
trezor-connect-rs = { version = "0.4", default-features = false, features = ["bluetooth"] }

# With OS keychain for credential storage
trezor-connect-rs = { version = "0.4", features = ["os-keychain"] }
```

## Quick Start

```rust
use trezor_connect_rs::{Trezor, GetAddressParams};

#[tokio::main]
async fn main() -> trezor_connect_rs::Result<()> {
    let mut trezor = Trezor::new()
        .with_credential_store("~/.trezor-credentials.json")
        .build()
        .await?;

    // Scan for USB and Bluetooth devices
    let devices = trezor.scan().await?;
    if devices.is_empty() {
        println!("No devices found");
        return Ok(());
    }

    // Connect to the first device
    let mut device = trezor.connect(&devices[0]).await?;
    device.initialize().await?;

    // Get a native SegWit address
    let result = device.get_address(GetAddressParams {
        path: "m/84'/0'/0'/0/0".into(),
        show_on_trezor: true,
        ..Default::default()
    }).await?;

    println!("Address: {}", result.address);

    device.disconnect().await?;
    Ok(())
}
```

## API

### Trezor (manager)

The entry point. Discovers devices across transports and manages connections.

```rust
let mut trezor = Trezor::new()
    .with_credential_store("/path/to/creds.json") // file-based credential persistence
    // .with_keychain_store(None)                  // or OS keychain (requires "os-keychain" feature)
    .usb_only()                                    // or .bluetooth_only()
    .build()
    .await?;

let devices = trezor.scan().await?;           // active scan (triggers BLE discovery)
let devices = trezor.list_devices().await?;    // list already-discovered devices
let device = trezor.connect(&devices[0]).await?;
trezor.clear_credentials("device-id").await?;  // remove stored pairing credentials
```

### ConnectedDevice (operations)

Returned by `trezor.connect()`. Provides Bitcoin operations on the connected device.

```rust
let features = device.initialize().await?;

let addr = device.get_address(GetAddressParams {
    path: "m/84'/0'/0'/0/0".into(),
    show_on_trezor: false,
    ..Default::default()
}).await?;

let pubkey = device.get_public_key(GetPublicKeyParams {
    path: "m/84'/0'/0'".into(),
    ..Default::default()
}).await?;

let signed = device.sign_message(SignMessageParams {
    path: "m/84'/0'/0'/0/0".into(),
    message: "Hello".into(),
    ..Default::default()
}).await?;

let valid = device.verify_message(VerifyMessageParams {
    address: signed.address,
    signature: signed.signature,
    message: "Hello".into(),
    ..Default::default()
}).await?;

let tx = device.sign_transaction(SignTxParams {
    inputs: vec![/* ... */],
    outputs: vec![/* ... */],
    ..Default::default()
}).await?;

device.disconnect().await?;
```

### Low-Level API

For protocol-level access, use `TrezorClient` with a transport directly:

```rust
use trezor_connect_rs::{TrezorClient, UsbTransport, Transport};

let mut transport = UsbTransport::new()?;
transport.init().await?;

let devices = transport.enumerate().await?;
let mut client = TrezorClient::new(transport);
client.acquire(&devices[0].path).await?;

let features = client.initialize().await?;
let address = client.get_address("m/84'/0'/0'/0/0", false).await?;

client.release().await?;
```

## Passphrases & Hidden Wallets

A passphrase opens a separate *hidden* wallet on top of the device seed; an empty
passphrase opens the standard wallet. Host-entered passphrases are normalized to
Unicode **NFKD** before being sent (matching `@trezor/connect`), so accented or
non-Latin passphrases derive the same wallet here as in Trezor Suite.

**How the passphrase is bound depends on the device:**

- **Legacy (v1) devices** prompt mid-operation. Provide a
  [`TrezorUiCallback`](src/ui_callback.rs) via `Trezor::new().with_ui_callback(...)`
  and return a `PassphraseResponse` (`Standard`, `Hidden { value }`, `OnDevice`,
  or `Cancel`) from `on_passphrase_request`.
- **THP devices (Safe 5 / Safe 7)** bind the passphrase when the session is
  created, not via a mid-operation prompt. Construct the transport directly and
  call `with_session_passphrase(passphrase, on_device)` before acquiring:

  ```rust
  let mut transport = CallbackTransport::new(adapter)
      .with_session_passphrase("my secret".to_string(), /* on_device = */ false);
  transport.init().await?;
  let session = transport.acquire(&path, None).await?;
  ```

  Pass `on_device = true` to have the user type the passphrase on the Trezor
  itself (the `passphrase` argument is then ignored). Note: the high-level
  `Trezor` manager shares one transport across connections and does **not** bind
  per-connection passphrases for THP — use the transport directly for hidden THP
  wallets, as the `hidden_passphrase` example does.

### Detecting a wrong passphrase

The host never sees the seed, so it can't tell from the passphrase string whether
the user re-typed the *same* passphrase as before — a typo silently opens a
different wallet. Use the **static session id** (a stable fingerprint of the
active seed + passphrase) to detect this:

```rust
// First time: derive and persist the id for this wallet.
let saved = device.get_static_session_id().await?;

// Later connections: compare against the saved id.
match device.verify_session_state(Some(&saved)).await {
    Ok(current) => { /* same wallet; `current == saved` */ }
    Err(TrezorError::Device(DeviceError::InvalidState)) => {
        // A different passphrase was entered.
    }
    Err(e) => return Err(e),
}
```

This is opt-in: call it yourself and persist the expected id. See
[`session_state`](src/session_state.rs) for the format and comparison rules.

## Credential Storage

Bluetooth (THP) pairing produces cryptographic credentials that allow reconnection without re-pairing. Two storage backends are available:

**File-based** (default, no extra feature):
```rust
Trezor::new()
    .with_credential_store("~/.trezor-credentials.json")
```
Stores credentials as JSON with `0600` file permissions on Unix.

**OS keychain** (requires `os-keychain` feature):
```rust
Trezor::new()
    .with_keychain_store(None) // uses default "trezor-connect" service name
```
Uses macOS Keychain, Windows Credential Manager, or Linux Secret Service. Credentials are encrypted at rest by the OS.

If neither is configured, Bluetooth pairing is required on every connection.

## Error Handling

All operations return `trezor_connect_rs::Result<T>`, which wraps `TrezorError`:

```rust
use trezor_connect_rs::TrezorError;

match result {
    Err(TrezorError::Transport(e)) => println!("Connection failed: {}", e),
    Err(TrezorError::Device(e))    => println!("Device error: {}", e),
    Err(TrezorError::Thp(e))       => println!("THP/Bluetooth error: {}", e),
    Err(TrezorError::Protocol(e))  => println!("Protocol error: {}", e),
    Err(TrezorError::Session(e))   => println!("Session error: {}", e),
    Err(TrezorError::Bitcoin(e))   => println!("Bitcoin error: {}", e),
    Err(TrezorError::Cancelled)    => println!("Operation cancelled"),
    Err(TrezorError::Timeout)      => println!("Operation timed out"),
    Err(TrezorError::IoError(e))   => println!("I/O error: {}", e),
    Ok(val) => { /* success */ }
}
```

## Examples

```bash
# Recommended starting point - unified API with scanning, signing, verification
cargo run --example simple_api

# With OS keychain credential storage
cargo run --example simple_api --features os-keychain

# Use a hidden (passphrase-protected) wallet.
# Prompts whether to enter the passphrase on the host or on the Trezor's screen.
cargo run --example hidden_passphrase

# For host entry you can pre-supply the passphrase value instead of being prompted:
TREZOR_PASSPHRASE="my secret" cargo run --example hidden_passphrase

# USB-specific examples (low-level TrezorClient API)
cargo run --example get_address
cargo run --example sign_message
cargo run --example sign_transaction

# Bluetooth low-level example (raw THP protocol, useful for debugging)
cargo run --example bluetooth_connect
```

| Example | Transport | API Level | Description |
|---------|-----------|-----------|-------------|
| `simple_api` | USB + BLE | High-level | Full demo: scan, connect, get address, sign/verify message |
| `hidden_passphrase` | USB + BLE | High-level | Unlock a hidden (passphrase-protected) wallet via host or on-device entry |
| `get_address` | USB | Low-level | Get a native SegWit address |
| `sign_message` | USB | Low-level | Sign and verify a message |
| `sign_transaction` | USB | Low-level | Sign a Bitcoin transaction |
| `bluetooth_connect` | BLE | Low-level | Raw THP handshake, pairing, and encrypted messaging |

## Supported Devices

| Device | Transport | Protocol |
|--------|-----------|----------|
| Trezor Safe 7 | Bluetooth | THP v2 (Noise XX encrypted) |
| Trezor Safe 5 | USB | Protocol v1 |
| Trezor Safe 3 | USB | Protocol v1 |
| Trezor Model T | USB | Protocol v1 |
| Trezor Model One | USB | Protocol v1 |

## Project Structure

```
src/
├── lib.rs                # Library entry, re-exports
├── trezor.rs             # High-level manager (Trezor, TrezorBuilder)
├── connected_device.rs   # Connected device API (get_address, sign_tx, etc.)
├── credential_store.rs   # Credential persistence (file + OS keychain)
├── device_info.rs        # Device metadata (USB/BLE, model, path)
├── params.rs             # API parameter types
├── responses.rs          # API response types
├── error.rs              # Error definitions
├── transport/            # Transport layer
│   ├── usb.rs            #   USB transport (Protocol v1)
│   ├── bluetooth.rs      #   Bluetooth transport (THP v2)
│   ├── callback.rs       #   Callback-based transport (for FFI)
│   └── session.rs        #   Session management
├── protocol/             # Wire protocol encoding/decoding
│   ├── v1/               #   Protocol v1 (USB)
│   └── thp/              #   THP v2 (handshake, crypto, pairing, state)
├── device/               # Low-level TrezorClient, features, commands
├── protos/               # Protobuf message definitions
└── types/                # Bitcoin types, paths, networks
```

## License

MIT
