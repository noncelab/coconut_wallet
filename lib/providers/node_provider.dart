import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
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
  late StreamController<SubscribeScriptStreamDto> _scriptStatusController;

  bool get isInitialized => _initCompleter?.isCompleted ?? false;
  String get host => _host;
  int get port => _port;
  bool get ssl => _ssl;

  Stream<SubscribeScriptStreamDto> get scriptStatusStream =>
      _scriptStatusController.stream;

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
      _scriptStatusController =
          StreamController<SubscribeScriptStreamDto>.broadcast();
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
  Future<void> _handleScriptStatusChanged(SubscribeScriptStreamDto dto) async {
    try {
      final now = DateTime.now();
      Logger.log(
          'HandleScriptStatusChanged: ${dto.walletItem.name} - ${dto.scriptStatus.derivationPath}');

      // 기존 인덱스 저장 (변경 전)
      final oldReceiveUsedIndex = dto.walletItem.receiveUsedIndex;
      final oldChangeUsedIndex = dto.walletItem.changeUsedIndex;

      // 지갑 인덱스 업데이트
      int receiveUsedIndex = dto.scriptStatus.isChange
          ? dto.walletItem.receiveUsedIndex
          : dto.scriptStatus.index;
      int changeUsedIndex = dto.scriptStatus.isChange
          ? dto.scriptStatus.index
          : dto.walletItem.changeUsedIndex;
      _walletDataManager.updateWalletUsedIndex(
          dto.walletItem, receiveUsedIndex, changeUsedIndex);

      // Balance 동기화

      await _fetchScriptBalance(dto.walletItem, dto.scriptStatus);

      // Transaction 동기화, 이벤트를 수신한 시점의 시간을 사용하기 위해 now 파라미터 전달
      await _fetchScriptTransaction(
          dto.walletItem, dto.scriptStatus, dto.walletProvider,
          now: now);

      // UTXO 동기화
      await _fetchScriptUtxo(dto.walletItem, dto.scriptStatus);

      // 새 스크립트 구독 여부 확인 및 처리
      if (_needSubscriptionUpdate(
        dto.walletItem,
        oldReceiveUsedIndex,
        oldChangeUsedIndex,
        dto.walletProvider,
      )) {
        final subResult =
            await subscribeWallet(dto.walletItem, dto.walletProvider);

        if (subResult.isSuccess) {
          Logger.log(
              'Successfully extended script subscription for ${dto.walletItem.name}');
        } else {
          Logger.error(
              'Failed to extend script subscription: ${subResult.error}');
        }
      }

      // 동기화 완료 state 업데이트
      _setState(newConnectionState: MainClientState.waiting);
    } catch (e) {
      Logger.error('Failed to handle script status change: $e');
    }
  }

  /// 필요한 경우 추가 스크립트를 구독합니다.
  bool _needSubscriptionUpdate(
    WalletListItemBase walletItem,
    int oldReceiveUsedIndex,
    int oldChangeUsedIndex,
    WalletProvider walletProvider,
  ) {
    // receive 또는 change 인덱스가 증가한 경우 추가 구독이 필요
    return walletItem.receiveUsedIndex > oldReceiveUsedIndex ||
        walletItem.changeUsedIndex > oldChangeUsedIndex;
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
        Logger.log('SubscribeWallet: ${walletItem.name} - no script statuses');
        return Result.success(true);
      }

      final changedScriptStatuses = subscribeResponse.scriptStatuses
          .where((status) => status.status != null)
          .toList();

      // 지갑 인덱스 업데이트
      _walletDataManager.updateWalletUsedIndex(
          walletItem,
          subscribeResponse.usedReceiveIndex,
          subscribeResponse.usedChangeIndex);

      // 배치 업데이트 처리
      await _handleBatchScriptStatusChanged(
        walletItem: walletItem,
        scriptStatuses: changedScriptStatuses,
        walletProvider: walletProvider,
      );

      // 변경된 상태만 DB에 저장
      _walletDataManager.batchUpdateScriptStatuses(
          changedScriptStatuses, walletItem.id);

      Logger.log(
          'SubscribeWallet: ${walletItem.name} - finished / subscribedScriptMap.length: ${walletItem.subscribedScriptMap.length}');
      return Result.success(true);
    } catch (e) {
      Logger.error('SubscribeWallet: ${walletItem.name} - failed');
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  Future<Result<bool>> unsubscribeWallet(WalletListItemBase walletItem) async {
    return _handleResult(() async {
      await _mainClient.unsubscribeWallet(walletItem);
      walletItem.subscribedScriptMap.clear();
      Logger.log('UnsubscribeWallet: ${walletItem.name} - finished');
      return true;
    }());
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
      ScriptStatus scriptStatus, WalletProvider walletProvider,
      {DateTime? now}) async {
    // Transaction 동기화 시작 state 업데이트
    _addWalletSyncState(walletItem.id, UpdateType.transaction);

    // 새로운 트랜잭션 조회
    final knownTransactionHashes = _walletDataManager
        .getTransactions(walletItem.id)
        .where((tx) => tx.blockHeight != null && tx.blockHeight! > 0)
        .map((tx) => tx.transactionHash)
        .toSet();

    final txFetchResults = await _mainClient.getFetchTransactionResponses(
        scriptStatus, knownTransactionHashes);

    if (txFetchResults.isEmpty) {
      return;
    }

    final txBlockHeightMap = Map<String, int>.fromEntries(txFetchResults
        .where((tx) => tx.height > 0)
        .map((tx) => MapEntry(tx.transactionHash, tx.height)));

    final blockTimestampMap = txBlockHeightMap.isEmpty
        ? <int, BlockTimestamp>{}
        : await _mainClient.getBlocksByHeight(txBlockHeightMap.values.toSet());

    final transactionFuture = await _mainClient
        .fetchTransactions(
            txFetchResults.map((tx) => tx.transactionHash).toSet())
        .toList();

    final txs = transactionFuture
        .whereType<SuccessState<Transaction>>()
        .map((state) => state.data)
        .toList();

    final txRecords = await _createTransactionRecords(
        walletItem, txs, txBlockHeightMap, blockTimestampMap, walletProvider,
        now: now);

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

    final blockTimestampMap = await _mainClient
        .getBlocksByHeight(utxos.map((utxo) => utxo.blockHeight).toSet());

    UtxoState.updateTimestampFromBlocks(utxos, blockTimestampMap);

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
      List<Transaction> previousTxs = const [],
      DateTime? now}) async {
    return Future.wait(txs.map((tx) async {
      return _createTransactionRecord(walletItemBase, tx, txBlockHeightMap,
          blockTimestampMap, walletProvider,
          nodeClient: nodeClient, previousTxs: previousTxs, now: now);
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
      List<Transaction> previousTxs = const [],
      DateTime? now}) async {
    now ??= DateTime.now();

    final previousTxsResult =
        await _getPreviousTransactions(tx, previousTxs, nodeClient: nodeClient);

    if (previousTxsResult.isFailure) {
      throw ErrorCodes.fetchTransactionsError;
    }
    int blockHeight = txBlockHeightMap[tx.transactionHash] ?? 0;
    final txDetails = _processTransactionDetails(
        tx, previousTxsResult.value, walletItemBase, walletProvider);

    return TransactionRecord.fromTransactions(
      transactionHash: tx.transactionHash,
      timestamp: blockTimestampMap[blockHeight]?.timestamp ?? now,
      blockHeight: blockHeight,
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
