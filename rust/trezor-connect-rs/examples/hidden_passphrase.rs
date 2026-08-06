//! Example: Use a hidden (passphrase-protected) wallet
//!
//! A Trezor "hidden wallet" is an entirely separate wallet derived from a
//! passphrase you supply in addition to your PIN. The same passphrase always
//! unlocks the same hidden wallet; a different passphrase (or no passphrase at
//! all — the "standard" wallet) derives a completely different set of keys and
//! addresses. The passphrase is never stored on the device, which is what makes
//! the wallet "hidden": without it, there is no way to know the wallet exists.
//!
//! The passphrase can be entered two ways, and this example asks which one to
//! use when it starts:
//!
//! 1. Host entry — you type the passphrase on this computer; the host sends it
//!    to the device.
//! 2. On-device entry — you type the passphrase on the Trezor's own screen; it
//!    never touches the host.
//!
//! Run it and pick a method when prompted:
//!
//!     cargo run --example hidden_passphrase
//!
//! For host entry you can pre-supply the passphrase via the `TREZOR_PASSPHRASE`
//! environment variable instead of being prompted for the value:
//!
//!     TREZOR_PASSPHRASE="my secret" cargo run --example hidden_passphrase
//!
//! Try running it with two different passphrases and compare the addresses —
//! they will differ, because each passphrase is its own wallet.

use std::io::{self, Write};
use std::sync::Arc;
use trezor_connect_rs::{
    GetAddressParams, GetPublicKeyParams, PassphraseResponse, Trezor, TrezorUiCallback,
};

/// UI callback that opens a hidden wallet, either via host entry or by
/// deferring passphrase entry to the Trezor's own screen.
struct HiddenWalletCallback {
    /// Passphrase used for host entry. Ignored when `prefer_on_device` is true.
    passphrase: String,
    /// When true, ask the user to type the passphrase on the Trezor instead of
    /// sending one from the host.
    prefer_on_device: bool,
}

impl TrezorUiCallback for HiddenWalletCallback {
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
        if pin.is_empty() { None } else { Some(pin) }
    }

    fn on_passphrase_request(&self, on_device: bool) -> PassphraseResponse {
        // `on_device == true` means the device itself asked for on-device entry
        // (e.g. it is configured that way). `self.prefer_on_device` means we are
        // choosing on-device entry from the host side. Either way, return
        // OnDevice so the library acks on-device entry and the Trezor shows its
        // own keyboard — the passphrase never touches the host.
        if on_device || self.prefer_on_device {
            println!("\n--- Passphrase Entry On Device ---");
            println!("Enter the passphrase for your hidden wallet on the Trezor's screen.");
            return PassphraseResponse::OnDevice;
        }

        // Host entry: send our passphrase to open the hidden wallet.
        println!("\n--- Passphrase Entry On Host ---");
        println!("Unlocking hidden wallet with the supplied passphrase.");
        PassphraseResponse::Hidden {
            value: self.passphrase.clone(),
        }
    }
}

/// Ask whether to enter the passphrase on the host or on the Trezor's screen.
fn prompt_on_device() -> bool {
    print!("\nEnter the passphrase on the (h)ost computer or on the (d)evice screen? [h/d]: ");
    io::stdout().flush().unwrap();
    let mut choice = String::new();
    io::stdin().read_line(&mut choice).unwrap();
    matches!(choice.trim().to_ascii_lowercase().as_str(), "d" | "device")
}

/// Get the passphrase from `TREZOR_PASSPHRASE`, or prompt for it on stdin.
fn read_passphrase() -> String {
    if let Ok(p) = std::env::var("TREZOR_PASSPHRASE") {
        if !p.is_empty() {
            println!("Using passphrase from TREZOR_PASSPHRASE.");
            return p;
        }
    }

    print!("Enter passphrase for the hidden wallet (input is visible): ");
    io::stdout().flush().unwrap();
    let mut passphrase = String::new();
    io::stdin().read_line(&mut passphrase).unwrap();
    passphrase.trim().to_string()
}

#[tokio::main]
async fn main() -> trezor_connect_rs::Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp(None)
        .init();

    println!("=== Trezor Connect - Hidden Passphrase Example ===\n");

    // Choose the entry method: on-device (type on the Trezor) vs host (type here).
    let prefer_on_device = prompt_on_device();

    let passphrase = if prefer_on_device {
        println!("On-device entry selected — you'll type the passphrase on the Trezor.");
        String::new()
    } else {
        let p = read_passphrase();
        if p.is_empty() {
            println!(
                "\nNote: an empty passphrase opens the *standard* wallet, not a hidden one.\n\
                 Provide a non-empty passphrase, or choose on-device entry to type it on the Trezor."
            );
        }
        p
    };

    // Build the Trezor manager with our hidden-wallet callback.
    let mut builder = Trezor::new().with_ui_callback(Arc::new(HiddenWalletCallback {
        passphrase,
        prefer_on_device,
    }));

    // THP devices (Safe 7 etc.) prompt for a 6-digit pairing code on first use.
    builder = builder.with_pairing_callback(Arc::new(|| {
        Box::pin(async {
            println!("\n--- THP Pairing Code Required ---");
            print!("Enter the 6-digit code shown on your Trezor: ");
            io::stdout().flush().unwrap();
            let mut code = String::new();
            io::stdin().read_line(&mut code).unwrap();
            code.trim().to_string()
        })
    }));

    let mut trezor = builder.build().await?;

    // Find and connect to a device.
    println!("\nScanning for devices...");
    let devices = trezor.scan().await?;
    if devices.is_empty() {
        println!("No devices found. Make sure your Trezor is connected.");
        return Ok(());
    }
    let selected = &devices[0];
    println!("Connecting to {}...", selected.display_name());
    let mut device = trezor.connect(selected).await?;

    // Initialize. The passphrase callback fires the first time an operation
    // needs the wallet (below), unlocking the hidden wallet. In on-device mode
    // the Trezor shows its own passphrase keyboard at that point.
    let features = device.initialize().await?;
    println!(
        "Connected to: {} (model {:?})",
        features.label.as_deref().unwrap_or("Unnamed Trezor"),
        features.model
    );

    // Derive from the hidden wallet. These keys/addresses belong to the wallet
    // defined by the passphrase — change the passphrase and they change.
    println!("\n--- Hidden Wallet Account (BIP84) ---");
    let pubkey = device
        .get_public_key(GetPublicKeyParams {
            path: "m/84'/0'/0'".into(),
            show_on_trezor: false,
            ..Default::default()
        })
        .await?;
    println!("Account xpub: {}", pubkey.xpub);

    println!("\n--- Hidden Wallet First Receive Address ---");
    let address = device
        .get_address(GetAddressParams {
            path: "m/84'/0'/0'/0/0".into(),
            show_on_trezor: false,
            ..Default::default()
        })
        .await?;
    println!("Address: {}", address.address);
    println!("Path:    {}", address.serialized_path);

    println!(
        "\nThis address belongs to the hidden wallet for the passphrase you \
         provided.\nRun again with a different passphrase (or choose on-device \
         entry) to reach a different wallet."
    );

    // --- Static session id (wrong-passphrase detection) ---
    // A stable fingerprint of the active seed + passphrase. Persist it the first
    // time you open a wallet; on later connections compare against it to catch a
    // mistyped passphrase — which would otherwise silently open a *different*
    // (usually empty) wallet. Changing the passphrase changes this value.
    let session_id = device.get_static_session_id().await?;
    println!("\n--- Static Session Id ---");
    println!("{session_id}");
    println!(
        "Save this, then on the next connection call\n\
         `device.verify_session_state(Some(&saved)).await?` — it returns the\n\
         current id, or `Err(DeviceError::InvalidState)` if a different\n\
         passphrase was entered."
    );

    device.disconnect().await?;
    println!("\nDisconnected.");
    Ok(())
}
