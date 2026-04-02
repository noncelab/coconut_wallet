import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/utils/suspicious_transaction_util.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionRecord _createRecord({
  required TransactionType type,
  required int amount,
  List<TransactionAddress>? inputs,
  List<TransactionAddress>? outputs,
}) {
  return TransactionRecord.fromTransactions(
    transactionHash: 'txhash_${DateTime.now().microsecondsSinceEpoch}',
    timestamp: DateTime.now(),
    blockHeight: 100,
    transactionType: type,
    amount: amount,
    fee: 200,
    inputAddressList: inputs ?? [TransactionAddress('external_addr_1', 50000)],
    outputAddressList: outputs ?? [TransactionAddress('my_addr_1', amount)],
    vSize: 141,
  );
}

UtxoState _createUtxo({required int amount}) {
  return UtxoState(
    transactionHash: 'txhash_utxo',
    index: 0,
    amount: amount,
    derivationPath: "m/84'/0'/0'/0/0",
    blockHeight: 100,
    to: 'my_addr_1',
    timestamp: DateTime.now(),
  );
}

void main() {
  // 내 지갑 주소 목록
  final myAddresses = {'my_addr_1', 'my_addr_2', 'my_wallet_b_addr_1'};
  bool isMyAddress(String address) => myAddresses.contains(address);

  group('isTransactionSuspicious', () {
    test('received + 소액 + 외부 input → suspicious', () {
      final record = _createRecord(
        type: TransactionType.received,
        amount: 500,
        inputs: [TransactionAddress('attacker_addr', 50000)],
      );

      expect(
        SuspiciousTransactionUtil.isTransactionSuspicious(record, isMyAddress),
        isTrue,
      );
    });

    test('received + 경계값(999 sats) → suspicious', () {
      final record = _createRecord(
        type: TransactionType.received,
        amount: 999,
        inputs: [TransactionAddress('attacker_addr', 50000)],
      );

      expect(
        SuspiciousTransactionUtil.isTransactionSuspicious(record, isMyAddress),
        isTrue,
      );
    });

    test('received + 경계값(1000 sats) → not suspicious', () {
      final record = _createRecord(
        type: TransactionType.received,
        amount: 1000,
        inputs: [TransactionAddress('attacker_addr', 50000)],
      );

      expect(
        SuspiciousTransactionUtil.isTransactionSuspicious(record, isMyAddress),
        isFalse,
      );
    });

    test('received + 큰 금액 → not suspicious', () {
      final record = _createRecord(
        type: TransactionType.received,
        amount: 100000,
        inputs: [TransactionAddress('external_addr', 200000)],
      );

      expect(
        SuspiciousTransactionUtil.isTransactionSuspicious(record, isMyAddress),
        isFalse,
      );
    });

    test('sent 트랜잭션 → not suspicious', () {
      final record = _createRecord(
        type: TransactionType.sent,
        amount: 500,
      );

      expect(
        SuspiciousTransactionUtil.isTransactionSuspicious(record, isMyAddress),
        isFalse,
      );
    });

    test('self 트랜잭션 → not suspicious', () {
      final record = _createRecord(
        type: TransactionType.self,
        amount: 500,
      );

      expect(
        SuspiciousTransactionUtil.isTransactionSuspicious(record, isMyAddress),
        isFalse,
      );
    });

    test('unknown 트랜잭션 → not suspicious', () {
      final record = _createRecord(
        type: TransactionType.unknown,
        amount: 500,
      );

      expect(
        SuspiciousTransactionUtil.isTransactionSuspicious(record, isMyAddress),
        isFalse,
      );
    });

    test('received + 소액 + input이 다른 내 지갑 주소 → not suspicious', () {
      final record = _createRecord(
        type: TransactionType.received,
        amount: 500,
        inputs: [TransactionAddress('my_wallet_b_addr_1', 50000)],
      );

      expect(
        SuspiciousTransactionUtil.isTransactionSuspicious(record, isMyAddress),
        isFalse,
      );
    });

    test('received + 소액 + 여러 input 중 하나가 내 주소 → not suspicious', () {
      final record = _createRecord(
        type: TransactionType.received,
        amount: 500,
        inputs: [
          TransactionAddress('attacker_addr_1', 30000),
          TransactionAddress('my_wallet_b_addr_1', 20000),
        ],
      );

      expect(
        SuspiciousTransactionUtil.isTransactionSuspicious(record, isMyAddress),
        isFalse,
      );
    });

    test('received + 소액 + 여러 external input → suspicious', () {
      final record = _createRecord(
        type: TransactionType.received,
        amount: 546,
        inputs: [
          TransactionAddress('attacker_addr_1', 30000),
          TransactionAddress('attacker_addr_2', 20000),
        ],
      );

      expect(
        SuspiciousTransactionUtil.isTransactionSuspicious(record, isMyAddress),
        isTrue,
      );
    });
  });

  group('isUtxoSuspicious', () {
    test('소액 UTXO + suspicious 트랜잭션 → suspicious', () {
      final utxo = _createUtxo(amount: 500);
      final txRecord = _createRecord(
        type: TransactionType.received,
        amount: 500,
        inputs: [TransactionAddress('attacker_addr', 50000)],
      );

      expect(
        SuspiciousTransactionUtil.isUtxoSuspicious(utxo, txRecord, isMyAddress),
        isTrue,
      );
    });

    test('소액 UTXO + txRecord null → not suspicious', () {
      final utxo = _createUtxo(amount: 500);

      expect(
        SuspiciousTransactionUtil.isUtxoSuspicious(utxo, null, isMyAddress),
        isFalse,
      );
    });

    test('큰 금액 UTXO + suspicious 트랜잭션 → not suspicious (UTXO 금액 기준)', () {
      final utxo = _createUtxo(amount: 5000);
      final txRecord = _createRecord(
        type: TransactionType.received,
        amount: 500,
        inputs: [TransactionAddress('attacker_addr', 50000)],
      );

      expect(
        SuspiciousTransactionUtil.isUtxoSuspicious(utxo, txRecord, isMyAddress),
        isFalse,
      );
    });

    test('소액 UTXO + sent 트랜잭션 → not suspicious', () {
      final utxo = _createUtxo(amount: 300);
      final txRecord = _createRecord(
        type: TransactionType.sent,
        amount: 300,
      );

      expect(
        SuspiciousTransactionUtil.isUtxoSuspicious(utxo, txRecord, isMyAddress),
        isFalse,
      );
    });

    test('소액 UTXO + 내 지갑 간 전송 → not suspicious', () {
      final utxo = _createUtxo(amount: 500);
      final txRecord = _createRecord(
        type: TransactionType.received,
        amount: 500,
        inputs: [TransactionAddress('my_wallet_b_addr_1', 50000)],
      );

      expect(
        SuspiciousTransactionUtil.isUtxoSuspicious(utxo, txRecord, isMyAddress),
        isFalse,
      );
    });

  });
}
