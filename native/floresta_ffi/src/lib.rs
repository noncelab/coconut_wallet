//! Coconut Wallet용 Floresta 임베딩 FFI.
//!
//! `floresta-node`의 `Florestad`를 프로세스 내부에서 기동/종료하는 얇은 C ABI 브리지다.
//! 노드가 뜨면 Electrum 서버(`127.0.0.1:50001` 기본)와 JSON-RPC 서버가 함께 열리므로,
//! 체인 질의는 기존 Electrum 클라이언트가 로컬 포트로 붙어서 처리하고
//! (디스크립터 등록/동기화 진행도는 JSON-RPC로), FFI는 생명주기만 노출한다.

use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::PathBuf;
use std::sync::{Arc, LazyLock, Mutex};

use bitcoin::Network;
use floresta_node::{Config, Florestad};
use serde::Deserialize;

pub type NodeHandle = i64;

struct NodeState {
    node: Arc<Florestad>,
    runtime: tokio::runtime::Runtime,
}

static NODES: LazyLock<Mutex<HashMap<NodeHandle, NodeState>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));
static NEXT_HANDLE: LazyLock<Mutex<NodeHandle>> = LazyLock::new(|| Mutex::new(1));

fn next_handle() -> NodeHandle {
    let mut h = NEXT_HANDLE.lock().unwrap();
    let id = *h;
    *h += 1;
    id
}

fn to_cstring(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

unsafe fn cstr_to_str<'a>(ptr: *const c_char) -> Result<&'a str, String> {
    if ptr.is_null() {
        return Err("null pointer".to_string());
    }
    CStr::from_ptr(ptr).to_str().map_err(|e| format!("invalid utf8: {e}"))
}

/// Dart에서 넘어오는 노드 설정 JSON.
///
/// ```json
/// {
///   "network": "bitcoin|testnet|signet|regtest",
///   "datadir": "/path/to/data",
///   "electrum_address": "127.0.0.1:50001",
///   "json_rpc_address": "127.0.0.1:8332",
///   "proxy": "127.0.0.1:9050",
///   "assume_utreexo": true,
///   "fixed_peers": ["1.2.3.4:8333"],
///   "user_agent": "coconut_wallet/1.0",
///   "log_to_stdout": false
/// }
/// ```
#[derive(Deserialize)]
struct NodeConfigJson {
    network: String,
    datadir: String,
    #[serde(default)]
    electrum_address: Option<String>,
    #[serde(default)]
    json_rpc_address: Option<String>,
    #[serde(default)]
    proxy: Option<String>,
    #[serde(default = "default_true")]
    assume_utreexo: bool,
    #[serde(default)]
    backfill: bool,
    #[serde(default)]
    filters_start_height: Option<i32>,
    #[serde(default)]
    fixed_peers: Option<Vec<String>>,
    #[serde(default = "default_user_agent")]
    user_agent: String,
    #[serde(default)]
    log_to_stdout: bool,
}

fn default_true() -> bool {
    true
}
fn default_user_agent() -> String {
    "coconut_wallet/1.0".to_string()
}

impl NodeConfigJson {
    fn into_config(self) -> Result<Config, String> {
        let network = match self.network.as_str() {
            "bitcoin" | "mainnet" => Network::Bitcoin,
            "testnet" => Network::Testnet,
            "signet" => Network::Signet,
            "regtest" => Network::Regtest,
            other => return Err(format!("unsupported network: {other}")),
        };

        let mut config = Config::new(network, PathBuf::from(&self.datadir));
        config.electrum_address = self.electrum_address;
        config.json_rpc_address = self.json_rpc_address;
        config.proxy = self.proxy;
        config.assume_utreexo = self.assume_utreexo;
        config.backfill = self.backfill;
        config.filters_start_height = self.filters_start_height;
        config.connect = self.fixed_peers.unwrap_or_default();
        config.user_agent = self.user_agent;
        config.log_to_stdout = self.log_to_stdout;
        Ok(config)
    }
}

/// 노드를 기동하고 핸들(> 0)을 반환합니다. 실패 시 -1.
///
/// Electrum/JSON-RPC 서버가 함께 열리며, 준비 여부는 각 포트로 폴링해서 확인한다.
#[no_mangle]
pub extern "C" fn node_start(config_json: *const c_char) -> NodeHandle {
    let config_str = match unsafe { cstr_to_str(config_json) } {
        Ok(s) => s,
        Err(e) => {
            eprintln!("floresta_ffi: node_start: {e}");
            return -1;
        }
    };

    let json: NodeConfigJson = match serde_json::from_str(config_str) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("floresta_ffi: node_start: invalid config json: {e}");
            return -1;
        }
    };

    let config = match json.into_config() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("floresta_ffi: node_start: {e}");
            return -1;
        }
    };

    let runtime = match tokio::runtime::Runtime::new() {
        Ok(rt) => rt,
        Err(e) => {
            eprintln!("floresta_ffi: node_start: runtime: {e}");
            return -1;
        }
    };

    let node = Arc::new(Florestad::from_config(config));
    let node_for_task = Arc::clone(&node);
    runtime.spawn(async move {
        if let Err(e) = node_for_task.start().await {
            eprintln!("floresta_ffi: node run error: {e:?}");
        }
    });

    let handle = next_handle();
    NODES.lock().unwrap().insert(handle, NodeState { node, runtime });
    handle
}

/// 노드를 종료합니다. 성공 시 null, 실패 시 에러 문자열(`node_free_string`으로 해제).
#[no_mangle]
pub extern "C" fn node_shutdown(handle: NodeHandle) -> *mut c_char {
    let mut nodes = NODES.lock().unwrap();
    match nodes.remove(&handle) {
        Some(state) => {
            state.runtime.block_on(async { state.node.stop().await });
            std::ptr::null_mut()
        }
        None => to_cstring("{\"Err\":\"handle not found\"}".to_string()),
    }
}

/// 노드가 실행 중이면 1, 아니면 0.
#[no_mangle]
pub extern "C" fn node_is_running(handle: NodeHandle) -> i32 {
    let nodes = NODES.lock().unwrap();
    i32::from(nodes.contains_key(&handle))
}

/// FFI가 반환한 문자열을 해제합니다.
#[no_mangle]
pub extern "C" fn node_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}
