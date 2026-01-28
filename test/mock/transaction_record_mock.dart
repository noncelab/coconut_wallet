import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';

class TransactionRecordMock {
  static const String testTxHash = 'test_tx_hash';

  /// 테스트용 기본 트랜잭션 객체 생성 메서드
  static TransactionRecord createMockTransactionRecord({
    String? transactionHash,
    DateTime? timestamp,
    int? blockHeight,
    TransactionType transactionType = TransactionType.sent,
    String? memo,
    int amount = 1000000,
    int fee = 141,
    double vSize = 141,
    DateTime? createdAt,
    required List<TransactionAddress> inputAddressList,
    required List<TransactionAddress> outputAddressList,
  }) {
    return TransactionRecord(
      transactionHash ?? testTxHash,
      timestamp ?? DateTime.now(),
      blockHeight ?? 0,
      transactionType,
      memo,
      amount,
      fee,
      inputAddressList, // inputAddressList
      outputAddressList, // outputAddressList
      vSize,
      createdAt ?? DateTime.now(),
    );
  }
}
