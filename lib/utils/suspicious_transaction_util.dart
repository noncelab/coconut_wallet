import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';

// WalletProvider 에서 사용
class SuspiciousTransactionUtil {
  /// Dust Attack 의심 기준: 프로토콜 보다 넉넉하게 1000 sats 미만 소액 전송
  static const int suspiciousAmountThreshold = 1000;

  /// TransactionRecord 기반 dust attack 의심 여부 판단
  ///
  /// [isMyAddress]는 주소가 사용자의 어떤 지갑에 속하는지 확인하는 콜백
  /// 다른 내 지갑에서 보낸 소액 전송을 false positive로 잡지 않기 위해 모든 지갑의 주소 검사
  static bool isTransactionSuspicious(TransactionRecord record, bool Function(String address) isMyAddress) {
    if (record.transactionType != TransactionType.received) return false;

    for (final input in record.inputAddressList) {
      if (isMyAddress(input.address)) return false;
    }

    // 내 주소로 온 output 중 dust 크기가 있는지 확인
    for (final output in record.outputAddressList) {
      if (isMyAddress(output.address) && output.amount > 0 && output.amount < suspiciousAmountThreshold) {
        return true;
      }
    }

    return false;
  }

  /// UtxoState 기반 dust attack 의심 여부 판단
  ///
  /// UTXO 자체에는 TransactionType 정보가 없으므로
  /// 해당 UTXO의 트랜잭션 레코드([txRecord])를 함께 전달
  static bool isUtxoSuspicious(UtxoState utxo, TransactionRecord? txRecord, bool Function(String address) isMyAddress) {
    if (utxo.amount <= 0 || utxo.amount >= suspiciousAmountThreshold) {
      return false;
    }

    if (txRecord == null) return false;
    if (txRecord.transactionType != TransactionType.received) return false;

    for (final input in txRecord.inputAddressList) {
      if (isMyAddress(input.address)) return false;
    }

    return true;
  }
}
