import 'dart:async';
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/services/model/response/block_header.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/services/network/socket/socket_manager.dart';
import 'package:coconut_wallet/utils/electrum_utils.dart';

part 'model/request/electrum_request_types.dart';

class ElectrumService {
  // static final ElectrumClient _instance = ElectrumClient._();
  final int _timeout = 30;
  int _idCounter = 0;
  SocketManager _socketManager;
  Timer? _pingTimer;

  int get reqId => _idCounter;

  SocketConnectionStatus get connectionStatus =>
      _socketManager.connectionStatus;

  ElectrumService._() : _socketManager = SocketManager();

  factory ElectrumService({SocketManager? socketManager}) {
    ElectrumService instance = ElectrumService._();
    instance._socketManager = socketManager ?? SocketManager();

    return instance;
  }

  Future<void> connect(String host, int port, {bool ssl = true}) async {
    await _socketManager.connect(host, port, ssl: ssl);

    _pingTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      ping();
    });
  }

  Future<ElectrumResponse<T>> _call<T>(_ElectrumRequest request,
      ElectrumResponse<T> Function(dynamic json, {int? id}) fromJson) async {
    if (connectionStatus != SocketConnectionStatus.connected) {
      throw 'Can not connect to the server. Please connect and try again.';
    }
    final requestId = ++_idCounter;
    Map jsonRpcRequest = {
      'id': requestId,
      'jsonrpc': '2.0',
      'method': request.method,
      'params': request.params
    };
    // Logger.log('[${DateTime.now()}]REQ - $jsonRpcRequest');
    await _socketManager.send(json.encode(jsonRpcRequest));

    final completer = Completer<Map>();
    _socketManager.setCompleter(requestId, completer);

    Map res = await completer.future.timeout(Duration(seconds: _timeout));

    if (res['error'] != null) {
      throw res['error'];
    }
    // Logger.log('[${DateTime.now()}]RES - $res');
    return fromJson(res['result'], id: requestId);
  }

  Future<String> ping() async {
    await _call(_PingReq(),
        (json, {int? id}) => ElectrumResponse(result: null, id: id));

    return 'pong';
  }

  Future<ServerFeaturesRes> serverFeatures() async {
    var response = await _call(
        _FeatureReq(),
        (json, {int? id}) =>
            ElectrumResponse(result: ServerFeaturesRes.fromJson(json), id: id));

    return response.result;
  }

  Future<List<String>> serverVersion() async {
    var response = await _call(
        _VersionReq(),
        (json, {int? id}) =>
            ElectrumResponse(result: List.castFrom<dynamic, String>(json)));

    return response.result;
  }

  Future<String> getBlockHeader(int height) async {
    var response = await _call(_BlockchainBlockHeaderReq(height),
        (json, {int? id}) => ElectrumResponse(result: json));

    return response.result;
  }

  Future<BlockTimestamp> getBlockTimestamp(int height) async {
    final blockHeaderHex = await getBlockHeader(height);
    final blockHeader = BlockHeader.parse(height, blockHeaderHex);
    return BlockTimestamp(
      height,
      DateTime.fromMillisecondsSinceEpoch(blockHeader.timestamp * 1000,
          isUtc: true),
    );
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
    var response = await _call(_BlockchainEstimateFeeReq(targetConfirmation),
        (json, {int? id}) => ElectrumResponse(result: json as num));

    return response.result;
  }

  Future<GetBalanceRes> getBalance(
      AddressType addressType, String address) async {
    var reversedScriptHash =
        ElectrumUtil.addressToReversedScriptHash(addressType, address);
    var response = await _call(
        _BlockchainScripthashGetBalanceReq(reversedScriptHash),
        (json, {int? id}) =>
            ElectrumResponse(result: GetBalanceRes.fromJson(json)));

    return response.result;
  }

  Future<List<GetHistoryRes>> getHistory(
      AddressType addressType, String address) async {
    var reversedScriptHash =
        ElectrumUtil.addressToReversedScriptHash(addressType, address);
    var response = await _call(
        _BlockchainScripthashGetHistoryReq(reversedScriptHash),
        (json, {int? id}) => ElectrumResponse(
            result: (json as List<dynamic>)
                .map((e) => GetHistoryRes.fromJson(e))
                .toList()));

    response.result.sort((prev, curr) => prev.height.compareTo(curr.height));

    return response.result;
  }

  Future<List<ListUnspentRes>> getUnspentList(
      AddressType addressType, String address) async {
    var reversedScriptHash =
        ElectrumUtil.addressToReversedScriptHash(addressType, address);
    var response = await _call(
        _BlockchainScripthashListUnspentReq(reversedScriptHash),
        (json, {int? id}) => ElectrumResponse(
            result: (json as List<dynamic>)
                .map((e) => ListUnspentRes.fromJson(e))
                .toList()));

    response.result.sort((prev, curr) => prev.height.compareTo(curr.height));

    return response.result;
  }

  Future<List<GetMempoolRes>> getMempool(
      AddressType addressType, String address) async {
    var reversedScriptHash =
        ElectrumUtil.addressToReversedScriptHash(addressType, address);
    var response = await _call(
        _BlockchainScripthashGetMempoolReq(reversedScriptHash),
        (json, {int? id}) => ElectrumResponse(
            result: (json as List<dynamic>)
                .map((e) => GetMempoolRes.fromJson(e))
                .toList()));

    return response.result;
  }

  Future<String> broadcast(String rawTransaction) async {
    var response = await _call(_BroadcastReq(rawTransaction),
        (json, {int? id}) => ElectrumResponse(result: json as String));

    return response.result;
  }

  Future<String> getTransaction(String txHash, {bool? verbose}) async {
    var response =
        await _call(_BlockchainTransactionGetReq(txHash, verbose: verbose),
            (json, {int? id}) {
      // verbose 모드일 때 서버는 Map을 반환하고, 그렇지 않을 때는 String을 반환합니다.
      if (json is Map) {
        return ElectrumResponse(result: jsonEncode(json));
      }
      return ElectrumResponse(result: json as String);
    });

    return response.result;
  }

  Future<List<List<num>>> getMempoolFeeHistogram() async {
    var response = await _call(_MempoolGetFeeHistogramReq(), (json, {int? id}) {
      if (json is List && json.isNotEmpty) {
        return ElectrumResponse(
            result: json.map((fee) {
          List<num> list = [];
          for (var e in fee) {
            if (e is num) list.add(e);
          }
          return list;
        }).toList());
      }
      List<List<num>> arr = [];
      return ElectrumResponse(result: arr);
    });
    return response.result;
  }

  Future<BlockHeaderSubscribe> getCurrentBlock() async {
    var response =
        await _call(_BlockchainHeadersSubscribeReq(), (json, {int? id}) {
      return ElectrumResponse(result: BlockHeaderSubscribe.fromJson(json));
    });

    return response.result;
  }

  Future<String?> subscribeScript(AddressType addressType, String address,
      {required Function(String, String?) onUpdate}) async {
    var reversedScriptHash =
        ElectrumUtil.addressToReversedScriptHash(addressType, address);
    var response = await _call(
        _BlockchainScripthashSubscribeReq(reversedScriptHash),
        (json, {int? id}) => ElectrumResponse(result: json));

    _socketManager.setSubscriptionCallback(reversedScriptHash, onUpdate);

    return response.result;
  }

  Future<bool> unsubscribeScript(
      AddressType addressType, String address) async {
    var reversedScriptHash =
        ElectrumUtil.addressToReversedScriptHash(addressType, address);
    var response = await _call(
        _BlockchainScripthashUnsubscribeReq(reversedScriptHash),
        (json, {int? id}) => ElectrumResponse(result: json));

    _socketManager.removeSubscriptionCallback(reversedScriptHash);

    return response.result;
  }

  Future<void> close() async {
    _pingTimer?.cancel();
    await _socketManager.disconnect();
  }
}
