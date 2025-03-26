import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/models/transaction_details.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';

/// 트랜잭션을 처리하고 변환하는 클래스
class TransactionProcessor {
  final ElectrumService _electrumService;
  final AddressRepository _addressRepository;

  TransactionProcessor(this._electrumService, this._addressRepository);

  /// 이전 트랜잭션을 조회합니다.
  Future<List<Transaction>> getPreviousTransactions(
    Transaction transaction,
    List<Transaction> existingTxList,
  ) async {
    if (transaction.inputs.isEmpty) {
      return [];
    }

    if (TransactionUtil.isCoinbaseTransaction(transaction)) {
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

  /// 트랜잭션 레코드를 생성합니다.
  Future<List<TransactionRecord>> createTransactionRecords(
    WalletListItemBase walletItemBase,
    List<Transaction> txs,
    Map<String, int> txBlockHeightMap,
    Map<int, BlockTimestamp> blockTimestampMap, {
    List<Transaction> previousTxs = const [],
    Future<String> Function(String)? getTransactionHex,
    DateTime? now,
  }) async {
    return Future.wait(txs.map((tx) async {
      return createTransactionRecord(
        walletItemBase,
        tx,
        txBlockHeightMap,
        blockTimestampMap,
        previousTxs: previousTxs,
        getTransactionHex: getTransactionHex,
        now: now,
      );
    }));
  }

  /// 단일 트랜잭션 레코드를 생성합니다.
  Future<TransactionRecord> createTransactionRecord(
    WalletListItemBase walletItemBase,
    Transaction tx,
    Map<String, int> txBlockHeightMap,
    Map<int, BlockTimestamp> blockTimestampMap, {
    List<Transaction> previousTxs = const [],
    Future<String> Function(String)? getTransactionHex,
    DateTime? now,
  }) async {
    now ??= DateTime.now();

    List<Transaction> prevTxs;
    if (getTransactionHex != null) {
      prevTxs = await getPreviousTransactions(tx, previousTxs);
    } else {
      prevTxs = previousTxs;
    }

    int blockHeight = txBlockHeightMap[tx.transactionHash] ?? 0;
    final txDetails = processTransactionDetails(tx, prevTxs, walletItemBase);

    return TransactionRecord.fromTransactions(
      transactionHash: tx.transactionHash,
      timestamp: blockTimestampMap[blockHeight]?.timestamp ?? now,
      blockHeight: blockHeight,
      inputAddressList: txDetails.inputAddressList,
      outputAddressList: txDetails.outputAddressList,
      transactionType: txDetails.txType.name,
      amount: txDetails.amount,
      fee: txDetails.fee,
      vSize: tx.getVirtualByte(),
    );
  }

  /// 트랜잭션의 입출력 상세 정보를 처리합니다.
  TransactionDetails processTransactionDetails(
    Transaction tx,
    List<Transaction> previousTxs,
    WalletListItemBase walletItemBase,
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

      if (_addressRepository.containsAddress(
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

      if (_addressRepository.containsAddress(
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

    return TransactionDetails(
      inputAddressList: inputAddressList,
      outputAddressList: outputAddressList,
      txType: txType,
      amount: amount,
      fee: fee,
    );
  }
}
