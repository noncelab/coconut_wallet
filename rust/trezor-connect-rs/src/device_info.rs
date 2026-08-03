//! Unified device information for USB and Bluetooth devices.

use serde::{Deserialize, Serialize};

/// Transport type for the device.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TransportType {
    /// USB connection
    Usb,
    /// Bluetooth connection
    Bluetooth,
}

impl std::fmt::Display for TransportType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            TransportType::Usb => write!(f, "USB"),
            TransportType::Bluetooth => write!(f, "Bluetooth"),
        }
    }
}

/// Unified device information across USB and Bluetooth.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceInfo {
    /// Unique identifier for the device
    pub id: String,
    /// Transport type (USB or Bluetooth)
    pub transport_type: TransportType,
    /// Device name (from BLE advertisement or USB descriptor)
    pub name: Option<String>,
    /// Transport-specific path (used internally for connection)
    pub path: String,
    /// Device label (set by user during device setup)
    pub label: Option<String>,
    /// Device model (e.g., "T2", "Safe 5", "Safe 7")
    pub model: Option<String>,
    /// Whether the device is in bootloader mode
    pub is_bootloader: bool,
}

impl DeviceInfo {
    /// Create a new USB device info.
    pub fn new_usb(path: String, _vendor_id: u16, product_id: u16) -> Self {
        let is_bootloader = product_id == 0x53c0;
        Self {
            id: format!("usb-{}", path),
            transport_type: TransportType::Usb,
            name: None,
            path,
            label: None,
            model: Self::model_from_product_id(product_id),
            is_bootloader,
        }
    }

    /// Create a new Bluetooth device info.
    pub fn new_bluetooth(id: String, name: Option<String>) -> Self {
        Self {
            id: format!("ble-{}", id),
            transport_type: TransportType::Bluetooth,
            path: id.clone(),
            name,
            label: None,
            model: Some("Safe 7".to_string()), // Only Safe 7 supports Bluetooth
            is_bootloader: false,              // Bluetooth not available in bootloader mode
        }
    }

    /// Determine model from USB product ID.
    fn model_from_product_id(product_id: u16) -> Option<String> {
        match product_id {
            0x53c0 => Some("Bootloader".to_string()),
            0x53c1 => Some("Trezor".to_string()),
            0x0001 => Some("Trezor One".to_string()),
            _ => None,
        }
    }

    /// Check if this is a USB device.
    pub fn is_usb(&self) -> bool {
        self.transport_type == TransportType::Usb
    }

    /// Check if this is a Bluetooth device.
    pub fn is_bluetooth(&self) -> bool {
        self.transport_type == TransportType::Bluetooth
    }

    /// Get a display name for the device.
    pub fn display_name(&self) -> String {
        if let Some(ref label) = self.label {
            label.clone()
        } else if let Some(ref name) = self.name {
            name.clone()
        } else if let Some(ref model) = self.model {
            format!("{} ({})", model, self.transport_type)
        } else {
            format!("Trezor ({})", self.transport_type)
        }
    }
}

impl std::fmt::Display for DeviceInfo {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.display_name())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_usb() {
        let info = DeviceInfo::new_usb("1-1".into(), 0x1209, 0x53c1);
        assert!(info.is_usb());
        assert!(!info.is_bluetooth());
        assert!(!info.is_bootloader);
        assert_eq!(info.id, "usb-1-1");
    }

    #[test]
    fn test_new_bluetooth() {
        let info =
            DeviceInfo::new_bluetooth("AA:BB:CC:DD:EE:FF".into(), Some("Trezor Safe 7".into()));
        assert!(info.is_bluetooth());
        assert!(!info.is_usb());
        assert_eq!(info.name, Some("Trezor Safe 7".into()));
        assert_eq!(info.model, Some("Safe 7".into()));
    }

    #[test]
    fn test_display_name() {
        let info = DeviceInfo::new_bluetooth("id".into(), Some("My Trezor".into()));
        assert_eq!(info.display_name(), "My Trezor");
    }
}
