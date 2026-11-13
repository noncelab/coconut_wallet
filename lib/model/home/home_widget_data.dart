import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
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
  final String? txHash;

  const HomeRecentTransaction({
    required this.walletId,
    required this.walletName,
    required this.amount,
    required this.time,
    required this.type,
    this.status,
    this.txHash,
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

/// 목표 수량 화면의 지갑 하나. [target]이 없으면 목표를 정하지 않은 지갑이다.
class HomeGoalShare {
  final int walletId;
  final String name;

  /// 전체 잔액(확인 전 입출금 포함). 진행률·남은 수량에 쓴다.
  final int balance;

  /// 확인된 잔액에서 보내는 중(확인 전 송금)인 코인을 뺀 값. 확인 전 입금은 넣지 않는다. 달성은 이 값으로 본다(B1-a.1).
  /// 주지 않으면 [balance]. [balance]와 같은 지갑에서 온 짝이다.
  final int confirmedUnspent;
  final int? target;
  final int? colorIndex;

  /// 같은 계정(같은 지갑)이면 같은 값([WalletItemBase.accountKey]). 주지 않으면 지갑마다 다르다.
  final String accountKey;

  /// 이 지갑의 마지막 동기화가 성공으로 끝났는지. 아니면 마지막 잔액을 그대로 보여 주되 달성은 미룬다(결정 ③, 지갑 하나여도).
  /// 같은 계정 지갑이 둘 이상이면 회당 수량도 미룬다. 주지 않으면 true
  final bool synced;

  /// 이 지갑 주소 가운데 확인 전 입출금이 남은 주소가 있는지(주소별 Electrum unconfirmed ≠ 0). 있으면 달성은 미룬다(B1-a.1).
  /// 보내는 중인 코인이 outgoing 목록에서 빠져도(자기 앞 전송, 목록을 다시 만들다 난 오류) 여기서 막는다. 주지 않으면 false
  final bool pending;

  const HomeGoalShare({
    required this.walletId,
    required this.name,
    required this.balance,
    int? confirmedUnspent,
    required this.target,
    this.colorIndex,
    String? accountKey,
    this.synced = true,
    this.pending = false,
  }) : confirmedUnspent = confirmedUnspent ?? balance,
       accountKey = accountKey ?? 'wallet:$walletId';

  bool get hasTarget => target != null && target! > 0;

  /// 달성 판정에 쓰는 잔액: [confirmedUnspent](전체 잔액을 넘지 않게). 노드 잔액의 확인 전 값은 입금과 송금이 상쇄된
  /// 합이라 confirmed·total만으로는 둘이 함께 있을 때 입금을 달성에 넣게 된다(Astra: 확인 1.1 − 송금 0.3 + 입금 0.2).
  int get reachBalance => math.min(confirmedUnspent, balance);

  /// 지갑별 잔액 도넛과 같은 색을 쓰도록 [HomeBalanceShare]로 바꾼다.
  HomeBalanceShare get asBalanceShare =>
      HomeBalanceShare(walletId: walletId, name: name, balance: balance, colorIndex: colorIndex);

  HomeSavingsGoal? get goal => hasTarget ? HomeSavingsGoal(balance: balance, target: target!) : null;
}

/// 목표 합계(결정 ⑦·B1-a). 같은 계정(핫월렛과 그 보기 전용 지갑)은 잔액을 한 번만 세고, 목표가 같으면 한 번,
/// 다르면 큰 목표로 센다. 저장된 목표는 바꾸거나 지우지 않는다.
/// 같은 계정은 주소가 같아 동기화가 끝나면 잔액도 같다. 지갑끼리 잔액 짝(전체·확인된 미사용 잔액)이 다르거나 동기화를
/// 성공으로 마치지 못한 지갑이 있으면 어느 쪽이 최신인지 모르므로 '확인 대기'다: 작은 쪽 지갑의 짝으로 보여 주고(남은 수량을
/// 적게 말하지 않음) 달성·회당 수량은 미룬다. 큰 값은 송금 뒤 옛 잔액일 수 있어 쓰지 않는다.
/// 지갑 하나뿐인 계정도 동기화를 성공으로 마치기 전에는 마지막 잔액만 보여 주고 달성은 미룬다(결정 ③, B1-a.2).
/// 홈 목표 위젯·인사이트 목표 카드·목표 화면·모으기 계획이 모두 이 합계를 쓴다.
@immutable
class HomeGoalSum {
  /// 목표가 있는 계정마다 하나. 목표가 큰 지갑(같으면 id가 작은 지갑)의 이름·색에, 잔액은 그 계정의 짝을 담는다.
  /// 지갑 목록 순서를 바꿔도 어느 지갑이 대표인지는 그대로다.
  final List<HomeGoalShare> accounts;

  /// 같은 계정에 서로 다른 목표가 있어 큰 목표로 계산했는지. 합계 옆에 이유와 [목표 정리]를 보여 주고,
  /// 정리하기 전에는 알림에 수량을 넣지 않는다(알림 쪽 규칙).
  final bool hasConflictingGoals;

  /// 목표가 있는 계정 가운데 같은 계정 지갑끼리 잔액 짝이 다르거나 동기화를 성공으로 마치지 못한 지갑이 있는지(확인 대기).
  /// 목표가 없는 쌍둥이 지갑도 본다.
  final bool hasUnsettledAccounts;

  /// [hasUnsettledAccounts] 가운데 잔액 짝이 실제로 다른 계정이 있는지. 같은데 동기화 중이면 false라
  /// '잔액이 서로 달라' 대신 '잔액을 확인하는 중'이라고 말한다(Fable C2).
  final bool hasDifferingBalances;

  /// 목표가 있는 계정의 지갑이 모두 마지막 동기화를 성공으로 마쳤는지. 아니면 달성·알림 수량을 미룬다(결정 ③).
  final bool allSynced;

  /// 목표가 있는 계정(목표 없는 쌍둥이 포함)의 주소 가운데 확인 전 입출금이 남은 주소가 있는지. 있으면 달성을 미룬다(B1-a.1).
  /// 작은 입금 하나여도 그렇다. 멤풀에서 빠지면 0으로 돌아가 풀린다
  final bool hasPendingActivity;

  const HomeGoalSum._(
    this.accounts,
    this.hasConflictingGoals,
    this.hasUnsettledAccounts,
    this.hasDifferingBalances,
    this.allSynced,
    this.hasPendingActivity,
  );

  factory HomeGoalSum.of(Iterable<HomeGoalShare> shares) {
    final members = <String, List<HomeGoalShare>>{};
    // 목표가 있는 계정, 처음 나온 순서
    final targeted = <String>{};
    for (final share in shares) {
      members.putIfAbsent(share.accountKey, () => []).add(share);
      if (share.hasTarget) targeted.add(share.accountKey);
    }
    var conflicting = false;
    var unsettled = false;
    var differing = false;
    var allSynced = true;
    var pendingAny = false;
    final accounts = <HomeGoalShare>[];
    for (final account in targeted) {
      final group = members[account]!;
      final withTarget = [
        for (final share in group)
          if (share.hasTarget) share,
      ];
      if (withTarget.map((share) => share.target).toSet().length > 1) conflicting = true;
      final lead = withTarget.reduce(
        (a, b) => b.target! > a.target! || (b.target == a.target && b.walletId < a.walletId) ? b : a,
      );
      final pairsDiffer = group.map((share) => (share.balance, share.confirmedUnspent)).toSet().length > 1;
      final groupSynced = group.every((share) => share.synced);
      if (group.length > 1 && (pairsDiffer || !groupSynced)) unsettled = true;
      if (pairsDiffer) differing = true;
      if (!groupSynced) allSynced = false;
      final groupPending = group.any((share) => share.pending);
      if (groupPending) pendingAny = true;
      // 작은 쪽 지갑의 짝: 전체 잔액이 작은 지갑(같으면 확인된 미사용 잔액이 작은 지갑). 잔액이 같으면 어느 지갑이든 같다.
      final pair = group.reduce(
        (a, b) => b.balance < a.balance || (b.balance == a.balance && b.confirmedUnspent < a.confirmedUnspent) ? b : a,
      );
      accounts.add(
        HomeGoalShare(
          walletId: lead.walletId,
          name: lead.name,
          balance: pair.balance,
          confirmedUnspent: pair.confirmedUnspent,
          target: lead.target,
          colorIndex: lead.colorIndex,
          accountKey: account,
          // 이 계정의 잔액을 믿을 수 있는지(모두 동기화를 마쳤고, 짝이 같고, 확인 전 입출금이 없음)
          synced: groupSynced && !pairsDiffer && !groupPending,
          pending: groupPending,
        ),
      );
    }
    return HomeGoalSum._(List.unmodifiable(accounts), conflicting, unsettled, differing, allSynced, pendingAny);
  }

  int get balance => accounts.fold(0, (sum, account) => sum + account.balance);

  int get target => accounts.fold(0, (sum, account) => sum + account.target!);

  /// 달성 판정에 쓰는 잔액의 합(확인된 잔액 − 보내는 중인 코인, 확인 전 입금 제외, 계정당 한 번)
  int get reachBalance => accounts.fold(0, (sum, account) => sum + account.reachBalance);

  /// 목표가 있는 계정이 없으면 null
  HomeSavingsGoal? get goal => accounts.isEmpty ? null : HomeSavingsGoal(balance: balance, target: target);

  /// 목표 달성: [reachBalance] 기준, 목표 지갑이 모두 동기화를 성공으로 마쳤고 같은 계정 잔액이 같고 확인 전 입출금이
  /// 남은 주소가 없을 때만. 합계·지갑별 줄([isSettled])·알림 끄기가 같은 규칙이다
  bool get reached =>
      accounts.isNotEmpty && allSynced && !hasUnsettledAccounts && !hasPendingActivity && reachBalance >= target;

  /// [accountKey] 계정의 잔액을 믿을 수 있는지(동기화를 마쳤고, 같은 계정 짝이 같고, 확인 전 입출금이 없음).
  /// 지갑별 목표 줄이 '목표 달성'을 정할 때 합계와 같은 규칙을 쓰게 한다
  bool isSettled(String accountKey) => accounts.any((account) => account.accountKey == accountKey && account.synced);

  /// 진행률(전체 잔액)은 목표에 닿았지만 아직 달성은 아님: 확인된 잔액으로는 모자라거나 잔액을 확인하는 중(동기화 중·
  /// 같은 계정 잔액이 다름·확인 전 입출금). '목표 달성' 대신 '확인 대기'
  bool get awaitingConfirmation => accounts.isNotEmpty && balance >= target && !reached;
}

String formatGoalPercent(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';
