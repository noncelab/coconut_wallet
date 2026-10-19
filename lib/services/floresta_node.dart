import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _NodeStartNative = Int64 Function(Pointer<Utf8> configJson);
typedef _NodeStartDart = int Function(Pointer<Utf8> configJson);

typedef _NodeShutdownNative = Pointer<Utf8> Function(Int64 handle);
typedef _NodeShutdownDart = Pointer<Utf8> Function(int handle);

typedef _NodeIsRunningNative = Int32 Function(Int64 handle);
typedef _NodeIsRunningDart = int Function(int handle);

typedef _NodeFreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef _NodeFreeStringDart = void Function(Pointer<Utf8> ptr);

/// `native/floresta_ffi`(Rust)로 임베드한 Floresta 노드를 제어하는 FFI 래퍼.
///
/// 노드가 뜨면 Electrum 서버와 JSON-RPC 서버가 함께 열리므로,
/// 체인 질의는 [ElectrumChainSource]가 로컬 포트로, 디스크립터 등록/동기화 진행도는
/// [FlorestaRpcClient]가 JSON-RPC로 처리한다. 이 클래스는 생명주기(start/shutdown)만 노출한다.
class FlorestaNode {
  static FlorestaNode? _instance;
  late final DynamicLibrary _lib;
  late final _NodeStartDart _nodeStart;
  late final _NodeShutdownDart _nodeShutdown;
  late final _NodeIsRunningDart _nodeIsRunning;
  late final _NodeFreeStringDart _nodeFreeString;

  FlorestaNode._() {
    _lib = _loadLibrary();
    _nodeStart = _lib.lookupFunction<_NodeStartNative, _NodeStartDart>('node_start');
    _nodeShutdown = _lib.lookupFunction<_NodeShutdownNative, _NodeShutdownDart>('node_shutdown');
    _nodeIsRunning = _lib.lookupFunction<_NodeIsRunningNative, _NodeIsRunningDart>('node_is_running');
    _nodeFreeString = _lib.lookupFunction<_NodeFreeStringNative, _NodeFreeStringDart>('node_free_string');
  }

  static FlorestaNode get instance {
    _instance ??= FlorestaNode._();
    return _instance!;
  }

  static DynamicLibrary _loadLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libfloresta_ffi.so');
    } else if (Platform.isIOS) {
      return DynamicLibrary.process();
    } else if (Platform.isMacOS) {
      return DynamicLibrary.open('libfloresta_ffi.dylib');
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libfloresta_ffi.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('floresta_ffi.dll');
    }
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// 노드를 기동하고 핸들(> 0)을 반환합니다.
  ///
  /// [dataDir]는 앱 샌드박스의 영속 디렉터리여야 합니다.
  /// [electrumAddress]/[jsonRpcAddress]를 지정하지 않으면 Floresta 기본 포트를 사용합니다.
  int start({
    required String network,
    required String dataDir,
    String? electrumAddress,
    String? jsonRpcAddress,
    String? proxy,
    bool assumeUtreexo = true,
    bool backfill = false,
    int? filtersStartHeight,
    List<String>? fixedPeers,
    String userAgent = 'coconut_wallet/1.0',
    bool logToStdout = false,
  }) {
    final configJson = jsonEncode({
      'network': network,
      'datadir': dataDir,
      if (electrumAddress != null) 'electrum_address': electrumAddress,
      if (jsonRpcAddress != null) 'json_rpc_address': jsonRpcAddress,
      if (proxy != null) 'proxy': proxy,
      'assume_utreexo': assumeUtreexo,
      'backfill': backfill,
      if (filtersStartHeight != null) 'filters_start_height': filtersStartHeight,
      if (fixedPeers != null) 'fixed_peers': fixedPeers,
      'user_agent': userAgent,
      'log_to_stdout': logToStdout,
    });

    final ptr = configJson.toNativeUtf8();
    try {
      final handle = _nodeStart(ptr);
      if (handle <= 0) {
        throw FlorestaNodeException('node_start failed (handle=$handle)');
      }
      return handle;
    } finally {
      malloc.free(ptr);
    }
  }

  /// 노드를 종료합니다. 실패 시 [FlorestaNodeException].
  void shutdown(int handle) {
    final errorPtr = _nodeShutdown(handle);
    if (errorPtr != nullptr) {
      final message = errorPtr.toDartString();
      _nodeFreeString(errorPtr);
      throw FlorestaNodeException(message);
    }
  }

  bool isRunning(int handle) => _nodeIsRunning(handle) == 1;
}

class FlorestaNodeException implements Exception {
  final String message;
  FlorestaNodeException(this.message);

  @override
  String toString() => 'FlorestaNodeException: $message';
}
