import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';

class TransactionUtil {
  static TransactionStatus? getStatus(TransactionRecord tx) {
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
