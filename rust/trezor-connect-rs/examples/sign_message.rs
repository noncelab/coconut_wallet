//! Example: Sign and verify a message with Trezor
//!
//! This example demonstrates how to:
//! 1. Sign a message using a Bitcoin key on the Trezor
//! 2. Verify the signature using the device
//!
//! Handles PIN/passphrase requests via stdin.

use std::io::{self, Write};
use std::sync::Arc;
use trezor_connect_rs::transport::Transport;
use trezor_connect_rs::{PassphraseResponse, Result, TrezorClient, TrezorUiCallback, UsbTransport};

/// UI callback that prompts for PIN and passphrase via stdin.
struct StdinUiCallback;

impl TrezorUiCallback for StdinUiCallback {
    fn on_pin_request(&self) -> Option<String> {
        println!("\nEnter PIN using the keypad layout on your Trezor (7-8-9 / 4-5-6 / 1-2-3):");
        print!("PIN: ");
        io::stdout().flush().unwrap();
        let mut pin = String::new();
        io::stdin().read_line(&mut pin).unwrap();
        let pin = pin.trim().to_string();
        if pin.is_empty() { None } else { Some(pin) }
    }

    fn on_passphrase_request(&self, on_device: bool) -> PassphraseResponse {
        if on_device {
            println!("\nPlease enter the passphrase on your Trezor device.");
            return PassphraseResponse::OnDevice;
        }
        print!("\nEnter passphrase (leave empty for none): ");
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
async fn main() -> Result<()> {
    // Initialize logging - set RUST_LOG=debug for verbose output
    env_logger::init();

    // Create USB transport
    println!("Creating USB transport...");
    let mut transport = UsbTransport::new()?;
    transport.init().await?;

    // List available devices
    let devices = transport.enumerate().await?;
    if devices.is_empty() {
        println!("No Trezor devices found!");
        return Ok(());
    }

    println!("Found {} device(s)", devices.len());
    for device in &devices {
        println!("  - {} ({})", device.path, device.product_id);
    }

    // Connect to the first device
    let device_path = &devices[0].path;
    println!("\nAcquiring session for device: {}...", device_path);
    let mut client = TrezorClient::new(transport);
    client.set_ui_callback(Arc::new(StdinUiCallback));
    client.acquire(device_path).await?;
    println!("Session acquired: {:?}", client.session());

    // Initialize device and get features
    println!("\nSending Initialize message...");
    let features = client.initialize().await?;
    println!(
        "\nConnected to: {} ({})",
        features.label.as_deref().unwrap_or_default(),
        features.model.as_deref().unwrap_or_default()
    );
    println!("Firmware: {}", features.version_string());

    // The message to sign
    let message = b"Hello from Rust trezor-connect!";
    let path = "m/84'/0'/0'/0/0";

    println!("\n=== Message Signing ===");
    println!("Path: {}", path);
    println!("Message: \"{}\"", String::from_utf8_lossy(message));

    // First get the address for this path (we'll need it for verification)
    println!("\nGetting address for signing path...");
    let address = client.get_address(path, false).await?;
    println!("Address: {}", address);

    // Sign the message (requires button confirmation on device)
    println!("\n--- Signing Message ---");
    println!("Please confirm the message signing on your Trezor device.");

    let signed = client.sign_message(path, message).await?;

    println!("\nMessage signed successfully!");
    println!("Address: {}", signed.address);
    println!("Signature (base64): {}", signed.signature_base64());
    println!("Signature (hex): {}", signed.signature_hex());

    // Verify the signature
    println!("\n=== Message Verification ===");
    println!("Verifying the signature on device...");
    println!("Please confirm on your Trezor device.");

    let verified = client
        .verify_message(&signed.address, &signed.signature, message)
        .await?;

    if verified {
        println!("\nSignature verified successfully!");
    } else {
        println!("\nSignature verification failed!");
    }

    // Test with a tampered message (should fail)
    println!("\n=== Testing with Tampered Message ===");
    let tampered_message = b"Hello from Rust trezor-connect! (tampered)";
    println!(
        "Verifying with tampered message: \"{}\"",
        String::from_utf8_lossy(tampered_message)
    );

    let tampered_result = client
        .verify_message(&signed.address, &signed.signature, tampered_message)
        .await?;

    if tampered_result {
        println!("WARNING: Tampered message verified (unexpected!)");
    } else {
        println!("Tampered message correctly rejected!");
    }

    // Release session
    client.release().await?;
    println!("\nSession released. Done!");

    Ok(())
}
