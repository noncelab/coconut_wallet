import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/model/node/chain_backend_config.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/floresta_network_info.dart';
import 'package:coconut_wallet/model/node/floresta_peer_info.dart';
import 'package:coconut_wallet/model/node/floresta_sync_info.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/services/floresta_rpc_client.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';

/// Floresta 노드 설정/디버그 화면의 상태.
///
/// 임베드 노드의 생명주기(실행/핸들/dataDir)는 [NodeProvider]의 세션에서 읽고,
/// 그 외 상세 조회(피어/체인/roots/raw RPC)는 로컬 RPC 포트에 직접 질의한다.
/// (embedded/external 모두 같은 방식으로 조회 가능해 모드 분기가 필요 없다.)
class FlorestaNodeViewModel extends ChangeNotifier {
  static const _fastPollInterval = Duration(seconds: 10);
  static const _rootsPollInterval = Duration(seconds: 30);

  final NodeProvider _nodeProvider;

  FlorestaRpcClient? _rpc;
  StreamSubscription<FlorestaSyncInfo>? _syncSub;
  Timer? _fastTimer;
  Timer? _rootsTimer;
  bool _disposed = false;
  bool _isBusy = false;

  FlorestaSyncInfo? _syncInfo;
  List<FlorestaPeerInfo> _peers = const [];
  int _connectionCount = 0;
  FlorestaNetworkInfo? _networkInfo;
  String? _bestBlockHash;
  double? _difficulty;
  List<String> _roots = const [];
  int? _uptime;

  String? _lastErrorMethod;
  String? _lastErrorMessage;
  DateTime? _lastErrorAt;
  int? _lastLatencyMs;

  String _rawMethod = 'getblockchaininfo';
  final List<String> rawMethods = const [
    'getblockchaininfo',
    'getbestblockhash',
    'getblockhash',
    'getblockheader',
    'getdifficulty',
    'getroots',
    'getpeerinfo',
    'getconnectioncount',
    'getnetworkinfo',
    'uptime',
    'getmemoryinfo',
    'getrpcinfo',
    'getblockcount',
    'getdeploymentinfo',
  ];
  String _rawParams = '[]';
  String? _rawResponse;
  bool _isRawLoading = false;

  bool get isFlorestaEmbedded => _nodeProvider.backend.isEmbedded;
  bool get isRunning => _nodeProvider.florestaStatus?.session?.isRunning ?? false;
  int? get nodeHandle => _nodeProvider.florestaStatus?.session?.nodeHandle;
  String? get dataDir => _nodeProvider.florestaStatus?.session?.dataDir;
  String get host => _nodeProvider.currentElectrumServer.host;
  int get electrumPort => _nodeProvider.currentElectrumServer.port;
  int get rpcPort => _nodeProvider.backend.rpcPort;

  String get platform => Platform.isAndroid ? 'process (libflorestad.so)' : 'in-process FFI';

  FlorestaSyncInfo? get syncInfo => _syncInfo;
  List<FlorestaPeerInfo> get peers => _peers;
  int get connectionCount => _connectionCount;
  FlorestaNetworkInfo? get networkInfo => _networkInfo;
  String? get bestBlockHash => _bestBlockHash;
  double? get difficulty => _difficulty;
  List<String> get roots => _roots;
  int? get uptime => _uptime;

  bool get isBusy => _isBusy;
  String? get lastErrorMethod => _lastErrorMethod;
  String? get lastErrorMessage => _lastErrorMessage;
  DateTime? get lastErrorAt => _lastErrorAt;
  int? get lastLatencyMs => _lastLatencyMs;

  String get rawMethod => _rawMethod;
  String get rawParams => _rawParams;
  String? get rawResponse => _rawResponse;
  bool get isRawLoading => _isRawLoading;

  FlorestaNodeViewModel(this._nodeProvider) {
    _syncInfo = _nodeProvider.florestaStatus?.syncInfo;
    _syncSub = _nodeProvider.florestaStatus?.syncInfoStream.listen((info) {
      if (_disposed) return;
      _syncInfo = info;
      notifyListeners();
    });
    _rebuildClient();
    unawaited(refresh());
    _fastTimer = Timer.periodic(_fastPollInterval, (_) => unawaited(_fetchFast()));
    _rootsTimer = Timer.periodic(_rootsPollInterval, (_) => unawaited(_fetchRoots()));
  }

  /// 현재 서버 설정에 맞춰 조회용 RPC 클라이언트를 (재)생성한다.
  void _rebuildClient() {
    final server = _nodeProvider.currentElectrumServer;
    final backend = _nodeProvider.backend;
    final port = backend.rpcPort;
    // 임베드 노드는 항상 127.0.0.1에 바인딩된다.
    final rpcHost = backend.isEmbedded ? '127.0.0.1' : server.host;
    // Floresta의 JSON-RPC(axum)는 평문 HTTP만 서빙한다. TLS(ssl)는 Electrum 연결 전용이므로
    // 외부 Floresta 모드에서 server.ssl이 켜져 있어도 RPC는 http로 질의한다.
    _rpc?.close();
    _rpc = port > 0 ? FlorestaRpcClient(rpcHost, port, false) : null;
  }

  Future<T?> _guard<T>(String method, Future<T> Function() call) async {
    final rpc = _rpc;
    if (rpc == null) return null;
    final sw = Stopwatch()..start();
    try {
      final result = await call();
      _lastLatencyMs = sw.elapsedMilliseconds;
      return result;
    } catch (e) {
      _recordError(method, e, sw.elapsedMilliseconds);
      return null;
    }
  }

  /// void를 돌려주는 변경성 RPC용. 성공 여부만 반환한다.
  Future<bool> _guardVoid(String method, Future<void> Function() call) async {
    final rpc = _rpc;
    if (rpc == null) return false;
    final sw = Stopwatch()..start();
    try {
      await call();
      _lastLatencyMs = sw.elapsedMilliseconds;
      return true;
    } catch (e) {
      _recordError(method, e, sw.elapsedMilliseconds);
      return false;
    }
  }

  void _recordError(String method, Object e, int latencyMs) {
    _lastLatencyMs = latencyMs;
    _lastErrorMethod = method;
    _lastErrorMessage = e is FlorestaRpcException ? e.message : e.toString();
    _lastErrorAt = DateTime.now();
    Logger.error('FlorestaNodeViewModel: $method failed: $e');
  }

  Future<void> refresh() async {
    if (_isBusy && !_disposed) return;
    _isBusy = true;
    notifyListeners();
    await Future.wait([_fetchFast(), _fetchRoots()]);
    _syncInfo = _nodeProvider.florestaStatus?.syncInfo;
    _isBusy = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> _fetchFast() async {
    if (_disposed) return;
    final networkInfo = await _guard('getnetworkinfo', () => _rpc!.getNetworkInfo());
    final peers = await _guard('getpeerinfo', () => _rpc!.getPeerInfo());
    final count = await _guard('getconnectioncount', () => _rpc!.getConnectionCount());
    final bestHash = await _guard('getbestblockhash', () => _rpc!.getBestBlockHash());
    final difficulty = await _guard('getdifficulty', () => _rpc!.getDifficulty());
    final uptime = await _guard('uptime', () => _rpc!.uptime());
    if (_disposed) return;
    if (networkInfo != null) _networkInfo = networkInfo;
    if (peers != null) _peers = peers;
    if (count != null) _connectionCount = count;
    if (bestHash != null) _bestBlockHash = bestHash;
    if (difficulty != null) _difficulty = difficulty;
    if (uptime != null) _uptime = uptime;
    notifyListeners();
  }

  Future<void> _fetchRoots() async {
    if (_disposed) return;
    final roots = await _guard('getroots', () => _rpc!.getRoots());
    if (_disposed || roots == null) return;
    _roots = roots;
    notifyListeners();
  }

  Future<bool> addNode(String node) async {
    final ok = await _guardVoid('addnode', () => _rpc!.addNode(node, 'onetry'));
    await _fetchFast();
    return ok;
  }

  Future<bool> disconnectNode(String address, {int? id}) async {
    final ok = await _guardVoid('disconnectnode', () => _rpc!.disconnectNode(address, nodeId: id));
    await _fetchFast();
    return ok;
  }

  Future<bool> rescan({int? startHeight}) async {
    return _guardVoid('rescanblockchain', () => _rpc!.rescan(startHeight: startHeight));
  }

  Future<bool> stopNode() async {
    final result = await _guard('stop', () => _rpc!.stop());
    // RPC stop은 노드만 멈추므로 provider 세션 참조(_session/_runningServer)도 함께 정리한다.
    // 비임베드(external/electrum)에서는 no-op이라 안전하다.
    try {
      await _nodeProvider.lifecycle.stop();
    } catch (e) {
      Logger.error('FlorestaNodeViewModel: lifecycle.stop 실패: $e');
    }
    _rebuildClient();
    if (!_disposed) notifyListeners();
    return result != null;
  }

  Future<bool> switchToEmbedded({int electrumPort = 50001, int rpcPort = 8332}) async {
    _isBusy = true;
    notifyListeners();
    final server = ElectrumServer.custom('127.0.0.1', electrumPort, false);
    final changed = await _nodeProvider.changeServer(
      server,
      backend: ChainBackendConfig.embeddedFloresta(rpcPort: rpcPort),
    );
    final ok = changed.isSuccess && (await _nodeProvider.applyServerChange()).isSuccess;
    _rebuildClient();
    _isBusy = false;
    await refresh();
    return ok;
  }

  Future<bool> switchToExternal({required String host, required int port, required int rpcPort, bool ssl = false}) async {
    _isBusy = true;
    notifyListeners();
    final server = ElectrumServer.custom(host, port, ssl);
    final changed = await _nodeProvider.changeServer(
      server,
      backend: ChainBackendConfig.externalFloresta(rpcPort: rpcPort),
    );
    final ok = changed.isSuccess && (await _nodeProvider.applyServerChange()).isSuccess;
    _rebuildClient();
    _isBusy = false;
    await refresh();
    return ok;
  }

  void setRawMethod(String method) {
    _rawMethod = method;
    notifyListeners();
  }

  void setRawParams(String params) {
    _rawParams = params;
  }

  Future<void> sendRawRpc() async {
    final rpc = _rpc;
    if (rpc == null) return;
    _isRawLoading = true;
    notifyListeners();
    List<dynamic> params;
    try {
      final decoded = jsonDecode(_rawParams);
      params = decoded is List ? decoded : [decoded];
    } catch (e) {
      _rawResponse = 'params JSON 파싱 실패: $e';
      _isRawLoading = false;
      notifyListeners();
      return;
    }
    final response = await rpc.debugRawRpc(_rawMethod, params);
    _rawResponse = const JsonEncoder.withIndent('  ').convert(response);
    _isRawLoading = false;
    notifyListeners();
  }

  /// 클립보드/로그로 넘길 진단 덤프.
  String buildDump() {
    final backend = _nodeProvider.backend;
    final buffer = StringBuffer()
      ..writeln('=== Floresta node dump ===')
      ..writeln('platform: $platform')
      ..writeln('mode: ${backend.isEmbedded ? 'embedded' : 'external'}')
      ..writeln('running: $isRunning')
      ..writeln('handle: $nodeHandle')
      ..writeln('dataDir: $dataDir')
      ..writeln('host: $host')
      ..writeln('electrumPort: $electrumPort')
      ..writeln('rpcPort: $rpcPort')
      ..writeln('uptime(s): $_uptime')
      ..writeln('sync: blocks=${_syncInfo?.blocks} headers=${_syncInfo?.headers} '
          'progress=${_syncInfo?.verificationProgress} ibd=${_syncInfo?.initialBlockDownload} '
          'best=${_syncInfo?.bestBlockHash}')
      ..writeln('bestBlockHash: $_bestBlockHash')
      ..writeln('difficulty: $_difficulty');
    final info = _networkInfo;
    if (info != null) {
      buffer.writeln('network: version=${info.version} subversion=${info.subversion} '
          'connections=${info.connections} in=${info.connectionsIn} out=${info.connectionsOut} '
          'active=${info.networkActive} warnings=${info.warnings}');
    }
    buffer.writeln('peers(${_peers.length}):');
    for (final p in _peers) {
      buffer.writeln('  - id=${p.id} ${p.address} agent=${p.userAgent} inbound=${p.inbound} '
          'height=${p.initialHeight} state=${p.state}');
    }
    buffer.writeln('roots(${_roots.length}): ${_roots.take(4).map(_shortRoot).toList()}');
    if (_lastErrorMessage != null) {
      buffer.writeln('lastError: $_lastErrorMethod $_lastErrorMessage at $_lastErrorAt');
    }
    return buffer.toString();
  }

  static String _shortRoot(String root) => root.length > 16 ? '${root.substring(0, 16)}…' : root;

  @override
  void dispose() {
    _disposed = true;
    _syncSub?.cancel();
    _fastTimer?.cancel();
    _rootsTimer?.cancel();
    _rpc?.close();
    super.dispose();
  }
}
