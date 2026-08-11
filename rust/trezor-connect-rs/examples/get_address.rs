//! Example: Get Bitcoin address from Trezor device
//!
//! This example demonstrates how to connect to a Trezor device via USB
//! and retrieve a Bitcoin address. Handles PIN/passphrase via stdin.

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

    // Get public key (BIP84 account)
    let account_path = "m/84'/0'/0'";
    println!("\nGetting public key for path: {}", account_path);
    let xpub = client.get_public_key(account_path).await?;
    println!("xpub: {}", xpub);

    // Get a native SegWit address (BIP84)
    let address_path = "m/84'/0'/0'/0/0";
    println!("\nGetting address for path: {} (no display)", address_path);
    let address = client.get_address(address_path, false).await?;
    println!("Address: {}", address);

    // Test with display confirmation (requires button press on device)
    // Comment this out if you don't want to wait for button press
    println!("\n--- Button Confirmation Test ---");
    println!("The address will now be shown on your Trezor device.");
    println!("Please confirm it by pressing the button.");
    println!("(This will timeout after ~50 seconds if not confirmed)\n");

    match client.get_address(address_path, true).await {
        Ok(addr) => println!("Confirmed address: {}", addr),
        Err(e) => println!("Confirmation timed out or failed: {:?}", e),
    }

    // Release session
    client.release().await?;

    Ok(())
}
