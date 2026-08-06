//! Credential storage for Bluetooth pairing credentials.
//!
//! Provides persistence for Bluetooth credentials to allow automatic
//! reconnection without re-pairing.
//!
//! Two backends are available:
//! - **File-based** (default): Stores credentials as JSON on disk with
//!   owner-only file permissions (0600 on Unix).
//! - **OS keychain** (requires `os-keychain` feature): Stores credentials
//!   in the platform's native secure store (macOS Keychain, Windows
//!   Credential Manager, or Linux Secret Service / keyutils).

use crate::error::{Result, TrezorError};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use zeroize::{Zeroize, ZeroizeOnDrop};

/// Default keyring service name used for OS keychain storage.
#[cfg(feature = "os-keychain")]
const KEYRING_SERVICE: &str = "trezor-connect";

/// Keyring user/account name for the credential entry.
#[cfg(feature = "os-keychain")]
const KEYRING_USER: &str = "credentials";

/// Stored credential for a Bluetooth device.
///
/// Contains the host static private key — zeroized on drop to prevent
/// key material from lingering in memory.
#[derive(Debug, Clone, Serialize, Deserialize, Zeroize, ZeroizeOnDrop)]
pub struct StoredCredential {
    /// Device ID (used as key)
    pub device_id: String,
    /// Host static private key (hex encoded)
    pub host_static_key: String,
    /// Trezor static public key (hex encoded)
    pub trezor_static_public_key: String,
    /// Pairing credential token (hex encoded)
    pub credential: String,
    /// Unix timestamp when the credential was created
    #[zeroize(skip)]
    pub created_at: u64,
    /// Device label (if known)
    pub device_label: Option<String>,
}

/// Credential store file format.
#[derive(Debug, Default, Serialize, Deserialize)]
struct CredentialFile {
    /// Version for future compatibility
    version: u32,
    /// Map of device ID to stored credential
    credentials: HashMap<String, StoredCredential>,
}

impl CredentialFile {
    fn new() -> Self {
        Self {
            version: 1,
            credentials: HashMap::new(),
        }
    }
}

/// Storage backend for credentials.
enum Backend {
    /// File-based storage at the given path.
    File { path: PathBuf },
    /// OS keychain storage via the `keyring` crate.
    #[cfg(feature = "os-keychain")]
    Keychain { service: String },
}

/// Credential store for Bluetooth pairing credentials.
///
/// When credentials are stored, the device can automatically reconnect
/// without requiring the user to enter the pairing code again.
///
/// Use [`CredentialStore::new`] for file-based storage or
/// [`CredentialStore::new_keychain`] (with the `os-keychain` feature)
/// for OS-native secure storage.
pub struct CredentialStore {
    backend: Backend,
    data: CredentialFile,
    dirty: bool,
}

impl CredentialStore {
    /// Create a new file-based credential store at the given path.
    ///
    /// The file will be created if it doesn't exist when credentials are saved.
    pub fn new(path: impl AsRef<Path>) -> Result<Self> {
        let path = path.as_ref().to_path_buf();
        let data = if path.exists() {
            let content =
                fs::read_to_string(&path).map_err(|e| TrezorError::IoError(e.to_string()))?;
            serde_json::from_str(&content)
                .map_err(|e| TrezorError::IoError(format!("Failed to parse credentials: {}", e)))?
        } else {
            CredentialFile::new()
        };

        Ok(Self {
            backend: Backend::File { path },
            data,
            dirty: false,
        })
    }

    /// Create a new credential store backed by the OS keychain.
    ///
    /// Uses the platform's native secure store:
    /// - **macOS**: Keychain
    /// - **Windows**: Credential Manager
    /// - **Linux**: Secret Service (GNOME Keyring / KWallet) or keyutils
    ///
    /// Credentials are encrypted at rest by the OS. An optional `service`
    /// name can be provided to namespace entries (defaults to `"trezor-connect"`).
    #[cfg(feature = "os-keychain")]
    pub fn new_keychain(service: Option<&str>) -> Result<Self> {
        let service = service.unwrap_or(KEYRING_SERVICE).to_string();
        let data = Self::keychain_load(&service)?;

        Ok(Self {
            backend: Backend::Keychain { service },
            data,
            dirty: false,
        })
    }

    /// Load credentials from the OS keychain.
    #[cfg(feature = "os-keychain")]
    fn keychain_load(service: &str) -> Result<CredentialFile> {
        let entry = keyring::Entry::new(service, KEYRING_USER)
            .map_err(|e| TrezorError::IoError(format!("Keychain entry error: {}", e)))?;

        match entry.get_password() {
            Ok(content) => serde_json::from_str(&content).map_err(|e| {
                TrezorError::IoError(format!("Failed to parse keychain credentials: {}", e))
            }),
            Err(keyring::Error::NoEntry) => Ok(CredentialFile::new()),
            Err(e) => Err(TrezorError::IoError(format!("Keychain read error: {}", e)).into()),
        }
    }

    /// Save credentials to the OS keychain.
    #[cfg(feature = "os-keychain")]
    fn keychain_save(service: &str, data: &CredentialFile) -> Result<()> {
        let entry = keyring::Entry::new(service, KEYRING_USER)
            .map_err(|e| TrezorError::IoError(format!("Keychain entry error: {}", e)))?;

        if data.credentials.is_empty() {
            // Delete the entry if no credentials remain
            match entry.delete_credential() {
                Ok(()) => Ok(()),
                Err(keyring::Error::NoEntry) => Ok(()),
                Err(e) => Err(TrezorError::IoError(format!("Keychain delete error: {}", e)).into()),
            }
        } else {
            let content = serde_json::to_string(data).map_err(|e| {
                TrezorError::IoError(format!("Failed to serialize credentials: {}", e))
            })?;
            entry
                .set_password(&content)
                .map_err(|e| TrezorError::IoError(format!("Keychain write error: {}", e)))?;
            Ok(())
        }
    }

    /// Load credentials from the backing store (refreshes from disk or keychain).
    pub fn load(&mut self) -> Result<()> {
        match &self.backend {
            Backend::File { path } => {
                if path.exists() {
                    let content = fs::read_to_string(path)
                        .map_err(|e| TrezorError::IoError(e.to_string()))?;
                    self.data = serde_json::from_str(&content).map_err(|e| {
                        TrezorError::IoError(format!("Failed to parse credentials: {}", e))
                    })?;
                    self.dirty = false;
                }
            }
            #[cfg(feature = "os-keychain")]
            Backend::Keychain { service } => {
                self.data = Self::keychain_load(service)?;
                self.dirty = false;
            }
        }
        Ok(())
    }

    /// Save credentials to the backing store.
    pub fn save(&mut self) -> Result<()> {
        if !self.dirty {
            return Ok(());
        }

        match &self.backend {
            Backend::File { path } => {
                // Create parent directories if needed (owner-only: 0700)
                if let Some(parent) = path.parent() {
                    if !parent.exists() {
                        fs::create_dir_all(parent).map_err(|e| {
                            TrezorError::IoError(format!("Failed to create directory: {}", e))
                        })?;
                        #[cfg(unix)]
                        {
                            use std::os::unix::fs::PermissionsExt;
                            fs::set_permissions(parent, fs::Permissions::from_mode(0o700))
                                .map_err(|e| {
                                    TrezorError::IoError(format!(
                                        "Failed to set directory permissions: {}",
                                        e
                                    ))
                                })?;
                        }
                    }
                }

                let content = serde_json::to_string_pretty(&self.data).map_err(|e| {
                    TrezorError::IoError(format!("Failed to serialize credentials: {}", e))
                })?;

                // Atomic write: write to temp file, set permissions, then rename into place
                let tmp_path = path.with_extension("tmp");
                fs::write(&tmp_path, &content).map_err(|e| TrezorError::IoError(e.to_string()))?;

                #[cfg(unix)]
                {
                    use std::os::unix::fs::PermissionsExt;
                    fs::set_permissions(&tmp_path, fs::Permissions::from_mode(0o600)).map_err(
                        |e| TrezorError::IoError(format!("Failed to set file permissions: {}", e)),
                    )?;
                }

                fs::rename(&tmp_path, path).map_err(|e| {
                    TrezorError::IoError(format!("Failed to rename temp file: {}", e))
                })?;
            }
            #[cfg(feature = "os-keychain")]
            Backend::Keychain { service } => {
                Self::keychain_save(service, &self.data)?;
            }
        }

        self.dirty = false;
        Ok(())
    }

    /// Get a stored credential by device ID.
    pub fn get(&self, device_id: &str) -> Option<&StoredCredential> {
        self.data.credentials.get(device_id)
    }

    /// Store a credential for a device.
    pub fn store(&mut self, credential: StoredCredential) -> Result<()> {
        self.data
            .credentials
            .insert(credential.device_id.clone(), credential);
        self.dirty = true;
        self.save()
    }

    /// Remove a credential for a device.
    pub fn remove(&mut self, device_id: &str) -> Result<()> {
        if self.data.credentials.remove(device_id).is_some() {
            self.dirty = true;
            self.save()?;
        }
        Ok(())
    }

    /// Clear all stored credentials.
    pub fn clear(&mut self) -> Result<()> {
        if !self.data.credentials.is_empty() {
            self.data.credentials.clear();
            self.dirty = true;
            self.save()?;
        }
        Ok(())
    }

    /// List all stored device IDs.
    pub fn list_devices(&self) -> Vec<&str> {
        self.data.credentials.keys().map(|s| s.as_str()).collect()
    }

    /// Check if a device has stored credentials.
    pub fn has_credentials(&self, device_id: &str) -> bool {
        self.data.credentials.contains_key(device_id)
    }

    /// Get the file path (only available for file-based stores).
    pub fn path(&self) -> Option<&Path> {
        match &self.backend {
            Backend::File { path } => Some(path),
            #[cfg(feature = "os-keychain")]
            Backend::Keychain { .. } => None,
        }
    }
}

impl StoredCredential {
    /// Create a new stored credential.
    pub fn new(
        device_id: String,
        host_static_key: String,
        trezor_static_public_key: String,
        credential: String,
    ) -> Self {
        let created_at = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);

        Self {
            device_id,
            host_static_key,
            trezor_static_public_key,
            credential,
            created_at,
            device_label: None,
        }
    }

    /// Set the device label.
    pub fn with_label(mut self, label: impl Into<String>) -> Self {
        self.device_label = Some(label.into());
        self
    }

    /// Get the host static key as bytes.
    pub fn host_static_key_bytes(&self) -> Option<[u8; 32]> {
        let bytes = hex::decode(&self.host_static_key).ok()?;
        if bytes.len() != 32 {
            return None;
        }
        let mut arr = [0u8; 32];
        arr.copy_from_slice(&bytes);
        Some(arr)
    }

    /// Get the credential as bytes.
    pub fn credential_bytes(&self) -> Option<Vec<u8>> {
        hex::decode(&self.credential).ok()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env::temp_dir;

    #[test]
    fn test_credential_store() {
        let path = temp_dir().join("trezor_test_creds.json");

        // Clean up any existing file
        let _ = fs::remove_file(&path);

        // Create store and add credential
        {
            let mut store = CredentialStore::new(&path).unwrap();
            let cred = StoredCredential::new(
                "test-device".into(),
                "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20".into(),
                "abcd".into(),
                "1234".into(),
            );
            store.store(cred).unwrap();
        }

        // Reload and verify
        {
            let store = CredentialStore::new(&path).unwrap();
            let cred = store.get("test-device").unwrap();
            assert_eq!(cred.device_id, "test-device");
        }

        // Clean up
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn test_stored_credential_bytes() {
        let cred = StoredCredential::new(
            "test".into(),
            "0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20".into(),
            "abcd".into(),
            "1234".into(),
        );

        let key = cred.host_static_key_bytes().unwrap();
        assert_eq!(key[0], 0x01);
        assert_eq!(key[31], 0x20);
    }
}
