//! Example: Connect to Trezor Safe 7 via Bluetooth
//!
//! This example demonstrates how to connect to a Trezor Safe 7 device
//! via Bluetooth using the THP (Trezor Host Protocol).
//!
//! Features demonstrated:
//! - BLE connection and THP handshake
//! - Code entry pairing
//! - GetAddress (native SegWit)
//! - SignMessage
//! - VerifyMessage
//!
//! Run with debug logging: RUST_LOG=debug cargo run --example bluetooth_connect

use std::io::{self, Write};
use trezor_connect_rs::transport::Transport;
use trezor_connect_rs::{BluetoothTransport, Result};

// Message type constants
const MSG_SUCCESS: u16 = 2;
const MSG_FAILURE: u16 = 3;
const MSG_FEATURES: u16 = 17;
const MSG_BUTTON_REQUEST: u16 = 26;
const MSG_BUTTON_ACK: u16 = 27;
const MSG_GET_ADDRESS: u16 = 29;
const MSG_ADDRESS: u16 = 30;
const MSG_SIGN_MESSAGE: u16 = 38;
const MSG_VERIFY_MESSAGE: u16 = 39;
const MSG_MESSAGE_SIGNATURE: u16 = 40;
const MSG_GET_FEATURES: u16 = 55;
const MSG_THP_CREATE_SESSION: u16 = 1000;

fn prompt_for_code() -> String {
    print!("\nEnter the 6-digit code shown on your Trezor: ");
    io::stdout().flush().unwrap();

    let mut code = String::new();
    io::stdin().read_line(&mut code).unwrap();
    code.trim().to_string()
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging - use RUST_LOG=debug for verbose output
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp(None)
        .init();

    println!("=== Trezor Safe 7 Bluetooth Connection ===\n");
    println!("IMPORTANT: Your Trezor needs to be in Bluetooth pairing mode!");
    println!("  1. On your Trezor: Go to Settings > Bluetooth");
    println!("  2. Enable Bluetooth pairing mode");
    println!("  3. The device should display 'Waiting for pairing' or similar");
    println!("\nNOTE: When connecting, you may need to confirm on the Trezor screen!\n");

    // Create Bluetooth transport
    println!("Initializing Bluetooth adapter...");
    let mut transport = BluetoothTransport::new().await?;

    println!("Starting BLE scan (5 seconds)...");
    transport.init().await?;

    // Scan for devices
    println!("Looking for Trezor devices...\n");
    let devices = transport.enumerate().await?;

    if devices.is_empty() {
        println!("No Trezor devices found!\n");
        println!("Troubleshooting:");
        println!("  1. Make sure Bluetooth is enabled on your computer");
        println!("  2. Put your Trezor Safe 7 in pairing mode");
        println!("  3. Keep the device close to your computer");
        println!("  4. Try running with RUST_LOG=debug for more info:");
        println!("     RUST_LOG=debug cargo run --example bluetooth_connect");
        return Ok(());
    }

    println!("Found {} device(s):", devices.len());
    for device in &devices {
        println!("  - {}", device.path);
    }

    // Connect to the first device
    let device_path = devices[0].path.clone();
    println!("\nConnecting to {}...", device_path);

    // Acquire the device (performs THP handshake)
    match transport.acquire(&device_path, None).await {
        Ok(session) => {
            println!("\n=== THP Handshake and Pairing Successful! ===");
            println!("Session: {}", session);

            // Now we can communicate with the device
            // TODO: Send Initialize and GetAddress

            // Release the session
            transport.release(&session).await?;
            println!("\nDisconnected.");
        }
        Err(e) => {
            let error_str = e.to_string();
            if error_str.contains("Pairing required") || error_str.contains("PairingRequired") {
                println!("\n=== Pairing Required ===");
                println!("\nThe THP handshake completed, but device needs pairing.");
                println!("Starting pairing flow...\n");

                // Perform pairing with user code input
                match transport
                    .perform_pairing(&device_path, prompt_for_code)
                    .await
                {
                    Ok(()) => {
                        println!("\n=== Pairing Successful! ===");

                        // After pairing, we need to create a THP session first
                        println!("\nCreating THP session...");

                        // ThpCreateNewSession (type 1000):
                        // Field 1: passphrase (string) - empty for no passphrase
                        // Field 2: on_device (bool) - false
                        // Field 3: derive_cardano (bool) - false
                        let mut create_session = Vec::new();
                        // Field 1: empty passphrase
                        create_session.push(0x0a); // field 1, wire type 2 (string)
                        create_session.push(0x00); // length 0 (empty string)

                        match transport
                            .send_encrypted_message(
                                &device_path,
                                MSG_THP_CREATE_SESSION,
                                &create_session,
                            )
                            .await
                        {
                            Ok((resp_type, resp_data)) => {
                                println!(
                                    "ThpCreateNewSession response type: {} ({} bytes)",
                                    resp_type,
                                    resp_data.len()
                                );

                                if resp_type == MSG_FAILURE {
                                    println!("Session creation failed!");
                                    if let Some(msg) = parse_failure(&resp_data) {
                                        println!("Error: {}", msg);
                                    }
                                    return Ok(());
                                } else if resp_type != MSG_SUCCESS {
                                    println!("Unexpected response type: {}", resp_type);
                                    println!("Raw data: {:02x?}", &resp_data);
                                    return Ok(());
                                }

                                println!("Session created successfully!");
                            }
                            Err(e) => {
                                println!("ThpCreateNewSession error: {}", e);
                                return Ok(());
                            }
                        }

                        // Now send GetFeatures - THP uses this instead of Initialize
                        println!("\nSending GetFeatures command...");
                        match transport
                            .send_encrypted_message(&device_path, MSG_GET_FEATURES, &[])
                            .await
                        {
                            Ok((resp_type, resp_data)) => {
                                println!(
                                    "GetFeatures response type {} ({} bytes)",
                                    resp_type,
                                    resp_data.len()
                                );

                                if resp_type == MSG_FAILURE {
                                    println!("\n=== Received Failure Response ===");
                                    println!("Raw data: {:02x?}", &resp_data);
                                    if let Some(msg) = parse_failure(&resp_data) {
                                        println!("Error: {}", msg);
                                    }
                                } else if resp_type == MSG_FEATURES {
                                    // Features message
                                    println!("\n=== Device Features Received! ===");
                                    println!(
                                        "Raw features data ({} bytes): {:02x?}",
                                        resp_data.len(),
                                        &resp_data[..resp_data.len().min(50)]
                                    );

                                    // Run the demo operations
                                    if let Err(e) =
                                        run_demo_operations(&transport, &device_path).await
                                    {
                                        println!("Demo operations error: {}", e);
                                    }
                                }
                            }
                            Err(e) => println!("GetFeatures error: {}", e),
                        }

                        // Try to release session
                        let _ = transport.release(&device_path).await;
                    }
                    Err(e) => {
                        println!("Pairing failed: {}", e);
                        return Err(e);
                    }
                }
            } else {
                return Err(e);
            }
        }
    }

    Ok(())
}

/// Helper to handle ButtonRequest flow
async fn handle_button_request(
    transport: &BluetoothTransport,
    device_path: &str,
    expected_type: u16,
) -> Result<(u16, Vec<u8>)> {
    println!("Device is asking for confirmation on screen...");
    println!("Please confirm on your Trezor.");

    // Send ButtonAck
    let (resp_type, resp_data) = transport
        .send_encrypted_message(device_path, MSG_BUTTON_ACK, &[])
        .await?;

    // May get another ButtonRequest (e.g., for signing)
    if resp_type == MSG_BUTTON_REQUEST {
        return Box::pin(handle_button_request(transport, device_path, expected_type)).await;
    }

    Ok((resp_type, resp_data))
}

/// Run demo operations: GetAddress, SignMessage, VerifyMessage
async fn run_demo_operations(transport: &BluetoothTransport, device_path: &str) -> Result<()> {
    // BIP84 path for native SegWit: m/84'/0'/0'/0/0
    let address_path: [u32; 5] = [
        0x80000000 | 84, // 84'
        0x80000000 | 0,  // 0'
        0x80000000 | 0,  // 0'
        0,               // 0
        0,               // 0
    ];

    // ========================================
    // 1. GET ADDRESS
    // ========================================
    println!("\n--- GetAddress (m/84'/0'/0'/0/0) ---");

    let get_address = encode_get_address(&address_path, 3); // 3 = SPENDWITNESS
    let (mut resp_type, mut resp_data) = transport
        .send_encrypted_message(device_path, MSG_GET_ADDRESS, &get_address)
        .await?;

    // Handle ButtonRequest if device wants confirmation
    if resp_type == MSG_BUTTON_REQUEST {
        (resp_type, resp_data) = handle_button_request(transport, device_path, MSG_ADDRESS).await?;
    }

    let address = if resp_type == MSG_ADDRESS {
        match parse_address(&resp_data) {
            Some(addr) => {
                println!("Bitcoin Address: {}", addr);
                addr
            }
            None => {
                println!("Failed to parse address response: {:02x?}", resp_data);
                return Ok(());
            }
        }
    } else if resp_type == MSG_FAILURE {
        println!(
            "GetAddress failed: {}",
            parse_failure(&resp_data).unwrap_or_default()
        );
        return Ok(());
    } else {
        println!("Unexpected response type {}: {:02x?}", resp_type, resp_data);
        return Ok(());
    };

    // ========================================
    // 2. SIGN MESSAGE
    // ========================================
    let message = b"Hello from Rust Trezor Connect!";
    println!("\n--- SignMessage ---");
    println!("Message: \"{}\"", String::from_utf8_lossy(message));
    println!("Path: m/84'/0'/0'/0/0");

    let sign_msg = encode_sign_message(&address_path, message, 3); // 3 = SPENDWITNESS
    let (mut resp_type, mut resp_data) = transport
        .send_encrypted_message(device_path, MSG_SIGN_MESSAGE, &sign_msg)
        .await?;

    // Handle ButtonRequest(s) - signing usually requires confirmation
    while resp_type == MSG_BUTTON_REQUEST {
        (resp_type, resp_data) =
            handle_button_request(transport, device_path, MSG_MESSAGE_SIGNATURE).await?;
    }

    let signature = if resp_type == MSG_MESSAGE_SIGNATURE {
        match parse_message_signature(&resp_data) {
            Some((sig_address, sig)) => {
                println!("Signed by: {}", sig_address);
                println!("Signature ({} bytes): {}", sig.len(), base64_encode(&sig));
                sig
            }
            None => {
                println!("Failed to parse signature response: {:02x?}", resp_data);
                return Ok(());
            }
        }
    } else if resp_type == MSG_FAILURE {
        println!(
            "SignMessage failed: {}",
            parse_failure(&resp_data).unwrap_or_default()
        );
        return Ok(());
    } else {
        println!("Unexpected response type {}: {:02x?}", resp_type, resp_data);
        return Ok(());
    };

    // ========================================
    // 3. VERIFY MESSAGE
    // ========================================
    println!("\n--- VerifyMessage ---");
    println!("Verifying the signature we just created...");

    let verify_msg = encode_verify_message(&address, &signature, message);
    let (mut resp_type, mut resp_data) = transport
        .send_encrypted_message(device_path, MSG_VERIFY_MESSAGE, &verify_msg)
        .await?;

    // Handle ButtonRequest if device wants to show verification
    while resp_type == MSG_BUTTON_REQUEST {
        (resp_type, resp_data) = handle_button_request(transport, device_path, MSG_SUCCESS).await?;
    }

    if resp_type == MSG_SUCCESS {
        println!("✓ Signature verified successfully!");
    } else if resp_type == MSG_FAILURE {
        println!(
            "✗ Verification failed: {}",
            parse_failure(&resp_data).unwrap_or_default()
        );
    } else {
        println!("Unexpected response type {}: {:02x?}", resp_type, resp_data);
    }

    // ========================================
    // 4. VERIFY WITH WRONG MESSAGE (should fail)
    // ========================================
    println!("\n--- VerifyMessage (with wrong message - should fail) ---");

    let wrong_message = b"This is not the original message!";
    let verify_wrong = encode_verify_message(&address, &signature, wrong_message);
    let (mut resp_type, mut resp_data) = transport
        .send_encrypted_message(device_path, MSG_VERIFY_MESSAGE, &verify_wrong)
        .await?;

    while resp_type == MSG_BUTTON_REQUEST {
        (resp_type, resp_data) = handle_button_request(transport, device_path, MSG_SUCCESS).await?;
    }

    if resp_type == MSG_SUCCESS {
        println!("✓ Signature verified (unexpected!)");
    } else if resp_type == MSG_FAILURE {
        println!(
            "✗ Verification failed (expected): {}",
            parse_failure(&resp_data).unwrap_or_default()
        );
    } else {
        println!("Unexpected response type {}: {:02x?}", resp_type, resp_data);
    }

    println!("\n=== All operations completed! ===");
    Ok(())
}

/// Encode a GetAddress protobuf
fn encode_get_address(address_n: &[u32], script_type: u8) -> Vec<u8> {
    let mut data = Vec::new();

    // Field 1: address_n (repeated uint32)
    for &n in address_n {
        data.push(0x08); // field 1, wire type 0 (varint)
        encode_varint(&mut data, n as u64);
    }

    // Field 2: coin_name (string) = "Bitcoin"
    data.extend_from_slice(&[0x12, 0x07]);
    data.extend_from_slice(b"Bitcoin");

    // Field 3: show_display (bool) = false
    data.extend_from_slice(&[0x18, 0x00]);

    // Field 5: script_type (enum)
    data.push(0x28); // field 5, wire type 0
    data.push(script_type);

    data
}

/// Simple base64 encoding for display
fn base64_encode(data: &[u8]) -> String {
    const ALPHABET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut result = String::new();

    for chunk in data.chunks(3) {
        let b0 = chunk[0] as usize;
        let b1 = chunk.get(1).copied().unwrap_or(0) as usize;
        let b2 = chunk.get(2).copied().unwrap_or(0) as usize;

        result.push(ALPHABET[b0 >> 2] as char);
        result.push(ALPHABET[((b0 & 0x03) << 4) | (b1 >> 4)] as char);

        if chunk.len() > 1 {
            result.push(ALPHABET[((b1 & 0x0f) << 2) | (b2 >> 6)] as char);
        } else {
            result.push('=');
        }

        if chunk.len() > 2 {
            result.push(ALPHABET[b2 & 0x3f] as char);
        } else {
            result.push('=');
        }
    }

    result
}

fn encode_varint(buf: &mut Vec<u8>, mut value: u64) {
    while value >= 0x80 {
        buf.push((value as u8) | 0x80);
        value >>= 7;
    }
    buf.push(value as u8);
}

fn parse_failure(data: &[u8]) -> Option<String> {
    // Failure message has:
    // Field 1: code (varint) - optional
    // Field 2: message (string) - the error message
    let mut pos = 0;
    while pos < data.len() {
        let tag = data[pos];
        pos += 1;
        let field_num = tag >> 3;
        let wire_type = tag & 0x07;

        if field_num == 2 && wire_type == 2 {
            // Length-delimited string
            if pos < data.len() {
                let len = data[pos] as usize;
                pos += 1;
                if pos + len <= data.len() {
                    return Some(String::from_utf8_lossy(&data[pos..pos + len]).to_string());
                }
            }
        } else if wire_type == 0 {
            // Varint - skip
            while pos < data.len() && data[pos] & 0x80 != 0 {
                pos += 1;
            }
            pos += 1;
        } else if wire_type == 2 {
            // Length-delimited - skip
            if pos < data.len() {
                let len = data[pos] as usize;
                pos += 1 + len;
            }
        }
    }
    None
}

/// Encode a SignMessage protobuf
/// Fields:
/// - 1: address_n (repeated uint32) - BIP32 path
/// - 2: message (bytes) - message to sign
/// - 3: coin_name (string) - optional, defaults to "Bitcoin"
/// - 4: script_type (enum) - input script type (3 = SPENDWITNESS)
fn encode_sign_message(address_n: &[u32], message: &[u8], script_type: u8) -> Vec<u8> {
    let mut data = Vec::new();

    // Field 1: address_n (repeated uint32)
    for &n in address_n {
        data.push(0x08); // field 1, wire type 0 (varint)
        encode_varint(&mut data, n as u64);
    }

    // Field 2: message (bytes)
    data.push(0x12); // field 2, wire type 2 (length-delimited)
    encode_varint(&mut data, message.len() as u64);
    data.extend_from_slice(message);

    // Field 3: coin_name (string) = "Bitcoin"
    data.push(0x1a); // field 3, wire type 2
    data.push(0x07); // length 7
    data.extend_from_slice(b"Bitcoin");

    // Field 4: script_type (enum)
    data.push(0x20); // field 4, wire type 0 (varint)
    data.push(script_type);

    data
}

/// Encode a VerifyMessage protobuf
/// Fields:
/// - 1: address (string) - address that signed the message
/// - 2: signature (bytes) - the signature
/// - 3: message (bytes) - the original message
/// - 4: coin_name (string) - optional
fn encode_verify_message(address: &str, signature: &[u8], message: &[u8]) -> Vec<u8> {
    let mut data = Vec::new();

    // Field 1: address (string)
    data.push(0x0a); // field 1, wire type 2
    encode_varint(&mut data, address.len() as u64);
    data.extend_from_slice(address.as_bytes());

    // Field 2: signature (bytes)
    data.push(0x12); // field 2, wire type 2
    encode_varint(&mut data, signature.len() as u64);
    data.extend_from_slice(signature);

    // Field 3: message (bytes)
    data.push(0x1a); // field 3, wire type 2
    encode_varint(&mut data, message.len() as u64);
    data.extend_from_slice(message);

    // Field 4: coin_name (string) = "Bitcoin"
    data.push(0x22); // field 4, wire type 2
    data.push(0x07); // length 7
    data.extend_from_slice(b"Bitcoin");

    data
}

/// Parse a MessageSignature response
/// Fields:
/// - 1: address (string) - address used to sign
/// - 2: signature (bytes) - the signature
fn parse_message_signature(data: &[u8]) -> Option<(String, Vec<u8>)> {
    let mut address = String::new();
    let mut signature = Vec::new();
    let mut pos = 0;

    while pos < data.len() {
        let tag = data[pos];
        pos += 1;
        let field_num = tag >> 3;
        let wire_type = tag & 0x07;

        if wire_type == 2 {
            // Length-delimited
            if pos >= data.len() {
                break;
            }
            let (len, varint_len) = decode_varint(&data[pos..])?;
            pos += varint_len;
            let end = pos + len as usize;
            if end > data.len() {
                break;
            }

            match field_num {
                1 => address = String::from_utf8_lossy(&data[pos..end]).to_string(),
                2 => signature = data[pos..end].to_vec(),
                _ => {}
            }
            pos = end;
        } else if wire_type == 0 {
            // Varint - skip
            while pos < data.len() && data[pos] & 0x80 != 0 {
                pos += 1;
            }
            pos += 1;
        }
    }

    if !address.is_empty() && !signature.is_empty() {
        Some((address, signature))
    } else {
        None
    }
}

/// Decode a varint, returns (value, bytes_consumed)
fn decode_varint(data: &[u8]) -> Option<(u64, usize)> {
    let mut value: u64 = 0;
    let mut shift = 0;

    for (i, &byte) in data.iter().enumerate() {
        value |= ((byte & 0x7f) as u64) << shift;
        if byte & 0x80 == 0 {
            return Some((value, i + 1));
        }
        shift += 7;
        if shift > 63 {
            return None;
        }
    }
    None
}

/// Parse an Address response (field 1 is the address string)
fn parse_address(data: &[u8]) -> Option<String> {
    if data.len() > 2 && data[0] == 0x0a {
        let (len, varint_len) = decode_varint(&data[1..])?;
        let start = 1 + varint_len;
        let end = start + len as usize;
        if data.len() >= end {
            return Some(String::from_utf8_lossy(&data[start..end]).to_string());
        }
    }
    None
}
