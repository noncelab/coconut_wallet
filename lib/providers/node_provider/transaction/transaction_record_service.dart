import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/node/transaction_details.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';

class TransactionRecordService {
  final ElectrumService _electrumService;
  final AddressRepository _addressRepository;

  TransactionRecordService(this._electrumService, this._addressRepository);

  /// 트랜잭션 레코드를 생성합니다.
  Future<List<TransactionRecord>> createTransactionRecords(
    WalletListItemBase walletItemBase,
    FetchedTransactionDetails fetchedTransactionDetails, {
    List<Transaction> previousTxs = const [],
    DateTime? now,
  }) async {
    return Future.wait(fetchedTransactionDetails.fetchedTransactions.map((tx) async {
      return createTransactionRecord(
        walletItemBase,
        tx,
        fetchedTransactionDetails.txBlockHeightMap,
        fetchedTransactionDetails.blockTimestampMap,
        previousTxs: previousTxs,
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
    DateTime? now,
  }) async {
    now ??= DateTime.now();

    List<Transaction> prevTxs =
        await _electrumService.getPreviousTransactions(tx, existingTxList: previousTxs);

    int blockHeight = txBlockHeightMap[tx.transactionHash] ?? 0;
    final txDetails = processTransactionDetails(tx, prevTxs, walletItemBase);

    return TransactionRecord.fromTransactions(
      transactionHash: tx.transactionHash,
      timestamp: blockTimestampMap[blockHeight]?.timestamp ?? now,
      blockHeight: blockHeight,
      inputAddressList: txDetails.inputAddressList,
      outputAddressList: txDetails.outputAddressList,
      transactionType: txDetails.txType,
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
        previousTx =
            previousTxs.firstWhere((prevTx) => prevTx.transactionHash == input.transactionHash);
      } catch (_) {
        continue;
      }

      if (input.index >= previousTx.outputs.length) {
        continue;
      }

      final previousOutput = previousTx.outputs[input.index];
      final inputAddress =
          TransactionAddress(previousOutput.scriptPubKey.getAddress(), previousOutput.amount);
      inputAddressList.add(inputAddress);

      fee += inputAddress.amount;

      if (_addressRepository.containsAddress(walletItemBase.id, inputAddress.address)) {
        selfInputCount++;
        amount -= inputAddress.amount;
      }
    }

    // 출력 처리
    List<TransactionAddress> outputAddressList = [];
    for (int i = 0; i < tx.outputs.length; i++) {
      final output = tx.outputs[i];
      final outputAddress = TransactionAddress(output.scriptPubKey.getAddress(), output.amount);
      outputAddressList.add(outputAddress);

      fee -= outputAddress.amount;

      if (_addressRepository.containsAddress(walletItemBase.id, outputAddress.address)) {
        selfOutputCount++;
        amount += outputAddress.amount;
      }
    }

    // 트랜잭션 유형 결정
    TransactionType txType = determineTransactionType(
      selfInputCount,
      selfOutputCount,
      tx.inputs.length,
      tx.outputs.length,
    );

    return TransactionDetails(
      inputAddressList: inputAddressList,
      outputAddressList: outputAddressList,
      txType: txType,
      amount: amount,
      fee: fee,
    );
  }

  TransactionType determineTransactionType(
    int selfInputCount,
    int selfOutputCount,
    int inputCount,
    int outputCount,
  ) {
    if (selfInputCount == 0) {
      return TransactionType.received;
    }

    if (selfOutputCount < outputCount) {
      return TransactionType.sent;
    }

    if (selfOutputCount == outputCount && selfInputCount == inputCount) {
      return TransactionType.self;
    }

    return TransactionType.received;
  }
}
