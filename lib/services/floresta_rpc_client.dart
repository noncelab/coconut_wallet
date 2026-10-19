import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:coconut_wallet/model/node/floresta_peer_info.dart';
import 'package:coconut_wallet/model/node/floresta_network_info.dart';
import 'package:coconut_wallet/model/node/floresta_sync_info.dart';
import 'package:coconut_wallet/services/floresta/floresta_descriptor_codec.dart';
import 'package:coconut_wallet/utils/logger.dart';

class FlorestaRpcClient {
  final String _host;
  final int _port;
  final bool _ssl;
  late final http.Client _client;

  String get _baseUrl {
    final scheme = _ssl ? 'https' : 'http';
    return '$scheme://$_host:$_port';
  }

  FlorestaRpcClient(this._host, this._port, this._ssl) {
    _client = http.Client();
  }

  Future<Map<String, dynamic>> _call(
    String method,
    List<dynamic> params, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final requestBody = {
      'jsonrpc': '2.0',
      'id': DateTime.now().microsecondsSinceEpoch,
      'method': method,
      'params': params,
    };

    try {
      final response = await _client
          .post(
            Uri.parse(_baseUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data.containsKey('error') && data['error'] != null) {
          throw FlorestaRpcException('$method failed: ${data['error']}');
        }
        return data;
      } else {
        throw FlorestaRpcException('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (e is FlorestaRpcException) rethrow;
      Logger.error('FlorestaRpcClient: $_baseUrl $method failed: $e');
      throw FlorestaRpcException('$method: $e');
    }
  }

  /// 디스크립터를 노드에 등록한다. 이미 노드 월렛에 캐시된 디스크립터는 건너뛴다.
  ///
  /// 반환값: 이번 호출에서 **새로** 등록된 디스크립터가 있으면 true.
  /// (true일 때만 노드 rescan이 필요하다. 이미 인덱싱된 디스크립터를 다시 rescan하면
  ///  florestad가 UTXO를 중복 적재해 잔액이 부풀므로, 호출부에서 rescan을 gate 한다.)
  Future<bool> loadDescriptor(String descriptor) async {
    // SLIP-132 키를 표준 xpub/tpub로 정규화하고, multipath `<0;1>`은
    // Florestad가 인덱싱하지 못하므로 단일 경로로 분해한다.
    final descriptors = FlorestaDescriptorCodec.encode(descriptor);
    Logger.log('FlorestaRpcClient: calling loaddescriptor on $_baseUrl (${descriptors.length} descriptor(s))');
    var registeredNew = false;
    for (final d in descriptors) {
      Logger.log('FlorestaRpcClient: descriptor length=${d.length}');
      try {
        await _call('loaddescriptor', [d]);
        registeredNew = true;
      } on FlorestaRpcException catch (e) {
        // 노드가 같은 디스크립터를 이미 캐시한 경우(노드 재시작 시)는 성공으로 간주한다.
        if (e.message.contains('already cached')) {
          Logger.log('FlorestaRpcClient: descriptor already cached, skipping');
          continue;
        }
        rethrow;
      }
    }
    Logger.log('FlorestaRpcClient: loaddescriptor done (new=$registeredNew)');
    return registeredNew;
  }

  Future<List<Map<String, dynamic>>> listDescriptors() async {
    final result = await _call('listdescriptors', []);
    final descriptors = result['result'] as List<dynamic>? ?? [];
    return descriptors.cast<Map<String, dynamic>>();
  }

  Future<void> rescan({int? startHeight}) async {
    final params = <dynamic>[];
    if (startHeight != null) {
      params.add(startHeight);
    }
    // florestad RPC 메서드명은 'rescan'이 아니라 'rescanblockchain'이다.
    await _call('rescanblockchain', params);
    Logger.log('FlorestaRpcClient: rescanblockchain triggered');
  }

  Future<bool> checkConnection({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      await _call('listdescriptors', [], timeout: timeout);
      Logger.log('FlorestaRpcClient: RPC connection ok on $_baseUrl');
      return true;
    } catch (e) {
      Logger.error('FlorestaRpcClient: RPC connection failed on $_baseUrl: $e');
      return false;
    }
  }

  /// 노드의 체인 동기화 상태를 조회합니다 (헤더/블록 높이, 진행도, IBD).
  Future<FlorestaSyncInfo> getBlockchainInfo({Duration timeout = const Duration(seconds: 5)}) async {
    final response = await _call('getblockchaininfo', [], timeout: timeout);
    final result = response['result'] as Map<String, dynamic>? ?? const {};
    return FlorestaSyncInfo.fromRpc(result);
  }

  /// most-work 블록 해시.
  Future<String> getBestBlockHash({Duration timeout = const Duration(seconds: 5)}) async {
    final response = await _call('getbestblockhash', [], timeout: timeout);
    return response['result'] as String? ?? '';
  }

  /// 높이에 해당하는 블록 해시.
  Future<String> getBlockHash(int height, {Duration timeout = const Duration(seconds: 5)}) async {
    final response = await _call('getblockhash', [height], timeout: timeout);
    return response['result'] as String? ?? '';
  }

  /// 블록 헤더(verbose). raw hex가 필요하면 [verbose]를 false로 둔다.
  Future<Map<String, dynamic>> getBlockHeader(
    String hash, {
    bool verbose = true,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final response = await _call('getblockheader', [hash, verbose], timeout: timeout);
    final result = response['result'];
    if (result is Map<String, dynamic>) return result;
    return {'raw': result};
  }

  /// 현재 난이도.
  Future<double> getDifficulty({Duration timeout = const Duration(seconds: 5)}) async {
    final response = await _call('getdifficulty', [], timeout: timeout);
    return (response['result'] as num?)?.toDouble() ?? 0.0;
  }

  /// utreexo accumulator roots. full validation 노드임을 보여주는 핵심 값.
  Future<List<String>> getRoots({Duration timeout = const Duration(seconds: 5)}) async {
    final response = await _call('getroots', [], timeout: timeout);
    return (response['result'] as List?)?.cast<String>() ?? const [];
  }

  /// 연결된 피어 목록.
  Future<List<FlorestaPeerInfo>> getPeerInfo({Duration timeout = const Duration(seconds: 5)}) async {
    final response = await _call('getpeerinfo', [], timeout: timeout);
    final peers = response['result'] as List? ?? const [];
    return peers.whereType<Map<String, dynamic>>().map(FlorestaPeerInfo.fromRpc).toList();
  }

  /// 연결 수.
  Future<int> getConnectionCount({Duration timeout = const Duration(seconds: 5)}) async {
    final response = await _call('getconnectioncount', [], timeout: timeout);
    return (response['result'] as num?)?.toInt() ?? 0;
  }

  /// 네트워크 요약(버전/연결/중계 상태).
  Future<FlorestaNetworkInfo> getNetworkInfo({Duration timeout = const Duration(seconds: 5)}) async {
    final response = await _call('getnetworkinfo', [], timeout: timeout);
    final result = response['result'] as Map<String, dynamic>? ?? const {};
    return FlorestaNetworkInfo.fromRpc(result);
  }

  /// 노드 가동 시간(초).
  Future<int> uptime({Duration timeout = const Duration(seconds: 5)}) async {
    final response = await _call('uptime', [], timeout: timeout);
    return (response['result'] as num?)?.toInt() ?? 0;
  }

  /// 메모리 사용량. [mode]는 null/'stats'/'mallocinfo'.
  Future<Map<String, dynamic>> getMemoryInfo({String? mode, Duration timeout = const Duration(seconds: 5)}) async {
    final response = await _call('getmemoryinfo', [if (mode != null) mode], timeout: timeout);
    return response['result'] as Map<String, dynamic>? ?? const {};
  }

  /// RPC 서버 상태(활성 커맨드, 로그 경로).
  Future<Map<String, dynamic>> getRpcInfo({Duration timeout = const Duration(seconds: 5)}) async {
    final response = await _call('getrpcinfo', [], timeout: timeout);
    return response['result'] as Map<String, dynamic>? ?? const {};
  }

  /// 피어를 추가한다. [command]는 'add'/'remove'/'onetry'.
  Future<void> addNode(String node, String command, {Duration timeout = const Duration(seconds: 5)}) async {
    await _call('addnode', [node, command], timeout: timeout);
  }

  /// 주소(또는 id)로 피어 연결을 끊는다.
  Future<void> disconnectNode(String nodeAddress, {int? nodeId, Duration timeout = const Duration(seconds: 5)}) async {
    await _call('disconnectnode', [nodeAddress, if (nodeId != null) nodeId], timeout: timeout);
  }

  /// 노드를 종료한다. 임베드 세션에서는 [FlorestaNodeSession.stop]과 중복이므로 디버그 전용.
  Future<String> stop({Duration timeout = const Duration(seconds: 5)}) async {
    final response = await _call('stop', [], timeout: timeout);
    return response['result'] as String? ?? '';
  }

  /// 디버그 뷰어용 raw RPC. RPC 에러도 예외 대신 `{'error': ...}`로 돌려준다.
  Future<Map<String, dynamic>> debugRawRpc(String method, List<dynamic> params) async {
    try {
      return await _call(method, params);
    } on FlorestaRpcException catch (e) {
      return {'error': e.message};
    }
  }

  void close() {
    _client.close();
  }
}

class FlorestaRpcException implements Exception {
  final String message;
  FlorestaRpcException(this.message);

  @override
  String toString() => 'FlorestaRpcException: $message';
}
