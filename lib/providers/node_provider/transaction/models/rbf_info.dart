import 'package:coconut_lib/coconut_lib.dart';

/// RBF 트랜잭션 정보를 담는 클래스
class RbfInfo {
  final String originalTransactionHash; // RBF 체인의 최초 트랜잭션
  final String spentTransactionHash; // 이 트랜잭션이 대체하는 직전 트랜잭션
  final List<Transaction> previousTransactions; // 이전 트랜잭션 목록

  RbfInfo({
    required this.originalTransactionHash,
    required this.spentTransactionHash,
    required this.previousTransactions,
  });
}
