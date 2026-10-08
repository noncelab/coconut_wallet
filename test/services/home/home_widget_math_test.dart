import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/services/home/home_widget_math.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionRecord _tx(DateTime time, int amount, [TransactionType type = TransactionType.received]) =>
    TransactionRecord('tx-$time-$amount', time, 1, type, null, amount, 0, const [], const [], 0, time);

void main() {
  final now = DateTime(2026, 9, 1, 15, 30);

  test('last days are midnights ending today, oldest first', () {
    expect(HomeWidgetMath.lastDays(now, 3), [DateTime(2026, 8, 30), DateTime(2026, 8, 31), DateTime(2026, 9, 1)]);
  });

  test('daily balances end at the current balance and undo later transactions for earlier days', () {
    final transactions = [
      _tx(DateTime(2026, 8, 28, 10), 1000),
      _tx(DateTime(2026, 8, 31, 9), 500),
      _tx(DateTime(2026, 9, 1, 8), -200, TransactionType.sent),
    ];

    final balances = HomeWidgetMath.dailyBalances(transactions, 1300, now, 4);

    expect(balances, [1000, 1000, 1500, 1300]);
  });

  test('daily balances without history stay flat at the current balance', () {
    expect(HomeWidgetMath.dailyBalances(const [], 700, now, 3), [700, 700, 700]);
  });

  test('change rate is relative to the first value and null when it starts at zero', () {
    expect(HomeWidgetMath.changeRate(100, 105), closeTo(0.05, 1e-9));
    expect(HomeWidgetMath.changeRate(100, 90), closeTo(-0.1, 1e-9));
    expect(HomeWidgetMath.changeRate(0, 10), isNull);
  });

  test('daily activity counts received, sent and organized per day', () {
    final activity = HomeWidgetMath.dailyActivity(
      [
        _tx(DateTime(2026, 8, 31, 1), 10),
        _tx(DateTime(2026, 8, 31, 23), 10),
        _tx(DateTime(2026, 9, 1, 2), -5, TransactionType.sent),
        _tx(DateTime(2026, 9, 1, 3), -1, TransactionType.self),
        _tx(DateTime(2026, 8, 20), 10),
      ],
      now,
      2,
    );

    expect(activity, [
      HomeDailyActivity(day: DateTime(2026, 8, 31), received: 2),
      HomeDailyActivity(day: DateTime(2026, 9, 1), sent: 1, organized: 1),
    ]);
  });

  test('utxo amounts fall into ≥0.1 / 0.01~0.1 / 0.001~0.01 / <0.001 BTC buckets', () {
    final buckets = HomeWidgetMath.utxoBuckets([10000000, 9999999, 1000000, 100000, 99999, 1]);

    expect(buckets.counts, [1, 2, 1, 2]);
    expect(buckets.total, 6);
  });

  test('balance shares keep the three largest and group the rest as others', () {
    final shares = HomeWidgetMath.balanceShares([
      const HomeBalanceShare(walletId: 1, name: 'a', balance: 10),
      const HomeBalanceShare(walletId: 2, name: 'b', balance: 50),
      const HomeBalanceShare(walletId: 3, name: 'c', balance: 0),
      const HomeBalanceShare(walletId: 4, name: 'd', balance: 30),
      const HomeBalanceShare(walletId: 5, name: 'e', balance: 5),
      const HomeBalanceShare(walletId: 6, name: 'f', balance: 20),
    ], othersName: 'others');

    expect(shares.map((share) => share.walletId), [2, 4, 6, null]);
    expect(shares.last.balance, 15);
    expect(shares.last.name, 'others');
  });

  test('four or fewer funded wallets are shown without others', () {
    final shares = HomeWidgetMath.balanceShares([
      for (var i = 1; i <= 4; i++) HomeBalanceShare(walletId: i, name: '$i', balance: i),
    ]);

    expect(shares.map((share) => share.walletId), [4, 3, 2, 1]);
  });

  group('fake data', () {
    test('the seed is the same for the same parts and differs otherwise', () {
      expect(HomeWidgetMath.seed(['trend', 1, 2, 7]), HomeWidgetMath.seed(['trend', 1, 2, 7]));
      expect(HomeWidgetMath.seed(['trend', 1, 2, 7]), isNot(HomeWidgetMath.seed(['trend', 1, 3, 7])));
    });

    test('a fake trend ends at the fake balance and repeats for the same seed', () {
      final trend = HomeWidgetMath.fakeTrend(end: 150000000, seed: 42, points: 7);

      expect(trend, hasLength(7));
      expect(trend.last, 150000000);
      expect(trend.every((value) => value >= 0), isTrue);
      expect(HomeWidgetMath.fakeTrend(end: 150000000, seed: 42, points: 7), trend);
      expect(HomeWidgetMath.fakeTrend(end: 150000000, seed: 43, points: 7), isNot(trend));
    });

    test(
      'fake recent transactions fill the widget within the last month, newest first, and repeat for the same seed',
      () {
        final wallets = [(walletId: 1, walletName: 'Main', balance: 100000000)];
        List<HomeRecentTransaction> make(int seed) =>
            HomeWidgetMath.fakeRecentTransactions(seed: seed, now: now, wallets: wallets);

        for (var seed = 0; seed < 20; seed++) {
          final transactions = make(seed);
          expect(transactions.length, 3);
          for (final tx in transactions) {
            expect(now.difference(tx.time).inDays, lessThanOrEqualTo(30));
            expect(tx.walletName, 'Main');
            expect(tx.amount > 0, tx.type == TransactionType.received);
          }
          for (var i = 1; i < transactions.length; i++) {
            expect(transactions[i - 1].time.isAfter(transactions[i].time), isTrue);
          }
          expect(make(seed).map((tx) => tx.amount), transactions.map((tx) => tx.amount));
        }
      },
    );

    test('no fake transactions without a funded wallet', () {
      expect(
        HomeWidgetMath.fakeRecentTransactions(seed: 1, now: now, wallets: [(walletId: 1, walletName: 'x', balance: 0)]),
        isEmpty,
      );
    });

    test('fake utxo buckets are empty for a zero balance', () {
      expect(HomeWidgetMath.fakeUtxoBuckets(seed: 1, total: 0).total, 0);
      expect(HomeWidgetMath.fakeUtxoBuckets(seed: 1, total: 50000000).total, greaterThan(0));
    });
  });

  test('a month of daily activity is grouped into six five-day bars that keep every count', () {
    final days = [
      for (var i = 0; i < 30; i++) HomeDailyActivity(day: DateTime(2026, 9, 1 + i), received: 1, sent: i == 29 ? 2 : 0),
    ];
    final grouped = HomeWidgetMath.groupActivity(days);
    expect(grouped.length, 6);
    expect(grouped.first.day, DateTime(2026, 9, 1));
    expect(grouped[1].day, DateTime(2026, 9, 6));
    expect(grouped.every((bar) => bar.received == 5), isTrue);
    expect(grouped.last.sent, 2);
    expect(HomeWidgetMath.groupActivity(days.take(7).toList()), days.take(7).toList());
  });

  test('three months are grouped into seven two-week bars and a year into calendar months', () {
    final today = DateTime(2026, 10, 8);
    final quarter = [for (final day in HomeWidgetMath.lastDays(today, 90)) HomeDailyActivity(day: day, received: 1)];
    final twoWeeks = HomeWidgetMath.groupActivity(quarter, groupDays: 14);
    expect(twoWeeks.length, 7);
    expect(twoWeeks.first.received, 14);
    expect(twoWeeks.last.received, 6);

    final days = HomeWidgetMath.daysSinceMonthsAgo(today, 12);
    expect(HomeWidgetMath.lastDays(today, days).first, DateTime(2025, 11, 1));
    final months = HomeWidgetMath.groupActivityByMonth([
      for (final day in HomeWidgetMath.lastDays(today, days)) HomeDailyActivity(day: day, sent: 1),
    ]);
    expect(months.length, 12);
    expect(months.first.day, DateTime(2025, 11));
    expect(months.first.sent, 30);
    expect(months.last.day, DateTime(2026, 10));
    expect(months.last.sent, 8);
  });

  test('utxo buckets add up each bucket and activity totals count amounts and organizing fees', () {
    final buckets = HomeWidgetMath.utxoBuckets([20000000, 15000000, 2000000, 50000]);
    expect(buckets.counts, [2, 1, 0, 1]);
    expect(buckets.amounts, [35000000, 2000000, 0, 50000]);

    final now = DateTime(2026, 10, 8);
    TransactionRecord tx(TransactionType type, int amount, int fee) =>
        TransactionRecord('h$type$amount', now, 1, type, null, amount, fee, const [], const [], 0, now);
    final totals = HomeWidgetMath.activityTotals([
      tx(TransactionType.received, 5000, 0),
      tx(TransactionType.received, 3000, 0),
      tx(TransactionType.sent, -2000, 150),
      tx(TransactionType.self, -300, 300),
    ]);
    expect(totals.receivedCount, 2);
    expect(totals.receivedSats, 8000);
    expect(totals.sentCount, 1);
    expect(totals.sentSats, 2000);
    expect(totals.organizedCount, 1);
    expect(totals.organizedFeeSats, 300);
  });

  test('fake utxo amounts add up to the fake balance', () {
    final buckets = HomeWidgetMath.fakeUtxoBuckets(seed: 3, total: 50000000);
    expect(buckets.amounts.fold<int>(0, (sum, amount) => sum + amount), closeTo(50000000, 4));
  });
}
