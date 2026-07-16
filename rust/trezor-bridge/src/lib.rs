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
use trezor_connect_rs::{
    CallbackDeviceInfo, CallbackReadResult, CallbackResult, CallbackTransport, ConnectedDevice,
    DeviceInfo, GetPublicKeyParams, TransportCallback,
};
use trezor_connect_rs::types::Network;

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
        if let Ok(parent) = std::fs::canonicalize(path.parent().unwrap_or(std::path::Path::new("."))) {
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
            use std::os::unix::fs::OpenOptionsExt;
            use std::io::Write;
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
        eprintln!("[TrezorBridge][{}] {}", tag, message);
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
        CallbackResult { success: true, error: String::new() }
    }

    fn close_device(&self, _path: &str) -> CallbackResult {
        CallbackResult { success: true, error: String::new() }
    }

    fn read_chunk(&self, _path: &str) -> CallbackReadResult {
        match self.cbs.read() {
            Some(data) => CallbackReadResult { success: true, data, error: String::new() },
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
            error: if ok { String::new() } else { "BLE write failed".to_string() },
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

struct Session {
    device: ConnectedDevice,
}

static PENDING: Lazy<Mutex<HashMap<u64, PendingEntry>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

static SESSIONS: Lazy<Mutex<HashMap<String, Session>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));

// In-memory THP credential store keyed by device_id (BLE peripheral UUID).
// Survives for the lifetime of the process so re-connection skips fresh pairing.
static THP_CREDS: Lazy<Mutex<HashMap<String, String>>> =
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
    PENDING.lock().unwrap().insert(ble_handle, PendingEntry {
        cbs: callbacks,
    });
}

/// Connect to a Trezor Safe 7 over BLE (THP v2 Noise XX handshake).
/// Must be preceded by `trezor_register_callbacks()` with the same `ble_handle`.
/// Returns a `device_id` string for subsequent calls.
pub fn trezor_connect(ble_handle: u64, device_uuid: String, credential_path: String) -> Result<String, TrezorError> {
    let entry = PENDING.lock().unwrap().remove(&ble_handle)
        .ok_or_else(|| TrezorError::Connect(
            format!("No callbacks for handle {ble_handle}. Call trezor_register_callbacks first.")
        ))?;

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
        cbs: entry.cbs,
        credential_path: cred_path,
    });

    RT.block_on(async move {
        let mut transport = CallbackTransport::new(adapter as Arc<dyn TransportCallback>)
            .with_app_identity("Coconut Wallet", "coconut-wallet");

        // init() is a no-op for CallbackTransport but required by the trait
        use trezor_connect_rs::Transport;
        transport.init().await
            .map_err(|e| TrezorError::Connect(e.to_string()))?;

        // acquire() triggers the full THP v2 handshake over BLE
        let session = transport.acquire(&path, None).await
            .map_err(|e| TrezorError::Connect(e.to_string()))?;

        let uses_thp = transport.has_thp(&path).await;
        eprintln!("[TrezorBridge] has_thp={}", uses_thp);

        let dev_info = DeviceInfo::new_bluetooth(path.clone(), Some("Trezor Safe 7".to_string()));

        let mut connected = ConnectedDevice::new(
            dev_info,
            Box::new(transport),
            session,
        );

        // BLE connections always use THP v2 — set unconditionally.
        connected.set_uses_thp(true);

        let features = connected.initialize().await
            .map_err(|e| TrezorError::Connect(e.to_string()))?;

        let label = features.label
            .filter(|s| !s.is_empty())
            .or_else(|| features.model.clone())
            .unwrap_or_default();
        eprintln!("[TrezorBridge] initialize() label={:?} model={:?}", label, features.model);
        SESSIONS.lock().unwrap().insert(device_id.clone(), Session { device: connected });
        // Return JSON so Flutter can pick up label without a separate call
        Ok(serde_json::json!({"device_id": device_id, "label": label}).to_string())
    })
}

/// Retrieve the extended public key at `keypath` (e.g. `"m/84'/0'/0'"`).
/// `network` must be one of: "mainnet", "testnet", "regtest" (default: "mainnet").
/// Returns JSON: `{"xpub": "..."}`.
pub fn trezor_get_xpub(device_id: String, keypath: String, network: String) -> Result<String, TrezorError> {
    RT.block_on(async move {
        let mut sessions = SESSIONS.lock().unwrap();
        let s = sessions.get_mut(&device_id)
            .ok_or_else(|| TrezorError::InvalidArg(format!("Unknown device_id: {device_id}")))?;

        let net = match network.to_lowercase().as_str() {
            "testnet" => Network::Testnet,
            "regtest" => Network::Regtest,
            _ => Network::Bitcoin,
        };

        let resp = s.device.get_public_key(GetPublicKeyParams {
            path: keypath,
            coin: Some(net),
            show_on_trezor: false,
            script_type: None,
        }).await.map_err(|e| TrezorError::XPub(e.to_string()))?;

        Ok(serde_json::json!({"xpub": resp.xpub}).to_string())
    })
}

/// Retrieve the master key fingerprint as an 8-character hex string.
pub fn trezor_get_fingerprint(device_id: String) -> Result<String, TrezorError> {
    RT.block_on(async move {
        let mut sessions = SESSIONS.lock().unwrap();
        let s = sessions.get_mut(&device_id)
            .ok_or_else(|| TrezorError::InvalidArg(format!("Unknown device_id: {device_id}")))?;

        // Request xpub at depth 1 ("m/0'") — its serialized form contains
        // the parent (master) fingerprint at bytes [5..9] of the Base58Check payload.
        let resp = s.device.get_public_key(GetPublicKeyParams {
            path: "m/0'".to_string(),
            coin: None,
            show_on_trezor: false,
            script_type: None,
        }).await.map_err(|e| TrezorError::Fingerprint(e.to_string()))?;

        let decoded = bitcoin::base58::decode_check(&resp.xpub)
            .map_err(|e| TrezorError::Fingerprint(format!("xpub decode: {e}")))?;
        if decoded.len() < 9 {
            return Err(TrezorError::Fingerprint("xpub payload too short".to_string()));
        }
        // Layout: version(4) + depth(1) + parent_fingerprint(4) + ...
        Ok(hex::encode(&decoded[5..9]))
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
