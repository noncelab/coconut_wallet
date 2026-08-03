// trezor-bridge/src/lib.rs
//
// UniFFI bridge for Trezor Safe 7 BLE using trezor-connect-rs CallbackTransport.
//
// Architecture:
//   Native BLE layer (Swift / Kotlin)
//     ├─ Handles GATT scan + connection
//     └─► trezor_connect(ble_handle) ─► Rust
//               ├─ THP v2 Noise XX handshake  (trezor-connect-rs)
//               ├─ Session management
//               └─ Returns device_id string
//
// `ble_handle` is a u64 key the native layer registers via
// `trezor_register_ble_callbacks()` before calling `trezor_connect()`.

uniffi::include_scaffolding!("trezor");

use once_cell::sync::Lazy;
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use trezor_connect_rs::types::Network;
use trezor_connect_rs::{
    psbt::{apply_signatures_to_psbt, psbt_to_sign_tx_params},
    CallbackDeviceInfo, CallbackReadResult, CallbackResult, CallbackTransport, ConnectedDevice,
    DeviceInfo, GetPublicKeyParams, PassphraseResponse, TransportCallback, TrezorUiCallback,
};

// ---------------------------------------------------------------------------
// Error type — must match trezor.udl [Error] enum variants exactly
// ---------------------------------------------------------------------------

#[derive(Debug, thiserror::Error)]
pub enum TrezorError {
    #[error("Connect error: {0}")]
    Connect(String),
    #[error("Pairing error: {0}")]
    Pairing(String),
    #[error("XPub error: {0}")]
    XPub(String),
    #[error("Fingerprint error: {0}")]
    Fingerprint(String),
    #[error("Sign error: {0}")]
    Sign(String),
    #[error("Disconnect error: {0}")]
    Disconnect(String),
    #[error("Invalid argument: {0}")]
    InvalidArg(String),
    #[error("Internal error: {0}")]
    Internal(String),
}

// ---------------------------------------------------------------------------
// UniFFI callback interface — implemented by Swift/Kotlin native layer
// ---------------------------------------------------------------------------

pub trait TrezorBleCallbacks: Send + Sync {
    fn write(&self, data: Vec<u8>) -> bool;
    fn read(&self) -> Option<Vec<u8>>;
    fn get_pin(&self) -> String;
    fn get_passphrase(&self, on_device: bool) -> String;
    fn get_pairing_code(&self) -> String;
}

pub trait TrezorUsbCallbacks: Send + Sync {
    fn write(&self, data: Vec<u8>) -> bool;
    fn read(&self) -> Option<Vec<u8>>;
    fn get_pin(&self) -> String;
    fn get_passphrase(&self, on_device: bool) -> String;
    fn get_pairing_code(&self) -> String;
}

// ---------------------------------------------------------------------------
// CallbackTransport adapter wrapping the UniFFI callback object
// ---------------------------------------------------------------------------

struct NativeAdapter {
    device_uuid: String,
    cbs: Arc<dyn TrezorBleCallbacks>,
    credential_path: Option<PathBuf>,
}

impl NativeAdapter {
    fn load_creds_file(&self) -> HashMap<String, String> {
        let path = match &self.credential_path {
            Some(p) => p,
            None => return HashMap::new(),
        };
        match std::fs::read_to_string(path) {
            Ok(content) => serde_json::from_str(&content).unwrap_or_default(),
            Err(_) => HashMap::new(),
        }
    }

    fn save_creds_file(&self, creds: &HashMap<String, String>) -> bool {
        let path = match &self.credential_path {
            Some(p) => p,
            None => return false,
        };
        if let Ok(parent) =
            std::fs::canonicalize(path.parent().unwrap_or(std::path::Path::new(".")))
        {
            let _ = std::fs::create_dir_all(&parent);
        } else if let Some(parent) = path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let json = match serde_json::to_string(creds) {
            Ok(j) => j,
            Err(_) => return false,
        };
        #[cfg(unix)]
        {
            use std::io::Write;
            use std::os::unix::fs::OpenOptionsExt;
            match std::fs::OpenOptions::new()
                .write(true)
                .create(true)
                .truncate(true)
                .mode(0o600)
                .open(path)
            {
                Ok(mut file) => file.write_all(json.as_bytes()).is_ok(),
                Err(_) => false,
            }
        }
        #[cfg(not(unix))]
        {
            std::fs::write(path, json).is_ok()
        }
    }
}

struct UsbNativeAdapter {
    device_path: String,
    vendor_id: u16,
    product_id: u16,
    cbs: Arc<dyn TrezorUsbCallbacks>,
    credential_path: Option<PathBuf>,
}

impl UsbNativeAdapter {
    fn load_creds_file(&self) -> HashMap<String, String> {
        let path = match &self.credential_path {
            Some(p) => p,
            None => return HashMap::new(),
        };
        match std::fs::read_to_string(path) {
            Ok(content) => serde_json::from_str(&content).unwrap_or_default(),
            Err(_) => HashMap::new(),
        }
    }

    fn save_creds_file(&self, creds: &HashMap<String, String>) -> bool {
        let path = match &self.credential_path {
            Some(p) => p,
            None => return false,
        };
        if let Some(parent) = path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        let json = match serde_json::to_string(creds) {
            Ok(j) => j,
            Err(_) => return false,
        };
        #[cfg(unix)]
        {
            use std::io::Write;
            use std::os::unix::fs::OpenOptionsExt;
            match std::fs::OpenOptions::new()
                .write(true)
                .create(true)
                .truncate(true)
                .mode(0o600)
                .open(path)
            {
                Ok(mut file) => file.write_all(json.as_bytes()).is_ok(),
                Err(_) => false,
            }
        }
        #[cfg(not(unix))]
        {
            std::fs::write(path, json).is_ok()
        }
    }
}

struct BleUiAdapter {
    cbs: Arc<dyn TrezorBleCallbacks>,
}

impl TrezorUiCallback for BleUiAdapter {
    fn on_pin_request(&self) -> Option<String> {
        let pin = self.cbs.get_pin();
        if pin.is_empty() {
            None
        } else {
            Some(pin)
        }
    }

    fn on_passphrase_request(&self, on_device: bool) -> PassphraseResponse {
        parse_passphrase_response(&self.cbs.get_passphrase(on_device))
    }
}

struct UsbUiAdapter {
    cbs: Arc<dyn TrezorUsbCallbacks>,
}

fn parse_passphrase_response(response: &str) -> PassphraseResponse {
    let value: serde_json::Value = match serde_json::from_str(response) {
        Ok(value) => value,
        Err(_) => return PassphraseResponse::Cancel,
    };
    match value.get("type").and_then(|value| value.as_str()) {
        Some("standard") => PassphraseResponse::Standard,
        Some("hidden") => PassphraseResponse::Hidden {
            value: value
                .get("value")
                .and_then(|value| value.as_str())
                .unwrap_or_default()
                .to_string(),
        },
        Some("on_device") => PassphraseResponse::OnDevice,
        _ => PassphraseResponse::Cancel,
    }
}

impl TrezorUiCallback for UsbUiAdapter {
    fn on_pin_request(&self) -> Option<String> {
        let pin = self.cbs.get_pin();
        if pin.is_empty() {
            None
        } else {
            Some(pin)
        }
    }

    fn on_passphrase_request(&self, on_device: bool) -> PassphraseResponse {
        parse_passphrase_response(&self.cbs.get_passphrase(on_device))
    }
}

impl TransportCallback for UsbNativeAdapter {
    fn enumerate_devices(&self) -> Vec<CallbackDeviceInfo> {
        vec![CallbackDeviceInfo {
            path: self.device_path.clone(),
            transport_type: "usb".to_string(),
            name: Some("Trezor".to_string()),
            vendor_id: Some(self.vendor_id),
            product_id: Some(self.product_id),
        }]
    }

    fn open_device(&self, _path: &str) -> CallbackResult {
        CallbackResult {
            success: true,
            error: String::new(),
        }
    }

    fn close_device(&self, _path: &str) -> CallbackResult {
        CallbackResult {
            success: true,
            error: String::new(),
        }
    }

    fn read_chunk(&self, _path: &str) -> CallbackReadResult {
        match self.cbs.read() {
            Some(data) => CallbackReadResult {
                success: true,
                data,
                error: String::new(),
            },
            None => CallbackReadResult {
                success: false,
                data: vec![],
                error: "USB read timeout".to_string(),
            },
        }
    }

    fn write_chunk(&self, _path: &str, data: &[u8]) -> CallbackResult {
        let success = self.cbs.write(data.to_vec());
        CallbackResult {
            success,
            error: if success {
                String::new()
            } else {
                "USB write failed".to_string()
            },
        }
    }

    fn get_chunk_size(&self, _path: &str) -> u32 {
        64
    }

    fn get_pairing_code(&self) -> String {
        self.cbs.get_pairing_code()
    }

    fn save_thp_credential(&self, device_id: &str, credential_json: &str) -> bool {
        if self.credential_path.is_some() {
            let mut creds = self.load_creds_file();
            if credential_json.is_empty() {
                creds.remove(device_id);
            } else {
                creds.insert(device_id.to_string(), credential_json.to_string());
            }
            self.save_creds_file(&creds)
        } else {
            let mut store = THP_CREDS.lock().unwrap();
            if credential_json.is_empty() {
                store.remove(device_id);
            } else {
                store.insert(device_id.to_string(), credential_json.to_string());
            }
            true
        }
    }

    fn load_thp_credential(&self, device_id: &str) -> Option<String> {
        if self.credential_path.is_some() {
            let creds = self.load_creds_file();
            creds.get(device_id).cloned()
        } else {
            THP_CREDS.lock().unwrap().get(device_id).cloned()
        }
    }

    fn clear_thp_credential(&self, device_id: &str) {
        if self.credential_path.is_some() {
            let mut creds = self.load_creds_file();
            creds.remove(device_id);
            self.save_creds_file(&creds);
        } else {
            THP_CREDS.lock().unwrap().remove(device_id);
        }
    }

    fn log_debug(&self, tag: &str, message: &str) {
    }
}

impl TransportCallback for NativeAdapter {
    fn save_thp_credential(&self, device_id: &str, credential_json: &str) -> bool {
        if self.credential_path.is_some() {
            let mut creds = self.load_creds_file();
            if credential_json.is_empty() {
                creds.remove(device_id);
            } else {
                creds.insert(device_id.to_string(), credential_json.to_string());
            }
            self.save_creds_file(&creds)
        } else {
            let mut store = THP_CREDS.lock().unwrap();
            if credential_json.is_empty() {
                store.remove(device_id);
            } else {
                store.insert(device_id.to_string(), credential_json.to_string());
            }
            true
        }
    }

    fn load_thp_credential(&self, device_id: &str) -> Option<String> {
        if self.credential_path.is_some() {
            let creds = self.load_creds_file();
            creds.get(device_id).cloned()
        } else {
            THP_CREDS.lock().unwrap().get(device_id).cloned()
        }
    }

    fn clear_thp_credential(&self, device_id: &str) {
        if self.credential_path.is_some() {
            let mut creds = self.load_creds_file();
            creds.remove(device_id);
            self.save_creds_file(&creds);
        } else {
            THP_CREDS.lock().unwrap().remove(device_id);
        }
    }

    fn log_debug(&self, tag: &str, message: &str) {
    }

    fn enumerate_devices(&self) -> Vec<CallbackDeviceInfo> {
        vec![CallbackDeviceInfo {
            path: format!("ble:{}", self.device_uuid),
            transport_type: "bluetooth".to_string(),
            name: Some("Trezor Safe 7".to_string()),
            vendor_id: None,
            product_id: None,
        }]
    }

    fn open_device(&self, _path: &str) -> CallbackResult {
        CallbackResult {
            success: true,
            error: String::new(),
        }
    }

    fn close_device(&self, _path: &str) -> CallbackResult {
        CallbackResult {
            success: true,
            error: String::new(),
        }
    }

    fn read_chunk(&self, _path: &str) -> CallbackReadResult {
        match self.cbs.read() {
            Some(data) => CallbackReadResult {
                success: true,
                data,
                error: String::new(),
            },
            None => CallbackReadResult {
                success: false,
                data: vec![],
                error: "BLE read timeout".to_string(),
            },
        }
    }

    fn write_chunk(&self, _path: &str, data: &[u8]) -> CallbackResult {
        let ok = self.cbs.write(data.to_vec());
        CallbackResult {
            success: ok,
            error: if ok {
                String::new()
            } else {
                "BLE write failed".to_string()
            },
        }
    }

    fn get_chunk_size(&self, _path: &str) -> u32 {
        244 // Trezor Safe 7 BLE packet size
    }

    fn get_pairing_code(&self) -> String {
        self.cbs.get_pairing_code()
    }
}

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------

struct PendingEntry {
    cbs: Arc<dyn TrezorBleCallbacks>,
}

struct PendingUsbEntry {
    cbs: Arc<dyn TrezorUsbCallbacks>,
}

struct Session {
    device: ConnectedDevice,
}

static PENDING: Lazy<Mutex<HashMap<u64, PendingEntry>>> = Lazy::new(|| Mutex::new(HashMap::new()));

static PENDING_USB: Lazy<Mutex<HashMap<u64, PendingUsbEntry>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

static SESSIONS: Lazy<Mutex<HashMap<String, Session>>> = Lazy::new(|| Mutex::new(HashMap::new()));

// In-memory THP credential store keyed by device_id (BLE peripheral UUID).
// Survives for the lifetime of the process so re-connection skips fresh pairing.
static THP_CREDS: Lazy<Mutex<HashMap<String, String>>> = Lazy::new(|| Mutex::new(HashMap::new()));

// In-memory store of previous transaction hexes keyed by (device_id, input_index).
// Populated by trezor_set_prev_tx_hex() before signing so that the PSBT can be
// enriched with NON_WITNESS_UTXO data that Trezor requires.
static PREV_TX_STORE: Lazy<Mutex<HashMap<String, HashMap<usize, String>>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

static RT: Lazy<tokio::runtime::Runtime> = Lazy::new(|| {
    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()
        .expect("tokio runtime init")
});

// ---------------------------------------------------------------------------
// UniFFI-exported functions
// ---------------------------------------------------------------------------

/// Register native BLE I/O callbacks before calling `trezor_connect`.
/// `callbacks` is implemented by the Swift/Kotlin native layer.
pub fn trezor_register_callbacks(ble_handle: u64, callbacks: Arc<dyn TrezorBleCallbacks>) {
    PENDING
        .lock()
        .unwrap()
        .insert(ble_handle, PendingEntry { cbs: callbacks });
}

pub fn trezor_register_usb_callbacks(usb_handle: u64, callbacks: Arc<dyn TrezorUsbCallbacks>) {
    PENDING_USB
        .lock()
        .unwrap()
        .insert(usb_handle, PendingUsbEntry { cbs: callbacks });
}

pub fn trezor_connect_usb(
    usb_handle: u64,
    device_path: String,
    vendor_id: u16,
    product_id: u16,
    credential_path: String,
) -> Result<String, TrezorError> {
    let entry = PENDING_USB
        .lock()
        .unwrap()
        .remove(&usb_handle)
        .ok_or_else(|| TrezorError::Connect(format!("No USB callbacks for handle {usb_handle}")))?;
    if !matches!((vendor_id, product_id), (0x534c, 0x0001) | (0x1209, 0x53c1)) {
        return Err(TrezorError::Connect(
            "Unsupported Trezor USB device".to_string(),
        ));
    }

    let cred_path = if credential_path.is_empty() {
        None
    } else {
        Some(PathBuf::from(credential_path))
    };

    let device_id = format!("usb:{device_path}");
    let adapter = Arc::new(UsbNativeAdapter {
        device_path: device_id.clone(),
        vendor_id,
        product_id,
        cbs: entry.cbs.clone(),
        credential_path: cred_path,
    });
    let ui_adapter = Arc::new(UsbUiAdapter { cbs: entry.cbs });

    RT.block_on(async move {
        use trezor_connect_rs::Transport;

        let mut transport = CallbackTransport::new(adapter as Arc<dyn TransportCallback>);
        transport
            .init()
            .await
            .map_err(|error| TrezorError::Connect(error.to_string()))?;
        let session = transport
            .acquire(&device_id, None)
            .await
            .map_err(|error| TrezorError::Connect(error.to_string()))?;
        // THP devices (Safe 3/5/7) are now supported via USB — the
        // CallbackTransport::acquire() call above already performed the
        // THP handshake if needed. Check if THP was negotiated so we can
        // tell ConnectedDevice to use GetFeatures instead of Initialize.
        let uses_thp = transport.has_thp(&device_id).await;
        let info = DeviceInfo::new_usb(device_id.clone(), vendor_id, product_id);
        let mut connected = ConnectedDevice::new(info, Box::new(transport), session);
        connected.set_uses_thp(uses_thp);
        connected.set_ui_callback(ui_adapter);
        let features = connected
            .initialize()
            .await
            .map_err(|error| TrezorError::Connect(error.to_string()))?;

        if features.is_bootloader() || !features.is_initialized() {
            return Err(TrezorError::Connect("UNSUPPORTED_DEVICE_STATE".to_string()));
        }
        let version = (
            features.major_version.unwrap_or(0),
            features.minor_version.unwrap_or(0),
            features.patch_version.unwrap_or(0),
        );
        if version < (1, 8, 0) {
            return Err(TrezorError::Connect(format!(
                "UNSUPPORTED_FIRMWARE:{}",
                features.version_string()
            )));
        }

        let label = features
            .label
            .clone()
            .filter(|label| !label.is_empty())
            .unwrap_or_else(|| "Trezor".to_string());
        let model = features.model.clone().unwrap_or_else(|| "1".to_string());
        SESSIONS
            .lock()
            .unwrap()
            .insert(device_id.clone(), Session { device: connected });
        Ok(serde_json::json!({
            "device_id": device_id,
            "label": label,
            "model": model,
            "transport": "usb",
            "passphrase_protection": features.passphrase_protection.unwrap_or(false),
            "passphrase_always_on_device": features.passphrase_always_on_device.unwrap_or(false),
            "passphrase_entry": features.capabilities.contains(&17),
            "uses_thp": uses_thp
        })
        .to_string())
    })
}

/// Connect to a Trezor Safe 7 over BLE (THP v2 Noise XX handshake).
/// Must be preceded by `trezor_register_callbacks()` with the same `ble_handle`.
/// Returns a `device_id` string for subsequent calls.
pub fn trezor_connect(
    ble_handle: u64,
    device_uuid: String,
    credential_path: String,
) -> Result<String, TrezorError> {
    let entry = PENDING.lock().unwrap().remove(&ble_handle).ok_or_else(|| {
        TrezorError::Connect(format!(
            "No callbacks for handle {ble_handle}. Call trezor_register_callbacks first."
        ))
    })?;

    // Use the stable device UUID as the path so credentials persist across app restarts.
    let path = format!("ble:{}", device_uuid);
    let device_id = path.clone();

    let cred_path = if credential_path.is_empty() {
        None
    } else {
        Some(PathBuf::from(credential_path))
    };

    let adapter = Arc::new(NativeAdapter {
        device_uuid: device_uuid.clone(),
        cbs: entry.cbs.clone(),
        credential_path: cred_path,
    });
    let ui_adapter = Arc::new(BleUiAdapter { cbs: entry.cbs });

    RT.block_on(async move {
        let mut transport = CallbackTransport::new(adapter as Arc<dyn TransportCallback>)
            .with_app_identity("Coconut Wallet", "coconut-wallet");

        // init() is a no-op for CallbackTransport but required by the trait
        use trezor_connect_rs::Transport;
        transport
            .init()
            .await
            .map_err(|e| TrezorError::Connect(e.to_string()))?;

        // acquire() triggers the full THP v2 handshake over BLE
        let session = transport
            .acquire(&path, None)
            .await
            .map_err(|e| TrezorError::Connect(e.to_string()))?;

        let uses_thp = transport.has_thp(&path).await;
        let dev_info = DeviceInfo::new_bluetooth(path.clone(), Some("Trezor Safe 7".to_string()));

        let mut connected = ConnectedDevice::new(dev_info, Box::new(transport), session);

        // BLE connections always use THP v2 — set unconditionally.
        connected.set_uses_thp(true);
        connected.set_ui_callback(ui_adapter);

        let features = connected
            .initialize()
            .await
            .map_err(|e| TrezorError::Connect(e.to_string()))?;

        let label = features
            .label
            .filter(|s| !s.is_empty())
            .or_else(|| features.model.clone())
            .unwrap_or_default();
        SESSIONS
            .lock()
            .unwrap()
            .insert(device_id.clone(), Session { device: connected });
        Ok(serde_json::json!({
            "device_id": device_id,
            "label": label,
            "model": features.model,
            "transport": "ble",
            "passphrase_protection": features.passphrase_protection.unwrap_or(false),
            "passphrase_always_on_device": features.passphrase_always_on_device.unwrap_or(false),
            "passphrase_entry": features.capabilities.contains(&17),
            "uses_thp": true
        })
        .to_string())
    })
}

/// Retrieve the extended public key at `keypath` (e.g. `"m/84'/0'/0'"`).
/// `network` must be one of: "mainnet", "testnet", "regtest" (default: "mainnet").
/// Returns JSON: `{"xpub": "..."}`.
pub fn trezor_get_xpub(
    device_id: String,
    keypath: String,
    network: String,
) -> Result<String, TrezorError> {
    RT.block_on(async move {
        let mut sessions = SESSIONS.lock().unwrap();
        let s = sessions
            .get_mut(&device_id)
            .ok_or_else(|| TrezorError::InvalidArg(format!("Unknown device_id: {device_id}")))?;

        let net = match network.to_lowercase().as_str() {
            "testnet" => Network::Testnet,
            "regtest" => Network::Regtest,
            _ => Network::Bitcoin,
        };

        let resp = s
            .device
            .get_public_key(GetPublicKeyParams {
                path: keypath,
                coin: Some(net),
                show_on_trezor: false,
                script_type: None,
            })
            .await
            .map_err(|e| TrezorError::XPub(e.to_string()))?;

        Ok(serde_json::json!({"xpub": resp.xpub}).to_string())
    })
}

/// Retrieve the master key fingerprint as an 8-character hex string.
pub fn trezor_get_fingerprint(device_id: String) -> Result<String, TrezorError> {
    RT.block_on(async move {
        let mut sessions = SESSIONS.lock().unwrap();
        let s = sessions
            .get_mut(&device_id)
            .ok_or_else(|| TrezorError::InvalidArg(format!("Unknown device_id: {device_id}")))?;

        // Request xpub at depth 1 ("m/0'") — its serialized form contains
        // the parent (master) fingerprint at bytes [5..9] of the Base58Check payload.
        let resp = s
            .device
            .get_public_key(GetPublicKeyParams {
                path: "m/0'".to_string(),
                coin: None,
                show_on_trezor: false,
                script_type: None,
            })
            .await
            .map_err(|e| TrezorError::Fingerprint(e.to_string()))?;

        let decoded = bitcoin::base58::decode_check(&resp.xpub)
            .map_err(|e| TrezorError::Fingerprint(format!("xpub decode: {e}")))?;
        if decoded.len() < 9 {
            return Err(TrezorError::Fingerprint(
                "xpub payload too short".to_string(),
            ));
        }
        // Layout: version(4) + depth(1) + parent_fingerprint(4) + ...
        Ok(hex::encode(&decoded[5..9]))
    })
}

/// Store a raw previous transaction hex for a specific PSBT input index.
/// Must be called for each input before [trezor_sign_transaction].
/// The hex is injected as NON_WITNESS_UTXO into the PSBT before signing.
pub fn trezor_set_prev_tx_hex(
    device_id: String,
    input_index: u32,
    raw_tx_hex: String,
) -> Result<(), TrezorError> {
    let mut store = PREV_TX_STORE.lock().unwrap();
    store
        .entry(device_id)
        .or_insert_with(HashMap::new)
        .insert(input_index as usize, raw_tx_hex);
    Ok(())
}

/// Clear stored previous transaction hexes for a device.
pub fn trezor_clear_prev_tx_hexes(device_id: String) -> Result<(), TrezorError> {
    let mut store = PREV_TX_STORE.lock().unwrap();
    store.remove(&device_id);
    Ok(())
}

/// Inject NON_WITNESS_UTXO into PSBT inputs from stored prev tx hexes.
fn inject_prev_txs_into_psbt(device_id: &str, psbt_bytes: &[u8]) -> Result<Vec<u8>, TrezorError> {
    let store = PREV_TX_STORE.lock().unwrap();
    let device_prev_txs = match store.get(device_id) {
        Some(m) => m,
        None => return Ok(psbt_bytes.to_vec()),
    };

    let mut psbt = bitcoin::psbt::Psbt::deserialize(psbt_bytes)
        .map_err(|e| TrezorError::Sign(format!("PSBT deserialize for prev tx injection: {e}")))?;

    for (&input_index, raw_tx_hex) in device_prev_txs.iter() {
        if input_index >= psbt.inputs.len() {
            return Err(TrezorError::Sign(format!(
                "prevtx input index {input_index} out of range (PSBT has {} inputs)",
                psbt.inputs.len()
            )));
        }
        if psbt.inputs[input_index].non_witness_utxo.is_some() {
            continue;
        }
        let raw_tx_bytes = hex::decode(raw_tx_hex)
            .map_err(|e| TrezorError::Sign(format!("prevtx[{input_index}]: invalid hex: {e}")))?;
        let prev_tx: bitcoin::Transaction = bitcoin::consensus::deserialize(&raw_tx_bytes)
            .map_err(|e| TrezorError::Sign(format!("prevtx[{input_index}]: deserialize: {e}")))?;
        psbt.inputs[input_index].non_witness_utxo = Some(prev_tx);
    }

    Ok(psbt.serialize())
}

/// Sign a Bitcoin transaction from a PSBT.
///
/// Takes raw PSBT bytes, converts them to Trezor signing parameters,
/// calls the device to sign, then applies the signatures back into the PSBT.
/// Returns the signed PSBT bytes.
/// `network` must be one of: "mainnet", "testnet", "regtest" (default: "mainnet").
pub fn trezor_sign_transaction(
    device_id: String,
    psbt_bytes: Vec<u8>,
    network: String,
) -> Result<Vec<u8>, TrezorError> {
    RT.block_on(async move {
        let mut sessions = SESSIONS.lock().unwrap();
        let s = sessions
            .get_mut(&device_id)
            .ok_or_else(|| TrezorError::InvalidArg(format!("Unknown device_id: {device_id}")))?;

        let net = match network.to_lowercase().as_str() {
            "testnet" => bitcoin::Network::Testnet,
            "regtest" => bitcoin::Network::Regtest,
            _ => bitcoin::Network::Bitcoin,
        };

        // Inject NON_WITNESS_UTXO from stored prev tx hexes before conversion.
        let enriched_psbt = inject_prev_txs_into_psbt(&device_id, &psbt_bytes)?;

        let params = psbt_to_sign_tx_params(&enriched_psbt, net)
            .map_err(|e| TrezorError::Sign(format!("PSBT conversion: {e}")))?;

        let signed = s
            .device
            .sign_transaction(params)
            .await
            .map_err(|e| TrezorError::Sign(e.to_string()))?;

        let signed_psbt = apply_signatures_to_psbt(&enriched_psbt, &signed)
            .map_err(|e| TrezorError::Sign(format!("Apply signatures: {e}")))?;

        Ok(signed_psbt)
    })
}

/// Disconnect and clean up the device session.
pub fn trezor_disconnect(device_id: String) -> Result<(), TrezorError> {
    RT.block_on(async move {
        if let Some(mut s) = SESSIONS.lock().unwrap().remove(&device_id) {
            let _ = s.device.disconnect().await;
        }
        Ok(())
    })
}

/// Create a THP session with the given passphrase.
///
/// Must be called after `trezor_connect` / `trezor_connect_usb` and before
/// `trezor_get_xpub` / `trezor_sign_transaction` for THP devices (Safe 3/5/7).
///
/// `passphrase_type` is one of: "standard", "hidden", "on_device".
/// `passphrase_value` is the passphrase string (used only for "hidden").
pub fn trezor_create_session(
    device_id: String,
    passphrase_type: String,
    passphrase_value: String,
) -> Result<(), TrezorError> {
    RT.block_on(async move {
        let mut sessions = SESSIONS.lock().unwrap();
        let s = sessions
            .get_mut(&device_id)
            .ok_or_else(|| TrezorError::Connect(format!("Unknown device_id: {device_id}")))?;

        let (passphrase, on_device) = match passphrase_type.as_str() {
            "standard" => (Some(""), false),
            "hidden" => (Some(passphrase_value.as_str()), false),
            "on_device" => (None, true),
            _ => return Err(TrezorError::InvalidArg("Invalid passphrase_type".to_string())),
        };

        s.device
            .create_session(passphrase, on_device)
            .await
            .map_err(|e| TrezorError::Connect(e.to_string()))?;
        Ok(())
    })
}

/// Apply settings to the device (e.g. enable/disable passphrase protection).
///
/// `use_passphrase` controls the `use_passphrase` field of `ApplySettings`:
/// - `Some(true)` → enable passphrase protection
/// - `Some(false)` → disable passphrase protection
/// - `None` → no change
///
/// The device will prompt the user to confirm on its screen.
pub fn trezor_apply_settings(
    device_id: String,
    use_passphrase: Option<bool>,
) -> Result<(), TrezorError> {
    RT.block_on(async move {
        let sessions = SESSIONS.lock().unwrap();
        let s = sessions
            .get(&device_id)
            .ok_or_else(|| TrezorError::Connect(format!("Unknown device_id: {device_id}")))?;

        s.device
            .apply_settings(use_passphrase)
            .await
            .map_err(|e| TrezorError::Connect(e.to_string()))?;
        Ok(())
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_usb_passphrase_responses() {
        assert_eq!(
            parse_passphrase_response(r#"{"type":"standard"}"#),
            PassphraseResponse::Standard
        );
        assert_eq!(
            parse_passphrase_response(r#"{"type":"hidden","value":"wallet"}"#),
            PassphraseResponse::Hidden {
                value: "wallet".to_string()
            }
        );
        assert_eq!(
            parse_passphrase_response(r#"{"type":"on_device"}"#),
            PassphraseResponse::OnDevice
        );
        assert_eq!(
            parse_passphrase_response("invalid"),
            PassphraseResponse::Cancel
        );
    }
}
