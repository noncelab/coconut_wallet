import 'dart:async';

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
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_header.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

/// NodeProvider의 트랜잭션 관련 기능을 담당하는 매니저 클래스
class TransactionManager {
  final ElectrumService _electrumService;
  final NodeStateManager _stateManager;
  final TransactionRepository _transactionRepository;
  final UtxoManager _utxoManager;

  TransactionManager(
    this._electrumService,
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
    bool inBatchProcess = false,
  }) async {
    if (!inBatchProcess) {
      // Transaction 동기화 시작 state 업데이트
      _stateManager.addWalletSyncState(
          walletItem.id, UpdateElement.transaction);
    }

    // 새로운 트랜잭션 조회
    final knownTransactionHashes = _transactionRepository
        .getTransactions(walletItem.id)
        .where((tx) => tx.blockHeight != null && tx.blockHeight! > 0)
        .map((tx) => tx.transactionHash)
        .toSet();

    final txFetchResults = await getFetchTransactionResponses(
        scriptStatus, knownTransactionHashes);

    final unconfirmedTxs = txFetchResults
        .where((tx) => tx.height == 0)
        .map((tx) => tx.transactionHash)
        .toSet();

    if (txFetchResults.isEmpty) {
      if (!inBatchProcess) {
        _stateManager.addWalletCompletedState(
            walletItem.id, UpdateElement.transaction);
      }
      return;
    }

    final txBlockHeightMap = Map<String, int>.fromEntries(txFetchResults
        .where((tx) => tx.height > 0)
        .map((tx) => MapEntry(tx.transactionHash, tx.height)));

    final blockTimestampMap = txBlockHeightMap.isEmpty
        ? <int, BlockTimestamp>{}
        : await getBlocksByHeight(txBlockHeightMap.values.toSet());

    // fetchTransactions를 Future 방식으로 변경
    final txs = await fetchTransactions(
        txFetchResults.map((tx) => tx.transactionHash).toSet());

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

    if (!inBatchProcess) {
      // Transaction 업데이트 완료 state 업데이트
      _stateManager.addWalletCompletedState(
          walletItem.id, UpdateElement.transaction);
    }
  }

  /// 스크립트에 대한 트랜잭션 응답을 가져옵니다.
  Future<List<FetchTransactionResponse>> getFetchTransactionResponses(
      ScriptStatus scriptStatus, Set<String> knownTransactionHashes) async {
    try {
      final historyList =
          await _electrumService.getHistory(scriptStatus.scriptPubKey);

      if (historyList.isEmpty) {
        return [];
      }

      final filteredHistoryList = historyList.where((history) {
        if (knownTransactionHashes.contains(history.txHash)) return false;
        knownTransactionHashes.add(history.txHash);
        return true;
      });

      return filteredHistoryList
          .map((history) => FetchTransactionResponse(
                transactionHash: history.txHash,
                height: history.height,
                addressIndex: scriptStatus.index,
                isChange: scriptStatus.isChange,
              ))
          .toList();
    } catch (e) {
      Logger.error('Failed to get fetch transaction responses: $e');
      return [];
    }
  }

  /// 블록 높이를 통해 블록 타임스탬프를 조회합니다.
  Future<Map<int, BlockTimestamp>> getBlocksByHeight(Set<int> heights) async {
    final futures = heights.map((height) async {
      try {
        final header = await _electrumService.getBlockHeader(height);
        final blockHeader = BlockHeader.parse(height, header);
        return MapEntry(
          height,
          BlockTimestamp(
            height,
            DateTime.fromMillisecondsSinceEpoch(blockHeader.timestamp * 1000,
                isUtc: true),
          ),
        );
      } catch (e) {
        Logger.error('Error fetching block header for height $height: $e');
        return null;
      }
    });

    final results = await Future.wait(futures);
    return Map.fromEntries(results.whereType<MapEntry<int, BlockTimestamp>>());
  }

  /// 트랜잭션 목록을 가져옵니다. (Future 방식으로 구현)
  Future<List<Transaction>> fetchTransactions(
      Set<String> transactionHashes) async {
    List<Transaction> results = [];

    final futures = transactionHashes.map((txHash) async {
      try {
        final txHex = await _electrumService.getTransaction(txHash);
        return Transaction.parse(txHex);
      } catch (e) {
        Logger.error('Failed to fetch transaction $txHash: $e');
        return null;
      }
    });

    final transactions = await Future.wait(futures);
    results.addAll(transactions.whereType<Transaction>());

    return results;
  }

  /// 이전 트랜잭션을 조회합니다.
  Future<List<Transaction>> getPreviousTransactions(
      Transaction transaction, List<Transaction> existingTxList) async {
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
      try {
        var inputTx = await _electrumService.getTransaction(transactionHash);
        return Transaction.parse(inputTx);
      } catch (e) {
        Logger.error('Failed to get previous transaction $transactionHash: $e');
        return null;
      }
    });

    try {
      List<Transaction?> fetchedTransactionsNullable =
          await Future.wait(futures);
      List<Transaction> fetchedTransactions =
          fetchedTransactionsNullable.whereType<Transaction>().toList();

      fetchedTransactions.addAll(existingTxList);

      List<Transaction> previousTransactions = [];

      for (var input in transaction.inputs) {
        final matchingTx = fetchedTransactions
            .where((tx) => tx.transactionHash == input.transactionHash)
            .toList();

        if (matchingTx.isNotEmpty) {
          previousTransactions.add(matchingTx.first);
        }
      }

      return previousTransactions;
    } catch (e) {
      Logger.error('Failed to process previous transactions: $e');
      return [];
    }
  }

  /// 코인베이스 트랜잭션 여부를 확인합니다.
  bool _isCoinbaseTransaction(Transaction tx) {
    if (tx.inputs.length != 1) {
      return false;
    }

    if (tx.inputs[0].transactionHash !=
        '0000000000000000000000000000000000000000000000000000000000000000') {
      return false;
    }

    return tx.inputs[0].index == 4294967295; // 0xffffffff
  }

  /// 트랜잭션 레코드를 생성합니다.
  Future<List<TransactionRecord>> _createTransactionRecords(
    WalletListItemBase walletItemBase,
    List<Transaction> txs,
    Map<String, int> txBlockHeightMap,
    Map<int, BlockTimestamp> blockTimestampMap,
    WalletProvider walletProvider, {
    ElectrumService? nodeClient,
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
    ElectrumService? nodeClient,
    List<Transaction> previousTxs = const [],
    DateTime? now,
  }) async {
    now ??= DateTime.now();
    nodeClient ??= _electrumService;

    final prevTxs = await getPreviousTransactions(tx, previousTxs);

    int blockHeight = txBlockHeightMap[tx.transactionHash] ?? 0;
    final txDetails =
        _processTransactionDetails(tx, prevTxs, walletItemBase, walletProvider);

    return TransactionRecord.fromTransactions(
      transactionHash: tx.transactionHash,
      timestamp: blockTimestampMap[blockHeight]?.timestamp ?? now,
      blockHeight: blockHeight,
      inputAddressList: txDetails.inputAddressList,
      outputAddressList: txDetails.outputAddressList,
      transactionType: txDetails.txType.name,
      amount: txDetails.amount,
      fee: txDetails.fee,
      vSize: tx.getVirtualByte().ceil(),
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

      // 이전 트랜잭션에서 해당 입력에 대응하는 출력 찾기
      Transaction? previousTx;
      try {
        previousTx = previousTxs.firstWhere(
            (prevTx) => prevTx.transactionHash == input.transactionHash);
      } catch (_) {
        // 해당 트랜잭션을 찾지 못한 경우 스킵
        continue;
      }

      // 유효한 인덱스인지 확인
      if (input.index >= previousTx.outputs.length) {
        continue; // 유효하지 않은 인덱스인 경우 스킵
      }

      final previousOutput = previousTx.outputs[input.index];
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

  /// 트랜잭션을 브로드캐스트합니다.
  Future<Result<String>> broadcast(Transaction signedTx) async {
    try {
      final txHash = await _electrumService.broadcast(signedTx.serialize());

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
      final tx = await _electrumService.getTransaction(txHash);
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
