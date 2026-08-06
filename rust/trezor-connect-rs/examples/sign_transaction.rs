//! Example: Sign a Bitcoin transaction with Trezor
//!
//! This example demonstrates how to sign a Bitcoin transaction
//! using a Trezor device. Handles PIN/passphrase requests via stdin.

use std::io::{self, Write};
use std::sync::Arc;
use trezor_connect_rs::{
    PassphraseResponse, Result, TrezorClient, TrezorUiCallback, UsbTransport,
    api::sign_tx::{SignTransactionParams, TxInput, TxOutput},
    transport::Transport,
};

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
    env_logger::init();

    // Create USB transport
    let mut transport = UsbTransport::new()?;
    transport.init().await?;

    // List available devices
    let devices = transport.enumerate().await?;
    if devices.is_empty() {
        println!("No Trezor devices found!");
        return Ok(());
    }

    // Connect to the first device
    let device_path = &devices[0].path;
    let mut client = TrezorClient::new(transport);
    client.set_ui_callback(Arc::new(StdinUiCallback));
    client.acquire(device_path).await?;

    // Initialize device
    let features = client.initialize().await?;
    println!(
        "Connected to: {}",
        features.label.as_deref().unwrap_or_default()
    );

    // Build transaction parameters
    // This is a dummy transaction for demonstration
    let params = SignTransactionParams {
        inputs: vec![TxInput::new(
            "0000000000000000000000000000000000000000000000000000000000000001",
            0,
            "m/84'/0'/0'/0/0",
            100000, // 0.001 BTC
        )],
        outputs: vec![
            TxOutput::to_address("bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4", 90000),
            TxOutput::to_change("m/84'/0'/0'/1/0", 9000), // Change
        ],
        coin: "Bitcoin".to_string(),
        lock_time: 0,
        version: 2,
        prev_txs: vec![], // Would need actual prev tx for non-segwit
    };

    println!("\nSigning transaction...");
    println!("Please confirm on device.");

    let signed = client.sign_transaction(&params).await?;

    println!("\nTransaction signed!");
    println!("Signatures: {:?}", signed.signatures);
    println!("Serialized TX: {}", signed.serialized_tx);

    client.release().await?;

    Ok(())
}
