import 'dart:async';
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/network_constants.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/mempool_api_service.dart';
import 'package:coconut_wallet/services/model/response/block_header.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/services/model/response/previous_transactions.dart';
import 'package:coconut_wallet/services/network/socket/socket_manager.dart';
import 'package:coconut_wallet/utils/electrum_utils.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';

part 'model/request/electrum_request_types.dart';

/// An Electrum RPC error response was followed by an HTTP 404 from the fallback.
class TransactionNotFound implements Exception {
  final String transactionHash;

  TransactionNotFound(this.transactionHash);

  @override
  String toString() => 'Transaction not found';
}

class ElectrumService {
  // static final ElectrumClient _instance = ElectrumClient._();
  int _idCounter = 0;
  SocketManager _socketManager;
  Timer? _pingTimer;
  MempoolApi Function() _createMempoolApi = MempoolApi.new;

  int get reqId => _idCounter;

  ElectrumService._() : _socketManager = SocketManager();

  factory ElectrumService({SocketManager? socketManager, MempoolApi Function()? mempoolApiFactory}) {
    ElectrumService instance = ElectrumService._();
    instance._socketManager = socketManager ?? SocketManager();
    instance._createMempoolApi = mempoolApiFactory ?? MempoolApi.new;

    return instance;
  }

  /// 연결 시도 후 성공/실패를 bool로 반환
  Future<bool> connect(String host, int port, {bool ssl = true, String? pinnedCertFingerprint}) async {
    // // 이전 타이머 정리
    // _pingTimer?.cancel();

    // 연결 실패/손실 콜백 설정
    _socketManager.onConnectionLost = () {
      Logger.log('ElectrumService: $host:$port Connection lost callback triggered');
      // // 연결 손실 시 타이머 정리
      // _pingTimer?.cancel();
    };

    try {
      final isConnected = await _socketManager.connect(
        host,
        port,
        ssl: ssl,
        pinnedCertFingerprint: pinnedCertFingerprint,
      );

      if (!isConnected || _socketManager.connectionStatus != SocketConnectionStatus.connected) {
        return false;
      }

      /// 1분 이내 요청이 없으면 소켓 연결 중단됨
      /// 소켓 연결 유지를 위해 ping 요청 필요
      if (isConnected) {
        _pingTimer = Timer.periodic(kElectrumPingInterval, (timer) async {
          try {
            await ping();
          } catch (e) {
            // 소켓 자체는 에러/종료 이벤트 없이 응답만 안 올 수 있음
            // ping 실패로 직접 감지해서 연결 끊김으로 확정
            Logger.error('ElectrumService: $host:$port ping 실패, 연결 끊김으로 처리: $e');
            _socketManager.markConnectionLost();
          }
        });
      }

      return isConnected;
    } catch (e) {
      Logger.error('ElectrumService: $host:$port Connection failed: $e');
      return false;
    }
  }

  Future<ElectrumResponse<T>> _call<T>(
    _ElectrumRequest request,
    ElectrumResponse<T> Function(dynamic json, {int? id}) fromJson, {
    Duration? timeout,
    void Function()? onRpcError,
  }) async {
    if (connectionStatus != SocketConnectionStatus.connected) {
      throw 'Can not connect to the server. Please connect and try again.';
    }
    final requestId = ++_idCounter;
    Map jsonRpcRequest = {'id': requestId, 'jsonrpc': '2.0', 'method': request.method, 'params': request.params};
    // Logger.log('[${DateTime.now()}]REQ - $jsonRpcRequest');
    await _socketManager.send(json.encode(jsonRpcRequest));

    final completer = Completer<Map>();
    _socketManager.setCompleter(requestId, completer);

    try {
      Map res = await completer.future.timeout(timeout ?? kElectrumResponseTimeout);

      if (res['error'] != null) {
        onRpcError?.call();
        throw res['error'];
      }
      // Logger.log('[${DateTime.now()}]RES - $res');
      return fromJson(res['result'], id: requestId);
    } finally {
      _socketManager.removeCompleter(requestId);
    }
  }

  Future<String> ping() async {
    await _call(_PingReq(), (json, {int? id}) => ElectrumResponse(result: null, id: id));

    return 'pong';
  }

  Future<ServerFeaturesRes> serverFeatures() async {
    var response = await _call(
      _FeatureReq(),
      (json, {int? id}) => ElectrumResponse(result: ServerFeaturesRes.fromJson(json), id: id),
    );

    return response.result;
  }

  Future<List<String>> serverVersion() async {
    var response = await _call(
      _VersionReq(),
      (json, {int? id}) => ElectrumResponse(result: List.castFrom<dynamic, String>(json)),
    );

    return response.result;
  }

  Future<String> getBlockHeader(int height) async {
    var response = await _call(_BlockchainBlockHeaderReq(height), (json, {int? id}) => ElectrumResponse(result: json));

    return response.result;
  }

  Future<BlockTimestamp> getBlockTimestamp(int height) async {
    final blockHeaderHex = await getBlockHeader(height);
    final blockHeader = BlockHeader.parse(height, blockHeaderHex);
    return BlockTimestamp(height, DateTime.fromMillisecondsSinceEpoch(blockHeader.timestamp * 1000, isUtc: true));
  }

  /// 블록 높이를 통해 블록 타임스탬프를 조회합니다.
  Future<Map<int, BlockTimestamp>> fetchBlocksByHeight(Set<int> heights) async {
    final futures = heights.map((height) async {
      try {
        final blockTimestamp = await getBlockTimestamp(height);
        return MapEntry(height, blockTimestamp);
      } catch (e) {
        return null;
      }
    });

    final results = await Future.wait(futures);
    return Map.fromEntries(results.whereType<MapEntry<int, BlockTimestamp>>());
  }

  Future<num> estimateFee(int targetConfirmation) async {
    var response = await _call(
      _BlockchainEstimateFeeReq(targetConfirmation),
      (json, {int? id}) => ElectrumResponse(result: json as num),
    );

    return response.result;
  }

  Future<GetBalanceRes> getBalance(AddressType addressType, String address) async {
    var reversedScriptHash = ElectrumUtil.addressToReversedScriptHash(addressType, address);
    var response = await _call(
      _BlockchainScripthashGetBalanceReq(reversedScriptHash),
      (json, {int? id}) => ElectrumResponse(result: GetBalanceRes.fromJson(json)),
    );

    return response.result;
  }

  Future<List<GetTxHistoryRes>> getHistory(AddressType addressType, String address) async {
    var reversedScriptHash = ElectrumUtil.addressToReversedScriptHash(addressType, address);
    var response = await _call(
      _BlockchainScripthashGetHistoryReq(reversedScriptHash),
      (json, {int? id}) =>
          ElectrumResponse(result: (json as List<dynamic>).map((e) => GetTxHistoryRes.fromJson(e)).toList()),
    );

    response.result.sort((prev, curr) => prev.height.compareTo(curr.height));

    return response.result;
  }

  Future<List<ListUnspentRes>> getUnspentList(AddressType addressType, String address) async {
    var reversedScriptHash = ElectrumUtil.addressToReversedScriptHash(addressType, address);
    var response = await _call(
      _BlockchainScripthashListUnspentReq(reversedScriptHash),
      (json, {int? id}) =>
          ElectrumResponse(result: (json as List<dynamic>).map((e) => ListUnspentRes.fromJson(e)).toList()),
    );

    response.result.sort((prev, curr) => prev.height.compareTo(curr.height));

    return response.result;
  }

  /// 일렉트럼 프로토콜에 존재하지만 Electrs 구현체에서 지원하지 않는 메서드
  @Deprecated('This method is not supported by Electrs implementation.')
  Future<List<GetMempoolRes>> getMempool(AddressType addressType, String address) async {
    var reversedScriptHash = ElectrumUtil.addressToReversedScriptHash(addressType, address);
    var response = await _call(
      _BlockchainScripthashGetMempoolReq(reversedScriptHash),
      (json, {int? id}) =>
          ElectrumResponse(result: (json as List<dynamic>).map((e) => GetMempoolRes.fromJson(e)).toList()),
    );

    return response.result;
  }

  /// [timeout]: 응답을 기다리는 시간(기본 [kElectrumResponseTimeout]). [onRpcError]: 서버가 오류로 답했을 때 불린다.
  Future<String> broadcast(String rawTransaction, {Duration? timeout, void Function()? onRpcError}) async {
    var response = await _call(
      _BroadcastReq(rawTransaction),
      (json, {int? id}) => ElectrumResponse(result: json as String),
      timeout: timeout,
      onRpcError: onRpcError,
    );

    return response.result;
  }

  /// 브로드캐스트 결과를 모를 때 서버가 이 거래를 갖고 있는지 묻습니다.
  /// true: 갖고 있음, false: 서버가 없다고 답함, null: 답을 받지 못함(시간 초과·연결 끊김·잘못된 응답).
  /// 보낸 직후의 txid를 제3자에게 알리지 않도록 외부 API로 대체하지 않고 같은 Electrum 서버에만 묻습니다.
  Future<bool?> lookUpTransaction(String txHash, {required Duration timeout}) async {
    var serverSaidNo = false;
    try {
      final response = await _call(
        _BlockchainTransactionGetReq(txHash),
        (json, {int? id}) => ElectrumResponse(result: json as String),
        timeout: timeout,
        onRpcError: () => serverSaidNo = true,
      );
      return Transaction.parse(response.result).transactionHash == txHash ? true : null;
    } catch (_) {
      return serverSaidNo ? false : null;
    }
  }

  Future<String> getTransaction(String txHash, {bool? verbose, Duration timeout = const Duration(seconds: 5)}) async {
    var receivedRpcError = false;
    try {
      var response = await _call(
        _BlockchainTransactionGetReq(txHash, verbose: verbose),
        (json, {int? id}) {
          // verbose 모드일 때 서버는 Map을 반환하고, 그렇지 않을 때는 String을 반환합니다.
          if (json is Map) {
            return ElectrumResponse(result: jsonEncode(json));
          }
          return ElectrumResponse(result: json as String);
        },
        timeout: timeout,
        onRpcError: () => receivedRpcError = true,
      );
      return response.result;
    } catch (e) {
      final mempoolApi = _createMempoolApi();
      try {
        return await mempoolApi.fetchTxHex(txHash);
      } on MempoolHttpNotFound {
        if (receivedRpcError) throw TransactionNotFound(txHash);
        // A fallback 404 cannot establish absence after a timeout or transport failure.
        rethrow;
      } finally {
        mempoolApi.close();
      }
    }
  }

  /// 모든 입력의 부모와 출력 인덱스가 검증된 경우에만 반환합니다. 실패는 스크립트 재시도로 전파합니다.
  Future<List<Transaction>> getPreviousTransactions(
    Transaction transaction, {
    List<Transaction>? existingTxList,
  }) async {
    if (transaction.inputs.isEmpty) {
      return [];
    }

    if (TransactionUtil.isCoinbaseTransaction(transaction)) {
      return [];
    }

    final parentsByHash =
        existingTxList is PreviousTransactions
            ? Map<String, Transaction>.of(existingTxList.byHash)
            : {for (final tx in existingTxList?.toSet() ?? <Transaction>{}) tx.transactionHash: tx};
    final requiredHashes = transaction.inputs.map((input) => input.transactionHash).toSet();
    final missingHashes = requiredHashes.where((hash) => !parentsByHash.containsKey(hash)).toList();
    // 부모 응답은 같은 소켓을 나눠 쓰므로 전송량에 여유를 주되 한 번의 대기는 60초로 제한한다.
    final timeoutMs = 5000 + 300 * missingHashes.length;
    final timeout = Duration(milliseconds: timeoutMs > 60000 ? 60000 : timeoutMs);
    final futures = missingHashes.map((hash) async {
      final tx = Transaction.parse(await getTransaction(hash, timeout: timeout));
      final parsedHash = tx.transactionHash;
      if (parsedHash != hash) throw StateError('Server returned a different parent transaction');
      return MapEntry(hash, tx);
    });

    // eagerError=false: 실패해도 이미 시작한 요청을 모두 회수한 뒤 오류를 전달한다.
    parentsByHash.addEntries(await Future.wait(futures));
    for (final input in transaction.inputs) {
      final parent = parentsByHash[input.transactionHash];
      if (parent == null || input.index < 0 || input.index >= parent.outputs.length) {
        throw StateError('Missing previous output');
      }
    }
    parentsByHash.removeWhere((hash, _) => !requiredHashes.contains(hash));
    return PreviousTransactions(parentsByHash);
  }

  Future<List<List<num>>> getMempoolFeeHistogram() async {
    var response = await _call(_MempoolGetFeeHistogramReq(), (json, {int? id}) {
      if (json is List && json.isNotEmpty) {
        return ElectrumResponse(
          result:
              json.map((fee) {
                List<num> list = [];
                for (var e in fee) {
                  if (e is num) list.add(e);
                }
                return list;
              }).toList(),
        );
      }
      List<List<num>> arr = [];
      return ElectrumResponse(result: arr);
    });
    return response.result;
  }

  Future<BlockHeaderSubscribe> getCurrentBlock() async {
    var response = await _call(_BlockchainHeadersSubscribeReq(), (json, {int? id}) {
      return ElectrumResponse(result: BlockHeaderSubscribe.fromJson(json));
    });

    return response.result;
  }

  Future<String?> subscribeScript(
    AddressType addressType,
    String address, {
    required Function(String, String?) onUpdate,
  }) async {
    var reversedScriptHash = ElectrumUtil.addressToReversedScriptHash(addressType, address);
    var response = await _call(
      _BlockchainScripthashSubscribeReq(reversedScriptHash),
      (json, {int? id}) => ElectrumResponse(result: json),
    );

    _socketManager.setSubscriptionCallback(reversedScriptHash, onUpdate);

    return response.result;
  }

  Future<bool> unsubscribeScript(AddressType addressType, String address) async {
    var reversedScriptHash = ElectrumUtil.addressToReversedScriptHash(addressType, address);
    var response = await _call(
      _BlockchainScripthashUnsubscribeReq(reversedScriptHash),
      (json, {int? id}) => ElectrumResponse(result: json),
    );

    _socketManager.removeSubscriptionCallback(reversedScriptHash);

    return response.result;
  }

  Future<String?> subscribeScriptForWallet(
    AddressType addressType,
    String address, {
    required int walletId,
    required Function(String, String?) onUpdate,
  }) async {
    final reversedScriptHash = ElectrumUtil.addressToReversedScriptHash(addressType, address);
    final response = await _call(
      _BlockchainScripthashSubscribeReq(reversedScriptHash),
      (json, {int? id}) => ElectrumResponse(result: json),
    );

    _socketManager.setWalletSubscriptionCallback(reversedScriptHash, walletId, onUpdate);
    return response.result;
  }

  Future<bool> unsubscribeScriptForWallet(AddressType addressType, String address, {required int walletId}) async {
    final reversedScriptHash = ElectrumUtil.addressToReversedScriptHash(addressType, address);
    final hasNoSubscriber = _socketManager.removeWalletSubscriptionCallback(reversedScriptHash, walletId);
    if (!hasNoSubscriber) return true;

    final response = await _call(
      _BlockchainScripthashUnsubscribeReq(reversedScriptHash),
      (json, {int? id}) => ElectrumResponse(result: json),
    );
    return response.result;
  }

  Future<void> close() async {
    _pingTimer?.cancel();
    try {
      await _socketManager.disconnect();
    } catch (e) {
      Logger.error('ElectrumService: close failed: $e');
    }
  }

  /// 소켓 연결 종료 콜백 등록
  void setOnConnectionLostCallback(void Function() callback) {
    _socketManager.onConnectionLost = callback;
  }

  /// connectionStatus getter 추가
  SocketConnectionStatus get connectionStatus => _socketManager.connectionStatus;

  /// 직전 connect() 시도가 신뢰할 수 없는 인증서(HandshakeException) 때문에 실패했는지 여부
  bool get lastConnectionFailedDueToUntrustedCertificate =>
      _socketManager.lastConnectionFailedDueToUntrustedCertificate;
}
