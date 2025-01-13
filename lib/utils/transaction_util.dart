import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/enums/transaction_enums.dart';

class TransactionUtil {
  static TransactionStatus? getStatus(Transfer tx) {
    if (tx.transferType == TransactionTypeEnum.received.name) {
      if (tx.blockHeight == 0 || tx.blockHeight == null) {
        return TransactionStatus.receiving;
      }
      return TransactionStatus.received;
    }
    if (tx.transferType == TransactionTypeEnum.sent.name) {
      if (tx.blockHeight == 0 || tx.blockHeight == null) {
        return TransactionStatus.sending;
      }
      return TransactionStatus.sent;
    }
    if (tx.transferType == TransactionTypeEnum.self.name) {
      if (tx.blockHeight == 0 || tx.blockHeight == null) {
        return TransactionStatus.selfsending;
      }
      return TransactionStatus.self;
    }

    return null;
  }
}
