//! Transport trait definitions.

use crate::error::Result;
use async_trait::async_trait;

/// Device descriptor returned from enumeration
#[derive(Debug, Clone)]
pub struct DeviceDescriptor {
    /// Unique path identifier for the device
    pub path: String,
    /// USB Vendor ID
    pub vendor_id: u16,
    /// USB Product ID
    pub product_id: u16,
    /// Device serial number (if available)
    pub serial_number: Option<String>,
    /// Current session ID (if acquired)
    pub session: Option<String>,
}

/// Low-level transport API trait
#[async_trait]
pub trait TransportApi: Send + Sync {
    /// Get the chunk size for this transport
    fn chunk_size(&self) -> usize;

    /// Enumerate connected devices
    async fn enumerate(&self) -> Result<Vec<DeviceDescriptor>>;

    /// Open a device for communication
    async fn open(&self, path: &str) -> Result<()>;

    /// Close a device
    async fn close(&self, path: &str) -> Result<()>;

    /// Read data from device
    async fn read(&self, path: &str) -> Result<Vec<u8>>;

    /// Write data to device
    async fn write(&self, path: &str, data: &[u8]) -> Result<()>;
}

/// High-level transport with session management
#[async_trait]
pub trait Transport: Send + Sync {
    /// Initialize the transport
    async fn init(&mut self) -> Result<()>;

    /// Enumerate connected devices
    async fn enumerate(&self) -> Result<Vec<DeviceDescriptor>>;

    /// Acquire a session for a device
    async fn acquire(&self, path: &str, previous: Option<&str>) -> Result<String>;

    /// Release a session
    async fn release(&self, session: &str) -> Result<()>;

    /// Call a method on the device
    async fn call(&self, session: &str, message_type: u16, data: &[u8]) -> Result<(u16, Vec<u8>)>;

    /// Stop the transport
    fn stop(&mut self);
}
