//! Scripted mock transport for exercising device flows in unit tests.
//!
//! Each expected exchange pairs the message type the code under test should
//! send with the canned response the "device" replies with. `call` pops the
//! next exchange, asserts the request type matches, records the raw request
//! bytes, and returns the scripted response.

use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

use async_trait::async_trait;

use crate::error::{DeviceError, Result};
use crate::transport::traits::{DeviceDescriptor, Transport};

/// One scripted request/response exchange.
pub(crate) struct ScriptedExchange {
    /// Message type the code under test is expected to send
    pub expect_type: u16,
    /// Message type of the canned response
    pub reply_type: u16,
    /// Encoded protobuf payload of the canned response
    pub reply: Vec<u8>,
}

/// A recorded request: (message_type, payload).
type RecordedCall = (u16, Vec<u8>);

/// Transport that replays a fixed script of exchanges. Clones share the same
/// script and call log, so tests can keep a handle while boxing another.
#[derive(Clone, Default)]
pub(crate) struct MockTransport {
    script: Arc<Mutex<VecDeque<ScriptedExchange>>>,
    calls: Arc<Mutex<Vec<RecordedCall>>>,
}

impl MockTransport {
    pub(crate) fn new(script: Vec<ScriptedExchange>) -> Self {
        Self {
            script: Arc::new(Mutex::new(script.into())),
            calls: Arc::new(Mutex::new(Vec::new())),
        }
    }

    /// Every request sent through `call`, as (message_type, payload).
    pub(crate) fn calls(&self) -> Vec<RecordedCall> {
        self.calls.lock().unwrap().clone()
    }

    /// Number of exchanges left unconsumed.
    pub(crate) fn remaining(&self) -> usize {
        self.script.lock().unwrap().len()
    }
}

#[async_trait]
impl Transport for MockTransport {
    async fn init(&mut self) -> Result<()> {
        Ok(())
    }

    async fn enumerate(&self) -> Result<Vec<DeviceDescriptor>> {
        Ok(vec![])
    }

    async fn acquire(&self, _path: &str, _previous: Option<&str>) -> Result<String> {
        Ok("mock-session".to_string())
    }

    async fn release(&self, _session: &str) -> Result<()> {
        Ok(())
    }

    async fn call(&self, _session: &str, message_type: u16, data: &[u8]) -> Result<(u16, Vec<u8>)> {
        self.calls
            .lock()
            .unwrap()
            .push((message_type, data.to_vec()));

        let exchange = self.script.lock().unwrap().pop_front().ok_or_else(|| {
            DeviceError::InvalidInput(format!(
                "MockTransport: unexpected call with message type {} (script exhausted)",
                message_type
            ))
        })?;

        if exchange.expect_type != message_type {
            return Err(DeviceError::InvalidInput(format!(
                "MockTransport: expected message type {}, got {}",
                exchange.expect_type, message_type
            ))
            .into());
        }

        Ok((exchange.reply_type, exchange.reply))
    }

    fn stop(&mut self) {}
}
