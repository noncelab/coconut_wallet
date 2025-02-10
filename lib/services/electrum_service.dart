import 'package:async/async.dart';
import 'package:coconut_lib/coconut_lib.dart' as lib;
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo.dart';
import 'package:coconut_wallet/services/model/response/block_header.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/network/electrum/electrum_client.dart';
import 'package:coconut_wallet/services/network/node_client.dart';
import 'package:coconut_wallet/services/model/stream/base_stream_state.dart';

/// @nodoc
class ElectrumService extends NodeClient {
  // static final ElectrumApi _instance = ElectrumApi._();

  ElectrumClient _client;

  @override
  int get reqId => _client.reqId;

  ElectrumService._() : _client = ElectrumClient();

  factory ElectrumService(String host, int port,
      {bool ssl = true, ElectrumClient? client}) {
    ElectrumService instance = ElectrumService._();
    if (client != null) {
      instance._client = client;
    }

    if (instance._client.connectionStatus != SocketConnectionStatus.connected) {
      instance._client.connect(host, port, ssl: ssl);
    }

    return instance;
  }

  static Future<ElectrumService> connectSync(String host, int port,
      {bool ssl = true, ElectrumClient? client}) async {
    var instance = ElectrumService._();

    if (client != null) {
      instance._client = client;
    }

    await instance._client.connect(host, port, ssl: ssl);

    return instance;
  }

  @override
  Future<String> broadcast(String rawTransaction) async {
    return _client.broadcast(rawTransaction);
  }

  @override
  Future<int> getNetworkMinimumFeeRate() {
    return _client.getMempoolFeeHistogram().then((feeHistogram) {
      if (feeHistogram.isEmpty) {
        return 1;
      }

      num minimumFeeRate = feeHistogram.first.first;
      feeHistogram.map((feeInfo) => feeInfo.first).forEach((feeRate) {
        if (minimumFeeRate > feeRate) {
          minimumFeeRate = feeRate;
        }
      });

      return minimumFeeRate.ceil();
    });
  }

  @override
  Future<BlockTimestamp> getLatestBlock() async {
    return _client.getCurrentBlock().then((result) {
      var blockHeader = BlockHeader.parse(result.height, result.hex);
      return BlockTimestamp(
          blockHeader.height,
          DateTime.fromMillisecondsSinceEpoch(blockHeader.timestamp * 1000,
              isUtc: true));
    });
  }

  @override
  Future<String> getTransaction(String transactionHash) async {
    return _client.getTransaction(transactionHash);
  }

  @override
  Future<void> dispose() async {
    await _client.close();
  }

  @override
  Stream<BaseStreamState<FetchTransactionResponse>> fetchTransactions(
      lib.WalletBase wallet,
      {Set<String>? knownTransactionHashes,
      int receiveUsedIndex = 0,
      int changeUsedIndex = 0}) async* {
    final receiveStream = _fetchTransactions(wallet,
        isChange: false,
        knownTransactionHashes: knownTransactionHashes,
        initialIndex: receiveUsedIndex);

    final changeStream = _fetchTransactions(wallet,
        isChange: true,
        knownTransactionHashes: knownTransactionHashes,
        initialIndex: changeUsedIndex);

    await for (final state
        in StreamGroup.merge([receiveStream, changeStream])) {
      yield state;
      if (state.hasError) return;
    }
  }

  Stream<BaseStreamState<FetchTransactionResponse>> _fetchTransactions(
      lib.WalletBase wallet,
      {Set<String>? knownTransactionHashes,
      int initialIndex = 0,
      required bool isChange}) async* {
    int addressScanLimit = gapLimit;
    int currentAddressIndex = initialIndex;
    Set<String> processedTxHashes = knownTransactionHashes ?? {};

    while (currentAddressIndex < addressScanLimit) {
      Map<int, String> addressScripts = _prepareAddressScriptsMap(
        wallet,
        currentAddressIndex,
        addressScanLimit,
        isChange,
      );

      Iterable<Stream<BaseStreamState<FetchTransactionResponse>>> streams =
          addressScripts.entries.map((entry) async* {
        final derivationIndex = entry.key;
        final script = entry.value;

        try {
          final historyList = await _client.getHistory(script);
          if (historyList.isEmpty) {
            return;
          }

          addressScanLimit = derivationIndex + gapLimit + 1;

          var filteredHistoryList = historyList.where((history) {
            if (processedTxHashes.contains(history.txHash)) return false;
            processedTxHashes.add(history.txHash);
            return true;
          });

          for (var history in filteredHistoryList) {
            yield BaseStreamState<FetchTransactionResponse>.success(
                'fetchTransactions',
                FetchTransactionResponse(
                  transactionHash: history.txHash,
                  height: history.height,
                  addressIndex: derivationIndex,
                  isChange: isChange,
                ));
          }
        } catch (e, stack) {
          yield BaseStreamState<FetchTransactionResponse>.error(
              'fetchTransactions', e.toString(), stack);
        }
      });

      yield* StreamGroup.merge(streams);

      currentAddressIndex += addressScripts.length;
      if (currentAddressIndex >= addressScanLimit) break;
    }
  }

  @override
  Stream<BaseStreamState<BlockTimestamp>> fetchBlocksByHeight(
      Set<int> heights) async* {
    // 모든 주소의 히스토리를 병렬로 조회
    final streams = heights.map((height) async* {
      try {
        final header = await _client.getBlockHeader(height);
        var blockHeader = BlockHeader.parse(height, header);

        yield BaseStreamState<BlockTimestamp>.success(
          'fetchBlocksByHeight',
          BlockTimestamp(
              height,
              DateTime.fromMillisecondsSinceEpoch(blockHeader.timestamp * 1000,
                  isUtc: true)),
        );
      } catch (e, stack) {
        yield BaseStreamState<BlockTimestamp>.error(
            'fetchBlocksByHeight', e.toString(), stack);
      }
    });

    await for (final state in StreamGroup.merge(streams)) {
      yield state;
      if (state.hasError) return;
    }
  }

  @override
  Future<WalletBalance> getBalance(lib.WalletBase wallet,
      {int receiveUsedIndex = -1, int changeUsedIndex = -1}) async {
    int receiveScanLimit = receiveUsedIndex + 1;
    int changeScanLimit = changeUsedIndex + 1;

    final receiveBalanceFutures = _getBalance(wallet, receiveScanLimit, false);
    final changeBalanceFutures = _getBalance(wallet, changeScanLimit, true);

    final [receive, change] = await Future.wait([
      Future.wait(receiveBalanceFutures),
      Future.wait(changeBalanceFutures)
    ]);

    return WalletBalance(receive, change);
  }

  Iterable<Future<AddressBalance>> _getBalance(
      lib.WalletBase wallet, int scanLimit, bool isChange) {
    if (scanLimit == 0) return [];
    Map<int, String> scripts =
        _prepareAddressScriptsMap(wallet, 0, scanLimit, isChange);

    return scripts.entries.map((entry) async {
      var balanceRes = await _client.getBalance(entry.value);
      return AddressBalance(
          balanceRes.confirmed, balanceRes.unconfirmed, entry.key);
    });
  }

  @override
  Future<List<lib.Transaction>> fetchPreviousTransactions(
      lib.Transaction transaction, List<lib.Transaction> existingTxList) async {
    if (transaction.inputs.isEmpty) {
      return [];
    }

    if (_isCoinbaseTransaction(transaction)) {
      return [];
    }

    Set<String> toFetchTransactionHashes = {};

    final existingTxHashes =
        existingTxList.map((tx) => tx.transactionHash).toSet();

    toFetchTransactionHashes = transaction.inputs
        .map((input) => input.transactionHash)
        .where((hash) => !existingTxHashes.contains(hash))
        .toSet();

    var futures = toFetchTransactionHashes.map((transactionHash) async {
      var inputTx = await _client.getTransaction(transactionHash);
      return lib.Transaction.parse(inputTx);
    });

    List<lib.Transaction> fetchedTransactions = await Future.wait(futures);

    fetchedTransactions.addAll(existingTxList);

    List<lib.Transaction> previousTransactions = [];

    for (var input in transaction.inputs) {
      previousTransactions.add(fetchedTransactions
          .firstWhere((tx) => tx.transactionHash == input.transactionHash));
    }

    return previousTransactions;
  }

  bool _isCoinbaseTransaction(lib.Transaction tx) {
    if (tx.inputs.length != 1) {
      return false;
    }

    if (tx.inputs[0].transactionHash !=
        '0000000000000000000000000000000000000000000000000000000000000000') {
      return false;
    }

    return tx.inputs[0].index == 4294967295; // 0xffffffff
  }

  @override
  Stream<BaseStreamState<lib.Transaction>> fetchTransactionDetails(
      Set<String> transactionHashes) async* {
    Iterable<Stream<BaseStreamState<lib.Transaction>>> streams =
        transactionHashes.map((transactionHash) async* {
      try {
        var transaction = await _client.getTransaction(transactionHash);
        yield BaseStreamState<lib.Transaction>.success(
            'fetchTransactionDetails', lib.Transaction.parse(transaction));
      } catch (e, stack) {
        yield BaseStreamState<lib.Transaction>.error(
            'fetchTransactionDetails', e.toString(), stack);
      }
    });

    await for (final state in StreamGroup.merge(streams)) {
      yield state;
      if (state.hasError) return;
    }
  }

  @override
  Stream<BaseStreamState<UTXO>> fetchUtxos(lib.WalletBase wallet,
      {int receiveUsedIndex = -1, int changeUsedIndex = -1}) async* {
    final receiveStream = _fetchUtxos(wallet, receiveUsedIndex + 1, false);
    final changeStream = _fetchUtxos(wallet, changeUsedIndex + 1, true);

    await for (final state
        in StreamGroup.merge([receiveStream, changeStream])) {
      yield state;
      if (state.hasError) return;
    }
  }

  Stream<BaseStreamState<UTXO>> _fetchUtxos(
      lib.WalletBase wallet, int scanLimit, bool isChange) async* {
    if (scanLimit == 0) return;
    Map<int, String> scripts =
        _prepareAddressScriptsMap(wallet, 0, scanLimit, isChange);

    Iterable<Stream<BaseStreamState<UTXO>>> streams =
        scripts.entries.map((entry) async* {
      try {
        var utxos = await _client.getUnspentList(entry.value);
        if (utxos.isEmpty) return;
        for (var utxo in utxos) {
          String derivationPath =
              '${wallet.derivationPath}/${isChange ? 1 : 0}/${entry.key}';

          // TODO: Utxo 타임스탬프 추가
          yield BaseStreamState<UTXO>.success(
              'fetchUtxos',
              UTXO(
                  '0',
                  utxo.height.toString(),
                  utxo.value,
                  wallet.getAddress(entry.key, isChange: isChange),
                  derivationPath,
                  utxo.txHash,
                  utxo.txPos));
        }
      } catch (e, stack) {
        yield BaseStreamState<UTXO>.error('fetchUtxos', e.toString(), stack);
      }
    });

    yield* StreamGroup.merge(streams);
  }

  Map<int, String> _prepareAddressScriptsMap(
    lib.WalletBase wallet,
    int startIndex,
    int endIndex,
    bool isChange,
  ) {
    Map<int, String> scripts = {};

    try {
      for (int derivationIndex = startIndex;
          derivationIndex < endIndex;
          derivationIndex++) {
        String address = wallet.getAddress(derivationIndex, isChange: isChange);
        String script = _getScriptForAddress(wallet, address);
        scripts[derivationIndex] = script.substring(2);
      }
      return scripts;
    } catch (e) {
      return {};
    }
  }

  String _getScriptForAddress(lib.WalletBase wallet, String address) {
    if (wallet.addressType == lib.AddressType.p2wpkh) {
      return lib.ScriptPublicKey.p2wpkh(address).serialize();
    } else if (wallet.addressType == lib.AddressType.p2wsh) {
      return lib.ScriptPublicKey.p2wsh(address).serialize();
    }
    throw 'Unsupported address type: ${wallet.addressType.scriptType}';
  }

  /// blockchain.estimatefee가 반환하는 BTC/kB 단위를 sat/vB 단위로 변환합니다.
  int convertFeeToSatPerVByte(double feeBtcPerKb) {
    // 1 BTC = 1e8 sat, 1 kB = 1000 vB → 변환 계수는 1e8/1000 = 100000
    return (feeBtcPerKb * 100000).round();
  }

  /// Electrum의 mempool.get_fee_histogram과 blockchain.estimatefee를 이용하여
  /// mempool.space API와 같은 형태의 추천 수수료 정보를 반환합니다.
  Future<RecommendedFee> getRecommendedFees() async {
    // 1. mempool.get_fee_histogram 호출
    //    결과는 [[fee, vsize], [fee, vsize], ...] 형태이며 fee 단위는 sat/vB.
    final dynamic histogramResult = await _client.getMempoolFeeHistogram();
    List<List<dynamic>> histogram = [];
    if (histogramResult is List) {
      for (var entry in histogramResult) {
        if (entry is List && entry.length >= 2) {
          histogram.add(entry);
        }
      }
    }

    // 2. blockchain.estimatefee를 여러 블록 목표로 호출하여 fee rate (BTC/kB)를 가져옴
    //    여기서는 아래와 같이 확인 목표를 정합니다.
    const int fastestTarget = 1; // 빠른 확인 (예: 1블록 이내)
    const int halfHourTarget = 3; // 30분 내 확인 (3블록)
    const int hourTarget = 6; // 1시간 내 확인 (6블록)
    const int economyTarget = 10; // 경제적 확인 (10블록)

    // 각 목표에 대해 fee 추정값 호출 (BTC/kB 단위)
    final dynamic feeFastRaw = await _client.estimateFee(fastestTarget);
    final dynamic feeHalfHourRaw = await _client.estimateFee(halfHourTarget);
    final dynamic feeHourRaw = await _client.estimateFee(hourTarget);
    final dynamic feeEconomyRaw = await _client.estimateFee(economyTarget);

    // 반환값이 -1이면 충분한 정보가 없다는 뜻이므로 0으로 처리 (추후 대체)
    double feeFast =
        (feeFastRaw is int ? feeFastRaw.toDouble() : feeFastRaw) as double;
    double feeHalfHour = (feeHalfHourRaw is int
        ? feeHalfHourRaw.toDouble()
        : feeHalfHourRaw) as double;
    double feeHour =
        (feeHourRaw is int ? feeHourRaw.toDouble() : feeHourRaw) as double;
    double feeEconomy = (feeEconomyRaw is int
        ? feeEconomyRaw.toDouble()
        : feeEconomyRaw) as double;
    feeFast = feeFast > 0 ? feeFast : 0;
    feeHalfHour = feeHalfHour > 0 ? feeHalfHour : 0;
    feeHour = feeHour > 0 ? feeHour : 0;
    feeEconomy = feeEconomy > 0 ? feeEconomy : 0;

    // 3. BTC/kB 단위를 sat/vB로 변환
    int fastestFee = feeFast > 0 ? convertFeeToSatPerVByte(feeFast) : 0;
    int halfHourFee =
        feeHalfHour > 0 ? convertFeeToSatPerVByte(feeHalfHour) : 0;
    int hourFee = feeHour > 0 ? convertFeeToSatPerVByte(feeHour) : 0;
    int economyFee = feeEconomy > 0 ? convertFeeToSatPerVByte(feeEconomy) : 0;

    // 4. 최소 수수료 (minimumFee)는 mempool 내에서 지불되고 있는 가장 낮은 fee rate (sat/vB)
    int minimumFee = 0;
    if (histogram.isNotEmpty) {
      // 예시 결과에서 histogram은 내림차순 정렬되어 있으므로 마지막 요소의 fee가 최소값임.
      minimumFee = (histogram.last[0] as num).toInt();
    }

    // 5. 만약 estimatefee 결과가 0(즉, -1인 경우)라면 최소 수수료 또는 기본값 1로 대체
    fastestFee =
        fastestFee > 0 ? fastestFee : (minimumFee > 0 ? minimumFee : 1);
    halfHourFee =
        halfHourFee > 0 ? halfHourFee : (minimumFee > 0 ? minimumFee : 1);
    hourFee = hourFee > 0 ? hourFee : (minimumFee > 0 ? minimumFee : 1);
    economyFee =
        economyFee > 0 ? economyFee : (minimumFee > 0 ? minimumFee : 1);
    minimumFee = minimumFee > 0 ? minimumFee : 1;

    return RecommendedFee(
        fastestFee, halfHourFee, hourFee, economyFee, minimumFee);
  }
}
