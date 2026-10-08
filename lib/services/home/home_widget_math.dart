import 'dart:math' as math;

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';

class HomeWidgetMath {
  static const utxoBucketLowerBounds = [10000000, 1000000, 100000, 0];

  /// [today]를 포함해 거꾸로 [days]일의 날짜(자정). 오래된 날부터.
  static List<DateTime> lastDays(DateTime today, int days) {
    final start = DateTime(today.year, today.month, today.day);
    return [for (var i = days - 1; i >= 0; i--) DateTime(start.year, start.month, start.day - i)];
  }

  // TODO(P10): 잔액 이력 서비스로 합친다. WalletListViewModel._updateWalletBalanceHistory도 같은 거래 기록에서 잔액 흐름을
  //  구하지만 방식이 다르다(그쪽은 0부터 거래를 더해 거래 시점마다 점을 찍고 끝을 현재 잔액에 맞추며, 이쪽은 현재 잔액에서
  //  거꾸로 빼 하루 한 값을 낸다). 거래 기록이 덜 받아진 지갑에서 결과가 갈리므로 합칠 때 처리 방식을 먼저 정해야 한다.
  /// 각 날의 마지막 잔액
  static List<int> dailyBalances(List<TransactionRecord> transactions, int currentBalance, DateTime now, int days) {
    final daysList = lastDays(now, days);
    return [
      for (final day in daysList)
        currentBalance -
            transactions
                .where((tx) => !tx.timestamp.isBefore(DateTime(day.year, day.month, day.day + 1)))
                .fold<int>(0, (sum, tx) => sum + tx.amount),
    ];
  }

  static double? changeRate(num from, num to) => from == 0 ? null : (to - from) / from;

  static List<HomeDailyActivity> dailyActivity(List<TransactionRecord> transactions, DateTime now, int days) {
    return [
      for (final day in lastDays(now, days))
        () {
          final next = DateTime(day.year, day.month, day.day + 1);
          final ofDay = transactions.where((tx) => !tx.timestamp.isBefore(day) && tx.timestamp.isBefore(next));
          int count(TransactionType type) => ofDay.where((tx) => tx.transactionType == type).length;
          return HomeDailyActivity(
            day: day,
            received: count(TransactionType.received),
            sent: count(TransactionType.sent),
            organized: count(TransactionType.self),
          );
        }(),
    ];
  }

  /// 일별 활동을 막대 [maxBars]개 이하가 되도록 앞에서부터 같은 일수씩 묶는다. [groupDays]가 있으면 그 일수씩. 묶음의 날짜는 첫날.
  static List<HomeDailyActivity> groupActivity(List<HomeDailyActivity> days, {int maxBars = 7, int? groupDays}) {
    if (groupDays == null && days.length <= maxBars) return days;
    final size = groupDays ?? (days.length / maxBars).ceil();
    return [
      for (var start = 0; start < days.length; start += size)
        () {
          final group = days.sublist(start, math.min(start + size, days.length));
          return HomeDailyActivity(
            day: group.first.day,
            received: group.fold(0, (sum, day) => sum + day.received),
            sent: group.fold(0, (sum, day) => sum + day.sent),
            organized: group.fold(0, (sum, day) => sum + day.organized),
          );
        }(),
    ];
  }

  /// 일별 활동을 달력 월로 묶는다. 묶음의 날짜는 그 달 첫날.
  static List<HomeDailyActivity> groupActivityByMonth(List<HomeDailyActivity> days) {
    final months = <DateTime, HomeDailyActivity>{};
    for (final day in days) {
      final month = DateTime(day.day.year, day.day.month);
      final sum = months[month];
      months[month] = HomeDailyActivity(
        day: month,
        received: (sum?.received ?? 0) + day.received,
        sent: (sum?.sent ?? 0) + day.sent,
        organized: (sum?.organized ?? 0) + day.organized,
      );
    }
    return months.values.toList();
  }

  /// [today]가 든 달을 포함해 최근 [months]개 달의 첫날부터 오늘까지의 일수
  static int daysSinceMonthsAgo(DateTime today, int months) {
    final start = DateTime(today.year, today.month - (months - 1));
    return DateTime(today.year, today.month, today.day).difference(start).inDays + 1;
  }

  static HomeUtxoBuckets utxoBuckets(Iterable<int> amounts) {
    final counts = List.filled(utxoBucketLowerBounds.length, 0);
    final sums = List.filled(utxoBucketLowerBounds.length, 0);
    for (final amount in amounts) {
      final bucket = utxoBucketLowerBounds.indexWhere((lower) => amount >= lower);
      counts[bucket]++;
      sums[bucket] += amount;
    }
    return HomeUtxoBuckets(counts, sums);
  }

  static HomeActivityTotals activityTotals(Iterable<TransactionRecord> transactions) {
    var received = 0, sent = 0, organized = 0, receivedSats = 0, sentSats = 0, feeSats = 0;
    for (final tx in transactions) {
      switch (tx.transactionType) {
        case TransactionType.received:
          received++;
          receivedSats += tx.amount.abs();
        case TransactionType.sent:
          sent++;
          sentSats += tx.amount.abs();
        case TransactionType.self:
          organized++;
          feeSats += tx.fee;
        case TransactionType.unknown:
          break;
      }
    }
    return HomeActivityTotals(
      receivedCount: received,
      sentCount: sent,
      organizedCount: organized,
      receivedSats: receivedSats,
      sentSats: sentSats,
      organizedFeeSats: feeSats,
    );
  }

  /// 가짜 잔액일 때의 기간 합계. 횟수는 가짜 일별 활동에서, 수량은 가짜 잔액 규모에 맞춰 만든다.
  static HomeActivityTotals fakeActivityTotals({
    required int seed,
    required List<HomeDailyActivity> days,
    required int balance,
  }) {
    final random = math.Random(seed);
    final received = days.fold(0, (sum, day) => sum + day.received);
    final sent = days.fold(0, (sum, day) => sum + day.sent);
    final organized = days.fold(0, (sum, day) => sum + day.organized);
    int amount(int count, double share) => (balance * share * count * (0.5 + random.nextDouble())).round();
    return HomeActivityTotals(
      receivedCount: received,
      sentCount: sent,
      organizedCount: organized,
      receivedSats: amount(received, 0.02),
      sentSats: amount(sent, 0.015),
      organizedFeeSats: organized * (300 + random.nextInt(2000)),
    );
  }

  /// 가장 큰 [top]개 지갑과 나머지를 합친 "기타". 잔액이 0인 지갑은 뺀다.
  static List<HomeBalanceShare> balanceShares(List<HomeBalanceShare> wallets, {int top = 3, String othersName = ''}) {
    final sorted = wallets.where((share) => share.balance > 0).toList()..sort((a, b) => b.balance.compareTo(a.balance));
    if (sorted.length <= top + 1) return sorted;
    final others = sorted.skip(top).fold<int>(0, (sum, share) => sum + share.balance);
    return [...sorted.take(top), HomeBalanceShare(walletId: null, name: othersName, balance: others)];
  }

  static int seed(Iterable<Object> parts) {
    var hash = 0x811c9dc5;
    for (final unit in parts.join('|').codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static List<int> fakeTrend({required int end, required int seed, required int points}) {
    final random = math.Random(seed);
    final values = List.filled(points, end);
    for (var i = points - 2; i >= 0; i--) {
      final step = (random.nextDouble() - 0.45) * 0.12;
      values[i] = math.max(0, (values[i + 1] * (1 - step)).round());
    }
    return values;
  }

  static List<HomeDailyActivity> fakeDailyActivity({required int seed, required DateTime now, required int days}) {
    final random = math.Random(seed);
    return [
      for (final day in lastDays(now, days))
        HomeDailyActivity(day: day, received: random.nextInt(4), sent: random.nextInt(3), organized: random.nextInt(2)),
    ];
  }

  static HomeUtxoBuckets fakeUtxoBuckets({required int seed, required int total}) {
    if (total <= 0) return const HomeUtxoBuckets([0, 0, 0, 0], [0, 0, 0, 0]);
    final random = math.Random(seed);
    final counts = [
      total >= 10000000 ? 1 + random.nextInt(3) : 0,
      1 + random.nextInt(6),
      random.nextInt(6),
      random.nextInt(4),
    ];
    const typical = [20000000, 3000000, 300000, 30000];
    final rough = [for (var i = 0; i < counts.length; i++) counts[i] * typical[i]];
    final roughTotal = rough.fold(0, (sum, value) => sum + value);
    final amounts = [for (final value in rough) roughTotal == 0 ? 0 : (total * value / roughTotal).round()];
    return HomeUtxoBuckets(counts, amounts);
  }

  static List<HomeRecentTransaction> fakeRecentTransactions({
    required int seed,
    required DateTime now,
    required List<({int walletId, String walletName, int balance})> wallets,
  }) {
    final funded = wallets.where((wallet) => wallet.balance > 0).toList();
    if (funded.isEmpty) return const [];
    final random = math.Random(seed);
    const count = 3;
    final result = [
      for (var i = 0; i < count; i++)
        () {
          final wallet = funded[random.nextInt(funded.length)];
          final received = random.nextBool();
          final amount = math.max(1000, (wallet.balance * (0.005 + random.nextDouble() * 0.05)).round());
          return HomeRecentTransaction(
            walletId: wallet.walletId,
            walletName: wallet.walletName,
            amount: received ? amount : -amount,
            time: now.subtract(Duration(minutes: 5 + random.nextInt(30 * 24 * 60))),
            type: received ? TransactionType.received : TransactionType.sent,
            status: received ? TransactionStatus.received : TransactionStatus.sent,
          );
        }(),
    ];
    return result..sort((a, b) => b.time.compareTo(a.time));
  }
}
