import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/stream/stream_state.dart';
import 'package:coconut_wallet/services/network/node_client.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

/// NodeProvider의 트랜잭션 관련 기능을 담당하는 매니저 클래스
class TransactionManager {
  final NodeClient _nodeClient;
  final NodeStateManager _stateManager;
  final TransactionRepository _transactionRepository;
  final UtxoManager _utxoManager;

  TransactionManager(
    this._nodeClient,
    this._stateManager,
    this._transactionRepository,
    this._utxoManager,
  );

  /// 특정 스크립트의 트랜잭션을 조회하고 업데이트합니다.
  Future<void> fetchScriptTransaction(
    WalletListItemBase walletItem,
    ScriptStatus scriptStatus,
    WalletProvider walletProvider, {
    DateTime? now,
  }) async {
    // Transaction 동기화 시작 state 업데이트
    _stateManager.addWalletSyncState(walletItem.id, UpdateElement.transaction);

    // 새로운 트랜잭션 조회
    final knownTransactionHashes = _transactionRepository
        .getTransactions(walletItem.id)
        .where((tx) => tx.blockHeight != null && tx.blockHeight! > 0)
        .map((tx) => tx.transactionHash)
        .toSet();

    final txFetchResults = await _nodeClient.getFetchTransactionResponses(
        scriptStatus, knownTransactionHashes);

    final unconfirmedTxs = txFetchResults
        .where((tx) => tx.height == 0)
        .map((tx) => tx.transactionHash)
        .toSet();

    if (txFetchResults.isEmpty) {
      _stateManager.addWalletCompletedState(
          walletItem.id, UpdateElement.transaction);
      return;
    }

    final txBlockHeightMap = Map<String, int>.fromEntries(txFetchResults
        .where((tx) => tx.height > 0)
        .map((tx) => MapEntry(tx.transactionHash, tx.height)));

    final blockTimestampMap = txBlockHeightMap.isEmpty
        ? <int, BlockTimestamp>{}
        : await _nodeClient.getBlocksByHeight(txBlockHeightMap.values.toSet());

    final transactionFuture = await _nodeClient
        .fetchTransactions(
            txFetchResults.map((tx) => tx.transactionHash).toSet())
        .toList();

    final txs = transactionFuture
        .whereType<SuccessState<Transaction>>()
        .map((state) => state.data)
        .toList();

    // 각 트랜잭션에 대해 사용된 UTXO 상태 업데이트
    for (final tx in txs) {
      // 언컨펌 트랜잭션의 경우 새로 브로드캐스트된 트랜잭션이므로 사용된 UTXO 상태 업데이트
      if (unconfirmedTxs.contains(tx.transactionHash)) {
        _utxoManager.updateUtxoStatusToOutgoingByTransaction(walletItem.id, tx);
      }
    }

    final txRecords = await _createTransactionRecords(
        walletItem, txs, txBlockHeightMap, blockTimestampMap, walletProvider,
        now: now);

    _transactionRepository.addAllTransactions(walletItem.id, txRecords);

    // Transaction 업데이트 완료 state 업데이트
    _stateManager.addWalletCompletedState(
        walletItem.id, UpdateElement.transaction);
  }

  /// 트랜잭션 레코드를 생성합니다.
  Future<List<TransactionRecord>> _createTransactionRecords(
    WalletListItemBase walletItemBase,
    List<Transaction> txs,
    Map<String, int> txBlockHeightMap,
    Map<int, BlockTimestamp> blockTimestampMap,
    WalletProvider walletProvider, {
    NodeClient? nodeClient,
    List<Transaction> previousTxs = const [],
    DateTime? now,
  }) async {
    return Future.wait(txs.map((tx) async {
      return _createTransactionRecord(
        walletItemBase,
        tx,
        txBlockHeightMap,
        blockTimestampMap,
        walletProvider,
        nodeClient: nodeClient,
        previousTxs: previousTxs,
        now: now,
      );
    }));
  }

  /// 단일 트랜잭션 레코드를 생성합니다.
  Future<TransactionRecord> _createTransactionRecord(
    WalletListItemBase walletItemBase,
    Transaction tx,
    Map<String, int> txBlockHeightMap,
    Map<int, BlockTimestamp> blockTimestampMap,
    WalletProvider walletProvider, {
    NodeClient? nodeClient,
    List<Transaction> previousTxs = const [],
    DateTime? now,
  }) async {
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
    TransactionType txType;
    if (selfInputCount > 0 &&
        selfOutputCount == tx.outputs.length &&
        selfInputCount == tx.inputs.length) {
      txType = TransactionType.self;
    } else if (selfInputCount > 0 && selfOutputCount < tx.outputs.length) {
      txType = TransactionType.sent;
    } else {
      txType = TransactionType.received;
    }

    return _TransactionDetails(
      inputAddressList: inputAddressList,
      outputAddressList: outputAddressList,
      txType: txType,
      amount: amount,
      fee: fee,
    );
  }

  /// 이전 트랜잭션을 조회합니다.
  Future<Result<List<Transaction>>> _getPreviousTransactions(
    Transaction transaction,
    List<Transaction> existingTxList, {
    NodeClient? nodeClient,
  }) async {
    nodeClient ??= _nodeClient;

    try {
      final result =
          await nodeClient.getPreviousTransactions(transaction, existingTxList);
      return Result.success(result);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 트랜잭션을 브로드캐스트합니다.
  Future<Result<String>> broadcast(Transaction signedTx) async {
    try {
      final txHash = await _nodeClient.broadcast(signedTx.serialize());

      // 브로드캐스트 시간 기록
      _transactionRepository
          .recordTemporaryBroadcastTime(
              signedTx.transactionHash, DateTime.now())
          .catchError((e) {
        Logger.error(e);
      });

      return Result.success(txHash);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 특정 트랜잭션을 조회합니다.
  Future<Result<String>> getTransaction(String txHash) async {
    try {
      final tx = await _nodeClient.getTransaction(txHash);
      return Result.success(tx);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }
}

/// 트랜잭션 상세 정보를 담는 클래스
class _TransactionDetails {
  final List<TransactionAddress> inputAddressList;
  final List<TransactionAddress> outputAddressList;
  final TransactionType txType;
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
