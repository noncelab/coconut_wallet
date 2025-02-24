import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/converter/transaction.dart';
import 'package:coconut_wallet/repository/realm/wallet_data_manager.dart';
import 'package:coconut_wallet/services/isolate_manager.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/model/stream/base_stream_state.dart';
import 'package:coconut_wallet/services/model/stream/stream_state.dart';
import 'package:coconut_wallet/services/network/node_client.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';

class NodeProvider extends ChangeNotifier {
  final IsolateManager _isolateManager;
  final WalletDataManager _walletDataManager;
  final String _host;
  final int _port;
  final bool _ssl;
  Completer<void>? _initCompleter;
  Completer<void>? _syncCompleter;

  bool get isInitialized => _initCompleter?.isCompleted ?? false;
  bool get isSyncing => _syncCompleter != null;
  String get host => _host;
  int get port => _port;
  bool get ssl => _ssl;

  NodeProvider(
    this._host,
    this._port,
    this._ssl,
    this._walletDataManager, {
    IsolateManager? isolateManager,
    NodeClientFactory? nodeClientFactory,
  }) : _isolateManager = isolateManager ?? IsolateManager() {
    _initCompleter = Completer<void>();
    _initialize(nodeClientFactory);
  }

  Future<void> _initialize(NodeClientFactory? nodeClientFactory) async {
    try {
      final factory = nodeClientFactory ?? ElectrumNodeClientFactory();
      await _isolateManager.initialize(factory, _host, _port, _ssl);
      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
    }
  }

  Future<Result<T>> _wrapResult<T>(Future<T> future) async {
    if (!isInitialized) {
      try {
        await _initCompleter?.future;
      } catch (e) {
        return Result.failure(e is AppError ? e : ErrorCodes.nodeIsolateError);
      }
    }

    try {
      return Result.success(await future);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  Future<Result<String>> broadcast(Transaction signedTx) async {
    final result =
        await _wrapResult(_isolateManager.broadcast(signedTx.serialize()));

    if (result.isFailure) {
      return result;
    }

    _walletDataManager
        .recordTemporaryBroadcastTime(signedTx.transactionHash, DateTime.now())
        .catchError((_) {
      Logger.error(_);
    });

    return result;
  }

  Future<Result<int>> getNetworkMinimumFeeRate() async {
    return _wrapResult(_isolateManager.getNetworkMinimumFeeRate());
  }

  Future<Result<BlockTimestamp>> getLatestBlock() async {
    return _wrapResult(_isolateManager.getLatestBlock());
  }

  Future<Result<String>> getTransaction(String txHash) async {
    return _wrapResult(_isolateManager.getTransaction(txHash));
  }

  Future<Result<List<Transaction>>> getPreviousTransactions(
      Transaction transaction, List<Transaction> existingTxList) async {
    return _wrapResult(
        _isolateManager.getPreviousTransactions(transaction, existingTxList));
  }

  Future<Result<RecommendedFee>> getRecommendedFees() async {
    return _wrapResult(_isolateManager.getRecommendedFees());
  }

  Future<
      Result<
          (
            List<AddressBalance> receiveBalanceList,
            List<AddressBalance> changeBalanceList,
            Balance total
          )>> getBalance(WalletListItemBase walletItem) async {
    final result = await _wrapResult(_isolateManager.getBalance(
        walletItem.walletBase,
        receiveUsedIndex: walletItem.receiveUsedIndex,
        changeUsedIndex: walletItem.changeUsedIndex));

    if (result.isSuccess) {
      _walletDataManager.updateWalletBalance(walletItem.id, result.value.$3);
      notifyListeners();
    }

    return result;
  }

  Stream<BaseStreamState<BlockTimestamp>> fetchBlocksByHeight(
      Set<int> heights) {
    return _isolateManager.fetchBlocksByHeight(heights);
  }

  Stream<BaseStreamState<FetchTransactionResponse>> fetchTransactions(
      WalletListItemBase walletItemBase,
      {Set<String>? knownTransactionHashes}) {
    return _isolateManager.fetchTransactions(
      walletItemBase.walletBase,
      knownTransactionHashes: knownTransactionHashes,
      receiveUsedIndex: walletItemBase.receiveUsedIndex,
      changeUsedIndex: walletItemBase.changeUsedIndex,
    );
  }

  Stream<BaseStreamState<Transaction>> fetchTransactionDetails(
      Set<String> transactionHashes) {
    return _isolateManager.fetchTransactionDetails(transactionHashes);
  }

  void stopFetching() {
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      _syncCompleter?.completeError(ErrorCodes.nodeConnectionError);
    }
    dispose();
  }

  List<TransactionRecord> getUnconfirmedTransactions(int walletId) {
    return _walletDataManager
        .getUnconfirmedTransactions(walletId)
        .map((realmTx) => mapRealmTransactionToTransaction(realmTx))
        .toList();
  }

  Future<void> updateTransactionStates(
      int walletId,
      List<String> txsToUpdate,
      List<String> txsToDelete,
      Map<String, FetchTransactionResponse> fetchedTxMap,
      Map<int, BlockTimestamp> blockTimestampMap) async {
    await _walletDataManager.updateTransactionStates(
        walletId, txsToUpdate, txsToDelete, fetchedTxMap, blockTimestampMap);
  }

  /// 새로운 트랜잭션을 조회합니다.
  Future<List<FetchTransactionResponse>> scanNewTransactionResponses(
      WalletListItemBase walletItemBase, WalletProvider walletProvider) async {
    Set<String> knownTransactionHashes = _walletDataManager
        .getTransactions(walletItemBase.id)
        .where((tx) {
          if (tx.blockHeight == null) {
            return false;
          }
          return tx.blockHeight! > 0;
        })
        .map((tx) => tx.transactionHash)
        .toSet();

    final List<FetchTransactionResponse> transactions = [];
    // 최대 주소 인덱스 업데이트
    int receiveUsedIndex = -1;
    int changeUsedIndex = -1;

    await for (final state in fetchTransactions(walletItemBase,
        knownTransactionHashes: knownTransactionHashes)) {
      if (state is SuccessState<FetchTransactionResponse>) {
        // 주소 인덱스가 -1인 경우는 스캔 완료를 의미
        if (state.data.addressIndex > -1) {
          transactions.add(state.data);
        }

        if (state.data.isChange) {
          changeUsedIndex = max(changeUsedIndex, state.data.addressIndex);
        } else {
          receiveUsedIndex = max(receiveUsedIndex, state.data.addressIndex);
        }
      }
    }

    if (walletItemBase.receiveUsedIndex < receiveUsedIndex) {
      walletItemBase.receiveUsedIndex = receiveUsedIndex;
      walletProvider.generateWalletAddress(
          walletItemBase, receiveUsedIndex, false);
    }
    if (walletItemBase.changeUsedIndex < changeUsedIndex) {
      walletItemBase.changeUsedIndex = changeUsedIndex;
      walletProvider.generateWalletAddress(
          walletItemBase, changeUsedIndex, true);
    }

    return transactions;
  }

  /// 기존 fetchTransactions 함수를 두 개의 함수로 분리하여 호출하는 방식으로 변경
  Future<void> saveFetchTransactions(
      WalletListItemBase walletItemBase,
      List<FetchTransactionResponse> fetchTxResList,
      WalletProvider walletProvider) async {
    if (fetchTxResList.isEmpty) {
      return;
    }

    // 1. 미확인 트랜잭션 상태 업데이트
    await _updateUnconfirmedTransactions(
      walletItemBase.id,
      fetchTxResList,
    );

    // 2. 트랜잭션의 블록 타임스탬프 조회
    final txBlockHeightMap = _createTxBlockHeightMap(fetchTxResList);
    final blockTimestampMap =
        await _fetchBlockTimestamps(txBlockHeightMap.values.toSet());

    // 3. 트랜잭션 상세 조회 및 처리
    final fetchedTransactions = await _fetchTransactionDetails(fetchTxResList);

    // 4. 트랜잭션 레코드 생성 및 저장
    final newTransactionRecords = await _createTransactionRecords(
      walletItemBase,
      fetchedTransactions,
      txBlockHeightMap,
      blockTimestampMap,
      walletProvider,
    );

    // DB에 저장
    _walletDataManager.addAllTransactions(
        walletItemBase.id, newTransactionRecords);
    notifyListeners();
  }

  /// 미확인 트랜잭션의 상태를 업데이트합니다.
  Future<void> _updateUnconfirmedTransactions(
    int walletId,
    List<FetchTransactionResponse> fetchedTxs,
  ) async {
    // 1. DB에서 미확인 트랜잭션 조회
    final unconfirmedTxs = getUnconfirmedTransactions(walletId);
    if (unconfirmedTxs.isEmpty) {
      return;
    }

    // 2. 새로 조회한 트랜잭션과 비교
    final fetchedTxMap = {for (var tx in fetchedTxs) tx.transactionHash: tx};

    final List<String> txsToUpdate = [];
    final List<String> txsToDelete = [];

    for (final unconfirmedTx in unconfirmedTxs) {
      final fetchedTx = fetchedTxMap[unconfirmedTx.transactionHash];

      if (fetchedTx == null) {
        // INFO: RBF(Replace-By-Fee)에 의해서 처리되지 않은 트랜잭션이 삭제된 경우를 대비
        // INFO: 추후에는 삭제가 아니라 '무효화됨'으로 표기될 수 있음
        txsToDelete.add(unconfirmedTx.transactionHash);
      } else if (fetchedTx.height > 0) {
        // 블록에 포함된 경우 (confirmed)
        txsToUpdate.add(unconfirmedTx.transactionHash);
      }
    }

    if (txsToUpdate.isEmpty && txsToDelete.isEmpty) {
      return;
    }

    // 3. 블록 타임스탬프 조회 (업데이트할 트랜잭션이 있는 경우)
    Map<int, BlockTimestamp> blockTimestampMap = txsToUpdate.isEmpty
        ? {}
        : await _fetchBlockTimestamps(
            fetchedTxs
                .where((tx) => txsToUpdate.contains(tx.transactionHash))
                .map((tx) => tx.height)
                .toSet(),
          );

    // 4. 트랜잭션 상태 업데이트
    await updateTransactionStates(
      walletId,
      txsToUpdate,
      txsToDelete,
      fetchedTxMap,
      blockTimestampMap,
    );
  }

  /// 트랜잭션 해시와 블록 높이를 매핑하는 맵을 생성합니다.
  Map<String, int> _createTxBlockHeightMap(
      List<FetchTransactionResponse> fetchTxResList) {
    return HashMap.fromEntries(fetchTxResList
        .where((tx) => tx.height > 0)
        .map((tx) => MapEntry(tx.transactionHash, tx.height)));
  }

  /// 블록 타임스탬프를 조회합니다.
  Future<Map<int, BlockTimestamp>> _fetchBlockTimestamps(
    Set<int> blockHeights,
  ) async {
    return await fetchBlocksByHeight(blockHeights)
        .where((state) => state is SuccessState<BlockTimestamp>)
        .cast<SuccessState<BlockTimestamp>>()
        .map((state) => state.data)
        .fold<Map<int, BlockTimestamp>>({}, (map, blockTimestamp) {
      map[blockTimestamp.height] = blockTimestamp;
      return map;
    });
  }

  /// 트랜잭션 상세 정보를 조회합니다.
  Future<List<Transaction>> _fetchTransactionDetails(
    List<FetchTransactionResponse> fetchTxResList,
  ) async {
    final fetchedTxHashes =
        fetchTxResList.map((tx) => tx.transactionHash).toSet();

    return await fetchTransactionDetails(fetchedTxHashes)
        .where((state) => state is SuccessState<Transaction>)
        .cast<SuccessState<Transaction>>()
        .map((state) => state.data)
        .toList();
  }

  /// 트랜잭션 레코드를 생성합니다.
  Future<List<TransactionRecord>> _createTransactionRecords(
    WalletListItemBase walletItemBase,
    List<Transaction> fetchedTransactions,
    Map<String, int> txBlockHeightMap,
    Map<int, BlockTimestamp> blockTimestampMap,
    WalletProvider walletProvider,
  ) async {
    return Future.wait(fetchedTransactions.map((tx) async {
      final previousTxsResult = await getPreviousTransactions(tx, []);

      if (previousTxsResult.isFailure) {
        throw ErrorCodes.fetchTransactionsError;
      }

      final txDetails = await _processTransactionDetails(
          tx, previousTxsResult.value, walletItemBase, walletProvider);

      return TransactionRecord.fromTransactions(
        transactionHash: tx.transactionHash,
        timestamp:
            blockTimestampMap[txBlockHeightMap[tx.transactionHash]!]!.timestamp,
        blockHeight: txBlockHeightMap[tx.transactionHash]!,
        inputAddressList: txDetails.inputAddressList,
        outputAddressList: txDetails.outputAddressList,
        transactionType: txDetails.txType.name,
        amount: txDetails.amount,
        fee: txDetails.fee,
      );
    }));
  }

  /// 트랜잭션의 입출력 상세 정보를 처리합니다.
  Future<_TransactionDetails> _processTransactionDetails(
    Transaction tx,
    List<Transaction> previousTxs,
    WalletListItemBase walletItemBase,
    WalletProvider walletProvider,
  ) async {
    List<TransactionAddress> inputAddressList = [];
    int selfInputCount = 0;
    int selfOutputCount = 0;
    int fee = 0;
    int amount = 0;

    // 입력 처리
    for (int i = 0; i < tx.inputs.length; i++) {
      final input = tx.inputs[i];
      final previousOutput = previousTxs[i].outputs[input.index];
      final inputAddress = TransactionAddress(
          previousOutput.scriptPubKey.getAddress(), previousOutput.amount);
      inputAddressList.add(inputAddress);

      fee += inputAddress.amount;

      if (walletProvider.containsAddress(
          walletItemBase.id, inputAddress.address)) {
        selfInputCount++;
        amount -= inputAddress.amount;
      }
    }

    // 출력 처리
    List<TransactionAddress> outputAddressList = [];
    for (int i = 0; i < tx.outputs.length; i++) {
      final output = tx.outputs[i];
      final outputAddress =
          TransactionAddress(output.scriptPubKey.getAddress(), output.amount);
      outputAddressList.add(outputAddress);

      fee -= outputAddress.amount;

      if (walletProvider.containsAddress(
          walletItemBase.id, outputAddress.address)) {
        selfOutputCount++;
        amount += outputAddress.amount;
      }
    }

    // 트랜잭션 유형 결정
    TransactionTypeEnum txType;
    if (selfInputCount > 0 &&
        selfOutputCount == tx.outputs.length &&
        selfInputCount == tx.inputs.length) {
      txType = TransactionTypeEnum.self;
    } else if (selfInputCount > 0 && selfOutputCount < tx.outputs.length) {
      txType = TransactionTypeEnum.sent;
    } else {
      txType = TransactionTypeEnum.received;
    }

    return _TransactionDetails(
      inputAddressList: inputAddressList,
      outputAddressList: outputAddressList,
      txType: txType,
      amount: amount,
      fee: fee,
    );
  }

  Future<List<UtxoState>> fetchUtxos(WalletListItemBase walletItem) async {
    final receiveUsedIndex = walletItem.receiveUsedIndex;
    final changeUsedIndex = walletItem.changeUsedIndex;

    final utxos = await _isolateManager
        .fetchUtxos(walletItem.walletBase,
            receiveUsedIndex: receiveUsedIndex,
            changeUsedIndex: changeUsedIndex)
        .map((state) => state.data)
        .where((utxo) => utxo != null)
        .map((utxo) => utxo!)
        .toList();

    final blockTimestampMap = await _fetchBlockTimestamps(
        utxos.map((utxo) => utxo.blockHeight).toSet());

    UtxoState.updateTimestampFromBlocks(utxos, blockTimestampMap);

    return utxos;
  }

  @override
  void dispose() {
    super.dispose();
    _syncCompleter = null;
    _isolateManager.dispose();
  }
}

/// 트랜잭션 상세 정보를 담는 클래스
class _TransactionDetails {
  final List<TransactionAddress> inputAddressList;
  final List<TransactionAddress> outputAddressList;
  final TransactionTypeEnum txType;
  final int amount;
  final int fee;

  _TransactionDetails({
    required this.inputAddressList,
    required this.outputAddressList,
    required this.txType,
    required this.amount,
    required this.fee,
  });
}
