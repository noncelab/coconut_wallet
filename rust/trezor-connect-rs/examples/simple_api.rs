//! Simple API Example
//!
//! Demonstrates using the unified high-level Trezor API, including
//! handling PIN and passphrase requests via a UI callback.
//!
//! Run with: cargo run --example simple_api

use std::io::{self, Write};
use std::sync::Arc;
use trezor_connect_rs::{
    GetAddressParams, GetPublicKeyParams, PassphraseResponse, SignMessageParams, Trezor,
    TrezorUiCallback, VerifyMessageParams,
};

/// UI callback that prompts for PIN and passphrase via stdin.
///
/// Implement `TrezorUiCallback` so the library can handle PIN/passphrase
/// requests from the device instead of returning hard errors.
struct StdinUiCallback;

impl TrezorUiCallback for StdinUiCallback {
    fn on_pin_request(&self) -> Option<String> {
        println!("\n--- PIN Required ---");
        println!("Enter your PIN using the keypad layout shown on your Trezor:");
        println!("  7 8 9");
        println!("  4 5 6");
        println!("  1 2 3");
        print!("PIN: ");
        io::stdout().flush().unwrap();

        let mut pin = String::new();
        io::stdin().read_line(&mut pin).unwrap();
        let pin = pin.trim().to_string();

        if pin.is_empty() {
            println!("PIN entry cancelled.");
            None
        } else {
            Some(pin)
        }
    }

    fn on_passphrase_request(&self, on_device: bool) -> PassphraseResponse {
        if on_device {
            println!("\n--- Passphrase Required ---");
            println!("Please enter the passphrase on your Trezor device.");
            return PassphraseResponse::OnDevice;
        }

        println!("\n--- Passphrase Required ---");
        print!("Enter passphrase (leave empty for none): ");
        io::stdout().flush().unwrap();

        let mut passphrase = String::new();
        io::stdin().read_line(&mut passphrase).unwrap();
        let passphrase = passphrase.trim().to_string();
        if passphrase.is_empty() {
            PassphraseResponse::Standard
        } else {
            PassphraseResponse::Hidden { value: passphrase }
        }
    }
}

#[tokio::main]
async fn main() -> trezor_connect_rs::Result<()> {
    // Initialize logging
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp(None)
        .init();

    println!("=== Trezor Connect - Simple API Example ===\n");

    // Build the Trezor manager
    // Persist Bluetooth pairing credentials so re-pairing isn't needed on reconnect.
    // Prefer OS keychain (encrypted at rest) when the feature is enabled,
    // otherwise fall back to file-based storage.
    let mut builder = Trezor::new();

    #[cfg(feature = "os-keychain")]
    {
        println!("Using OS keychain for credential storage");
        builder = builder.with_keychain_store(None);
    }

    #[cfg(not(feature = "os-keychain"))]
    {
        let credential_path = dirs::home_dir()
            .map(|p| p.join(".trezor-credentials.json"))
            .map(|p| p.to_string_lossy().to_string());

        if let Some(path) = credential_path {
            println!("Using file credential store: {}", path);
            builder = builder.with_credential_store(&path);
        }
    }

    // Set the UI callback so PIN/passphrase requests are handled interactively
    // instead of returning errors.
    builder = builder.with_ui_callback(Arc::new(StdinUiCallback));

    // Set pairing callback for THP devices (Safe 7 etc.) — prompts for the
    // 6-digit code displayed on the Trezor screen during first-time pairing.
    builder = builder.with_pairing_callback(Arc::new(|| {
        Box::pin(async {
            println!("\n--- THP Pairing Code Required ---");
            println!("Enter the 6-digit code shown on your Trezor:");
            print!("Code: ");
            io::stdout().flush().unwrap();
            let mut code = String::new();
            io::stdin().read_line(&mut code).unwrap();
            code.trim().to_string()
        })
    }));

    let mut trezor = builder.build().await?;

    // Scan for devices
    println!("Scanning for devices...");
    let devices = trezor.scan().await?;

    if devices.is_empty() {
        println!("No devices found. Make sure your Trezor is connected.");
        return Ok(());
    }

    println!("\nFound {} device(s):", devices.len());
    for (i, device) in devices.iter().enumerate() {
        println!(
            "  [{}] {} ({})",
            i,
            device.display_name(),
            device.transport_type
        );
    }

    // Let user select a device if multiple found
    let device_idx = if devices.len() > 1 {
        print!("\nSelect device [0-{}]: ", devices.len() - 1);
        io::stdout().flush().unwrap();
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        input.trim().parse().unwrap_or(0)
    } else {
        0
    };

    let selected_device = &devices[device_idx];
    println!("\nConnecting to {}...", selected_device.display_name());

    // Connect to device
    let mut device = trezor.connect(selected_device).await?;

    // Initialize and get features
    let features = device.initialize().await?;
    println!(
        "Connected to: {}",
        features.label.as_deref().unwrap_or("Unnamed Trezor")
    );
    println!("  Model: {:?}", features.model);
    println!(
        "  Firmware: {}.{}.{}",
        features.major_version.unwrap_or(0),
        features.minor_version.unwrap_or(0),
        features.patch_version.unwrap_or(0)
    );

    // Get Bitcoin address
    println!("\n--- Get Address ---");
    let address = device
        .get_address(GetAddressParams {
            path: "m/84'/0'/0'/0/0".into(),
            show_on_trezor: false,
            ..Default::default()
        })
        .await?;
    println!("Address: {}", address.address);
    println!("Path: {}", address.serialized_path);

    // Get public key
    println!("\n--- Get Public Key ---");
    let pubkey = device
        .get_public_key(GetPublicKeyParams {
            path: "m/84'/0'/0'".into(),
            show_on_trezor: false,
            ..Default::default()
        })
        .await?;
    println!("XPub: {}", pubkey.xpub);
    println!("Path: {}", pubkey.serialized_path);

    // Sign message (requires button confirmation)
    println!("\n--- Sign Message ---");
    println!("Please confirm the message on your device...");
    let message = "Hello from Rust!";
    let signature = device
        .sign_message(SignMessageParams {
            path: "m/84'/0'/0'/0/0".into(),
            message: message.into(),
            ..Default::default()
        })
        .await?;
    println!("Signed: \"{}\"", message);
    println!("Address: {}", signature.address);
    println!("Signature: {}", signature.signature);

    // Verify message
    println!("\n--- Verify Message ---");
    let valid = device
        .verify_message(VerifyMessageParams {
            address: signature.address.clone(),
            signature: signature.signature.clone(),
            message: message.into(),
            ..Default::default()
        })
        .await?;
    println!("Signature valid: {}", valid);

    // Disconnect
    device.disconnect().await?;
    println!("\nDisconnected successfully.");

    Ok(())
}
