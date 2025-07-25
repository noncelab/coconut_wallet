import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/rbf_service.dart';

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
    double vSize = 250,
    DateTime? createdAt,
  }) {
    return TransactionRecord(
      transactionHash ?? testTxHash,
      timestamp ?? DateTime.now(),
      blockHeight ?? 0,
      transactionType,
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

  static Transaction createMockTransaction({
    required String toAddress,
    required int amount,
    String? inputTransactionHash,
    bool isCoinbase = false,
    ({int amount, String address})? change,
  }) {
    List<TransactionInput> inputs = [];
    List<TransactionOutput> outputs = [];

    if (isCoinbase) {
      inputs.add(TransactionInput.forPayment(
          '0000000000000000000000000000000000000000000000000000000000000000', 4294967295));
    } else {
      inputs.add(
          TransactionInput.forPayment(inputTransactionHash ?? Hash.sha256('$toAddress$amount'), 0));
    }

    outputs.add(TransactionOutput.forPayment(amount, toAddress));

    if (change != null) {
      outputs.add(TransactionOutput.forPayment(change.amount, change.address));
    }

    return Transaction.withInputsAndOutputs(inputs, outputs, AddressType.p2wpkh);
  }

  /// RBF 테스트를 위한 RbfInfo 생성 메서드
  static RbfInfo createMockRbfInfo({
    required String originalTransactionHash,
    required String previousTransactionHash,
  }) {
    return (
      originalTransactionHash: originalTransactionHash,
      previousTransactionHash: previousTransactionHash,
    );
  }

  /// RBF 테스트를 위한 트랜잭션 생성 메서드
  static TransactionRecord createRbfTransactionRecord({
    required String transactionHash,
    int amount = 1000000,
    int fee = 15000, // RBF는 보통 더 높은 수수료
  }) {
    return createMockTransactionRecord(
      transactionHash: transactionHash,
      blockHeight: 0, // 미확인 트랜잭션
      amount: amount,
      fee: fee,
    );
  }
}
