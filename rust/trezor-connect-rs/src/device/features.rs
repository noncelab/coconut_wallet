//! Device features and capabilities.

use serde::{Deserialize, Serialize};

use crate::protos::management::Features as ProtoFeatures;

/// Device features returned from Initialize
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Features {
    /// Vendor string
    pub vendor: Option<String>,
    /// Device model
    pub model: Option<String>,
    /// Major version
    pub major_version: Option<u32>,
    /// Minor version
    pub minor_version: Option<u32>,
    /// Patch version
    pub patch_version: Option<u32>,
    /// Bootloader mode
    pub bootloader_mode: Option<bool>,
    /// Device ID
    pub device_id: Option<String>,
    /// PIN protection enabled
    pub pin_protection: Option<bool>,
    /// Passphrase protection enabled
    pub passphrase_protection: Option<bool>,
    /// Language
    pub language: Option<String>,
    /// Device label
    pub label: Option<String>,
    /// Device initialized
    pub initialized: Option<bool>,
    /// Revision
    pub revision: Option<String>,
    /// Bootloader hash
    pub bootloader_hash: Option<String>,
    /// Imported flag
    pub imported: Option<bool>,
    /// Unlocked flag
    pub unlocked: Option<bool>,
    /// Passphrase cached
    pub passphrase_cached: Option<bool>,
    /// Firmware present
    pub firmware_present: Option<bool>,
    /// Needs backup
    pub needs_backup: Option<bool>,
    /// Flags
    pub flags: Option<u32>,
    /// FW vendor
    pub fw_vendor: Option<String>,
    /// Unfinished backup
    pub unfinished_backup: Option<bool>,
    /// No backup
    pub no_backup: Option<bool>,
    /// Recovery mode
    pub recovery_mode: Option<bool>,
    /// Capabilities
    pub capabilities: Vec<u32>,
    /// Backup type
    pub backup_type: Option<u32>,
    /// SD card present
    pub sd_card_present: Option<bool>,
    /// SD protection
    pub sd_protection: Option<bool>,
    /// Wipe code protection
    pub wipe_code_protection: Option<bool>,
    /// Session ID
    pub session_id: Option<Vec<u8>>,
    /// Passphrase always on device
    pub passphrase_always_on_device: Option<bool>,
    /// Safety checks level
    pub safety_checks: Option<u32>,
    /// Auto-lock delay in ms
    pub auto_lock_delay_ms: Option<u32>,
    /// Display rotation
    pub display_rotation: Option<u32>,
    /// Experimental features
    pub experimental_features: Option<bool>,
}

impl Features {
    /// Get the firmware version as a string
    pub fn version_string(&self) -> String {
        format!(
            "{}.{}.{}",
            self.major_version.unwrap_or(0),
            self.minor_version.unwrap_or(0),
            self.patch_version.unwrap_or(0)
        )
    }

    /// Check if device is in bootloader mode
    pub fn is_bootloader(&self) -> bool {
        self.bootloader_mode.unwrap_or(false)
    }

    /// Check if device is initialized
    pub fn is_initialized(&self) -> bool {
        self.initialized.unwrap_or(false)
    }

    /// Check if device needs backup
    pub fn requires_backup(&self) -> bool {
        self.needs_backup.unwrap_or(false)
    }

    /// Create Features from protobuf message
    pub fn from_proto(proto: &ProtoFeatures) -> Self {
        Self {
            vendor: proto.vendor.clone(),
            model: proto.model.clone(),
            major_version: Some(proto.major_version),
            minor_version: Some(proto.minor_version),
            patch_version: Some(proto.patch_version),
            bootloader_mode: proto.bootloader_mode,
            device_id: proto.device_id.clone(),
            pin_protection: proto.pin_protection,
            passphrase_protection: proto.passphrase_protection,
            language: proto.language.clone(),
            label: proto.label.clone(),
            initialized: proto.initialized,
            revision: proto.revision.as_ref().map(hex::encode),
            bootloader_hash: proto.bootloader_hash.as_ref().map(hex::encode),
            imported: proto.imported,
            unlocked: proto.unlocked,
            passphrase_cached: proto.passphrase_cached,
            firmware_present: proto.firmware_present,
            // backup_availability: 0 = None, 1 = Required, 2 = Available
            needs_backup: proto.backup_availability.map(|b| b == 1),
            flags: proto.flags,
            fw_vendor: proto.fw_vendor.clone(),
            unfinished_backup: proto.unfinished_backup,
            no_backup: proto.no_backup,
            // recovery_status: 0 = Nothing, 1 = Recovery, 2 = Backup
            recovery_mode: proto.recovery_status.map(|s| s != 0),
            capabilities: proto.capabilities.iter().map(|c| *c as u32).collect(),
            backup_type: proto.backup_type.map(|b| b as u32),
            sd_card_present: proto.sd_card_present,
            sd_protection: proto.sd_protection,
            wipe_code_protection: proto.wipe_code_protection,
            session_id: proto.session_id.clone(),
            passphrase_always_on_device: proto.passphrase_always_on_device,
            safety_checks: proto.safety_checks.map(|s| s as u32),
            auto_lock_delay_ms: proto.auto_lock_delay_ms,
            display_rotation: proto.display_rotation.map(|d| d as u32),
            experimental_features: proto.experimental_features,
        }
    }
}
