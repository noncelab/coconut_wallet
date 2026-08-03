//! TrezorClient - Main client for device communication.

use std::sync::Arc;

use prost::Message;

use crate::api::sign_tx::{SignTransactionParams, SignedTransaction, TxInput, TxOutput};
use crate::error::{DeviceError, Result};
use crate::protos::bitcoin::{tx_ack, tx_request};
use crate::protos::{self, MessageType};
use crate::transport::Transport;
use crate::types::bitcoin::{OutputScriptType, ScriptType};
use crate::types::path::parse_path;
use crate::ui_callback::TrezorUiCallback;

use super::Features;

/// Signed message result
#[derive(Debug, Clone)]
pub struct SignedMessage {
    /// Address used to sign
    pub address: String,
    /// Signature bytes
    pub signature: Vec<u8>,
}

impl SignedMessage {
    /// Get signature as base64 string
    pub fn signature_base64(&self) -> String {
        use base64::Engine;
        base64::engine::general_purpose::STANDARD.encode(&self.signature)
    }

    /// Get signature as hex string
    pub fn signature_hex(&self) -> String {
        hex::encode(&self.signature)
    }
}

/// Main client for communicating with Trezor devices
pub struct TrezorClient<T: Transport> {
    transport: T,
    session: Option<String>,
    features: Option<Features>,
    ui_callback: Option<Arc<dyn TrezorUiCallback>>,
}

impl<T: Transport> TrezorClient<T> {
    /// Create a new Trezor client with the given transport
    pub fn new(transport: T) -> Self {
        Self {
            transport,
            session: None,
            features: None,
            ui_callback: None,
        }
    }

    /// Set the UI callback for handling PIN and passphrase requests.
    pub fn set_ui_callback(&mut self, cb: Arc<dyn TrezorUiCallback>) {
        self.ui_callback = Some(cb);
    }

    /// Handle potential button request/PIN/passphrase flows
    async fn handle_response<Resp: Message + Default>(
        &self,
        resp_type: u16,
        resp_data: Vec<u8>,
    ) -> Result<Resp> {
        const MAX_BUTTON_REQUESTS: usize = 64;

        let mut current_type = resp_type;
        let mut current_data = resp_data;

        for _ in 0..MAX_BUTTON_REQUESTS {
            match MessageType::try_from(current_type as i32) {
                Ok(MessageType::Failure) => {
                    let failure = protos::common::Failure::decode(current_data.as_slice())
                        .map_err(|e| DeviceError::ProtobufDecode(e.to_string()))?;
                    return Err(DeviceError::from_failure(
                        failure.code,
                        failure.message.unwrap_or_default(),
                    )
                    .into());
                }
                Ok(MessageType::ButtonRequest) => {
                    // Send ButtonAck and wait for next response
                    let ack = protos::common::ButtonAck {};
                    let session = self.session.as_ref().ok_or(DeviceError::NotConnected)?;
                    let (next_type, next_data) = self
                        .transport
                        .call(session, MessageType::ButtonAck as u16, &ack.encode_to_vec())
                        .await?;
                    current_type = next_type;
                    current_data = next_data;
                    continue;
                }
                Ok(MessageType::PinMatrixRequest) => {
                    if let Some(ref cb) = self.ui_callback {
                        match cb.on_pin_request() {
                            Some(pin) => {
                                let ack = protos::PinMatrixAck { pin };
                                let session =
                                    self.session.as_ref().ok_or(DeviceError::NotConnected)?;
                                let (next_type, next_data) = self
                                    .transport
                                    .call(
                                        session,
                                        MessageType::PinMatrixAck as u16,
                                        &ack.encode_to_vec(),
                                    )
                                    .await?;
                                current_type = next_type;
                                current_data = next_data;
                                continue;
                            }
                            None => return Err(DeviceError::PinCancelled.into()),
                        }
                    }
                    return Err(DeviceError::PinRequired.into());
                }
                Ok(MessageType::PassphraseRequest) => {
                    if let Some(ref cb) = self.ui_callback {
                        let request = protos::PassphraseRequest::decode(current_data.as_slice())
                            .unwrap_or_default();
                        // `on_device` reflects whether the device is asking for the
                        // passphrase to be entered on the Trezor itself; the callback
                        // decides how to respond (host entry, on-device, or cancel).
                        let on_device = request.on_device.unwrap_or(false);

                        let ack = match cb.on_passphrase_request(on_device) {
                            crate::ui_callback::PassphraseResponse::Cancel => {
                                return Err(DeviceError::PassphraseCancelled.into());
                            }
                            crate::ui_callback::PassphraseResponse::Standard => {
                                protos::PassphraseAck {
                                    passphrase: Some(String::new()),
                                    state: None,
                                    on_device: None,
                                }
                            }
                            crate::ui_callback::PassphraseResponse::Hidden { value } => {
                                protos::PassphraseAck {
                                    passphrase: Some(crate::passphrase::normalize_passphrase(
                                        &value,
                                    )),
                                    state: None,
                                    on_device: None,
                                }
                            }
                            crate::ui_callback::PassphraseResponse::OnDevice => {
                                protos::PassphraseAck {
                                    passphrase: None,
                                    state: None,
                                    on_device: Some(true),
                                }
                            }
                        };
                        let session = self.session.as_ref().ok_or(DeviceError::NotConnected)?;
                        let (next_type, next_data) = self
                            .transport
                            .call(
                                session,
                                MessageType::PassphraseAck as u16,
                                &ack.encode_to_vec(),
                            )
                            .await?;
                        current_type = next_type;
                        current_data = next_data;
                        continue;
                    }
                    return Err(DeviceError::PassphraseRequired.into());
                }
                _ => {
                    return Resp::decode(current_data.as_slice())
                        .map_err(|e| DeviceError::ProtobufDecode(e.to_string()).into());
                }
            }
        }

        Err(DeviceError::DeviceError {
            code: 0,
            message: "Too many consecutive ButtonRequests".to_string(),
        }
        .into())
    }

    /// Initialize the device and get features
    pub async fn initialize(&mut self) -> Result<Features> {
        let session = self.session.as_ref().ok_or(DeviceError::NotConnected)?;

        let init = protos::management::Initialize::default();
        let (resp_type, resp_data) = self
            .transport
            .call(
                session,
                MessageType::Initialize as u16,
                &init.encode_to_vec(),
            )
            .await?;

        let proto_features: protos::management::Features =
            self.handle_response(resp_type, resp_data).await?;

        // Convert to our Features type
        let features = Features::from_proto(&proto_features);
        self.features = Some(features.clone());
        Ok(features)
    }

    /// Get cached device features
    pub fn features(&self) -> Option<&Features> {
        self.features.as_ref()
    }

    /// Get a Bitcoin address
    pub async fn get_address(&self, path: &str, show_on_trezor: bool) -> Result<String> {
        self.get_address_full(path, show_on_trezor, "Bitcoin", ScriptType::SpendWitness)
            .await
    }

    /// Get a Bitcoin address with full options
    pub async fn get_address_full(
        &self,
        path: &str,
        show_on_trezor: bool,
        coin_name: &str,
        script_type: ScriptType,
    ) -> Result<String> {
        let address_n = parse_path(path)?;

        let request = protos::bitcoin::GetAddress {
            address_n,
            coin_name: Some(coin_name.to_string()),
            show_display: Some(show_on_trezor),
            script_type: Some(script_type as i32),
            multisig: None,
            ignore_xpub_magic: None,
            chunkify: None,
        };

        let session = self.session.as_ref().ok_or(DeviceError::NotConnected)?;

        let (resp_type, resp_data) = self
            .transport
            .call(
                session,
                MessageType::GetAddress as u16,
                &request.encode_to_vec(),
            )
            .await?;

        let response: protos::bitcoin::Address = self.handle_response(resp_type, resp_data).await?;

        Ok(response.address)
    }

    /// Get public key (xpub)
    pub async fn get_public_key(&self, path: &str) -> Result<String> {
        self.get_public_key_full(path, "Bitcoin", ScriptType::SpendWitness, false)
            .await
    }

    /// Get public key with full options
    pub async fn get_public_key_full(
        &self,
        path: &str,
        coin_name: &str,
        script_type: ScriptType,
        show_display: bool,
    ) -> Result<String> {
        let address_n = parse_path(path)?;

        let request = protos::bitcoin::GetPublicKey {
            address_n,
            ecdsa_curve_name: None,
            show_display: Some(show_display),
            coin_name: Some(coin_name.to_string()),
            script_type: Some(script_type as i32),
            ignore_xpub_magic: None,
        };

        let session = self.session.as_ref().ok_or(DeviceError::NotConnected)?;

        let (resp_type, resp_data) = self
            .transport
            .call(
                session,
                MessageType::GetPublicKey as u16,
                &request.encode_to_vec(),
            )
            .await?;

        let response: protos::bitcoin::PublicKey =
            self.handle_response(resp_type, resp_data).await?;

        Ok(response.xpub)
    }

    /// Sign a message with a Bitcoin key
    pub async fn sign_message(&self, path: &str, message: &[u8]) -> Result<SignedMessage> {
        self.sign_message_full(path, message, "Bitcoin", ScriptType::SpendWitness)
            .await
    }

    /// Sign a message with full options
    pub async fn sign_message_full(
        &self,
        path: &str,
        message: &[u8],
        coin_name: &str,
        script_type: ScriptType,
    ) -> Result<SignedMessage> {
        let address_n = parse_path(path)?;

        let request = protos::bitcoin::SignMessage {
            address_n,
            message: message.to_vec(),
            coin_name: Some(coin_name.to_string()),
            script_type: Some(script_type as i32),
            no_script_type: None,
            chunkify: None,
        };

        let session = self.session.as_ref().ok_or(DeviceError::NotConnected)?;

        let (resp_type, resp_data) = self
            .transport
            .call(
                session,
                MessageType::SignMessage as u16,
                &request.encode_to_vec(),
            )
            .await?;

        let response: protos::bitcoin::MessageSignature =
            self.handle_response(resp_type, resp_data).await?;

        Ok(SignedMessage {
            address: response.address,
            signature: response.signature,
        })
    }

    /// Verify a signed message
    pub async fn verify_message(
        &self,
        address: &str,
        signature: &[u8],
        message: &[u8],
    ) -> Result<bool> {
        self.verify_message_full(address, signature, message, "Bitcoin")
            .await
    }

    /// Verify a signed message with full options
    pub async fn verify_message_full(
        &self,
        address: &str,
        signature: &[u8],
        message: &[u8],
        coin_name: &str,
    ) -> Result<bool> {
        let request = protos::bitcoin::VerifyMessage {
            address: address.to_string(),
            signature: signature.to_vec(),
            message: message.to_vec(),
            coin_name: Some(coin_name.to_string()),
            chunkify: None,
        };

        let session = self.session.as_ref().ok_or(DeviceError::NotConnected)?;

        let (resp_type, resp_data) = self
            .transport
            .call(
                session,
                MessageType::VerifyMessage as u16,
                &request.encode_to_vec(),
            )
            .await?;

        // On success, device returns Success message
        match MessageType::try_from(resp_type as i32) {
            Ok(MessageType::Success) => Ok(true),
            Ok(MessageType::Failure) => {
                // Verify failed but not an error
                Ok(false)
            }
            _ => {
                let _: protos::common::Success = self.handle_response(resp_type, resp_data).await?;
                Ok(true)
            }
        }
    }

    /// Sign a Bitcoin transaction
    ///
    /// This implements the TxRequest/TxAck flow used by Trezor for transaction signing.
    ///
    /// **Note**: this is the legacy low-level path. It supports plain
    /// single-sig flows only: no payment requests (TXPAYMENTREQ), no prev-tx
    /// extra data (TXEXTRADATA), no multisig, no external inputs, and no
    /// post-sign verification of the returned transaction. Prefer
    /// [`ConnectedDevice::sign_transaction`](crate::connected_device::ConnectedDevice::sign_transaction),
    /// which supports all of the above.
    pub async fn sign_transaction(
        &self,
        params: &SignTransactionParams,
    ) -> Result<SignedTransaction> {
        let session = self.session.as_ref().ok_or(DeviceError::NotConnected)?;

        // Send initial SignTx message
        let sign_tx = protos::bitcoin::SignTx {
            outputs_count: params.outputs.len() as u32,
            inputs_count: params.inputs.len() as u32,
            coin_name: Some(params.coin.clone()),
            version: Some(params.version),
            lock_time: Some(params.lock_time),
            expiry: None,
            overwintered: None,
            version_group_id: None,
            timestamp: None,
            branch_id: None,
            amount_unit: None,
            decred_staking_ticket: None,
            serialize: None,
            coinjoin_request: None,
            chunkify: None,
        };

        let (mut resp_type, mut resp_data) = self
            .transport
            .call(
                session,
                MessageType::SignTx as u16,
                &sign_tx.encode_to_vec(),
            )
            .await?;

        let mut signatures: Vec<String> = vec![String::new(); params.inputs.len()];
        let mut serialized_tx = Vec::new();

        // TxRequest/TxAck loop
        loop {
            // Handle button requests
            if let Ok(MessageType::ButtonRequest) = MessageType::try_from(resp_type as i32) {
                let ack = protos::common::ButtonAck {};
                let result = self
                    .transport
                    .call(session, MessageType::ButtonAck as u16, &ack.encode_to_vec())
                    .await?;
                resp_type = result.0;
                resp_data = result.1;
                continue;
            }

            // Handle failure (e.g., user cancelled on device)
            if let Ok(MessageType::Failure) = MessageType::try_from(resp_type as i32) {
                let failure = protos::common::Failure::decode(resp_data.as_slice())
                    .map_err(|e| DeviceError::ProtobufDecode(e.to_string()))?;
                return Err(DeviceError::from_failure(
                    failure.code,
                    failure.message.unwrap_or_default(),
                )
                .into());
            }

            // Parse TxRequest
            let tx_request = protos::bitcoin::TxRequest::decode(resp_data.as_slice())
                .map_err(|e| DeviceError::ProtobufDecode(e.to_string()))?;

            // Collect serialized data if present
            if let Some(ref serialized) = tx_request.serialized {
                if let Some(ref sig) = serialized.signature {
                    if let Some(sig_idx) = serialized.signature_index {
                        let idx = sig_idx as usize;
                        if idx >= signatures.len() {
                            return Err(DeviceError::InvalidInput(format!(
                                "signature_index {} out of bounds (max {})",
                                idx,
                                signatures.len().saturating_sub(1)
                            ))
                            .into());
                        }
                        signatures[idx] = hex::encode(sig);
                    }
                }
                if let Some(ref tx_part) = serialized.serialized_tx {
                    serialized_tx.extend_from_slice(tx_part);
                }
            }

            // Check request type
            let request_type = tx_request
                .request_type
                .and_then(|t| tx_request::RequestType::try_from(t).ok())
                .unwrap_or(tx_request::RequestType::Txfinished);

            match request_type {
                tx_request::RequestType::Txfinished => {
                    // Signing complete
                    break;
                }
                tx_request::RequestType::Txinput => {
                    let details = tx_request
                        .details
                        .as_ref()
                        .ok_or(DeviceError::ProtobufDecode("Missing details".to_string()))?;
                    let idx = details.request_index.unwrap_or(0) as usize;

                    let tx_ack = if let Some(ref tx_hash) = details.tx_hash {
                        // Previous transaction input
                        let prev_tx = params
                            .prev_txs
                            .iter()
                            .find(|tx| tx.hash == *tx_hash)
                            .ok_or(DeviceError::ProtobufDecode(
                                "Previous tx not found".to_string(),
                            ))?;
                        if idx >= prev_tx.inputs.len() {
                            return Err(DeviceError::InvalidInput(format!(
                                "prev tx input index {} out of bounds (len {})",
                                idx,
                                prev_tx.inputs.len()
                            ))
                            .into());
                        }
                        self.build_prev_tx_input_ack(&prev_tx.inputs[idx])?
                    } else {
                        if idx >= params.inputs.len() {
                            return Err(DeviceError::InvalidInput(format!(
                                "request_index {} out of bounds for inputs (len {})",
                                idx,
                                params.inputs.len()
                            ))
                            .into());
                        }
                        self.build_input_ack(&params.inputs[idx])?
                    };

                    let result = self
                        .transport
                        .call(session, MessageType::TxAck as u16, &tx_ack.encode_to_vec())
                        .await?;
                    resp_type = result.0;
                    resp_data = result.1;
                }
                tx_request::RequestType::Txoutput => {
                    let details = tx_request
                        .details
                        .as_ref()
                        .ok_or(DeviceError::ProtobufDecode("Missing details".to_string()))?;
                    let idx = details.request_index.unwrap_or(0) as usize;

                    let tx_ack = if let Some(ref tx_hash) = details.tx_hash {
                        // Previous transaction output (uses bin_outputs)
                        let prev_tx = params
                            .prev_txs
                            .iter()
                            .find(|tx| tx.hash == *tx_hash)
                            .ok_or(DeviceError::ProtobufDecode(
                                "Previous tx not found".to_string(),
                            ))?;
                        if idx >= prev_tx.outputs.len() {
                            return Err(DeviceError::InvalidInput(format!(
                                "prev tx output index {} out of bounds (len {})",
                                idx,
                                prev_tx.outputs.len()
                            ))
                            .into());
                        }
                        self.build_prev_tx_output_ack(&prev_tx.outputs[idx])?
                    } else {
                        if idx >= params.outputs.len() {
                            return Err(DeviceError::InvalidInput(format!(
                                "request_index {} out of bounds for outputs (len {})",
                                idx,
                                params.outputs.len()
                            ))
                            .into());
                        }
                        self.build_output_ack(&params.outputs[idx])?
                    };

                    let result = self
                        .transport
                        .call(session, MessageType::TxAck as u16, &tx_ack.encode_to_vec())
                        .await?;
                    resp_type = result.0;
                    resp_data = result.1;
                }
                tx_request::RequestType::Txmeta => {
                    let details = tx_request
                        .details
                        .as_ref()
                        .ok_or(DeviceError::ProtobufDecode("Missing details".to_string()))?;
                    let tx_hash = details
                        .tx_hash
                        .as_ref()
                        .ok_or(DeviceError::ProtobufDecode("Missing tx_hash".to_string()))?;
                    let prev_tx = params
                        .prev_txs
                        .iter()
                        .find(|tx| tx.hash == *tx_hash)
                        .ok_or(DeviceError::ProtobufDecode(
                            "Previous tx not found".to_string(),
                        ))?;

                    let tx_ack = self.build_prev_tx_meta_ack(prev_tx)?;
                    let result = self
                        .transport
                        .call(session, MessageType::TxAck as u16, &tx_ack.encode_to_vec())
                        .await?;
                    resp_type = result.0;
                    resp_data = result.1;
                }
                tx_request::RequestType::Txoriginput => {
                    let details = tx_request
                        .details
                        .as_ref()
                        .ok_or(DeviceError::ProtobufDecode("Missing details".to_string()))?;
                    let idx = details.request_index.unwrap_or(0);
                    let tx_hash = details.tx_hash.as_ref().ok_or(DeviceError::ProtobufDecode(
                        "Missing tx_hash for TXORIGINPUT".to_string(),
                    ))?;

                    // Find the current input that references this original transaction
                    let orig_input = params
                        .inputs
                        .iter()
                        .find(|input| {
                            input.orig_hash.as_ref() == Some(tx_hash)
                                && input.orig_index == Some(idx)
                        })
                        .ok_or(DeviceError::InvalidInput(format!(
                            "No current input references orig tx {} at index {}",
                            hex::encode(tx_hash),
                            idx
                        )))?;

                    let tx_ack = self.build_input_ack(orig_input)?;
                    let result = self
                        .transport
                        .call(session, MessageType::TxAck as u16, &tx_ack.encode_to_vec())
                        .await?;
                    resp_type = result.0;
                    resp_data = result.1;
                }
                tx_request::RequestType::Txorigoutput => {
                    let details = tx_request
                        .details
                        .as_ref()
                        .ok_or(DeviceError::ProtobufDecode("Missing details".to_string()))?;
                    let idx = details.request_index.unwrap_or(0);
                    let tx_hash = details.tx_hash.as_ref().ok_or(DeviceError::ProtobufDecode(
                        "Missing tx_hash for TXORIGOUTPUT".to_string(),
                    ))?;

                    // Find the current output that references this original transaction
                    let orig_output = params
                        .outputs
                        .iter()
                        .find(|output| {
                            let (oh, oi) = match output {
                                TxOutput::External {
                                    orig_hash,
                                    orig_index,
                                    ..
                                } => (orig_hash, orig_index),
                                TxOutput::Change {
                                    orig_hash,
                                    orig_index,
                                    ..
                                } => (orig_hash, orig_index),
                                TxOutput::OpReturn {
                                    orig_hash,
                                    orig_index,
                                    ..
                                } => (orig_hash, orig_index),
                            };
                            oh.as_ref() == Some(tx_hash) && *oi == Some(idx)
                        })
                        .ok_or(DeviceError::InvalidInput(format!(
                            "No current output references orig tx {} at index {}",
                            hex::encode(tx_hash),
                            idx
                        )))?;

                    let tx_ack = self.build_output_ack(orig_output)?;
                    let result = self
                        .transport
                        .call(session, MessageType::TxAck as u16, &tx_ack.encode_to_vec())
                        .await?;
                    resp_type = result.0;
                    resp_data = result.1;
                }
                _ => {
                    return Err(DeviceError::NotSupported(format!(
                        "TrezorClient::sign_transaction does not handle {:?} \
                         (TXEXTRADATA/TXPAYMENTREQ); use ConnectedDevice::sign_transaction",
                        request_type
                    ))
                    .into());
                }
            }
        }

        Ok(SignedTransaction {
            signatures,
            serialized_tx: hex::encode(&serialized_tx),
        })
    }

    /// Build TxAck for an input
    fn build_input_ack(&self, input: &TxInput) -> Result<protos::bitcoin::TxAck> {
        let tx_input = tx_ack::transaction_type::TxInputType {
            address_n: input.path.clone(),
            prev_hash: input.prev_hash.clone(),
            prev_index: input.prev_index,
            script_sig: None,
            // Omitted when unset so firmware applies its 0xFFFFFFFF default,
            // matching @trezor/connect. Callers wanting RBF set 0xFFFFFFFD.
            sequence: input.sequence,
            script_type: Some(input.script_type as i32),
            multisig: None,
            amount: Some(input.amount),
            decred_tree: None,
            witness: None,
            ownership_proof: None,
            commitment_data: None,
            orig_hash: input.orig_hash.clone(),
            orig_index: input.orig_index,
            decred_staking_spend: None,
            script_pubkey: None,
            coinjoin_flags: None,
        };

        Ok(protos::bitcoin::TxAck {
            tx: Some(tx_ack::TransactionType {
                version: None,
                inputs: vec![tx_input],
                bin_outputs: vec![],
                lock_time: None,
                outputs: vec![],
                inputs_cnt: None,
                outputs_cnt: None,
                extra_data: None,
                extra_data_len: None,
                expiry: None,
                overwintered: None,
                version_group_id: None,
                timestamp: None,
                branch_id: None,
            }),
        })
    }

    /// Build TxAck for an output
    fn build_output_ack(&self, output: &TxOutput) -> Result<protos::bitcoin::TxAck> {
        let tx_output = match output {
            TxOutput::External {
                address,
                amount,
                orig_hash,
                orig_index,
            } => tx_ack::transaction_type::TxOutputType {
                address: Some(address.clone()),
                address_n: vec![],
                amount: *amount,
                script_type: Some(OutputScriptType::PayToAddress as i32),
                multisig: None,
                op_return_data: None,
                orig_hash: orig_hash.clone(),
                orig_index: *orig_index,
                payment_req_index: None,
            },
            TxOutput::Change {
                path,
                amount,
                script_type,
                orig_hash,
                orig_index,
            } => {
                let output_script_type = match script_type {
                    ScriptType::SpendAddress => OutputScriptType::PayToAddress,
                    ScriptType::SpendP2SHWitness => OutputScriptType::PayToP2SHWitness,
                    ScriptType::SpendWitness => OutputScriptType::PayToWitness,
                    ScriptType::SpendTaproot => OutputScriptType::PayToTaproot,
                    _ => OutputScriptType::PayToAddress,
                };
                tx_ack::transaction_type::TxOutputType {
                    address: None,
                    address_n: path.clone(),
                    amount: *amount,
                    script_type: Some(output_script_type as i32),
                    multisig: None,
                    op_return_data: None,
                    orig_hash: orig_hash.clone(),
                    orig_index: *orig_index,
                    payment_req_index: None,
                }
            }
            TxOutput::OpReturn {
                data,
                orig_hash,
                orig_index,
            } => tx_ack::transaction_type::TxOutputType {
                address: None,
                address_n: vec![],
                amount: 0,
                script_type: Some(OutputScriptType::PayToOpReturn as i32),
                multisig: None,
                op_return_data: Some(data.clone()),
                orig_hash: orig_hash.clone(),
                orig_index: *orig_index,
                payment_req_index: None,
            },
        };

        Ok(protos::bitcoin::TxAck {
            tx: Some(tx_ack::TransactionType {
                version: None,
                inputs: vec![],
                bin_outputs: vec![],
                lock_time: None,
                outputs: vec![tx_output],
                inputs_cnt: None,
                outputs_cnt: None,
                extra_data: None,
                extra_data_len: None,
                expiry: None,
                overwintered: None,
                version_group_id: None,
                timestamp: None,
                branch_id: None,
            }),
        })
    }

    /// Build TxAck for a previous transaction input
    fn build_prev_tx_input_ack(
        &self,
        input: &crate::api::sign_tx::PrevTxInput,
    ) -> Result<protos::bitcoin::TxAck> {
        let tx_input = tx_ack::transaction_type::TxInputType {
            address_n: vec![],
            prev_hash: input.prev_hash.clone(),
            prev_index: input.prev_index,
            script_sig: Some(input.script_sig.clone()),
            sequence: Some(input.sequence),
            script_type: Some(ScriptType::SpendAddress as i32),
            multisig: None,
            amount: Some(0),
            decred_tree: None,
            witness: None,
            ownership_proof: None,
            commitment_data: None,
            orig_hash: None,
            orig_index: None,
            decred_staking_spend: None,
            script_pubkey: None,
            coinjoin_flags: None,
        };

        Ok(protos::bitcoin::TxAck {
            tx: Some(tx_ack::TransactionType {
                version: None,
                inputs: vec![tx_input],
                bin_outputs: vec![],
                lock_time: None,
                outputs: vec![],
                inputs_cnt: None,
                outputs_cnt: None,
                extra_data: None,
                extra_data_len: None,
                expiry: None,
                overwintered: None,
                version_group_id: None,
                timestamp: None,
                branch_id: None,
            }),
        })
    }

    /// Build TxAck for a previous transaction output (uses bin_outputs)
    fn build_prev_tx_output_ack(
        &self,
        output: &crate::api::sign_tx::PrevTxOutput,
    ) -> Result<protos::bitcoin::TxAck> {
        let bin_output = tx_ack::transaction_type::TxOutputBinType {
            amount: output.amount,
            script_pubkey: output.script_pubkey.clone(),
            decred_script_version: None,
        };

        Ok(protos::bitcoin::TxAck {
            tx: Some(tx_ack::TransactionType {
                version: None,
                inputs: vec![],
                bin_outputs: vec![bin_output],
                lock_time: None,
                outputs: vec![],
                inputs_cnt: None,
                outputs_cnt: None,
                extra_data: None,
                extra_data_len: None,
                expiry: None,
                overwintered: None,
                version_group_id: None,
                timestamp: None,
                branch_id: None,
            }),
        })
    }

    /// Build TxAck for previous transaction metadata
    fn build_prev_tx_meta_ack(
        &self,
        prev_tx: &crate::api::sign_tx::PrevTx,
    ) -> Result<protos::bitcoin::TxAck> {
        Ok(protos::bitcoin::TxAck {
            tx: Some(tx_ack::TransactionType {
                version: Some(prev_tx.version),
                inputs: vec![],
                bin_outputs: vec![],
                lock_time: Some(prev_tx.lock_time),
                outputs: vec![],
                inputs_cnt: Some(prev_tx.inputs.len() as u32),
                outputs_cnt: Some(prev_tx.outputs.len() as u32),
                extra_data: None,
                // Omitted rather than hardcoded to 0: this legacy path has no
                // extra_data support, and a forced 0 breaks prev txs that
                // carry extra data
                extra_data_len: None,
                expiry: None,
                overwintered: None,
                version_group_id: None,
                timestamp: None,
                branch_id: None,
            }),
        })
    }

    /// Acquire session for device
    pub async fn acquire(&mut self, path: &str) -> Result<()> {
        let session = self
            .transport
            .acquire(path, self.session.as_deref())
            .await?;
        self.session = Some(session);
        Ok(())
    }

    /// Release session
    pub async fn release(&mut self) -> Result<()> {
        if let Some(session) = &self.session {
            self.transport.release(session).await?;
            self.session = None;
        }
        Ok(())
    }

    /// Get current session ID
    pub fn session(&self) -> Option<&str> {
        self.session.as_deref()
    }
}
