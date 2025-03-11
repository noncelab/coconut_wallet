import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';

class TransactionMock {
  static const String testTxHash = 'test_tx_hash';

  /// 테스트용 기본 트랜잭션 객체 생성 메서드
  static TransactionRecord createMockTransactionRecord({
    String? transactionHash,
    DateTime? timestamp,
    int? blockHeight,
    TransactionType transactionType = TransactionType.sent,
    String? memo,
    int amount = 1000000,
    int fee = 10000,
    int vSize = 250,
    DateTime? createdAt,
  }) {
    return TransactionRecord(
      transactionHash ?? testTxHash,
      timestamp ?? DateTime.now(),
      blockHeight ?? 0,
      transactionType.name,
      memo,
      amount,
      fee,
      [], // inputAddressList
      [], // outputAddressList
      vSize,
      createdAt ?? DateTime.now(),
    );
  }

  /// 확인된 트랜잭션 생성 메서드
  static TransactionRecord createConfirmedTransactionRecord({
    String? transactionHash,
    DateTime? timestamp,
    int blockHeight = 2100,
    String? memo,
    int amount = 1000000,
    int fee = 10000,
  }) {
    return createMockTransactionRecord(
      transactionHash: transactionHash,
      timestamp: timestamp,
      blockHeight: blockHeight,
      memo: memo,
      amount: amount,
      fee: fee,
    );
  }

  /// 미확인 트랜잭션 생성 메서드
  static TransactionRecord createUnconfirmedTransactionRecord({
    String? transactionHash,
    DateTime? timestamp,
    String? memo,
    int amount = 500000,
    int fee = 5000,
  }) {
    return createMockTransactionRecord(
      transactionHash: transactionHash,
      timestamp: timestamp,
      blockHeight: 0,
      memo: memo,
      amount: amount,
      fee: fee,
    );
  }

  static Transaction createMockTransaction(String toAddress, int amount,
      {bool isCoinbase = false}) {
    List<TransactionInput> inputs = [];

    if (isCoinbase) {
      inputs.add(TransactionInput.forPayment(
          '0000000000000000000000000000000000000000000000000000000000000000',
          4294967295));
    } else {
      inputs.add(
          TransactionInput.forPayment(Hash.sha256('$toAddress$amount'), 0));
    }

    List<TransactionOutput> outputs = [
      TransactionOutput.forPayment(amount, toAddress),
    ];

    return Transaction.withInputsAndOutputs(
        inputs, outputs, AddressType.p2wpkh);
  }
}
