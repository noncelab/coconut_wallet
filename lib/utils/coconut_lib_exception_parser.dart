import 'package:coconut_lib/coconut_lib.dart';

int? extractEstimatedFeeFromException(Exception e) {
  if (e is TransactionException && e.code == TransactionErrorCode.insufficientFunds) {
    final fee = e.context['fee'];
    if (fee is int) return fee;
    if (fee is num) return fee.toInt();
    if (fee is String) return int.tryParse(fee);
  }

  return null;
}
