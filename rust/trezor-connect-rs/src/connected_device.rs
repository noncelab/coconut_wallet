//! Connected device wrapper with high-level Bitcoin API.
//!
//! Provides a simple interface for interacting with connected Trezor devices,
//! abstracting away transport details and protocol differences.

use prost::Message;

use std::sync::Arc;

use crate::device::Features;
use crate::device_info::DeviceInfo;
use crate::error::{DeviceError, Result};
use crate::params::*;
use crate::protos::bitcoin::{tx_ack, tx_request};
use crate::protos::{self, MessageType};
use crate::responses::*;
use crate::transport::Transport;
use crate::types::bitcoin::{OutputScriptType, ScriptType};
use crate::types::path::{parse_path, serialize_path};
use crate::ui_callback::TrezorUiCallback;

/// A connected Trezor device with high-level API methods.
///
/// This struct wraps a transport connection and provides easy-to-use
/// methods for Bitcoin operations like getting addresses and signing messages.
pub struct ConnectedDevice {
    /// Device information
    info: DeviceInfo,
    /// Transport for communication (boxed for transport abstraction)
    transport: Box<dyn Transport>,
    /// Active session ID
    session: String,
    /// Cached device features
    features: Option<Features>,
    /// Optional UI callback for PIN/passphrase input
    ui_callback: Option<Arc<dyn TrezorUiCallback>>,
    /// Whether this device uses THP (detected at acquire time, regardless of transport)
    uses_thp: bool,
}

impl ConnectedDevice {
    /// Create a new connected device wrapper.
    ///
    /// # Arguments
    /// * `info` - Device information
    /// * `transport` - Transport for communication (boxed for transport abstraction)
    /// * `session` - Active session ID
    pub fn new(info: DeviceInfo, transport: Box<dyn Transport>, session: String) -> Self {
        Self {
            info,
            transport,
            session,
            features: None,
            ui_callback: None,
            uses_thp: false,
        }
    }

    /// Mark this device as using THP protocol (detected during acquire).
    /// When set, initialize() will use GetFeatures instead of Initialize,
    /// since the THP session was already created during the handshake.
    pub fn set_uses_thp(&mut self, uses_thp: bool) {
        self.uses_thp = uses_thp;
    }

    /// Set the UI callback for handling PIN and passphrase requests.
    pub fn set_ui_callback(&mut self, cb: Arc<dyn TrezorUiCallback>) {
        self.ui_callback = Some(cb);
    }

    /// Get device information.
    pub fn info(&self) -> &DeviceInfo {
        &self.info
    }

    /// Get cached device features (available after initialize).
    pub fn features(&self) -> Option<&Features> {
        self.features.as_ref()
    }

    /// Get the session ID.
    pub fn session(&self) -> &str {
        &self.session
    }

    /// Initialize the device and get features.
    ///
    /// This should be called after connecting to get device information.
    ///
    /// For V1 protocol devices, this sends the Initialize message.
    /// For THP devices (any transport), this sends GetFeatures since the THP session
    /// was already created during connection via ThpCreateNewSession.
    pub async fn initialize(&mut self) -> Result<Features> {
        let (resp_type, resp_data) = if self.uses_thp {
            // For THP devices, use GetFeatures since session is already initialized
            // via ThpCreateNewSession during acquire()
            log::debug!("[Device] Using GetFeatures for THP device");
            let get_features = protos::management::GetFeatures::default();
            self.transport
                .call(
                    &self.session,
                    MessageType::GetFeatures as u16,
                    &get_features.encode_to_vec(),
                )
                .await?
        } else {
            // For V1 devices, use Initialize
            log::debug!("[Device] Using Initialize for V1 device");
            let init = protos::management::Initialize::default();
            self.transport
                .call(
                    &self.session,
                    MessageType::Initialize as u16,
                    &init.encode_to_vec(),
                )
                .await?
        };

        let proto_features: protos::management::Features =
            self.handle_response(resp_type, resp_data).await?;

        let features = Features::from_proto(&proto_features);

        // Update device info with label from features
        if let Some(ref label) = features.label {
            self.info.label = Some(label.clone());
        }

        self.features = Some(features.clone());
        Ok(features)
    }

    /// Get a Bitcoin address.
    ///
    /// # Example
    /// ```ignore
    /// let address = device.get_address(GetAddressParams {
    ///     path: "m/84'/0'/0'/0/0".into(),
    ///     show_on_trezor: false,
    ///     ..Default::default()
    /// }).await?;
    /// println!("Address: {}", address.address);
    /// ```
    pub async fn get_address(&self, params: GetAddressParams) -> Result<AddressResponse> {
        let address_n = parse_path(&params.path)?;
        let script_type = params
            .script_type
            .unwrap_or_else(|| infer_script_type(&address_n));
        let coin_name = params.coin.unwrap_or_default().coin_name().to_string();
        let multisig = params.multisig.as_ref().map(convert_multisig).transpose()?;

        let build_request = |show_display: bool| protos::bitcoin::GetAddress {
            address_n: address_n.clone(),
            coin_name: Some(coin_name.clone()),
            show_display: Some(show_display),
            script_type: Some(script_type as i32),
            multisig: multisig.clone(),
            ignore_xpub_magic: None,
            chunkify: params.chunkify,
        };

        // When displaying, first derive the address silently and compare it
        // against the caller-supplied expectation (JS getAddress parity). The
        // silent result becomes the expectation when none was supplied, so a
        // device returning a different address from the display call is
        // caught either way.
        let mut expected = params.address.clone();
        if params.show_on_trezor {
            let silent = self.get_address_raw(build_request(false)).await?;
            match expected {
                Some(ref exp) if *exp != silent.address => {
                    return Err(DeviceError::AddressMismatch {
                        expected: exp.clone(),
                        actual: silent.address,
                    }
                    .into());
                }
                None => expected = Some(silent.address),
                _ => {}
            }
        }

        let response = self
            .get_address_raw(build_request(params.show_on_trezor))
            .await?;

        if let Some(ref exp) = expected {
            if *exp != response.address {
                return Err(DeviceError::AddressMismatch {
                    expected: exp.clone(),
                    actual: response.address,
                }
                .into());
            }
        }

        Ok(AddressResponse {
            path: address_n.clone(),
            serialized_path: serialize_path(&address_n),
            address: response.address,
            mac: response.mac.map(hex::encode),
        })
    }

    /// Send a GetAddress request and decode the Address response, handling
    /// button/PIN/passphrase interactions.
    async fn get_address_raw(
        &self,
        request: protos::bitcoin::GetAddress,
    ) -> Result<protos::bitcoin::Address> {
        let (resp_type, resp_data) = self
            .transport
            .call(
                &self.session,
                MessageType::GetAddress as u16,
                &request.encode_to_vec(),
            )
            .await?;
        self.handle_response(resp_type, resp_data).await
    }

    /// Derive this wallet's static session id — a stable fingerprint of the
    /// active seed + passphrase.
    ///
    /// Asks the device for its first testnet receive address
    /// (`m/44'/1'/0'/0/0`, P2PKH, not shown on screen) and combines it with the
    /// device id into the trezor-suite format `<address>@<deviceId>:0`. The
    /// address changes whenever the passphrase changes, so two ids can be
    /// compared to tell whether the same passphrase was used. See
    /// [`crate::session_state`].
    ///
    /// Call [`initialize`](Self::initialize) first so `device_id` is populated.
    /// If features are unavailable the device-id component is empty, which makes
    /// the id unparseable and therefore uncomparable —
    /// [`verify_session_state`](Self::verify_session_state) will then report no
    /// mismatch.
    pub async fn get_static_session_id(&self) -> Result<String> {
        let device_id = self
            .features
            .as_ref()
            .and_then(|f| f.device_id.clone())
            .unwrap_or_default();

        let address = self
            .get_address(GetAddressParams {
                path: "m/44'/1'/0'/0/0".to_string(),
                coin: Some(crate::types::network::Network::Testnet),
                show_on_trezor: false,
                script_type: Some(ScriptType::SpendAddress),
                ..Default::default()
            })
            .await?;

        Ok(crate::session_state::build_static_session_id(
            &address.address,
            &device_id,
            0,
        ))
    }

    /// Verify the active passphrase against a previously remembered wallet.
    ///
    /// Derives the current [static session id](Self::get_static_session_id) and,
    /// when `expected` is provided, compares it (ignoring the instance suffix).
    /// Returns [`DeviceError::InvalidState`] if they identify different wallets —
    /// i.e. the entered passphrase differs from the one that created `expected`.
    /// Pass `None` on first use to simply obtain the id to persist.
    ///
    /// Returns the freshly derived static session id on success.
    pub async fn verify_session_state(&self, expected: Option<&str>) -> Result<String> {
        let current = self.get_static_session_id().await?;
        if let Some(expected) = expected {
            if crate::session_state::is_unexpected_state(expected, &current) {
                return Err(DeviceError::InvalidState.into());
            }
        }
        Ok(current)
    }

    /// Get a public key (xpub).
    ///
    /// # Example
    /// ```ignore
    /// let pubkey = device.get_public_key(GetPublicKeyParams {
    ///     path: "m/84'/0'/0'".into(),
    ///     ..Default::default()
    /// }).await?;
    /// println!("XPub: {}", pubkey.xpub);
    /// ```
    pub async fn get_public_key(&self, params: GetPublicKeyParams) -> Result<PublicKeyResponse> {
        let address_n = parse_path(&params.path)?;
        let script_type = params
            .script_type
            .unwrap_or_else(|| infer_script_type(&address_n));
        let coin_name = params.coin.unwrap_or_default().coin_name().to_string();

        let request = protos::bitcoin::GetPublicKey {
            address_n: address_n.clone(),
            ecdsa_curve_name: None,
            show_display: Some(params.show_on_trezor),
            coin_name: Some(coin_name),
            script_type: Some(script_type as i32),
            ignore_xpub_magic: None,
        };

        let (resp_type, resp_data) = self
            .transport
            .call(
                &self.session,
                MessageType::GetPublicKey as u16,
                &request.encode_to_vec(),
            )
            .await?;

        let response: protos::bitcoin::PublicKey =
            self.handle_response(resp_type, resp_data).await?;

        Ok(PublicKeyResponse {
            path: address_n.clone(),
            serialized_path: serialize_path(&address_n),
            xpub: response.xpub,
            chain_code: hex::encode(&response.node.chain_code),
            public_key: hex::encode(&response.node.public_key),
            depth: response.node.depth,
            fingerprint: response.node.fingerprint,
            child_num: response.node.child_num,
            root_fingerprint: response.root_fingerprint,
        })
    }

    /// Sign a message.
    ///
    /// # Example
    /// ```ignore
    /// let signature = device.sign_message(SignMessageParams {
    ///     path: "m/84'/0'/0'/0/0".into(),
    ///     message: "Hello Bitcoin!".into(),
    ///     ..Default::default()
    /// }).await?;
    /// println!("Signature: {}", signature.signature);
    /// ```
    pub async fn sign_message(&self, params: SignMessageParams) -> Result<SignedMessageResponse> {
        let address_n = parse_path(&params.path)?;
        let script_type = infer_script_type(&address_n);
        let coin_name = params.coin.unwrap_or_default().coin_name().to_string();

        // Model One firmware rejects messages over 1024 bytes; fail fast like
        // JS validateModelOneMessageSize does.
        if self
            .features
            .as_ref()
            .and_then(|f| f.major_version)
            .is_some_and(|v| v == 1)
            && params.message.len() > 1024
        {
            return Err(DeviceError::NotSupported(
                "Message exceeds the 1024-byte Trezor Model One limit".to_string(),
            )
            .into());
        }

        let request = protos::bitcoin::SignMessage {
            address_n,
            message: params.message.as_bytes().to_vec(),
            coin_name: Some(coin_name),
            script_type: Some(script_type as i32),
            no_script_type: if params.no_script_type {
                Some(true)
            } else {
                None
            },
            chunkify: params.chunkify,
        };

        let (resp_type, resp_data) = self
            .transport
            .call(
                &self.session,
                MessageType::SignMessage as u16,
                &request.encode_to_vec(),
            )
            .await?;

        let response: protos::bitcoin::MessageSignature =
            self.handle_response(resp_type, resp_data).await?;

        use base64::Engine;
        let signature_base64 =
            base64::engine::general_purpose::STANDARD.encode(&response.signature);

        Ok(SignedMessageResponse {
            address: response.address,
            signature: signature_base64,
        })
    }

    /// Verify a message signature.
    ///
    /// # Example
    /// ```ignore
    /// let valid = device.verify_message(VerifyMessageParams {
    ///     address: "bc1q...".into(),
    ///     signature: "H...".into(),
    ///     message: "Hello Bitcoin!".into(),
    ///     ..Default::default()
    /// }).await?;
    /// println!("Valid: {}", valid);
    /// ```
    pub async fn verify_message(&self, params: VerifyMessageParams) -> Result<bool> {
        use base64::Engine;
        let signature_bytes = base64::engine::general_purpose::STANDARD
            .decode(&params.signature)
            .map_err(|e| DeviceError::InvalidInput(format!("Invalid base64 signature: {}", e)))?;

        let coin_name = params.coin.unwrap_or_default().coin_name().to_string();

        let request = protos::bitcoin::VerifyMessage {
            address: params.address,
            signature: signature_bytes,
            message: params.message.as_bytes().to_vec(),
            coin_name: Some(coin_name),
            chunkify: params.chunkify,
        };

        let (resp_type, resp_data) = self
            .transport
            .call(
                &self.session,
                MessageType::VerifyMessage as u16,
                &request.encode_to_vec(),
            )
            .await?;

        // On success, device returns Success message
        match MessageType::try_from(resp_type as i32) {
            Ok(MessageType::Success) => Ok(true),
            Ok(MessageType::Failure) => Ok(false),
            _ => {
                let _: protos::common::Success = self.handle_response(resp_type, resp_data).await?;
                Ok(true)
            }
        }
    }

    /// Sign a Bitcoin transaction.
    ///
    /// This implements the TxRequest/TxAck flow used by Trezor for transaction signing.
    ///
    /// # Example
    /// ```ignore
    /// let signed = device.sign_transaction(SignTxParams {
    ///     inputs: vec![SignTxInput {
    ///         prev_hash: "abc123...".into(),
    ///         prev_index: 0,
    ///         path: "m/84'/0'/0'/0/0".into(),
    ///         amount: 100000,
    ///         script_type: ScriptType::SpendWitness,
    ///         sequence: None,
    ///         orig_hash: None,
    ///         orig_index: None,
    ///     }],
    ///     outputs: vec![SignTxOutput {
    ///         address: Some("bc1q...".into()),
    ///         path: None,
    ///         amount: 90000,
    ///         script_type: None,
    ///         op_return_data: None,
    ///         orig_hash: None,
    ///         orig_index: None,
    ///     }],
    ///     ..Default::default()
    /// }).await?;
    /// println!("Signed TX: {}", signed.serialized_tx);
    /// ```
    pub async fn sign_transaction(&self, params: SignTxParams) -> Result<SignedTxResponse> {
        let coin_name = params.coin.unwrap_or_default().coin_name().to_string();
        let version = params.version.unwrap_or(2);
        let lock_time = params.lock_time.unwrap_or(0);

        // Validate output fields: exactly one of (address, path, op_return_data) must be set
        for (i, output) in params.outputs.iter().enumerate() {
            let has_address = output.address.is_some();
            let has_path = output.path.is_some();
            let has_op_return = output.op_return_data.is_some();

            let field_count = has_address as u8 + has_path as u8 + has_op_return as u8;
            if field_count != 1 {
                return Err(DeviceError::InvalidInput(format!(
                    "Output {}: exactly one of address, path, or op_return_data must be set (got {})",
                    i, field_count
                )).into());
            }

            if has_op_return && output.amount != 0 {
                return Err(DeviceError::InvalidInput(format!(
                    "Output {}: OP_RETURN output must have amount 0, got {}",
                    i, output.amount
                ))
                .into());
            }
        }

        validate_sign_tx_params(&params)?;

        // SLIP-24: when payment requests are present every output belongs to
        // the (single) request, so default payment_req_index to 0 like JS does.
        let auto_payment_req = !params.payment_requests.is_empty();

        // Parse all input paths upfront (EXTERNAL inputs may have empty paths)
        let parsed_inputs: Vec<(Vec<u32>, ScriptType)> = params
            .inputs
            .iter()
            .map(|input| {
                if input.script_type == ScriptType::External && input.path.is_empty() {
                    Ok((vec![], input.script_type))
                } else {
                    let path = parse_path(&input.path)?;
                    Ok((path, input.script_type))
                }
            })
            .collect::<Result<Vec<_>>>()?;

        // Parse output paths for change outputs
        let parsed_outputs: Vec<Option<(Vec<u32>, ScriptType)>> = params
            .outputs
            .iter()
            .map(|output| {
                if let Some(ref path_str) = output.path {
                    let path = parse_path(path_str)?;
                    let script_type = output
                        .script_type
                        .unwrap_or_else(|| infer_script_type(&path));
                    Ok(Some((path, script_type)))
                } else {
                    Ok(None)
                }
            })
            .collect::<Result<Vec<_>>>()?;

        // Derive the scriptPubKey every output is expected to serialize to,
        // before signing, so the returned transaction can be verified against
        // requests independent of the device (JS verifyTx parity). Skipped
        // when the caller opted out of serialization.
        let expected_scripts = if params.serialize != Some(false) {
            Some(self.derive_output_scripts(&params, &parsed_outputs).await?)
        } else {
            None
        };

        // Send UnlockPath if provided
        if let Some(ref unlock) = params.unlock_path {
            self.send_unlock_path(unlock).await?;
        }

        // Send initial SignTx message
        let sign_tx = protos::bitcoin::SignTx {
            outputs_count: params.outputs.len() as u32,
            inputs_count: params.inputs.len() as u32,
            coin_name: Some(coin_name),
            version: Some(version),
            lock_time: Some(lock_time),
            expiry: None,
            overwintered: None,
            version_group_id: None,
            timestamp: None,
            branch_id: None,
            amount_unit: params.amount_unit.map(|u| u as i32),
            decred_staking_ticket: None,
            serialize: params.serialize,
            coinjoin_request: None,
            chunkify: params.chunkify,
        };

        let (mut resp_type, mut resp_data) = self
            .transport
            .call(
                &self.session,
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
                    .call(
                        &self.session,
                        MessageType::ButtonAck as u16,
                        &ack.encode_to_vec(),
                    )
                    .await?;
                resp_type = result.0;
                resp_data = result.1;
                continue;
            }

            // Handle failure
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
                        if idx < signatures.len() {
                            signatures[idx] = hex::encode(sig);
                        } else {
                            return Err(DeviceError::InvalidInput(format!(
                                "signature_index {} out of bounds (max {})",
                                idx,
                                signatures.len() - 1
                            ))
                            .into());
                        }
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
                    let details = tx_request.details.as_ref().ok_or_else(|| {
                        DeviceError::ProtobufDecode("Missing details".to_string())
                    })?;
                    let idx = details.request_index.unwrap_or(0) as usize;

                    let tx_ack = if let Some(ref tx_hash) = details.tx_hash {
                        // Previous transaction input
                        let prev_tx = find_prev_tx(&params.prev_txs, tx_hash)?;
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
                        // Current transaction input
                        if idx >= params.inputs.len() {
                            return Err(DeviceError::InvalidInput(format!(
                                "request_index {} out of bounds for inputs (len {})",
                                idx,
                                params.inputs.len()
                            ))
                            .into());
                        }
                        self.build_input_ack(&params.inputs[idx], &parsed_inputs[idx])?
                    };

                    let result = self
                        .transport
                        .call(
                            &self.session,
                            MessageType::TxAck as u16,
                            &tx_ack.encode_to_vec(),
                        )
                        .await?;
                    resp_type = result.0;
                    resp_data = result.1;
                }
                tx_request::RequestType::Txoutput => {
                    let details = tx_request.details.as_ref().ok_or_else(|| {
                        DeviceError::ProtobufDecode("Missing details".to_string())
                    })?;
                    let idx = details.request_index.unwrap_or(0) as usize;

                    let tx_ack = if let Some(ref tx_hash) = details.tx_hash {
                        // Previous transaction output (uses bin_outputs, not outputs)
                        let prev_tx = find_prev_tx(&params.prev_txs, tx_hash)?;
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
                        // Current transaction output
                        if idx >= params.outputs.len() {
                            return Err(DeviceError::InvalidInput(format!(
                                "request_index {} out of bounds for outputs (len {})",
                                idx,
                                params.outputs.len()
                            ))
                            .into());
                        }
                        self.build_output_ack(
                            &params.outputs[idx],
                            &parsed_outputs[idx],
                            auto_payment_req,
                        )?
                    };

                    let result = self
                        .transport
                        .call(
                            &self.session,
                            MessageType::TxAck as u16,
                            &tx_ack.encode_to_vec(),
                        )
                        .await?;
                    resp_type = result.0;
                    resp_data = result.1;
                }
                tx_request::RequestType::Txmeta => {
                    let details = tx_request.details.as_ref().ok_or_else(|| {
                        DeviceError::ProtobufDecode("Missing details".to_string())
                    })?;
                    let tx_hash = details.tx_hash.as_ref().ok_or_else(|| {
                        DeviceError::InvalidInput("TXMETA missing tx_hash".to_string())
                    })?;
                    let prev_tx = find_prev_tx(&params.prev_txs, tx_hash)?;
                    let tx_ack = self.build_prev_tx_meta_ack(prev_tx)?;

                    let result = self
                        .transport
                        .call(
                            &self.session,
                            MessageType::TxAck as u16,
                            &tx_ack.encode_to_vec(),
                        )
                        .await?;
                    resp_type = result.0;
                    resp_data = result.1;
                }
                tx_request::RequestType::Txoriginput => {
                    let details = tx_request.details.as_ref().ok_or_else(|| {
                        DeviceError::ProtobufDecode("Missing details".to_string())
                    })?;
                    let idx = details.request_index.unwrap_or(0);
                    let tx_hash = details.tx_hash.as_ref().ok_or_else(|| {
                        DeviceError::InvalidInput("TXORIGINPUT missing tx_hash".to_string())
                    })?;
                    let tx_hash_hex = hex::encode(tx_hash);

                    // Find the current input that references this original transaction
                    let (input_idx, _) = params
                        .inputs
                        .iter()
                        .enumerate()
                        .find(|(_, input)| {
                            input.orig_hash.as_deref() == Some(&tx_hash_hex)
                                && input.orig_index == Some(idx)
                        })
                        .ok_or_else(|| {
                            DeviceError::InvalidInput(format!(
                                "No current input references orig tx {} at index {}",
                                tx_hash_hex, idx
                            ))
                        })?;

                    let tx_ack =
                        self.build_input_ack(&params.inputs[input_idx], &parsed_inputs[input_idx])?;

                    let result = self
                        .transport
                        .call(
                            &self.session,
                            MessageType::TxAck as u16,
                            &tx_ack.encode_to_vec(),
                        )
                        .await?;
                    resp_type = result.0;
                    resp_data = result.1;
                }
                tx_request::RequestType::Txorigoutput => {
                    let details = tx_request.details.as_ref().ok_or_else(|| {
                        DeviceError::ProtobufDecode("Missing details".to_string())
                    })?;
                    let idx = details.request_index.unwrap_or(0);
                    let tx_hash = details.tx_hash.as_ref().ok_or_else(|| {
                        DeviceError::InvalidInput("TXORIGOUTPUT missing tx_hash".to_string())
                    })?;
                    let tx_hash_hex = hex::encode(tx_hash);

                    // Find the current output that references this original transaction
                    let (output_idx, _) = params
                        .outputs
                        .iter()
                        .enumerate()
                        .find(|(_, output)| {
                            output.orig_hash.as_deref() == Some(&tx_hash_hex)
                                && output.orig_index == Some(idx)
                        })
                        .ok_or_else(|| {
                            DeviceError::InvalidInput(format!(
                                "No current output references orig tx {} at index {}",
                                tx_hash_hex, idx
                            ))
                        })?;

                    let tx_ack = self.build_output_ack(
                        &params.outputs[output_idx],
                        &parsed_outputs[output_idx],
                        auto_payment_req,
                    )?;

                    let result = self
                        .transport
                        .call(
                            &self.session,
                            MessageType::TxAck as u16,
                            &tx_ack.encode_to_vec(),
                        )
                        .await?;
                    resp_type = result.0;
                    resp_data = result.1;
                }
                tx_request::RequestType::Txextradata => {
                    let details = tx_request.details.as_ref().ok_or_else(|| {
                        DeviceError::ProtobufDecode("Missing details for TXEXTRADATA".to_string())
                    })?;
                    let tx_hash = details.tx_hash.as_ref().ok_or_else(|| {
                        DeviceError::InvalidInput("TXEXTRADATA missing tx_hash".to_string())
                    })?;
                    let prev_tx = find_prev_tx(&params.prev_txs, tx_hash)?;

                    let extra_data_bytes = prev_tx
                        .extra_data
                        .as_ref()
                        .map(|d| hex::decode(d))
                        .transpose()
                        .map_err(|e| {
                            DeviceError::InvalidInput(format!("Invalid extra_data hex: {}", e))
                        })?
                        .unwrap_or_default();

                    let offset = details.extra_data_offset.unwrap_or(0) as usize;
                    let length = details.extra_data_len.unwrap_or(0) as usize;
                    let end = std::cmp::min(offset + length, extra_data_bytes.len());
                    let chunk = if offset < extra_data_bytes.len() {
                        extra_data_bytes[offset..end].to_vec()
                    } else {
                        vec![]
                    };

                    let tx_ack = protos::bitcoin::TxAck {
                        tx: Some(tx_ack::TransactionType {
                            version: None,
                            inputs: vec![],
                            bin_outputs: vec![],
                            lock_time: None,
                            outputs: vec![],
                            inputs_cnt: None,
                            outputs_cnt: None,
                            extra_data: Some(chunk),
                            extra_data_len: None,
                            expiry: None,
                            overwintered: None,
                            version_group_id: None,
                            timestamp: None,
                            branch_id: None,
                        }),
                    };

                    let result = self
                        .transport
                        .call(
                            &self.session,
                            MessageType::TxAck as u16,
                            &tx_ack.encode_to_vec(),
                        )
                        .await?;
                    resp_type = result.0;
                    resp_data = result.1;
                }
                tx_request::RequestType::Txpaymentreq => {
                    let details = tx_request.details.as_ref().ok_or_else(|| {
                        DeviceError::ProtobufDecode("Missing details for TXPAYMENTREQ".to_string())
                    })?;
                    let idx = details.request_index.unwrap_or(0) as usize;

                    if idx >= params.payment_requests.len() {
                        return Err(DeviceError::InvalidInput(format!(
                            "payment_req_index {} out of bounds (len {})",
                            idx,
                            params.payment_requests.len()
                        ))
                        .into());
                    }

                    let pr = &params.payment_requests[idx];
                    let payment_req = convert_payment_request(pr)?;

                    let result = self
                        .transport
                        .call(
                            &self.session,
                            MessageType::PaymentRequest as u16,
                            &payment_req.encode_to_vec(),
                        )
                        .await?;
                    resp_type = result.0;
                    resp_data = result.1;
                }
            }
        }

        // Verify the device-returned transaction against the request and
        // compute its txid. A mismatch here means the device serialized
        // something other than what was requested.
        let mut txid = None;
        let mut witnesses = None;
        if let Some(ref expected) = expected_scripts {
            if !serialized_tx.is_empty() {
                let tx = crate::tx_verify::verify_signed_tx(
                    &serialized_tx,
                    params.inputs.len(),
                    &params.outputs,
                    expected,
                )?;
                txid = Some(tx.compute_txid().to_string());
                witnesses = Some(
                    tx.input
                        .iter()
                        .map(|input| {
                            if input.witness.is_empty() {
                                None
                            } else {
                                Some(hex::encode(bitcoin::consensus::serialize(&input.witness)))
                            }
                        })
                        .collect(),
                );
            }
        }

        Ok(SignedTxResponse {
            signatures,
            serialized_tx: hex::encode(&serialized_tx),
            txid,
            witnesses,
        })
    }

    /// Send UnlockPath and consume the UnlockedPathRequest response,
    /// unlocking a keychain subtree (e.g. SLIP-25) for the next command.
    async fn send_unlock_path(&self, unlock: &UnlockPath) -> Result<()> {
        let unlock_msg = protos::management::UnlockPath {
            address_n: unlock.address_n.clone(),
            mac: unlock
                .mac
                .as_ref()
                .map(|m| hex::decode(m))
                .transpose()
                .map_err(|e| {
                    DeviceError::InvalidInput(format!("Invalid unlock_path mac hex: {}", e))
                })?,
        };

        let (resp_type, resp_data) = self
            .transport
            .call(
                &self.session,
                MessageType::UnlockPath as u16,
                &unlock_msg.encode_to_vec(),
            )
            .await?;

        let _: protos::management::UnlockedPathRequest =
            self.handle_response(resp_type, resp_data).await?;
        Ok(())
    }

    /// Fetch the compressed public key at `address_n` without any device UI,
    /// honoring an optional UnlockPath prefix (SLIP-25 subtrees).
    async fn get_node_public_key(
        &self,
        address_n: &[u32],
        coin: crate::types::network::Network,
        unlock_path: Option<&UnlockPath>,
    ) -> Result<Vec<u8>> {
        if let Some(unlock) = unlock_path {
            self.send_unlock_path(unlock).await?;
        }

        let request = protos::bitcoin::GetPublicKey {
            address_n: address_n.to_vec(),
            ecdsa_curve_name: None,
            show_display: Some(false),
            coin_name: Some(coin.coin_name().to_string()),
            script_type: None,
            ignore_xpub_magic: None,
        };

        let (resp_type, resp_data) = self
            .transport
            .call(
                &self.session,
                MessageType::GetPublicKey as u16,
                &request.encode_to_vec(),
            )
            .await?;

        let response: protos::bitcoin::PublicKey =
            self.handle_response(resp_type, resp_data).await?;
        Ok(response.node.public_key)
    }

    /// Derive the expected scriptPubKey for each output (JS deriveOutputScript
    /// parity): external addresses parse locally, OP_RETURN embeds its data,
    /// and change outputs are derived from the device's own public key at the
    /// output path. Outputs that can't be derived from a single key
    /// (multisig) yield `None` and are skipped during verification.
    async fn derive_output_scripts(
        &self,
        params: &SignTxParams,
        parsed_outputs: &[Option<(Vec<u32>, ScriptType)>],
    ) -> Result<Vec<Option<bitcoin::ScriptBuf>>> {
        let coin = params.coin.unwrap_or_default();
        let mut scripts = Vec::with_capacity(params.outputs.len());

        for (output, parsed) in params.outputs.iter().zip(parsed_outputs) {
            let script = if let Some(ref data) = output.op_return_data {
                let bytes = hex::decode(data).map_err(|e| {
                    DeviceError::InvalidInput(format!("Invalid op_return_data hex: {}", e))
                })?;
                Some(crate::bitcoin_utils::op_return_script(&bytes)?)
            } else if output.multisig.is_some() {
                // Multisig scripts can't be derived from a single key; JS
                // skips them during verification too.
                None
            } else if let Some((path, script_type)) = parsed {
                let public_key = self
                    .get_node_public_key(path, coin, params.unlock_path.as_ref())
                    .await?;
                crate::bitcoin_utils::script_for_pubkey(&public_key, *script_type)?
            } else if let Some(ref address) = output.address {
                Some(crate::bitcoin_utils::address_to_script(address, coin)?)
            } else {
                None
            };
            scripts.push(script);
        }

        Ok(scripts)
    }

    /// Build TxAck for an input
    fn build_input_ack(
        &self,
        input: &SignTxInput,
        parsed: &(Vec<u32>, ScriptType),
    ) -> Result<protos::bitcoin::TxAck> {
        let prev_hash = hex::decode(&input.prev_hash)
            .map_err(|e| DeviceError::InvalidInput(format!("Invalid prev_hash hex: {}", e)))?;

        let multisig = input.multisig.as_ref().map(convert_multisig).transpose()?;

        // For EXTERNAL inputs, decode optional hex fields
        let script_sig = if input.script_type == ScriptType::External {
            input
                .script_sig
                .as_ref()
                .map(|s| hex::decode(s))
                .transpose()
                .map_err(|e| DeviceError::InvalidInput(format!("Invalid script_sig hex: {}", e)))?
        } else {
            None
        };
        let witness = if input.script_type == ScriptType::External {
            input
                .witness
                .as_ref()
                .map(|w| hex::decode(w))
                .transpose()
                .map_err(|e| DeviceError::InvalidInput(format!("Invalid witness hex: {}", e)))?
        } else {
            None
        };
        let ownership_proof = if input.script_type == ScriptType::External {
            input
                .ownership_proof
                .as_ref()
                .map(|p| hex::decode(p))
                .transpose()
                .map_err(|e| {
                    DeviceError::InvalidInput(format!("Invalid ownership_proof hex: {}", e))
                })?
        } else {
            None
        };
        let commitment_data = if input.script_type == ScriptType::External {
            input
                .commitment_data
                .as_ref()
                .map(|c| hex::decode(c))
                .transpose()
                .map_err(|e| {
                    DeviceError::InvalidInput(format!("Invalid commitment_data hex: {}", e))
                })?
        } else {
            None
        };
        let script_pubkey = if input.script_type == ScriptType::External {
            input
                .script_pubkey
                .as_ref()
                .map(|s| hex::decode(s))
                .transpose()
                .map_err(|e| {
                    DeviceError::InvalidInput(format!("Invalid script_pubkey hex: {}", e))
                })?
        } else {
            None
        };

        let tx_input = tx_ack::transaction_type::TxInputType {
            address_n: parsed.0.clone(),
            prev_hash,
            prev_index: input.prev_index,
            script_sig,
            // Omitted when unset so firmware applies its 0xFFFFFFFF default,
            // matching @trezor/connect. Callers wanting RBF set 0xFFFFFFFD.
            sequence: input.sequence,
            script_type: Some(parsed.1 as i32),
            multisig,
            amount: Some(input.amount),
            decred_tree: None,
            witness,
            ownership_proof,
            commitment_data,
            orig_hash: input
                .orig_hash
                .as_ref()
                .map(|h| hex::decode(h))
                .transpose()
                .map_err(|e| DeviceError::InvalidInput(format!("Invalid orig_hash hex: {}", e)))?,
            orig_index: input.orig_index,
            decred_staking_spend: None,
            script_pubkey,
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
    fn build_output_ack(
        &self,
        output: &SignTxOutput,
        parsed: &Option<(Vec<u32>, ScriptType)>,
        auto_payment_req: bool,
    ) -> Result<protos::bitcoin::TxAck> {
        let orig_hash = output
            .orig_hash
            .as_ref()
            .map(|h| hex::decode(h))
            .transpose()
            .map_err(|e| DeviceError::InvalidInput(format!("Invalid orig_hash hex: {}", e)))?;
        let orig_index = output.orig_index;
        let payment_req_index =
            output
                .payment_req_index
                .or(if auto_payment_req { Some(0) } else { None });

        let tx_output = if let Some(ref op_return_data) = output.op_return_data {
            // OP_RETURN output
            let data = hex::decode(op_return_data).map_err(|e| {
                DeviceError::InvalidInput(format!("Invalid op_return_data hex: {}", e))
            })?;
            tx_ack::transaction_type::TxOutputType {
                address: None,
                address_n: vec![],
                amount: 0,
                script_type: Some(OutputScriptType::PayToOpReturn as i32),
                multisig: None,
                op_return_data: Some(data),
                orig_hash,
                orig_index,
                payment_req_index,
            }
        } else if let Some((path, script_type)) = parsed {
            // Change output (to own address)
            let multisig = output.multisig.as_ref().map(convert_multisig).transpose()?;
            let output_script_type = if multisig.is_some() {
                OutputScriptType::PayToMultisig
            } else {
                match script_type {
                    ScriptType::SpendAddress => OutputScriptType::PayToAddress,
                    ScriptType::SpendP2SHWitness => OutputScriptType::PayToP2SHWitness,
                    ScriptType::SpendWitness => OutputScriptType::PayToWitness,
                    ScriptType::SpendTaproot => OutputScriptType::PayToTaproot,
                    _ => OutputScriptType::PayToAddress,
                }
            };
            tx_ack::transaction_type::TxOutputType {
                address: None,
                address_n: path.clone(),
                amount: output.amount,
                script_type: Some(output_script_type as i32),
                multisig,
                op_return_data: None,
                orig_hash,
                orig_index,
                payment_req_index,
            }
        } else if let Some(ref address) = output.address {
            // External output (to address)
            tx_ack::transaction_type::TxOutputType {
                address: Some(address.clone()),
                address_n: vec![],
                amount: output.amount,
                script_type: Some(OutputScriptType::PayToAddress as i32),
                multisig: None,
                op_return_data: None,
                orig_hash,
                orig_index,
                payment_req_index,
            }
        } else {
            return Err(DeviceError::InvalidInput(
                "Output must have either address, path, or op_return_data".to_string(),
            )
            .into());
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

    /// Build TxAck for previous transaction metadata
    fn build_prev_tx_meta_ack(&self, prev_tx: &SignTxPrevTx) -> Result<protos::bitcoin::TxAck> {
        let extra_data_len = prev_tx
            .extra_data
            .as_ref()
            .map(|d| hex::decode(d).map(|b| b.len() as u32))
            .transpose()
            .map_err(|e| DeviceError::InvalidInput(format!("Invalid extra_data hex: {}", e)))?
            .unwrap_or(0);

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
                extra_data_len: Some(extra_data_len),
                expiry: None,
                overwintered: None,
                version_group_id: None,
                timestamp: None,
                branch_id: None,
            }),
        })
    }

    /// Build TxAck for a previous transaction input
    fn build_prev_tx_input_ack(&self, input: &SignTxPrevTxInput) -> Result<protos::bitcoin::TxAck> {
        let prev_hash = hex::decode(&input.prev_hash).map_err(|e| {
            DeviceError::InvalidInput(format!("Invalid prev tx input prev_hash hex: {}", e))
        })?;
        let script_sig = hex::decode(&input.script_sig).map_err(|e| {
            DeviceError::InvalidInput(format!("Invalid prev tx input script_sig hex: {}", e))
        })?;

        let tx_input = tx_ack::transaction_type::TxInputType {
            address_n: vec![],
            prev_hash,
            prev_index: input.prev_index,
            script_sig: Some(script_sig),
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
        output: &SignTxPrevTxOutput,
    ) -> Result<protos::bitcoin::TxAck> {
        let script_pubkey = hex::decode(&output.script_pubkey).map_err(|e| {
            DeviceError::InvalidInput(format!("Invalid prev tx output script_pubkey hex: {}", e))
        })?;

        let bin_output = tx_ack::transaction_type::TxOutputBinType {
            amount: output.amount,
            script_pubkey,
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

    /// Disconnect from the device.
    pub async fn disconnect(&mut self) -> Result<()> {
        self.transport.release(&self.session).await?;
        Ok(())
    }

    /// Handle potential button request/PIN/passphrase flows.
    ///
    /// Uses a loop instead of recursion to avoid unbounded stack growth
    /// if the device sends many consecutive ButtonRequests.
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
                    // Send ButtonAck and loop for the next response
                    let ack = protos::common::ButtonAck {};
                    let (next_type, next_data) = self
                        .transport
                        .call(
                            &self.session,
                            MessageType::ButtonAck as u16,
                            &ack.encode_to_vec(),
                        )
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
                                let (next_type, next_data) = self
                                    .transport
                                    .call(
                                        &self.session,
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
                        let (next_type, next_data) = self
                            .transport
                            .call(
                                &self.session,
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
            message: "Too many consecutive ButtonRequests from device".to_string(),
        }
        .into())
    }
}

impl std::fmt::Debug for ConnectedDevice {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ConnectedDevice")
            .field("info", &self.info)
            .field("session", &self.session)
            .field("features", &self.features)
            .finish()
    }
}

/// Client-side validation performed before any message is sent to the device.
/// Mirrors the checks `@trezor/connect` runs in `signTransaction`.
fn validate_sign_tx_params(params: &SignTxParams) -> Result<()> {
    let coin = params.coin.unwrap_or_default();

    // Total spendable (non-OP_RETURN) output value must clear the dust limit.
    let spendable: Vec<u64> = params
        .outputs
        .iter()
        .filter(|o| o.op_return_data.is_none())
        .map(|o| o.amount)
        .collect();
    if !spendable.is_empty() {
        let total: u64 = spendable.iter().sum();
        if total < crate::constants::DUST_LIMIT_SATOSHIS {
            return Err(
                DeviceError::InvalidInput("Total amount is below dust limit".to_string()).into(),
            );
        }
    }

    // EXTERNAL inputs must carry the previous output's script.
    for (i, input) in params.inputs.iter().enumerate() {
        if input.script_type == ScriptType::External && input.script_pubkey.is_none() {
            return Err(DeviceError::InvalidInput(format!(
                "Input {}: EXTERNAL input requires script_pubkey",
                i
            ))
            .into());
        }
    }

    // External output addresses must parse and match the coin network.
    for (i, output) in params.outputs.iter().enumerate() {
        if let Some(ref address) = output.address {
            crate::bitcoin_utils::address_to_script(address, coin)
                .map_err(|e| DeviceError::InvalidInput(format!("Output {}: {}", i, e)))?;
        }
    }

    // Previous transactions are required for every input the device verifies
    // by streaming its prev tx: everything except taproot and external inputs
    // (segwit included). Fail early with the full list instead of erroring
    // mid-flow on the first device request.
    let mut missing: Vec<String> = Vec::new();
    for input in &params.inputs {
        if matches!(
            input.script_type,
            ScriptType::SpendTaproot | ScriptType::External
        ) {
            continue;
        }
        let hash = input.prev_hash.to_lowercase();
        let provided = params
            .prev_txs
            .iter()
            .any(|tx| tx.hash.eq_ignore_ascii_case(&hash));
        if !provided && !missing.contains(&hash) {
            missing.push(hash);
        }
    }
    if !missing.is_empty() {
        return Err(DeviceError::InvalidInput(format!(
            "Missing previous transactions for inputs: {}",
            missing.join(", ")
        ))
        .into());
    }

    // Declared prev tx hashes must match their contents (skipped for txs
    // carrying extra_data, which serialize differently).
    for prev in &params.prev_txs {
        if let Some(computed) = crate::bitcoin_utils::compute_prev_txid(prev)?
            && !computed.eq_ignore_ascii_case(&prev.hash)
        {
            return Err(crate::error::BitcoinError::InvalidTransaction(format!(
                "prev tx {}: provided contents hash to {}",
                prev.hash, computed
            ))
            .into());
        }
    }

    Ok(())
}

/// Find a previous transaction by its hash (hex-encoded bytes from the device).
fn find_prev_tx<'a>(
    prev_txs: &'a [SignTxPrevTx],
    tx_hash_bytes: &[u8],
) -> Result<&'a SignTxPrevTx> {
    let tx_hash_hex = hex::encode(tx_hash_bytes);
    prev_txs
        .iter()
        .find(|tx| tx.hash.eq_ignore_ascii_case(&tx_hash_hex))
        .ok_or_else(|| {
            DeviceError::InvalidInput(format!(
                "Previous transaction {} not found in prev_txs",
                tx_hash_hex
            ))
            .into()
        })
}

/// Convert MultisigConfig to protobuf MultisigRedeemScriptType.
fn convert_multisig(config: &MultisigConfig) -> Result<protos::bitcoin::MultisigRedeemScriptType> {
    use protos::bitcoin::multisig_redeem_script_type::HdNodePathType;

    let pubkeys = config
        .pubkeys
        .iter()
        .map(|pk| {
            let node = if let Some(ref hd) = pk.node {
                crate::params::HDNodeType {
                    depth: hd.depth,
                    fingerprint: hd.fingerprint,
                    child_num: hd.child_num,
                    chain_code: hd.chain_code.clone(),
                    public_key: hd.public_key.clone(),
                }
            } else if let Some(ref xpub) = pk.xpub {
                // Decode the xpub into the node fields the device expects,
                // like JS convertMultisigPubKey does.
                crate::bitcoin_utils::xpub_to_hd_node_type(xpub)?
            } else {
                return Err(DeviceError::InvalidInput(
                    "Multisig pubkey requires either node or xpub".to_string(),
                )
                .into());
            };

            Ok(HdNodePathType {
                node: protos::common::HdNodeType {
                    depth: node.depth,
                    fingerprint: node.fingerprint,
                    child_num: node.child_num,
                    chain_code: node.chain_code,
                    private_key: None,
                    public_key: node.public_key,
                },
                address_n: pk.address_n.clone(),
            })
        })
        .collect::<Result<Vec<_>>>()?;

    let signatures = match config.signatures.as_ref() {
        Some(sigs) => sigs
            .iter()
            .map(|s| {
                if s.is_empty() {
                    Ok(vec![])
                } else {
                    hex::decode(s).map_err(|e| {
                        DeviceError::InvalidInput(format!("Invalid multisig signature hex: {}", e))
                            .into()
                    })
                }
            })
            .collect::<Result<Vec<_>>>()?,
        None => vec![vec![]; config.pubkeys.len()],
    };

    Ok(protos::bitcoin::MultisigRedeemScriptType {
        pubkeys,
        signatures,
        m: config.m,
        nodes: vec![],
        address_n: vec![],
        pubkeys_order: None,
    })
}

/// Convert PaymentRequest params to protobuf PaymentRequest.
fn convert_payment_request(pr: &PaymentRequest) -> Result<protos::common::PaymentRequest> {
    use protos::common::payment_request::*;

    let nonce = pr
        .nonce
        .as_ref()
        .map(|n| hex::decode(n))
        .transpose()
        .map_err(|e| {
            DeviceError::InvalidInput(format!("Invalid payment_request nonce hex: {}", e))
        })?;

    let signature = hex::decode(&pr.signature).map_err(|e| {
        DeviceError::InvalidInput(format!("Invalid payment_request signature hex: {}", e))
    })?;

    let memos = pr
        .memos
        .iter()
        .map(|m| PaymentRequestMemo {
            text_memo: m.text_memo.as_ref().map(|t| TextMemo {
                text: t.text.clone(),
            }),
            refund_memo: m.refund_memo.as_ref().map(|r| {
                let mac = hex::decode(&r.mac).unwrap_or_default();
                RefundMemo {
                    address: r.address.clone(),
                    address_n: r.address_n.clone(),
                    mac,
                }
            }),
            coin_purchase_memo: m.coin_purchase_memo.as_ref().map(|c| {
                let mac = hex::decode(&c.mac).unwrap_or_default();
                CoinPurchaseMemo {
                    coin_type: c.coin_type,
                    amount: c.amount.clone(),
                    address: c.address.clone(),
                    address_n: c.address_n.clone(),
                    mac,
                }
            }),
            text_details_memo: None,
        })
        .collect();

    let amount = pr.amount.map(|a| a.to_le_bytes().to_vec());

    Ok(protos::common::PaymentRequest {
        nonce,
        recipient_name: pr.recipient_name.clone(),
        memos,
        amount,
        signature,
    })
}

/// Infer script type from BIP32 path.
fn infer_script_type(path: &[u32]) -> ScriptType {
    const HARDENED: u32 = 0x80000000;

    if path.is_empty() {
        return ScriptType::SpendWitness;
    }

    let purpose = path[0] & !HARDENED;
    match purpose {
        44 => ScriptType::SpendAddress,     // Legacy P2PKH
        49 => ScriptType::SpendP2SHWitness, // Nested SegWit
        84 => ScriptType::SpendWitness,     // Native SegWit
        86 => ScriptType::SpendTaproot,     // Taproot
        _ => ScriptType::SpendWitness,      // Default to native SegWit
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::transport::mock::{MockTransport, ScriptedExchange};

    #[test]
    fn test_infer_script_type() {
        assert_eq!(
            infer_script_type(&[0x8000002C, 0x80000000, 0x80000000, 0, 0]),
            ScriptType::SpendAddress
        );
        assert_eq!(
            infer_script_type(&[0x80000031, 0x80000000, 0x80000000, 0, 0]),
            ScriptType::SpendP2SHWitness
        );
        assert_eq!(
            infer_script_type(&[0x80000054, 0x80000000, 0x80000000, 0, 0]),
            ScriptType::SpendWitness
        );
        assert_eq!(
            infer_script_type(&[0x80000056, 0x80000000, 0x80000000, 0, 0]),
            ScriptType::SpendTaproot
        );
    }

    // ---- Test helpers -----------------------------------------------------

    fn mock_device(script: Vec<ScriptedExchange>) -> (ConnectedDevice, MockTransport) {
        let mock = MockTransport::new(script);
        let handle = mock.clone();
        let device = ConnectedDevice::new(
            DeviceInfo::new_usb("mock".into(), 0x1209, 0x53c1),
            Box::new(mock),
            "mock-session".into(),
        );
        (device, handle)
    }

    fn tx_request_reply(
        request_type: tx_request::RequestType,
        request_index: Option<u32>,
    ) -> Vec<u8> {
        protos::bitcoin::TxRequest {
            request_type: Some(request_type as i32),
            details: Some(tx_request::TxRequestDetailsType {
                request_index,
                tx_hash: None,
                extra_data_len: None,
                extra_data_offset: None,
            }),
            serialized: None,
        }
        .encode_to_vec()
    }

    /// secp256k1 generator point, compressed. Its P2WPKH address is the
    /// BIP-173 example bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4.
    const G_PUBKEY: &str = "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798";

    /// Build the transaction the mocked device "signs": inputs mirror the
    /// params, outputs pay the requested amounts to the expected scripts.
    /// Change outputs use P2WPKH of `G_PUBKEY`, matching the mocked
    /// GetPublicKey reply from `public_key_reply()`.
    fn dummy_signed_tx(params: &SignTxParams) -> bitcoin::Transaction {
        use bitcoin::absolute::LockTime;
        use bitcoin::transaction::Version;
        use bitcoin::{Amount, OutPoint, ScriptBuf, Sequence, TxIn, TxOut, Txid, Witness};
        use std::str::FromStr;

        let input = params
            .inputs
            .iter()
            .map(|i| TxIn {
                previous_output: OutPoint::new(Txid::from_str(&i.prev_hash).unwrap(), i.prev_index),
                script_sig: ScriptBuf::new(),
                sequence: Sequence(0xffffffff),
                witness: Witness::from_slice(&[vec![0xaa; 64]]),
            })
            .collect();

        let output = params
            .outputs
            .iter()
            .map(|o| {
                let script_pubkey = if let Some(ref addr) = o.address {
                    crate::bitcoin_utils::address_to_script(
                        addr,
                        crate::types::network::Network::Bitcoin,
                    )
                    .unwrap()
                } else if let Some(ref data) = o.op_return_data {
                    crate::bitcoin_utils::op_return_script(&hex::decode(data).unwrap()).unwrap()
                } else {
                    // change output: P2WPKH of the mocked device pubkey
                    crate::bitcoin_utils::script_for_pubkey(
                        &hex::decode(G_PUBKEY).unwrap(),
                        ScriptType::SpendWitness,
                    )
                    .unwrap()
                    .unwrap()
                };
                TxOut {
                    value: Amount::from_sat(if o.op_return_data.is_some() {
                        0
                    } else {
                        o.amount
                    }),
                    script_pubkey,
                }
            })
            .collect();

        bitcoin::Transaction {
            version: Version::TWO,
            lock_time: LockTime::ZERO,
            input,
            output,
        }
    }

    fn tx_finished_reply_with(serialized_tx: Vec<u8>) -> Vec<u8> {
        protos::bitcoin::TxRequest {
            request_type: Some(tx_request::RequestType::Txfinished as i32),
            details: None,
            serialized: Some(tx_request::TxRequestSerializedType {
                signature_index: Some(0),
                signature: Some(vec![0xaa, 0xbb]),
                serialized_tx: Some(serialized_tx),
            }),
        }
        .encode_to_vec()
    }

    /// Mocked GetPublicKey reply carrying `G_PUBKEY` as the node key.
    fn public_key_reply() -> Vec<u8> {
        protos::bitcoin::PublicKey {
            node: protos::common::HdNodeType {
                depth: 5,
                fingerprint: 0,
                child_num: 0,
                chain_code: vec![0; 32],
                private_key: None,
                public_key: hex::decode(G_PUBKEY).unwrap(),
            },
            xpub: "xpub-mock".into(),
            root_fingerprint: None,
            descriptor: None,
        }
        .encode_to_vec()
    }

    fn taproot_input() -> SignTxInput {
        SignTxInput {
            prev_hash: "aa".repeat(32),
            prev_index: 0,
            path: "m/86'/0'/0'/0/0".into(),
            amount: 100_000,
            script_type: ScriptType::SpendTaproot,
            sequence: None,
            orig_hash: None,
            orig_index: None,
            multisig: None,
            script_pubkey: None,
            script_sig: None,
            witness: None,
            ownership_proof: None,
            commitment_data: None,
        }
    }

    fn address_output(amount: u64) -> SignTxOutput {
        SignTxOutput {
            address: Some("bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4".into()),
            path: None,
            amount,
            script_type: None,
            op_return_data: None,
            orig_hash: None,
            orig_index: None,
            multisig: None,
            payment_req_index: None,
        }
    }

    fn base_params() -> SignTxParams {
        SignTxParams {
            inputs: vec![taproot_input()],
            outputs: vec![address_output(90_000)],
            ..Default::default()
        }
    }

    /// Standard 1-in/1-out script: SignTx -> TXINPUT -> TXOUTPUT -> TXFINISHED,
    /// finishing with a serialized tx that matches `params` so post-sign
    /// verification passes.
    fn simple_flow_script(params: &SignTxParams) -> Vec<ScriptedExchange> {
        let serialized = bitcoin::consensus::serialize(&dummy_signed_tx(params));
        vec![
            ScriptedExchange {
                expect_type: MessageType::SignTx as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_request_reply(tx_request::RequestType::Txinput, Some(0)),
            },
            ScriptedExchange {
                expect_type: MessageType::TxAck as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_request_reply(tx_request::RequestType::Txoutput, Some(0)),
            },
            ScriptedExchange {
                expect_type: MessageType::TxAck as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_finished_reply_with(serialized),
            },
        ]
    }

    fn decode_tx_ack(payload: &[u8]) -> protos::bitcoin::TxAck {
        protos::bitcoin::TxAck::decode(payload).expect("valid TxAck payload")
    }

    // ---- Pre-sign validation ----------------------------------------------

    #[tokio::test]
    async fn sign_rejects_total_below_dust_limit() {
        let (device, mock) = mock_device(vec![]);
        let mut params = base_params();
        params.outputs = vec![address_output(545)];

        let err = device.sign_transaction(params).await.unwrap_err();
        assert!(err.to_string().contains("dust"), "unexpected error: {err}");
        assert!(mock.calls().is_empty(), "device must not be contacted");
    }

    #[tokio::test]
    async fn sign_accepts_total_at_dust_limit() {
        let mut params = base_params();
        params.outputs = vec![address_output(546)];
        let (device, mock) = mock_device(simple_flow_script(&params));

        let signed = device.sign_transaction(params).await.unwrap();
        assert_eq!(signed.signatures[0], "aabb");
        assert!(signed.txid.is_some());
        assert_eq!(mock.remaining(), 0);
    }

    #[tokio::test]
    async fn sign_requires_prev_txs_for_non_taproot_inputs() {
        let (device, mock) = mock_device(vec![]);
        let mut params = base_params();
        params.inputs[0].script_type = ScriptType::SpendWitness;
        params.inputs[0].path = "m/84'/0'/0'/0/0".into();

        let err = device.sign_transaction(params).await.unwrap_err();
        let msg = err.to_string();
        assert!(
            msg.contains("Missing previous transactions") && msg.contains(&"aa".repeat(32)),
            "unexpected error: {msg}"
        );
        assert!(mock.calls().is_empty());
    }

    #[tokio::test]
    async fn sign_taproot_needs_no_prev_txs() {
        let params = base_params();
        let (device, _mock) = mock_device(simple_flow_script(&params));
        device.sign_transaction(params).await.unwrap();
    }

    #[tokio::test]
    async fn sign_rejects_external_input_without_script_pubkey() {
        let (device, mock) = mock_device(vec![]);
        let mut params = base_params();
        params.inputs[0].script_type = ScriptType::External;
        params.inputs[0].path = String::new();

        let err = device.sign_transaction(params).await.unwrap_err();
        assert!(err.to_string().contains("script_pubkey"));
        assert!(mock.calls().is_empty());
    }

    #[tokio::test]
    async fn sign_rejects_invalid_output_address() {
        let (device, mock) = mock_device(vec![]);
        let mut params = base_params();
        params.outputs[0].address = Some("not-an-address".into());

        assert!(device.sign_transaction(params).await.is_err());
        assert!(mock.calls().is_empty());
    }

    #[tokio::test]
    async fn sign_rejects_wrong_network_output_address() {
        let (device, mock) = mock_device(vec![]);
        let mut params = base_params();
        // testnet address while coin defaults to Bitcoin mainnet
        params.outputs[0].address = Some("tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx".into());

        assert!(device.sign_transaction(params).await.is_err());
        assert!(mock.calls().is_empty());
    }

    #[tokio::test]
    async fn sign_rejects_prev_tx_hash_mismatch() {
        let (device, mock) = mock_device(vec![]);
        let mut params = base_params();
        params.inputs[0].script_type = ScriptType::SpendWitness;
        params.inputs[0].path = "m/84'/0'/0'/0/0".into();
        params.inputs[0].prev_hash = "bb".repeat(32);
        // Declared hash matches the input, but the contents hash to something else.
        params.prev_txs = vec![SignTxPrevTx {
            hash: "bb".repeat(32),
            version: 1,
            lock_time: 0,
            inputs: vec![SignTxPrevTxInput {
                prev_hash: "cc".repeat(32),
                prev_index: 0,
                script_sig: String::new(),
                sequence: 0xffffffff,
            }],
            outputs: vec![SignTxPrevTxOutput {
                amount: 100_000,
                script_pubkey: "0014751e76e8199196d454941c45d1b3a323f1433bd6".into(),
            }],
            extra_data: None,
        }];

        let err = device.sign_transaction(params).await.unwrap_err();
        assert!(
            err.to_string().contains("hash to"),
            "unexpected error: {err}"
        );
        assert!(mock.calls().is_empty());
    }

    // ---- Protocol fidelity -------------------------------------------------

    #[tokio::test]
    async fn sign_omits_sequence_when_unset() {
        let params = base_params();
        let (device, mock) = mock_device(simple_flow_script(&params));
        device.sign_transaction(params).await.unwrap();

        let calls = mock.calls();
        // calls[0] is SignTx, calls[1] is the TXINPUT TxAck
        let ack = decode_tx_ack(&calls[1].1);
        let input = &ack.tx.unwrap().inputs[0];
        assert_eq!(input.sequence, None, "sequence must be omitted when unset");
    }

    #[tokio::test]
    async fn sign_passes_explicit_sequence_through() {
        let mut params = base_params();
        params.inputs[0].sequence = Some(0xFFFFFFFD);
        let (device, mock) = mock_device(simple_flow_script(&params));
        device.sign_transaction(params).await.unwrap();

        let ack = decode_tx_ack(&mock.calls()[1].1);
        assert_eq!(ack.tx.unwrap().inputs[0].sequence, Some(0xFFFFFFFD));
    }

    #[tokio::test]
    async fn sign_auto_assigns_payment_req_index() {
        let mut params = base_params();
        params.payment_requests = vec![PaymentRequest {
            recipient_name: "Merchant".into(),
            nonce: None,
            memos: vec![],
            amount: Some(90_000),
            signature: "00".into(),
        }];
        let (device, mock) = mock_device(simple_flow_script(&params));
        device.sign_transaction(params).await.unwrap();

        let ack = decode_tx_ack(&mock.calls()[2].1);
        let output = &ack.tx.unwrap().outputs[0];
        assert_eq!(
            output.payment_req_index,
            Some(0),
            "payment_req_index must default to 0 when payment requests exist"
        );
    }

    #[tokio::test]
    async fn sign_leaves_payment_req_index_unset_without_requests() {
        let params = base_params();
        let (device, mock) = mock_device(simple_flow_script(&params));
        device.sign_transaction(params).await.unwrap();

        let ack = decode_tx_ack(&mock.calls()[2].1);
        assert_eq!(ack.tx.unwrap().outputs[0].payment_req_index, None);
    }

    // ---- Post-sign verification ---------------------------------------------

    #[tokio::test]
    async fn sign_returns_verified_txid_and_witnesses() {
        let params = base_params();
        let expected_txid = dummy_signed_tx(&params).compute_txid().to_string();
        let (device, _mock) = mock_device(simple_flow_script(&params));

        let signed = device.sign_transaction(params).await.unwrap();
        assert_eq!(signed.txid, Some(expected_txid));
        let witnesses = signed.witnesses.unwrap();
        assert_eq!(witnesses.len(), 1);
        assert!(witnesses[0].is_some(), "witness input must surface data");
    }

    #[tokio::test]
    async fn sign_rejects_tampered_output_amount() {
        let params = base_params();
        // Device "signs" a tx paying a different amount than requested
        let mut tampered = params.clone();
        tampered.outputs[0].amount = 80_000;
        let script = vec![
            ScriptedExchange {
                expect_type: MessageType::SignTx as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_request_reply(tx_request::RequestType::Txinput, Some(0)),
            },
            ScriptedExchange {
                expect_type: MessageType::TxAck as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_request_reply(tx_request::RequestType::Txoutput, Some(0)),
            },
            ScriptedExchange {
                expect_type: MessageType::TxAck as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_finished_reply_with(bitcoin::consensus::serialize(&dummy_signed_tx(
                    &tampered,
                ))),
            },
        ];
        let (device, _mock) = mock_device(script);

        let err = device.sign_transaction(params).await.unwrap_err();
        assert!(
            err.to_string().contains("Wrong output amount"),
            "unexpected error: {err}"
        );
    }

    #[tokio::test]
    async fn sign_rejects_tampered_output_script() {
        let params = base_params();
        // Device "signs" a tx paying a different address than requested
        let mut tampered = params.clone();
        tampered.outputs[0].address = Some("1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH".into());
        let script = vec![
            ScriptedExchange {
                expect_type: MessageType::SignTx as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_request_reply(tx_request::RequestType::Txinput, Some(0)),
            },
            ScriptedExchange {
                expect_type: MessageType::TxAck as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_request_reply(tx_request::RequestType::Txoutput, Some(0)),
            },
            ScriptedExchange {
                expect_type: MessageType::TxAck as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_finished_reply_with(bitcoin::consensus::serialize(&dummy_signed_tx(
                    &tampered,
                ))),
            },
        ];
        let (device, _mock) = mock_device(script);

        let err = device.sign_transaction(params).await.unwrap_err();
        assert!(
            err.to_string().contains("scripts differ"),
            "unexpected error: {err}"
        );
    }

    #[tokio::test]
    async fn sign_verifies_change_output_script_via_device_pubkey() {
        let mut params = base_params();
        params.outputs.push(SignTxOutput {
            address: None,
            path: Some("m/84'/0'/0'/1/0".into()),
            amount: 9_000,
            script_type: None,
            op_return_data: None,
            orig_hash: None,
            orig_index: None,
            multisig: None,
            payment_req_index: None,
        });

        let serialized = bitcoin::consensus::serialize(&dummy_signed_tx(&params));
        let script = vec![
            // change output derivation happens before SignTx
            ScriptedExchange {
                expect_type: MessageType::GetPublicKey as u16,
                reply_type: MessageType::PublicKey as u16,
                reply: public_key_reply(),
            },
            ScriptedExchange {
                expect_type: MessageType::SignTx as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_request_reply(tx_request::RequestType::Txinput, Some(0)),
            },
            ScriptedExchange {
                expect_type: MessageType::TxAck as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_request_reply(tx_request::RequestType::Txoutput, Some(0)),
            },
            ScriptedExchange {
                expect_type: MessageType::TxAck as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_request_reply(tx_request::RequestType::Txoutput, Some(1)),
            },
            ScriptedExchange {
                expect_type: MessageType::TxAck as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_finished_reply_with(serialized),
            },
        ];
        let (device, mock) = mock_device(script);

        let signed = device.sign_transaction(params).await.unwrap();
        assert!(signed.txid.is_some());
        assert_eq!(mock.remaining(), 0, "all exchanges must be consumed");
    }

    #[tokio::test]
    async fn sign_skips_verification_when_serialize_disabled() {
        let mut params = base_params();
        params.serialize = Some(false);

        // Device returns signatures but no serialized tx
        let finished = protos::bitcoin::TxRequest {
            request_type: Some(tx_request::RequestType::Txfinished as i32),
            details: None,
            serialized: Some(tx_request::TxRequestSerializedType {
                signature_index: Some(0),
                signature: Some(vec![0xaa, 0xbb]),
                serialized_tx: None,
            }),
        }
        .encode_to_vec();
        let script = vec![
            ScriptedExchange {
                expect_type: MessageType::SignTx as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_request_reply(tx_request::RequestType::Txinput, Some(0)),
            },
            ScriptedExchange {
                expect_type: MessageType::TxAck as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: tx_request_reply(tx_request::RequestType::Txoutput, Some(0)),
            },
            ScriptedExchange {
                expect_type: MessageType::TxAck as u16,
                reply_type: MessageType::TxRequest as u16,
                reply: finished,
            },
        ];
        let (device, mock) = mock_device(script);

        let signed = device.sign_transaction(params).await.unwrap();
        assert_eq!(signed.txid, None);
        assert_eq!(signed.witnesses, None);
        // No GetPublicKey derivation call happened; first call is SignTx
        assert_eq!(mock.calls()[0].0, MessageType::SignTx as u16);
    }

    // ---- get_address ---------------------------------------------------------

    fn address_reply(address: &str, mac: Option<Vec<u8>>) -> Vec<u8> {
        protos::bitcoin::Address {
            address: address.into(),
            mac,
        }
        .encode_to_vec()
    }

    #[tokio::test]
    async fn get_address_show_does_silent_prederive_then_display() {
        let script = vec![
            ScriptedExchange {
                expect_type: MessageType::GetAddress as u16,
                reply_type: MessageType::Address as u16,
                reply: address_reply("bc1qexample", None),
            },
            ScriptedExchange {
                expect_type: MessageType::GetAddress as u16,
                reply_type: MessageType::Address as u16,
                reply: address_reply("bc1qexample", Some(vec![0xab, 0xcd])),
            },
        ];
        let (device, mock) = mock_device(script);

        let result = device
            .get_address(GetAddressParams {
                path: "m/84'/0'/0'/0/0".into(),
                show_on_trezor: true,
                ..Default::default()
            })
            .await
            .unwrap();

        assert_eq!(result.address, "bc1qexample");
        assert_eq!(result.mac.as_deref(), Some("abcd"));
        let calls = mock.calls();
        assert_eq!(calls.len(), 2, "silent pre-derive then display call");
        let silent = protos::bitcoin::GetAddress::decode(calls[0].1.as_slice()).unwrap();
        assert_eq!(silent.show_display, Some(false));
        let display = protos::bitcoin::GetAddress::decode(calls[1].1.as_slice()).unwrap();
        assert_eq!(display.show_display, Some(true));
    }

    #[tokio::test]
    async fn get_address_rejects_mismatched_expected_address() {
        let script = vec![ScriptedExchange {
            expect_type: MessageType::GetAddress as u16,
            reply_type: MessageType::Address as u16,
            reply: address_reply("bc1qactual", None),
        }];
        let (device, mock) = mock_device(script);

        let err = device
            .get_address(GetAddressParams {
                path: "m/84'/0'/0'/0/0".into(),
                show_on_trezor: true,
                address: Some("bc1qexpected".into()),
                ..Default::default()
            })
            .await
            .unwrap_err();

        assert!(matches!(
            err,
            crate::error::TrezorError::Device(DeviceError::AddressMismatch { .. })
        ));
        // Failed before the display call: only the silent call happened
        assert_eq!(mock.calls().len(), 1);
    }

    #[tokio::test]
    async fn get_address_rejects_display_result_differing_from_silent() {
        let script = vec![
            ScriptedExchange {
                expect_type: MessageType::GetAddress as u16,
                reply_type: MessageType::Address as u16,
                reply: address_reply("bc1qsilent", None),
            },
            ScriptedExchange {
                expect_type: MessageType::GetAddress as u16,
                reply_type: MessageType::Address as u16,
                reply: address_reply("bc1qdifferent", None),
            },
        ];
        let (device, _mock) = mock_device(script);

        let err = device
            .get_address(GetAddressParams {
                path: "m/84'/0'/0'/0/0".into(),
                show_on_trezor: true,
                ..Default::default()
            })
            .await
            .unwrap_err();

        assert!(matches!(
            err,
            crate::error::TrezorError::Device(DeviceError::AddressMismatch { .. })
        ));
    }

    #[tokio::test]
    async fn get_address_without_display_makes_single_call() {
        let script = vec![ScriptedExchange {
            expect_type: MessageType::GetAddress as u16,
            reply_type: MessageType::Address as u16,
            reply: address_reply("bc1qexample", None),
        }];
        let (device, mock) = mock_device(script);

        let result = device
            .get_address(GetAddressParams {
                path: "m/84'/0'/0'/0/0".into(),
                show_on_trezor: false,
                ..Default::default()
            })
            .await
            .unwrap();

        assert_eq!(result.address, "bc1qexample");
        assert_eq!(mock.calls().len(), 1);
    }

    #[tokio::test]
    async fn get_address_wires_multisig_through() {
        let script = vec![ScriptedExchange {
            expect_type: MessageType::GetAddress as u16,
            reply_type: MessageType::Address as u16,
            reply: address_reply("3multisig", None),
        }];
        let (device, mock) = mock_device(script);

        device
            .get_address(GetAddressParams {
                path: "m/48'/0'/0'/0/0/0".into(),
                show_on_trezor: false,
                script_type: Some(ScriptType::SpendMultisig),
                multisig: Some(MultisigConfig {
                    m: 2,
                    pubkeys: vec![MultisigPubkey {
                        node: None,
                        xpub: Some(
                            "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8"
                                .into(),
                        ),
                        address_n: vec![0, 0],
                    }],
                    signatures: None,
                }),
                ..Default::default()
            })
            .await
            .unwrap();

        let request = protos::bitcoin::GetAddress::decode(mock.calls()[0].1.as_slice()).unwrap();
        let multisig = request.multisig.expect("multisig must be forwarded");
        assert_eq!(multisig.m, 2);
        assert_eq!(multisig.pubkeys[0].node.public_key.len(), 33);
    }

    // ---- Deprecated api stubs -------------------------------------------------

    #[tokio::test]
    #[allow(deprecated)]
    async fn api_stubs_error_instead_of_returning_fake_data() {
        assert!(matches!(
            crate::api::public_key::get_public_key(Default::default())
                .await
                .unwrap_err(),
            crate::error::TrezorError::NotImplemented(_)
        ));
        assert!(matches!(
            crate::api::coinjoin::cancel_coinjoin_authorization()
                .await
                .unwrap_err(),
            crate::error::TrezorError::NotImplemented(_)
        ));
    }

    // ---- Multisig conversion -----------------------------------------------

    #[test]
    fn convert_multisig_decodes_xpub_only_pubkeys() {
        let config = MultisigConfig {
            m: 2,
            pubkeys: vec![MultisigPubkey {
                node: None,
                xpub: Some(
                    "xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8"
                        .into(),
                ),
                address_n: vec![0, 0],
            }],
            signatures: None,
        };

        let proto = convert_multisig(&config).unwrap();
        let node = &proto.pubkeys[0].node;
        assert_eq!(node.public_key.len(), 33);
        assert!(node.public_key[0] == 0x02 || node.public_key[0] == 0x03);
        assert_eq!(node.chain_code.len(), 32);
        assert_eq!(proto.signatures, vec![Vec::<u8>::new()]);
    }

    #[test]
    fn convert_multisig_rejects_pubkey_without_node_or_xpub() {
        let config = MultisigConfig {
            m: 1,
            pubkeys: vec![MultisigPubkey {
                node: None,
                xpub: None,
                address_n: vec![],
            }],
            signatures: None,
        };
        assert!(convert_multisig(&config).is_err());
    }

    #[test]
    fn convert_multisig_rejects_bad_signature_hex() {
        let config = MultisigConfig {
            m: 1,
            pubkeys: vec![MultisigPubkey {
                node: Some(HDNodeType {
                    depth: 0,
                    fingerprint: 0,
                    child_num: 0,
                    chain_code: vec![0; 32],
                    public_key: vec![2; 33],
                }),
                xpub: None,
                address_n: vec![],
            }],
            signatures: Some(vec!["zz-not-hex".into()]),
        };
        assert!(convert_multisig(&config).is_err());
    }

    // ---- Model One message size ---------------------------------------------

    #[tokio::test]
    async fn sign_message_rejects_oversized_message_on_model_one() {
        let features_reply = protos::management::Features {
            major_version: 1,
            ..Default::default()
        }
        .encode_to_vec();

        let (mut device, mock) = mock_device(vec![ScriptedExchange {
            expect_type: MessageType::Initialize as u16,
            reply_type: MessageType::Features as u16,
            reply: features_reply,
        }]);
        device.initialize().await.unwrap();

        let err = device
            .sign_message(SignMessageParams {
                path: "m/84'/0'/0'/0/0".into(),
                message: "x".repeat(1025),
                ..Default::default()
            })
            .await
            .unwrap_err();
        assert!(err.to_string().contains("1024"));
        // Only the Initialize exchange happened
        assert_eq!(mock.calls().len(), 1);
    }
}
