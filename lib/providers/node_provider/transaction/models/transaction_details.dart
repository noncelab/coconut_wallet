import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';

/// 트랜잭션 상세 정보를 담는 클래스
class TransactionDetails {
  final List<TransactionAddress> inputAddressList;
  final List<TransactionAddress> outputAddressList;
  final TransactionType txType;
  final int amount;
  final int fee;

  TransactionDetails({
    required this.inputAddressList,
    required this.outputAddressList,
    required this.txType,
    required this.amount,
    required this.fee,
  });
}
