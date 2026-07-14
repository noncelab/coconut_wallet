//! Device command types.

/// Message types for Trezor communication
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u16)]
pub enum MessageType {
    // Management
    Initialize = 0,
    Ping = 1,
    Success = 2,
    Failure = 3,
    ChangePin = 4,
    WipeDevice = 5,
    GetEntropy = 9,
    Entropy = 10,
    LoadDevice = 13,
    ResetDevice = 14,
    Features = 17,
    PinMatrixRequest = 18,
    PinMatrixAck = 19,
    Cancel = 20,
    ClearSession = 24,
    ApplySettings = 25,
    ButtonRequest = 26,
    ButtonAck = 27,
    ApplyFlags = 28,
    BackupDevice = 34,
    EntropyRequest = 35,
    EntropyAck = 36,
    PassphraseRequest = 41,
    PassphraseAck = 42,
    RecoveryDevice = 45,
    WordRequest = 46,
    WordAck = 47,
    GetFeatures = 55,
    SdProtect = 79,
    ChangeWipeCode = 82,

    // Bitcoin
    GetPublicKey = 11,
    PublicKey = 12,
    SignTx = 15,
    TxRequest = 21,
    TxAck = 22,
    GetAddress = 29,
    Address = 30,
    SignMessage = 38,
    VerifyMessage = 39,
    MessageSignature = 40,
    GetOwnershipId = 43,
    OwnershipId = 44,
    GetOwnershipProof = 49,
    OwnershipProof = 50,
    AuthorizeCoinJoin = 51,
    CancelAuthorization = 63,

    // Firmware
    FirmwareErase = 6,
    FirmwareUpload = 7,
    FirmwareRequest = 8,
    SelfTest = 32,

    // Debug
    DebugLinkDecision = 100,
    DebugLinkGetState = 101,
    DebugLinkState = 102,
    DebugLinkStop = 103,
    DebugLinkLog = 104,
    DebugLinkMemoryRead = 110,
    DebugLinkMemory = 111,
    DebugLinkMemoryWrite = 112,
    DebugLinkFlashErase = 113,
}

impl From<MessageType> for u16 {
    fn from(mt: MessageType) -> u16 {
        mt as u16
    }
}

impl TryFrom<u16> for MessageType {
    type Error = ();

    fn try_from(value: u16) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(MessageType::Initialize),
            1 => Ok(MessageType::Ping),
            2 => Ok(MessageType::Success),
            3 => Ok(MessageType::Failure),
            11 => Ok(MessageType::GetPublicKey),
            12 => Ok(MessageType::PublicKey),
            15 => Ok(MessageType::SignTx),
            17 => Ok(MessageType::Features),
            21 => Ok(MessageType::TxRequest),
            22 => Ok(MessageType::TxAck),
            26 => Ok(MessageType::ButtonRequest),
            27 => Ok(MessageType::ButtonAck),
            29 => Ok(MessageType::GetAddress),
            30 => Ok(MessageType::Address),
            38 => Ok(MessageType::SignMessage),
            39 => Ok(MessageType::VerifyMessage),
            40 => Ok(MessageType::MessageSignature),
            41 => Ok(MessageType::PassphraseRequest),
            42 => Ok(MessageType::PassphraseAck),
            43 => Ok(MessageType::GetOwnershipId),
            44 => Ok(MessageType::OwnershipId),
            49 => Ok(MessageType::GetOwnershipProof),
            50 => Ok(MessageType::OwnershipProof),
            51 => Ok(MessageType::AuthorizeCoinJoin),
            55 => Ok(MessageType::GetFeatures),
            63 => Ok(MessageType::CancelAuthorization),
            _ => Err(()),
        }
    }
}
