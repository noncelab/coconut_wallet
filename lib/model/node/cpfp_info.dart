import 'package:coconut_lib/coconut_lib.dart';

/// CPFP 트랜잭션 정보를 담는 클래스
class CpfpInfo {
  final String parentTransactionHash; // 부모 트랜잭션
  final double originalFee; // 원본 수수료율
  final List<Transaction> previousTransactions; // 이전 트랜잭션 목록

  CpfpInfo({
    required this.parentTransactionHash,
    required this.originalFee,
    required this.previousTransactions,
  });
}
