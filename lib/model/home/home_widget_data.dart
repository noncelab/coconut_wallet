import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';

/// 최근 트랜잭션 위젯
class HomeRecentTransaction {
  final int walletId;
  final String walletName;
  final int amount;
  final DateTime time;
  final TransactionType type;
  final TransactionStatus? status;

  const HomeRecentTransaction({
    required this.walletId,
    required this.walletName,
    required this.amount,
    required this.time,
    required this.type,
    this.status,
  });
}

/// Transaction Activity 위젯
class HomeDailyActivity {
  final DateTime day;
  final int received;
  final int sent;
  final int organized;

  const HomeDailyActivity({required this.day, this.received = 0, this.sent = 0, this.organized = 0});

  @override
  bool operator ==(Object other) =>
      other is HomeDailyActivity &&
      other.day == day &&
      other.received == received &&
      other.sent == sent &&
      other.organized == organized;

  @override
  int get hashCode => Object.hash(day, received, sent, organized);

  @override
  String toString() => 'HomeDailyActivity($day, $received, $sent, $organized)';
}

/// UTXO Status 위젯의 금액 구간별 개수
/// 구간: ≥0.1 / 0.01~0.1 / 0.001~0.01 / <0.001 BTC
class HomeUtxoBuckets {
  final List<int> counts;

  /// 구간별 금액 합계(sats)
  /// 개수만 쓰는 곳에서는 값이 비어 있을 수 있다.
  final List<int> amounts;

  const HomeUtxoBuckets(this.counts, [this.amounts = const []]);

  int get total => counts.fold(0, (sum, count) => sum + count);
}

/// 기간 동안의 받기·보내기·정리 횟수와 수량
/// [정리]는 내 지갑끼리 옮긴 것이라 낸 수수료만 카운트
class HomeActivityTotals {
  final int receivedCount;
  final int sentCount;
  final int organizedCount;
  final int receivedSats;
  final int sentSats;
  final int organizedFeeSats;

  const HomeActivityTotals({
    this.receivedCount = 0,
    this.sentCount = 0,
    this.organizedCount = 0,
    this.receivedSats = 0,
    this.sentSats = 0,
    this.organizedFeeSats = 0,
  });
}

/// 지갑별 잔액
/// [walletId]가 null이면 나머지 지갑을 합친 "기타"
class HomeBalanceShare {
  final int? walletId;
  final String name;
  final int balance;
  final int? colorIndex;

  const HomeBalanceShare({required this.walletId, required this.name, required this.balance, this.colorIndex});
}

/// 목표 수량
/// 각 지갑의 목표 수량의 총합
class HomeSavingsGoal {
  final int balance;
  final int target;

  const HomeSavingsGoal({required this.balance, required this.target});

  /// 막대를 채울 비율(최대 1)
  double get progress => ratio.clamp(0, 1).toDouble();

  /// 실제 달성 비율. 초과 달성이면 1보다 크다.
  double get ratio => target <= 0 ? 0 : balance / target;

  String get percentText => formatGoalPercent(ratio);
}

String formatGoalPercent(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';
