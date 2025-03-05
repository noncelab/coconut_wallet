import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';

class TransactionUtil {
  static TransactionStatus? getStatus(TransactionRecord tx) {
    if (tx.transactionType == TransactionType.received.name) {
      if (tx.blockHeight == 0 || tx.blockHeight == null) {
        return TransactionStatus.receiving;
      }
      return TransactionStatus.received;
    }
    if (tx.transactionType == TransactionType.sent.name) {
      if (tx.blockHeight == 0 || tx.blockHeight == null) {
        return TransactionStatus.sending;
      }
      return TransactionStatus.sent;
    }
    if (tx.transactionType == TransactionType.self.name) {
      if (tx.blockHeight == 0 || tx.blockHeight == null) {
        return TransactionStatus.selfsending;
      }
      return TransactionStatus.self;
    }

    return null;
  }

  static String getInputAddress(TransactionRecord? transaction, index) =>
      _getTransactionField<String>(transaction, index,
          (tx) => transaction!.inputAddressList, (item) => item.address,
          defaultValue: '');

  static String getOutputAddress(TransactionRecord? transaction, int index) =>
      _getTransactionField<String>(transaction, index,
          (tx) => transaction!.outputAddressList, (item) => item.address,
          defaultValue: '');

  static int getInputAmount(TransactionRecord? transaction, int index) =>
      _getTransactionField<int>(transaction, index,
          (tx) => transaction!.inputAddressList, (item) => item.amount,
          defaultValue: 0);

  static int getOutputAmount(TransactionRecord? transaction, int index) =>
      _getTransactionField<int>(transaction, index,
          (tx) => transaction!.outputAddressList, (item) => item.amount,
          defaultValue: 0);

  static T _getTransactionField<T>(
    TransactionRecord? transaction,
    int index,
    List<dynamic> Function(TransactionRecord) listSelector,
    T Function(dynamic) valueSelector, {
    required T defaultValue,
  }) {
    if (transaction == null) return defaultValue;

    final list = listSelector(transaction);
    if (index < 0 || index >= list.length) return defaultValue;

    return valueSelector(list[index]);
  }
}
