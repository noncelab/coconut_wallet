import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/services/home/home_widget_math.dart';
import 'package:coconut_wallet/services/home/wallet_balance_detail_math.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionRecord _tx(DateTime time, int amount) => TransactionRecord(
  'tx-$time-$amount',
  time,
  1,
  TransactionType.received,
  null,
  amount,
  0,
  const [],
  const [],
  0,
  time,
);

WalletBalanceInput _wallet(
  int id,
  List<int> balances, {
  String? name,
  DateTime? first,
  List<WalletKindTag> tags = const [],
}) => WalletBalanceInput(walletId: id, name: name ?? 'w$id', balances: balances, firstTransactionAt: first, tags: tags);

void main() {
  final today = DateTime(2026, 11, 26);
  final days = HomeWidgetMath.lastDays(today, 4); // 11/23 ~ 11/26

  group('shareOf', () {
    test('is the ratio of the total and 0 when the total is empty', () {
      expect(WalletBalanceDetailMath.shareOf(25, 100), 0.25);
      expect(WalletBalanceDetailMath.shareOf(0, 100), 0);
      expect(WalletBalanceDetailMath.shareOf(5, 0), 0);
    });
  });

  group('compose', () {
    final wallets = [
      _wallet(1, [50, 55, 60, 60]),
      _wallet(2, [30, 28, 25, 24]),
      _wallet(3, [10, 10, 10, 10]),
      _wallet(4, [0, 0, 5, 6]),
    ];

    test('shares use the sum of the included wallets and add up to 1', () {
      final result = WalletBalanceDetailMath.compose(wallets: wallets, excluded: {}, days: days);
      expect(result.total, 100);
      expect(result.change, 100 - 90);
      expect(result.rows.map((row) => row.share), [0.6, 0.24, 0.1, 0.06]);
      expect(result.rows.fold<double>(0, (sum, row) => sum + row.share), closeTo(1, 1e-9));
      expect(result.isSingle, isFalse);
    });

    test('excluding a wallet recomputes total, shares and change from the rest', () {
      final result = WalletBalanceDetailMath.compose(wallets: wallets, excluded: {2}, days: days);
      expect(result.rows.map((row) => row.walletId), [1, 3, 4]);
      expect(result.total, 76);
      expect(result.totals, [60, 65, 75, 76]);
      expect(result.change, 76 - 60);
      expect(result.rows.first.share, closeTo(60 / 76, 1e-9));
      expect(result.rows.fold<double>(0, (sum, row) => sum + row.share), closeTo(1, 1e-9));
    });

    test('one included wallet switches to the single layout with 100% share', () {
      final result = WalletBalanceDetailMath.compose(wallets: wallets, excluded: {2, 3, 4}, days: days);
      expect(result.isSingle, isTrue);
      expect(result.rows.single.share, 1);
      expect(result.totals, [50, 55, 60, 60]);
    });

    test('a single existing wallet is single and every wallet excluded falls back to all', () {
      expect(WalletBalanceDetailMath.compose(wallets: [wallets.first], excluded: {}, days: days).isSingle, isTrue);
      final all = WalletBalanceDetailMath.compose(wallets: wallets, excluded: {1, 2, 3, 4}, days: days);
      expect(all.rows.length, 4);
    });

    test('a wallet added during the period is 0 before it and a day with a zero total has 0 shares', () {
      final result = WalletBalanceDetailMath.compose(wallets: wallets, excluded: {}, days: days);
      final added = result.rows.firstWhere((row) => row.walletId == 4);
      expect(added.input.balances.take(2), [0, 0]);
      final firstDay = result.sharesAt(0);
      expect(firstDay[result.stack.indexWhere((wallet) => wallet.walletId == 4)], 0);
      expect(firstDay.fold<double>(0, (sum, value) => sum + value), closeTo(1, 1e-9));

      final empty = WalletBalanceDetailMath.compose(
        wallets: [
          _wallet(1, [0, 0, 0, 0]),
          _wallet(2, [0, 0, 0, 0]),
        ],
        excluded: {},
        days: days,
      );
      expect(empty.sharesAt(2), [0.0, 0.0]);
      expect(empty.rows.map((row) => row.share), [0.0, 0.0]);
    });

    test('stack order is by current balance and does not depend on the list sort', () {
      final byChange = WalletBalanceDetailMath.compose(
        wallets: wallets,
        excluded: {},
        days: days,
        sort: WalletBalanceSort.change,
      );
      expect(byChange.stack.map((wallet) => wallet.walletId), [1, 2, 3, 4]);
    });
  });

  group('sort', () {
    final wallets = [
      _wallet(1, [60, 60, 60, 60]), // change 0
      _wallet(2, [30, 28, 25, 24]), // change -6
      _wallet(3, [0, 0, 5, 10]), // change +10
      _wallet(4, [0, 0, 5, 10]), // change +10, same balance as 3
    ];

    test('balance order is the default', () {
      final result = WalletBalanceDetailMath.compose(wallets: wallets, excluded: {}, days: days);
      expect(result.rows.map((row) => row.walletId), [1, 2, 3, 4]);
    });

    test('change order is signed descending, not absolute, and ties fall back to balance then position', () {
      final result = WalletBalanceDetailMath.compose(
        wallets: wallets,
        excluded: {},
        days: days,
        sort: WalletBalanceSort.change,
      );
      expect(result.rows.map((row) => row.walletId), [3, 4, 1, 2]);
    });

    test('equal change prefers the larger balance', () {
      final result = WalletBalanceDetailMath.compose(
        wallets: [
          _wallet(1, [0, 0, 0, 5]),
          _wallet(2, [10, 10, 10, 15]),
        ],
        excluded: {},
        days: days,
        sort: WalletBalanceSort.change,
      );
      expect(result.rows.map((row) => row.walletId), [2, 1]);
    });
  });

  group('toggleExcluded', () {
    test('excludes and restores a wallet', () {
      var excluded = WalletBalanceDetailMath.toggleExcluded({}, 2, [1, 2, 3]);
      expect(excluded, {2});
      excluded = WalletBalanceDetailMath.toggleExcluded(excluded, 2, [1, 2, 3]);
      expect(excluded, isEmpty);
    });

    test('the last remaining wallet cannot be excluded', () {
      expect(WalletBalanceDetailMath.toggleExcluded({1}, 2, [1, 2]), {1});
      expect(WalletBalanceDetailMath.toggleExcluded({}, 1, [1]), isEmpty);
      // 복원은 마지막 한 개일 때도 된다.
      expect(WalletBalanceDetailMath.toggleExcluded({1}, 1, [1, 2]), isEmpty);
    });

    test('ids of deleted wallets are dropped', () {
      expect(WalletBalanceDetailMath.toggleExcluded({9}, 2, [1, 2, 3]), {2});
      expect(WalletBalanceDetailMath.toggleExcluded({}, 9, [1, 2]), isEmpty);
    });
  });

  group('first active day', () {
    test('is the first transaction day only when the period starts at 0 and the first transaction is inside it', () {
      final input = _wallet(1, [0, 0, 5, 6], first: DateTime(2026, 11, 25, 9));
      expect(WalletBalanceDetailMath.firstActiveDay(input, days), DateTime(2026, 11, 25));
      // 기간 시작 잔액이 있으면 추가된 지갑이 아니다.
      expect(
        WalletBalanceDetailMath.firstActiveDay(_wallet(1, [4, 4, 5, 6], first: DateTime(2026, 11, 25)), days),
        isNull,
      );
      // 첫 거래가 기간 앞이면 없다.
      expect(
        WalletBalanceDetailMath.firstActiveDay(_wallet(1, [0, 0, 5, 6], first: DateTime(2026, 11, 1)), days),
        isNull,
      );
      expect(WalletBalanceDetailMath.firstActiveDay(_wallet(1, [0, 0, 0, 0]), days), isNull);
    });

    test('works with balances rebuilt from transactions: 0 until the first deposit', () {
      final transactions = [_tx(DateTime(2026, 11, 25, 10), 70000), _tx(DateTime(2026, 11, 26, 8), 30000)];
      final balances = HomeWidgetMath.dailyBalances(transactions, 100000, today, 4);
      expect(balances, [0, 0, 70000, 100000]);
      final input = _wallet(1, balances, first: DateTime(2026, 11, 25, 10));
      expect(WalletBalanceDetailMath.firstActiveDay(input, days), DateTime(2026, 11, 25));
      final result = WalletBalanceDetailMath.compose(wallets: [input], excluded: {}, days: days);
      expect(result.change, 100000);
      expect(result.rows.single.firstActiveDay, DateTime(2026, 11, 25));
    });
  });

  group('normalizeExcluded', () {
    test('drops ids of deleted wallets so the screen state matches what compose aggregates', () {
      // A(1)를 제외하고 B(2)만 포함한 상태에서 B가 삭제되면, 남은 지갑 A가 모두 제외된 상태가 된다.
      expect(WalletBalanceDetailMath.normalizeExcluded({1}, [1]), isEmpty);
      expect(WalletBalanceDetailMath.normalizeExcluded({1, 9}, [1, 2]), {1});
    });

    test('resets to empty when every remaining wallet is excluded', () {
      expect(WalletBalanceDetailMath.normalizeExcluded({1, 2}, [1, 2]), isEmpty);
    });

    test('keeps a valid exclusion and handles no wallets', () {
      expect(WalletBalanceDetailMath.normalizeExcluded({2}, [1, 2, 3]), {2});
      expect(WalletBalanceDetailMath.normalizeExcluded({}, [1, 2]), isEmpty);
      expect(WalletBalanceDetailMath.normalizeExcluded({1}, const []), isEmpty);
    });

    test('result agrees with compose: the scope notice and the aggregate use the same wallets', () {
      final wallets = [
        _wallet(1, [10, 10, 10, 10]),
      ];
      final excluded = WalletBalanceDetailMath.normalizeExcluded({1}, [1]);
      final result = WalletBalanceDetailMath.compose(wallets: wallets, excluded: excluded, days: days);
      expect(excluded, isEmpty);
      expect(result.rows.map((row) => row.walletId), [1]);
    });
  });

  group('balanceRows', () {
    test('stay in balance order whatever the list sort is, while rows follow the sort', () {
      // 잔액 A(1)=60, B(2)=40. 기간 변화 A=0, B=+10.
      final wallets = [
        _wallet(1, [60, 60, 60, 60]),
        _wallet(2, [30, 30, 35, 40]),
      ];
      final byBalance = WalletBalanceDetailMath.compose(wallets: wallets, excluded: {}, days: days);
      final byChange = WalletBalanceDetailMath.compose(
        wallets: wallets,
        excluded: {},
        days: days,
        sort: WalletBalanceSort.change,
      );
      expect(byBalance.rows.map((row) => row.walletId), [1, 2]);
      expect(byChange.rows.map((row) => row.walletId), [2, 1]);
      expect(byChange.balanceRows.map((row) => row.walletId), [1, 2]);
      expect(byBalance.balanceRows.map((row) => row.walletId), [1, 2]);
    });

    test('respect exclusion', () {
      final wallets = [
        _wallet(1, [60, 60, 60, 60]),
        _wallet(2, [1, 1, 1, 1]),
        _wallet(3, [5, 5, 5, 5]),
      ];
      final result = WalletBalanceDetailMath.compose(wallets: wallets, excluded: {1}, days: days);
      expect(result.balanceRows.map((row) => row.walletId), [3, 2]);
    });
  });

  group('tagsOf', () {
    test('hot, vault and watch-only are exclusive and multisig is added', () {
      expect(WalletBalanceDetailMath.tagsOf(hasLocalKey: true, isVault: false, isMultisig: false), [WalletKindTag.hot]);
      expect(WalletBalanceDetailMath.tagsOf(hasLocalKey: false, isVault: true, isMultisig: true), [
        WalletKindTag.vault,
        WalletKindTag.multisig,
      ]);
      expect(WalletBalanceDetailMath.tagsOf(hasLocalKey: false, isVault: false, isMultisig: false), [
        WalletKindTag.watchOnly,
      ]);
    });
  });
}
