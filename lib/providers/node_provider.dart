import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/script/script_status.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/wallet_data_manager.dart';
import 'package:coconut_wallet/services/isolate_manager.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/model/response/subscribe_wallet_response.dart';
import 'package:coconut_wallet/services/model/stream/stream_state.dart';
import 'package:coconut_wallet/services/network/node_client.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';

/// 갱신된 데이터 종류
enum UpdateType { balance, utxo, transaction }

/// 갱신된 데이터의 상태
enum UpdateTypeState { syncing, completed }

/// 메인 소켓의 상태, 지갑 중 어느 하나라도 동기화 중이면 syncing, 모두 동기화 완료면 waiting로 변경
enum MainClientState { waiting, syncing, disconnected }

/// 갱신된 데이터 정보를 담는 클래스
class WalletUpdateInfo {
  final int walletId;
  UpdateTypeState balance;
  UpdateTypeState utxo;
  UpdateTypeState transaction;

  WalletUpdateInfo(this.walletId,
      {this.balance = UpdateTypeState.completed,
      this.transaction = UpdateTypeState.completed,
      this.utxo = UpdateTypeState.completed});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletUpdateInfo &&
          walletId == other.walletId &&
          balance == other.balance &&
          utxo == other.utxo &&
          transaction == other.transaction;

  @override
  int get hashCode => Object.hash(walletId, balance, utxo, transaction);

  factory WalletUpdateInfo.fromExisting(WalletUpdateInfo existingInfo,
      {UpdateTypeState? balance,
      UpdateTypeState? transaction,
      UpdateTypeState? utxo}) {
    return WalletUpdateInfo(existingInfo.walletId,
        balance: balance ?? existingInfo.balance,
        transaction: transaction ?? existingInfo.transaction,
        utxo: utxo ?? existingInfo.utxo);
  }
}

/// NodeProvider 상태 정보를 담는 클래스
class NodeProviderState {
  final MainClientState connectionState;
  final Map<int, WalletUpdateInfo> updatedWallets;

  const NodeProviderState({
    required this.connectionState,
    required this.updatedWallets,
  });

  NodeProviderState copyWith({
    MainClientState? newConnectionState,
    Map<int, WalletUpdateInfo>? newUpdatedWallets,
  }) {
    return NodeProviderState(
      connectionState: newConnectionState ?? connectionState,
      updatedWallets: newUpdatedWallets ?? updatedWallets,
    );
  }
}

class NodeProvider extends ChangeNotifier {
  final IsolateManager _isolateManager;
  final WalletDataManager _walletDataManager;
  final String _host;
  final int _port;
  final bool _ssl;
  Completer<void>? _initCompleter;
  Completer<void>? _syncCompleter;

  NodeProviderState _state = const NodeProviderState(
    connectionState: MainClientState.waiting,
    updatedWallets: {},
  );

  NodeProviderState get state => _state;

  // 구독, 단건 기능 처리를 위한 소켓
  late NodeClient _mainClient;

  // 구독중인 스크립트 상태 변경을 인지하는 컨트롤러
  late StreamController<
      ({
        WalletListItemBase walletItem,
        ScriptStatus scriptStatus,
        WalletProvider walletProvider,
      })> _scriptStatusController;

  bool get isInitialized => _initCompleter?.isCompleted ?? false;
  String get host => _host;
  int get port => _port;
  bool get ssl => _ssl;

  Stream<
      ({
        WalletListItemBase walletItem,
        ScriptStatus scriptStatus,
        WalletProvider walletProvider,
      })> get scriptStatusStream => _scriptStatusController.stream;

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
      // IsolateManager 초기화
      final factory = nodeClientFactory ?? ElectrumNodeClientFactory();
      await _isolateManager.initialize(factory, _host, _port, _ssl);

      _mainClient = await factory.create(_host, _port, ssl: _ssl);
      _scriptStatusController = StreamController<
          ({
            WalletListItemBase walletItem,
            ScriptStatus scriptStatus,
            WalletProvider walletProvider,
          })>.broadcast();
      _scriptStatusController.stream.listen(_handleScriptStatusChanged);
      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
      rethrow;
    }
  }

  void _setState(
      {MainClientState? newConnectionState,
      Map<int, WalletUpdateInfo>? newUpdatedWallets}) {
    _state = _state.copyWith(
      newConnectionState: newConnectionState,
      newUpdatedWallets: newUpdatedWallets,
    );
    notifyListeners();
  }

  /// 지갑의 업데이트 정보를 추가합니다.
  void _addWalletSyncState(int walletId, UpdateType updateType) {
    final existingInfo = _state.updatedWallets[walletId];

    WalletUpdateInfo walletUpdateInfo;

    if (existingInfo == null) {
      walletUpdateInfo = WalletUpdateInfo(walletId);
    } else {
      walletUpdateInfo = WalletUpdateInfo.fromExisting(existingInfo);
    }

    switch (updateType) {
      case UpdateType.balance:
        walletUpdateInfo.balance = UpdateTypeState.syncing;
        break;
      case UpdateType.transaction:
        walletUpdateInfo.transaction = UpdateTypeState.syncing;
        break;
      case UpdateType.utxo:
        walletUpdateInfo.utxo = UpdateTypeState.syncing;
        break;
    }

    // mainClient 상태 업데이트
    _setState(
      newConnectionState: MainClientState.syncing,
      newUpdatedWallets: {
        ..._state.updatedWallets,
        walletId: walletUpdateInfo,
      },
    );
  }

  void _addWalletCompletedState(int walletId, UpdateType updateType) {
    final existingInfo = _state.updatedWallets[walletId];

    WalletUpdateInfo walletUpdateInfo;

    if (existingInfo == null) {
      walletUpdateInfo = WalletUpdateInfo(walletId);
    } else {
      walletUpdateInfo = WalletUpdateInfo.fromExisting(existingInfo);
    }

    switch (updateType) {
      case UpdateType.balance:
        walletUpdateInfo.balance = UpdateTypeState.completed;
        break;
      case UpdateType.transaction:
        walletUpdateInfo.transaction = UpdateTypeState.completed;
        break;
      case UpdateType.utxo:
        walletUpdateInfo.utxo = UpdateTypeState.completed;
        break;
    }

    _setState(
      newUpdatedWallets: {
        ..._state.updatedWallets,
        walletId: walletUpdateInfo,
      },
    );
  }

  /// 지갑의 특정 업데이트 타입을 제거합니다.
  void removeWalletUpdateType(int walletId, UpdateType updateType) {
    final existingInfo = _state.updatedWallets[walletId];
    if (existingInfo == null) return;

    switch (updateType) {
      case UpdateType.balance:
        existingInfo.balance = UpdateTypeState.completed;
        break;
      case UpdateType.transaction:
        existingInfo.transaction = UpdateTypeState.completed;
        break;
      case UpdateType.utxo:
        existingInfo.utxo = UpdateTypeState.completed;
        break;
    }

    // notifyListeners 호출 없이 상태만 업데이트
    _setState(
      newUpdatedWallets: {
        ..._state.updatedWallets,
        walletId: existingInfo,
      },
    );
  }

  Future<Result<T>> _handleResult<T>(Future<T> future) async {
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

  /// 스크립트 상태 변경 이벤트 처리
  Future<void> _handleScriptStatusChanged(
      ({
        WalletListItemBase walletItem,
        ScriptStatus scriptStatus,
        WalletProvider walletProvider,
      }) params) async {
    try {
      Logger.log(
          'HandleScriptStatusChanged: ${params.walletItem.name} - ${params.scriptStatus.derivationPath}');
      // Balance 동기화
      await _fetchScriptBalance(params.walletItem, params.scriptStatus);

      // Transaction 동기화
      await _fetchScriptTransaction(
          params.walletItem, params.scriptStatus, params.walletProvider);

      // UTXO 동기화
      await _fetchScriptUtxo(params.walletItem, params.scriptStatus);

      // 동기화 완료 state 업데이트
      _setState(newConnectionState: MainClientState.waiting);
    } catch (e) {
      Logger.error('Failed to handle script status change: $e');
    }
  }

  /// 스크립트 구독
  /// [scriptPubKey] 구독할 스크립트 공개키
  /// [walletId] 지갑 ID
  Future<Result<bool>> subscribeWallet(
      WalletListItemBase walletItem, WalletProvider walletProvider) async {
    if (!isInitialized) {
      return Result.failure(ErrorCodes.nodeIsolateError);
    }

    try {
      SubscribeWalletResponse subscribeResponse = await _mainClient
          .subscribeWallet(walletItem, _scriptStatusController, walletProvider);

      if (subscribeResponse.scriptStatuses.isEmpty) {
        return Result.success(true);
      }

      // 구독중인 스크립트 메모리 저장
      walletItem.scriptStatusMap = {
        for (var scriptStatus in subscribeResponse.scriptStatuses)
          scriptStatus.scriptPubKey: scriptStatus,
      };

      // DB에 상태 저장
      final batchUpdateResult = _walletDataManager.batchUpdateScriptStatuses(
          subscribeResponse, walletItem.id);

      if (batchUpdateResult.isSuccess) {
        notifyListeners();

        // 배치 업데이트 처리
        await _handleBatchScriptStatusChanged(
          walletItem: walletItem,
          scriptStatuses: subscribeResponse.scriptStatuses,
          walletProvider: walletProvider,
        );

        Logger.log('SubscribeWallet: ${walletItem.name} - finished');
        return Result.success(true);
      }

      Logger.error('SubscribeWallet: ${walletItem.name} - failed');
      return Result.failure(batchUpdateResult.error);
    } catch (e) {
      Logger.error('SubscribeWallet: ${walletItem.name} - failed');
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  Future<Result<bool>> unsubscribeWallet(WalletListItemBase walletItem) async {
    return _handleResult(_mainClient.unsubscribeWallet(walletItem));
  }

  /// 스크립트 상태 변경 배치 처리
  Future<void> _handleBatchScriptStatusChanged({
    required WalletListItemBase walletItem,
    required List<ScriptStatus> scriptStatuses,
    required WalletProvider walletProvider,
  }) async {
    try {
      // Balance 병렬 처리
      _addWalletSyncState(walletItem.id, UpdateType.balance);
      await Future.wait(
        scriptStatuses.map((status) => _fetchScriptBalance(walletItem, status)),
      );
      _addWalletCompletedState(walletItem.id, UpdateType.balance);

      // Transaction 병렬 처리
      _addWalletSyncState(walletItem.id, UpdateType.transaction);
      final transactionFutures = scriptStatuses.map(
        (status) => _fetchScriptTransaction(walletItem, status, walletProvider),
      );
      await Future.wait(transactionFutures);
      _addWalletCompletedState(walletItem.id, UpdateType.transaction);

      // UTXO 병렬 처리
      _addWalletSyncState(walletItem.id, UpdateType.utxo);
      await Future.wait(
        scriptStatuses.map((status) => _fetchScriptUtxo(walletItem, status)),
      );
      _addWalletCompletedState(walletItem.id, UpdateType.utxo);

      // 동기화 완료 state 업데이트
      _setState(newConnectionState: MainClientState.waiting);
    } catch (e) {
      Logger.error('Failed to handle batch script status change: $e');
      _setState(newConnectionState: MainClientState.waiting);
    }
  }

  Future<void> _fetchScriptBalance(
      WalletListItemBase walletItem, ScriptStatus scriptStatus) async {
    // 동기화 시작 state 업데이트
    _addWalletSyncState(walletItem.id, UpdateType.balance);

    final addressBalance =
        await _mainClient.getAddressBalance(scriptStatus.scriptPubKey);

    _walletDataManager.updateAddressBalance(
        walletId: walletItem.id,
        index: scriptStatus.index,
        isChange: scriptStatus.isChange,
        balance: addressBalance);

    // Balance 업데이트 완료 state 업데이트
    _addWalletCompletedState(walletItem.id, UpdateType.balance);
  }

  Future<void> _fetchScriptTransaction(WalletListItemBase walletItem,
      ScriptStatus scriptStatus, WalletProvider walletProvider) async {
    // Transaction 동기화 시작 state 업데이트
    _addWalletSyncState(walletItem.id, UpdateType.transaction);

    // 새로운 트랜잭션 조회
    final knownTransactionHashes = _walletDataManager
        .getTransactions(walletItem.id)
        .map((tx) => tx.transactionHash)
        .toSet();

    final txFetchResults = await _mainClient.getFetchTransactionResponses(
        scriptStatus, knownTransactionHashes);

    final txBlockHeightMap = Map<String, int>.fromEntries(
        txFetchResults.map((tx) => MapEntry(tx.transactionHash, tx.height)));

    final blockTimestampMap =
        await _mainClient.getBlocksByHeight(txBlockHeightMap.values.toSet());

    final transactionFuture = await _mainClient
        .fetchTransactions(
            txFetchResults.map((tx) => tx.transactionHash).toSet())
        .toList();

    final txs = transactionFuture
        .whereType<SuccessState<Transaction>>()
        .map((state) => state.data)
        .toList();

    final txRecords = await _createTransactionRecords(
        walletItem, txs, txBlockHeightMap, blockTimestampMap, walletProvider);

    _walletDataManager.addAllTransactions(walletItem.id, txRecords);

    // Transaction 업데이트 완료 state 업데이트
    _addWalletCompletedState(walletItem.id, UpdateType.transaction);
  }

  Future<void> _fetchScriptUtxo(
      WalletListItemBase walletItem, ScriptStatus scriptStatus) async {
    // UTXO 동기화 시작 state 업데이트
    _addWalletSyncState(walletItem.id, UpdateType.utxo);

    // UTXO 목록 조회
    final utxos = await _mainClient.getUtxoStateList(scriptStatus);

    _walletDataManager.addAllUtxos(walletItem.id, utxos);

    // UTXO 업데이트 완료 state 업데이트
    _addWalletCompletedState(walletItem.id, UpdateType.utxo);
  }

  /// 트랜잭션 레코드를 생성합니다.
  Future<List<TransactionRecord>> _createTransactionRecords(
      WalletListItemBase walletItemBase,
      List<Transaction> txs,
      Map<String, int> txBlockHeightMap,
      Map<int, BlockTimestamp> blockTimestampMap,
      WalletProvider walletProvider,
      {NodeClient? nodeClient,
      List<Transaction> previousTxs = const []}) async {
    return Future.wait(txs.map((tx) async {
      return _createTransactionRecord(walletItemBase, tx, txBlockHeightMap,
          blockTimestampMap, walletProvider,
          nodeClient: nodeClient, previousTxs: previousTxs);
    }));
  }

  /// 트랜잭션 레코드를 생성합니다.
  Future<TransactionRecord> _createTransactionRecord(
      WalletListItemBase walletItemBase,
      Transaction tx,
      Map<String, int> txBlockHeightMap,
      Map<int, BlockTimestamp> blockTimestampMap,
      WalletProvider walletProvider,
      {NodeClient? nodeClient,
      List<Transaction> previousTxs = const []}) async {
    final previousTxsResult =
        await _getPreviousTransactions(tx, previousTxs, nodeClient: nodeClient);

    if (previousTxsResult.isFailure) {
      throw ErrorCodes.fetchTransactionsError;
    }

    final txDetails = _processTransactionDetails(
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
  }

  /// 트랜잭션의 입출력 상세 정보를 처리합니다.
  _TransactionDetails _processTransactionDetails(
    Transaction tx,
    List<Transaction> previousTxs,
    WalletListItemBase walletItemBase,
    WalletProvider walletProvider,
  ) {
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

  Future<Result<String>> broadcast(Transaction signedTx) async {
    final result =
        await _handleResult(_mainClient.broadcast(signedTx.serialize()));

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
    return _handleResult(_mainClient.getNetworkMinimumFeeRate());
  }

  Future<Result<BlockTimestamp>> getLatestBlock() async {
    return _handleResult(_mainClient.getLatestBlock());
  }

  Future<Result<String>> getTransaction(String txHash) async {
    return _handleResult(_mainClient.getTransaction(txHash));
  }

  Future<Result<List<Transaction>>> _getPreviousTransactions(
      Transaction transaction, List<Transaction> existingTxList,
      {NodeClient? nodeClient}) async {
    nodeClient ??= _mainClient;

    return _handleResult(
        nodeClient.getPreviousTransactions(transaction, existingTxList));
  }

  Future<Result<RecommendedFee>> getRecommendedFees() async {
    return _handleResult(_mainClient.getRecommendedFees());
  }

  void stopFetching() {
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      _syncCompleter?.completeError(ErrorCodes.nodeConnectionError);
    }
    dispose();
  }

  @override
  void dispose() {
    super.dispose();
    _syncCompleter = null;
    _mainClient.dispose();
    _scriptStatusController.close();
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
