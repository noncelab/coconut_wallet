import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/node/transaction_details.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
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
    int walletId,
    FetchedTransactionDetails fetchedTransactionDetails, {
    List<Transaction> previousTxs = const [],
    DateTime? now,
  }) async {
    return Future.wait(fetchedTransactionDetails.fetchedTransactions.map((tx) async {
      final blockHeight = fetchedTransactionDetails.txBlockHeightMap[tx.transactionHash];
      final blockTimestamp = fetchedTransactionDetails.blockTimestampMap[blockHeight];

      return createTransactionRecord(
        walletId,
        tx,
        blockTimestamp: blockTimestamp,
        previousTxs: previousTxs,
        now: now,
      );
    }));
  }

  /// 단일 트랜잭션 레코드를 생성합니다.
  Future<TransactionRecord> createTransactionRecord(
    int walletId,
    Transaction tx, {
    BlockTimestamp? blockTimestamp,
    List<Transaction> previousTxs = const [],
    DateTime? now,
  }) async {
    now ??= DateTime.now();

    List<Transaction> prevTxs =
        await _electrumService.getPreviousTransactions(tx, existingTxList: previousTxs);

    final txDetails = processTransactionDetails(tx, prevTxs, walletId);

    return TransactionRecord.fromTransactions(
      transactionHash: tx.transactionHash,
      timestamp: blockTimestamp?.timestamp ?? now,
      blockHeight: blockTimestamp?.height ?? 0,
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
    int walletId,
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

      if (_addressRepository.containsAddress(walletId, inputAddress.address)) {
        selfInputCount++;
        amount -= inputAddress.amount;
      }
    }

    // 출력 처리
    List<TransactionAddress> outputAddressList = [];
    for (int i = 0; i < tx.outputs.length; i++) {
      final output = tx.outputs[i];
      final outputAddressString = output.scriptPubKey.getAddress();

      if (outputAddressString.startsWith('Script')) {
        continue;
      }

      final outputAddress = TransactionAddress(outputAddressString, output.amount);
      outputAddressList.add(outputAddress);

      fee -= outputAddress.amount;

      if (_addressRepository.containsAddress(walletId, outputAddress.address)) {
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

  /// 트랜잭션 레코드를 조회합니다.
  Future<TransactionRecord> getTransactionRecord(
      WalletListItemBase walletItem, String txHash) async {
    final txRaw = await _electrumService.getTransaction(txHash);
    final tx = Transaction.parse(txRaw);
    final previousTxs = await _electrumService.getPreviousTransactions(tx);
    final txDetails = processTransactionDetails(tx, previousTxs, walletItem.id);
    final blockTimestamp = await getTxHeight(
        walletItem.id, walletItem.walletBase.addressType, tx, previousTxs, txDetails);

    return TransactionRecord.fromTransactions(
      transactionHash: tx.transactionHash,
      timestamp: blockTimestamp.timestamp,
      blockHeight: blockTimestamp.height,
      inputAddressList: txDetails.inputAddressList,
      outputAddressList: txDetails.outputAddressList,
      transactionType: txDetails.txType,
      amount: txDetails.amount,
      fee: txDetails.fee,
      vSize: tx.getVirtualByte(),
    );
  }

  /// 트랜잭션의 블록 높이를 조회합니다.
  Future<BlockTimestamp> getTxHeight(int walletId, AddressType addressType, Transaction tx,
      List<Transaction> previousTxs, TransactionDetails txDetails) async {
    final address = _findWalletRelatedAddress(walletId, txDetails);
    final history = await _electrumService.getHistory(addressType, address);

    if (history.isEmpty) {
      return BlockTimestamp(0, DateTime.now());
    }

    final height = _findTransactionHeightFromHistory(history, tx.transactionHash);

    if (height == 0) {
      return BlockTimestamp(0, DateTime.now());
    }

    return await _electrumService.getBlockTimestamp(height);
  }

  /// 지갑과 관련된 주소를 찾습니다.
  /// 우선순위: 입력 주소 → 출력 주소 → 첫 번째 입력 주소
  String _findWalletRelatedAddress(int walletId, TransactionDetails txDetails) {
    // 입력 주소에서 지갑에 속한 주소 찾기
    for (var inputAddress in txDetails.inputAddressList) {
      if (_addressRepository.containsAddress(walletId, inputAddress.address)) {
        return inputAddress.address;
      }
    }

    // 출력 주소에서 지갑에 속한 주소 찾기
    for (var outputAddress in txDetails.outputAddressList) {
      if (_addressRepository.containsAddress(walletId, outputAddress.address)) {
        return outputAddress.address;
      }
    }

    // 둘 다 없으면 첫 번째 입력 주소 사용
    return txDetails.inputAddressList.first.address;
  }

  /// 히스토리에서 특정 트랜잭션의 블록 높이를 찾습니다.
  int _findTransactionHeightFromHistory(List<dynamic> history, String txHash) {
    for (var historyItem in history) {
      if (historyItem.txHash == txHash) {
        return historyItem.height;
      }
    }
    return 0;
  }
}
