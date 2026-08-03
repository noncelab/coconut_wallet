//! Main Trezor manager with unified device discovery and connection.
//!
//! Provides a high-level interface for working with Trezor devices,
//! abstracting away transport details (USB vs Bluetooth).

use std::future::Future;
use std::path::{Path, PathBuf};
use std::pin::Pin;
use std::sync::Arc;

use crate::connected_device::ConnectedDevice;
use crate::credential_store::{CredentialStore, StoredCredential};
use crate::device_info::{DeviceInfo, TransportType};
use crate::error::{Result, TransportError};
use crate::transport::Transport;
use crate::ui_callback::TrezorUiCallback;

#[cfg(feature = "usb")]
use crate::transport::usb::UsbTransport;

#[cfg(feature = "bluetooth")]
use crate::transport::bluetooth::BluetoothTransport;

/// Async callback for pairing code input.
///
/// This callback is invoked during Bluetooth pairing when the device
/// displays a 6-digit code that the user must enter.
pub type PairingCallback =
    Arc<dyn Fn() -> Pin<Box<dyn Future<Output = String> + Send>> + Send + Sync>;

/// How credentials should be stored.
enum CredentialBackendConfig {
    /// No credential persistence.
    None,
    /// File-based storage at the given path.
    File(PathBuf),
    /// OS keychain storage with an optional custom service name.
    #[cfg(feature = "os-keychain")]
    Keychain(Option<String>),
}

/// Builder for creating a Trezor manager.
pub struct TrezorBuilder {
    credential_backend: CredentialBackendConfig,
    scan_usb: bool,
    scan_bluetooth: bool,
    pairing_callback: Option<PairingCallback>,
    ui_callback: Option<Arc<dyn TrezorUiCallback>>,
    host_name: String,
    app_name: String,
    scan_duration: std::time::Duration,
}

impl TrezorBuilder {
    /// Create a new builder with default settings.
    fn new() -> Self {
        Self {
            credential_backend: CredentialBackendConfig::None,
            scan_usb: true,
            scan_bluetooth: true,
            pairing_callback: None,
            ui_callback: None,
            host_name: "trezor-connect-rs".to_string(),
            app_name: "trezor-connect-rs".to_string(),
            scan_duration: std::time::Duration::from_secs(3),
        }
    }

    /// Set a file path for credential storage.
    ///
    /// If set, Bluetooth pairing credentials will be saved to this file
    /// and loaded on subsequent connections to skip the pairing process.
    ///
    /// If neither this nor [`with_keychain_store`](Self::with_keychain_store)
    /// is called, pairing will be required on every Bluetooth connection.
    pub fn with_credential_store(mut self, path: impl AsRef<Path>) -> Self {
        self.credential_backend = CredentialBackendConfig::File(path.as_ref().to_path_buf());
        self
    }

    /// Use the OS keychain for credential storage.
    ///
    /// Stores Bluetooth pairing credentials in the platform's native
    /// secure store (macOS Keychain, Windows Credential Manager, or
    /// Linux Secret Service / keyutils), encrypted at rest by the OS.
    ///
    /// An optional `service` name can be provided to namespace entries
    /// (defaults to `"trezor-connect"`).
    #[cfg(feature = "os-keychain")]
    pub fn with_keychain_store(mut self, service: Option<&str>) -> Self {
        self.credential_backend = CredentialBackendConfig::Keychain(service.map(String::from));
        self
    }

    /// Set the async callback for pairing code input.
    ///
    /// This callback is invoked during Bluetooth pairing when the device
    /// displays a 6-digit code. The callback should prompt the user and
    /// return the entered code.
    ///
    /// # Example
    /// ```ignore
    /// .with_pairing_callback(Arc::new(|| {
    ///     Box::pin(async {
    ///         // Prompt user and return the code
    ///         "123456".to_string()
    ///     })
    /// }))
    /// ```
    pub fn with_pairing_callback(mut self, callback: PairingCallback) -> Self {
        self.pairing_callback = Some(callback);
        self
    }

    /// Set the UI callback for handling PIN and passphrase requests.
    ///
    /// When set, PIN and passphrase requests will be forwarded to this callback
    /// instead of returning `PinRequired` / `PassphraseRequired` errors.
    pub fn with_ui_callback(mut self, callback: Arc<dyn TrezorUiCallback>) -> Self {
        self.ui_callback = Some(callback);
        self
    }

    /// Set the application identity used during THP Bluetooth pairing.
    ///
    /// `host_name` identifies the host software (e.g., "Bitkit").
    /// `app_name` identifies the application (e.g., "Bitkit").
    ///
    /// Defaults to `"trezor-connect-rs"` for both.
    pub fn with_app_identity(
        mut self,
        host_name: impl Into<String>,
        app_name: impl Into<String>,
    ) -> Self {
        self.host_name = host_name.into();
        self.app_name = app_name.into();
        self
    }

    /// Set the Bluetooth scan duration.
    ///
    /// Controls how long [`Trezor::scan`] waits for BLE device discovery.
    /// Defaults to 3 seconds.
    pub fn with_scan_duration(mut self, duration: std::time::Duration) -> Self {
        self.scan_duration = duration;
        self
    }

    /// Only scan for USB devices.
    pub fn usb_only(mut self) -> Self {
        self.scan_usb = true;
        self.scan_bluetooth = false;
        self
    }

    /// Only scan for Bluetooth devices.
    pub fn bluetooth_only(mut self) -> Self {
        self.scan_usb = false;
        self.scan_bluetooth = true;
        self
    }

    /// Build the Trezor manager.
    pub async fn build(self) -> Result<Trezor> {
        // Initialize credential store based on configured backend
        let credential_store = match self.credential_backend {
            CredentialBackendConfig::None => None,
            CredentialBackendConfig::File(path) => Some(CredentialStore::new(path)?),
            #[cfg(feature = "os-keychain")]
            CredentialBackendConfig::Keychain(service) => {
                Some(CredentialStore::new_keychain(service.as_deref())?)
            }
        };

        // Initialize USB transport
        #[cfg(feature = "usb")]
        let usb_transport = if self.scan_usb {
            match UsbTransport::new() {
                Ok(mut transport) => {
                    // Wire pairing callback for USB THP (Safe 7 etc.)
                    if let Some(ref cb) = self.pairing_callback {
                        let cb = cb.clone();
                        transport.set_pairing_callback(Arc::new(move || {
                            // Block on the async callback to get the pairing code synchronously.
                            // UsbTransport pairing runs inside an async context so we use
                            // tokio::task::block_in_place + Handle::block_on.
                            let cb = cb.clone();
                            let handle = tokio::runtime::Handle::current();
                            std::thread::spawn(move || handle.block_on(cb()))
                                .join()
                                .unwrap_or_default()
                        }));
                    }
                    let _ = transport.init().await;
                    Some(Arc::new(transport))
                }
                Err(e) => {
                    log::warn!("Failed to initialize USB transport: {}", e);
                    None
                }
            }
        } else {
            None
        };

        #[cfg(not(feature = "usb"))]
        let _usb_transport: Option<()> = None;

        // Initialize Bluetooth transport
        #[cfg(feature = "bluetooth")]
        let ble_transport = if self.scan_bluetooth {
            match BluetoothTransport::new().await {
                Ok(mut transport) => {
                    transport.set_app_identity(&self.host_name, &self.app_name);
                    // Wire pairing callback for BLE THP (Safe 7 etc.)
                    if let Some(ref cb) = self.pairing_callback {
                        let cb = cb.clone();
                        transport.set_pairing_callback(Arc::new(move || {
                            // Block on the async callback to get the pairing code
                            // synchronously, mirroring the USB transport above.
                            let cb = cb.clone();
                            let handle = tokio::runtime::Handle::current();
                            std::thread::spawn(move || handle.block_on(cb()))
                                .join()
                                .unwrap_or_default()
                        }));
                    }
                    let _ = transport.init().await;
                    Some(Arc::new(transport))
                }
                Err(e) => {
                    log::warn!("Failed to initialize Bluetooth transport: {}", e);
                    None
                }
            }
        } else {
            None
        };

        #[cfg(not(feature = "bluetooth"))]
        let ble_transport: Option<()> = None;

        Ok(Trezor {
            #[cfg(feature = "usb")]
            usb_transport,
            #[cfg(feature = "bluetooth")]
            ble_transport,
            credential_store,
            ui_callback: self.ui_callback,
            scan_duration: self.scan_duration,
        })
    }
}

/// Main Trezor manager.
///
/// Handles device discovery and connection for both USB and Bluetooth devices.
///
/// # Example
/// ```ignore
/// let mut trezor = Trezor::new()
///     .with_credential_store("~/.trezor-credentials.json")
///     .with_pairing_callback(Arc::new(|| Box::pin(async { "123456".to_string() })))
///     .build()
///     .await?;
///
/// let devices = trezor.list_devices().await?;
/// let device = trezor.connect(&devices[0]).await?;
/// ```
pub struct Trezor {
    #[cfg(feature = "usb")]
    usb_transport: Option<Arc<UsbTransport>>,
    #[cfg(feature = "bluetooth")]
    ble_transport: Option<Arc<BluetoothTransport>>,
    credential_store: Option<CredentialStore>,
    ui_callback: Option<Arc<dyn TrezorUiCallback>>,
    scan_duration: std::time::Duration,
}

impl Trezor {
    /// Create a new Trezor manager builder.
    pub fn new() -> TrezorBuilder {
        TrezorBuilder::new()
    }

    /// List all available devices (USB + Bluetooth).
    ///
    /// Returns a list of device information that can be used to connect.
    pub async fn list_devices(&self) -> Result<Vec<DeviceInfo>> {
        let mut devices = Vec::new();

        // List USB devices
        #[cfg(feature = "usb")]
        if let Some(ref transport) = self.usb_transport {
            match transport.enumerate().await {
                Ok(usb_devices) => {
                    for desc in usb_devices {
                        devices.push(DeviceInfo::new_usb(
                            desc.path,
                            desc.vendor_id,
                            desc.product_id,
                        ));
                    }
                }
                Err(e) => {
                    log::warn!("Failed to enumerate USB devices: {}", e);
                }
            }
        }

        // List Bluetooth devices
        #[cfg(feature = "bluetooth")]
        if let Some(ref transport) = self.ble_transport {
            match transport.enumerate().await {
                Ok(ble_devices) => {
                    for desc in ble_devices {
                        let name = desc.serial_number.clone();
                        devices.push(DeviceInfo::new_bluetooth(desc.path, name));
                    }
                }
                Err(e) => {
                    log::warn!("Failed to enumerate Bluetooth devices: {}", e);
                }
            }
        }

        Ok(devices)
    }

    /// Scan for devices (triggers Bluetooth scan if enabled).
    ///
    /// This is useful for Bluetooth devices which need active scanning.
    /// USB devices are always discoverable.
    pub async fn scan(&mut self) -> Result<Vec<DeviceInfo>> {
        #[cfg(feature = "bluetooth")]
        if let Some(ref transport) = self.ble_transport {
            transport.start_scan().await?;
            // Give BLE some time to discover devices
            tokio::time::sleep(self.scan_duration).await;
            transport.stop_scan().await?;
        }

        self.list_devices().await
    }

    /// Connect to a device.
    ///
    /// For Bluetooth devices, this will:
    /// 1. Try to use stored credentials if available
    /// 2. Fall back to pairing if credentials are not available or invalid
    /// 3. Store new credentials after successful pairing (if credential store is configured)
    pub async fn connect(&mut self, device: &DeviceInfo) -> Result<ConnectedDevice> {
        match device.transport_type {
            TransportType::Usb => self.connect_usb(device).await,
            TransportType::Bluetooth => self.connect_bluetooth(device).await,
        }
    }

    /// Connect to a USB device.
    #[cfg(feature = "usb")]
    async fn connect_usb(&mut self, device: &DeviceInfo) -> Result<ConnectedDevice> {
        use crate::protocol::thp::state::ThpCredentials;

        let transport = self
            .usb_transport
            .as_ref()
            .ok_or_else(|| TransportError::Usb("USB transport not initialized".to_string()))?;

        // Load stored THP pairing credentials if available, so a THP device
        // (Safe 5/7 over USB) can reconnect without re-pairing. No-op for
        // protocol-v1 devices.
        if let Some(ref store) = self.credential_store {
            if let Some(cred) = store.get(&device.path) {
                log::info!("Found stored credentials for device {}", device.path);
                let thp_creds = ThpCredentials {
                    host_static_key: cred.host_static_key.clone(),
                    trezor_static_public_key: cred.trezor_static_public_key.clone(),
                    credential: cred.credential.clone(),
                    autoconnect: false,
                };
                transport
                    .add_device_credentials(&device.path, thp_creds)
                    .await;
            }
        }

        // Acquire session (this also detects THP and performs handshake if needed)
        let session = transport.acquire(&device.path, None).await?;

        // Check if device negotiated THP during acquire
        let uses_thp = transport.has_thp(&device.path).await;

        // Persist pairing credentials after a successful THP connection so the
        // next process run skips pairing.
        if uses_thp {
            if let Some(ref mut store) = self.credential_store {
                if let Some(creds) = transport.get_device_credentials(&device.path).await {
                    let stored = StoredCredential::new(
                        device.path.clone(),
                        creds.host_static_key.clone(),
                        creds.trezor_static_public_key.clone(),
                        creds.credential.clone(),
                    );
                    if let Err(e) = store.store(stored) {
                        log::warn!("Failed to save credentials: {}", e);
                    } else {
                        log::info!("Saved credentials for device {}", device.path);
                    }
                }
            }
        }

        let mut connected = ConnectedDevice::new(
            device.clone(),
            Box::new(TransportWrapper::Usb(Arc::clone(transport))),
            session,
        );

        if uses_thp {
            connected.set_uses_thp(true);
        }

        if let Some(ref cb) = self.ui_callback {
            connected.set_ui_callback(cb.clone());
        }

        Ok(connected)
    }

    #[cfg(not(feature = "usb"))]
    async fn connect_usb(&mut self, _device: &DeviceInfo) -> Result<ConnectedDevice> {
        Err(crate::TrezorError::Transport(TransportError::UnableToOpen(
            "USB support not compiled (libusb has no iOS backend)".to_string(),
        )))
    }

    /// Connect to a Bluetooth device.
    #[cfg(feature = "bluetooth")]
    async fn connect_bluetooth(&mut self, device: &DeviceInfo) -> Result<ConnectedDevice> {
        use crate::protocol::thp::state::ThpCredentials;
        use crate::transport::TransportApi;

        let transport = self.ble_transport.as_ref().ok_or_else(|| {
            TransportError::Bluetooth("Bluetooth transport not initialized".to_string())
        })?;

        // Open the device first so it has a protocol state, then load stored credentials
        TransportApi::open(transport.as_ref(), &device.path).await?;

        // Load stored credentials if available
        if let Some(ref store) = self.credential_store {
            if let Some(cred) = store.get(&device.path) {
                log::info!("Found stored credentials for device {}", device.path);
                let thp_creds = ThpCredentials {
                    host_static_key: cred.host_static_key.clone(),
                    trezor_static_public_key: cred.trezor_static_public_key.clone(),
                    credential: cred.credential.clone(),
                    autoconnect: false,
                };
                transport
                    .add_device_credentials(&device.path, thp_creds)
                    .await;
            }
        }

        // Acquire session (this triggers THP handshake and pairing if needed)
        let session = transport.acquire(&device.path, None).await?;

        log::debug!("Session acquired: {}", session);

        // After successful connection, save credentials if we have a store
        if let Some(ref mut store) = self.credential_store {
            log::debug!("Getting credentials for save...");
            if let Some(creds) = transport.get_device_credentials(&device.path).await {
                log::debug!("Found credentials, saving...");
                let stored = StoredCredential::new(
                    device.path.clone(),
                    creds.host_static_key.clone(),
                    creds.trezor_static_public_key.clone(),
                    creds.credential.clone(),
                );
                if let Err(e) = store.store(stored) {
                    log::warn!("Failed to save credentials: {}", e);
                } else {
                    log::info!("Saved credentials for device {}", device.path);
                }
            } else {
                log::debug!("No credentials found in protocol state");
            }
        }

        log::debug!("Creating ConnectedDevice...");
        // Share transport via Arc clone
        let transport_box = Box::new(TransportWrapper::Bluetooth(Arc::clone(transport)));

        let mut connected = ConnectedDevice::new(device.clone(), transport_box, session);

        // Bluetooth always uses THP
        connected.set_uses_thp(true);

        if let Some(ref cb) = self.ui_callback {
            connected.set_ui_callback(cb.clone());
        }

        log::debug!("Returning ConnectedDevice");
        Ok(connected)
    }

    #[cfg(not(feature = "bluetooth"))]
    async fn connect_bluetooth(&mut self, _device: &DeviceInfo) -> Result<ConnectedDevice> {
        Err(TrezorError::Transport(TransportError::Bluetooth(
            "Bluetooth support not compiled".to_string(),
        )))
    }

    /// Clear all stored credentials.
    pub fn clear_all_credentials(&mut self) -> Result<()> {
        if let Some(ref mut store) = self.credential_store {
            store.clear()?;
        }
        Ok(())
    }

    /// Clear stored credentials for a specific device.
    pub async fn clear_credentials(&mut self, device_id: &str) -> Result<()> {
        if let Some(ref mut store) = self.credential_store {
            store.remove(device_id)?;
        }
        Ok(())
    }

    /// Check if credentials are stored for a device.
    pub fn has_credentials(&self, device_id: &str) -> bool {
        self.credential_store
            .as_ref()
            .map(|s| s.has_credentials(device_id))
            .unwrap_or(false)
    }
}

/// Wrapper to share transports via Arc.
enum TransportWrapper {
    #[cfg(feature = "usb")]
    Usb(Arc<UsbTransport>),
    #[cfg(feature = "bluetooth")]
    Bluetooth(Arc<BluetoothTransport>),
}

#[async_trait::async_trait]
impl Transport for TransportWrapper {
    async fn init(&mut self) -> Result<()> {
        // Already initialized before wrapping in Arc
        Ok(())
    }

    async fn enumerate(&self) -> Result<Vec<crate::transport::DeviceDescriptor>> {
        match self {
            #[cfg(feature = "usb")]
            TransportWrapper::Usb(t) => t.enumerate().await,
            #[cfg(feature = "bluetooth")]
            TransportWrapper::Bluetooth(t) => t.enumerate().await,
        }
    }

    async fn acquire(&self, path: &str, previous: Option<&str>) -> Result<String> {
        match self {
            #[cfg(feature = "usb")]
            TransportWrapper::Usb(t) => t.acquire(path, previous).await,
            #[cfg(feature = "bluetooth")]
            TransportWrapper::Bluetooth(t) => t.acquire(path, previous).await,
        }
    }

    async fn release(&self, session: &str) -> Result<()> {
        match self {
            #[cfg(feature = "usb")]
            TransportWrapper::Usb(t) => t.release(session).await,
            #[cfg(feature = "bluetooth")]
            TransportWrapper::Bluetooth(t) => t.release(session).await,
        }
    }

    async fn call(&self, session: &str, message_type: u16, data: &[u8]) -> Result<(u16, Vec<u8>)> {
        match self {
            #[cfg(feature = "usb")]
            TransportWrapper::Usb(t) => t.call(session, message_type, data).await,
            #[cfg(feature = "bluetooth")]
            TransportWrapper::Bluetooth(t) => t.call(session, message_type, data).await,
        }
    }

    fn stop(&mut self) {
        // Transport is shared via Arc, don't stop it here
        // The Trezor manager owns the transport lifecycle
    }
}

impl Default for TrezorBuilder {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_builder_defaults() {
        let builder = TrezorBuilder::new();
        assert!(builder.scan_usb);
        assert!(builder.scan_bluetooth);
        assert!(matches!(
            builder.credential_backend,
            CredentialBackendConfig::None
        ));
    }

    #[test]
    fn test_builder_usb_only() {
        let builder = TrezorBuilder::new().usb_only();
        assert!(builder.scan_usb);
        assert!(!builder.scan_bluetooth);
    }

    #[test]
    fn test_builder_bluetooth_only() {
        let builder = TrezorBuilder::new().bluetooth_only();
        assert!(!builder.scan_usb);
        assert!(builder.scan_bluetooth);
    }
}
