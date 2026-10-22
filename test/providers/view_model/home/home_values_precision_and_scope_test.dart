import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/providers/view_model/home/widget_configure_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

import '../../../mock/utxo_mock.dart';
import '../../../mock/wallet_mock.dart';

/// Disposable in-memory ids. Protected device wallets 1 and 2 are not used.
const _alphaId = 11;
const _betaId = 12;
const _staleId = 99;

const _smallAmounts = <int, int>{21: 1, 22: 4999, 23: 5000, 24: 9999};
const _normalSats = 123000000;

const _btcNumbers = <int, String>{
  1: '0.0000 0001',
  4999: '0.0000 4999',
  5000: '0.0000 5000',
  9999: '0.0000 9999',
  19999: '0.0001 9999',
  _normalSats: '1.23',
};

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  final List<WalletItemBase> items;
  final Map<int, int> balances;
  final Map<int, List<TransactionRecord>> transactions;
  final Map<int, List<UtxoState>> utxos;

  _Wallets({required this.items, required this.balances, required this.transactions, required this.utxos});

  @override
  WalletLoadState get walletLoadState => WalletLoadState.loadCompleted;

  @override
  late final ValueNotifier<WalletLoadState> walletLoadStateNotifier = ValueNotifier(walletLoadState);

  @override
  late final ValueNotifier<List<WalletItemBase>> walletItemListNotifier = ValueNotifier(items);

  @override
  List<WalletItemBase> get walletItemList => items;

  @override
  Balance getWalletBalance(int walletId) => Balance(balances[walletId] ?? 0, 0);

  @override
  List<TransactionRecord> getTransactionRecordList(int walletId) => transactions[walletId] ?? const [];

  @override
  List<TransactionRecord> getConfirmedTransactionRecordListWithinDateRange(
    List<int> walletIds,
    Tuple2<DateTime, DateTime> dateRange,
  ) => [
    for (final id in walletIds)
      for (final tx in getTransactionRecordList(id))
        if (tx.blockHeight > 0) tx,
  ];

  @override
  List<UtxoState> getUtxoList(int walletId) => utxos[walletId] ?? const [];
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  _Preferences(this.currentUnit);

  @override
  BitcoinUnit currentUnit;

  @override
  FiatCode get selectedFiat => FiatCode.KRW;

  @override
  bool get isFakeBalanceActive => false;

  @override
  int? get fakeBalanceTotalAmount => null;

  @override
  List<int> get walletOrder => const [];

  @override
  double getFakeBalance(int walletId) => 0;

  @override
  UtxoTierTheme get utxoTierTheme => UtxoTierThemes.pastelWallet;
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {}

TransactionRecord _received(DateTime time, int amount) => TransactionRecord(
  'disposable-${time.millisecondsSinceEpoch}-$amount',
  time,
  100,
  TransactionType.received,
  null,
  amount,
  0,
  const [],
  const [],
  141.0,
  time,
);

_Wallets _scopeWallets() {
  final today = DateTime(2026, 10, 22, 12);
  final older = DateTime(today.year, today.month - 1, today.day, 12);
  return _Wallets(
    items: [
      WalletMock.createSingleSigWalletItem(id: _alphaId, name: 'DisposableAlpha-'),
      WalletMock.createSingleSigWalletItem(id: _betaId, name: 'DisposableBeta-'),
    ],
    balances: {_alphaId: 4999, _betaId: _normalSats},
    transactions: {
      _alphaId: [_received(today, 4999)],
      _betaId: [_received(older, _normalSats), _received(today, 1000)],
    },
    utxos: {
      _betaId: [UtxoMock.createMockUtxoState(amount: _normalSats, blockHeight: 100)],
    },
  );
}

HomeWidgetsViewModel _viewModel(
  _Wallets wallets,
  _Preferences preferences, {
  int? Function(int walletId)? targetSatsOf,
}) {
  final viewModel = HomeWidgetsViewModel(
    walletProvider: wallets,
    preferenceProvider: preferences,
    priceProvider: _Prices(),
    targetSatsOf: targetSatsOf ?? (_) => null,
    now: () => DateTime(2026, 10, 22, 12),
    usesFakeBalance: false,
  );
  return viewModel;
}

HomeItem _item(
  String definitionId, {
  List<int>? walletIds,
  bool storeWalletIds = false,
  HomeSpan span = HomeSpan.wide,
}) {
  return HomeItem(
    id: 'staged-$definitionId',
    definitionId: definitionId,
    kind: HomeItemKind.widget,
    order: 0,
    span: span,
    configuration: storeWalletIds ? {'walletIds': walletIds ?? const <int>[]} : const {},
  );
}

Future<void> _pump(WidgetTester tester, HomeWidgetsViewModel viewModel, String definitionId, HomeItem item, Size size) {
  final definition = builtinHomeWidgets().whereType<BuiltinHomeWidget>().firstWhere(
    (widget) => widget.id == definitionId,
  );
  return tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Scaffold(
        body: ChangeNotifierProvider<HomeWidgetsViewModel>.value(
          value: viewModel,
          child: Center(
            child: SizedBox.fromSize(size: size, child: Builder(builder: (context) => definition.build(context, item))),
          ),
        ),
      ),
    ),
  );
}

String _row(BitcoinUnit unit, int sats) {
  final number = unit.displayBitcoinAmount(sats);
  return unit.isPrefixSymbol ? '${unit.symbol} $number' : '$number ${unit.symbol}';
}

void main() {
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
  });

  testWidgets('balance by wallet shows the app BTC formatter for 1, 4999, 5000, 9999 and a normal amount', (
    tester,
  ) async {
    for (final entry in _btcNumbers.entries) {
      expect(BitcoinUnit.btc.displayBitcoinAmount(entry.key), entry.value, reason: '${entry.key} sats');
    }

    final wallets = _Wallets(
      items: [for (final id in _smallAmounts.keys) WalletMock.createSingleSigWalletItem(id: id, name: 'Small-')],
      balances: _smallAmounts,
      transactions: const {},
      utxos: const {},
    );
    final viewModel = _viewModel(wallets, _Preferences(BitcoinUnit.btc));
    await _pump(
      tester,
      viewModel,
      HomeItemIds.balanceByWallet,
      _item(HomeItemIds.balanceByWallet),
      const Size(328, 156),
    );

    expect(tester.takeException(), isNull);
    for (final sats in _smallAmounts.values) {
      expect(find.text(_row(BitcoinUnit.btc, sats)), findsOneWidget, reason: '$sats sats');
      expect(find.text('0.0000 BTC'), findsNothing);
      expect(find.text('0.0001 BTC'), findsNothing);
    }
    expect(
      find.descendant(of: find.byKey(const Key('balance-by-wallet-total')), matching: find.text('0.0001 9999')),
      findsOneWidget,
    );

    final normal = _Wallets(
      items: [WalletMock.createSingleSigWalletItem(id: 25, name: 'Normal-')],
      balances: const {25: _normalSats},
      transactions: const {},
      utxos: const {},
    );
    final normalModel = _viewModel(normal, _Preferences(BitcoinUnit.btc));
    await _pump(
      tester,
      normalModel,
      HomeItemIds.balanceByWallet,
      _item(HomeItemIds.balanceByWallet),
      const Size(328, 156),
    );
    expect(tester.takeException(), isNull);
    expect(find.text(_row(BitcoinUnit.btc, _normalSats)), findsOneWidget);
    expect(find.text('1.0000 BTC'), findsNothing);
    viewModel.dispose();
    normalModel.dispose();
  });

  testWidgets('a comma decimal preset stays on the balance-by-wallet rows', (tester) async {
    NumberFormatConfig.instance.applyPreset(NumberFormatPreset.commaDecimal);
    expect(BitcoinUnit.btc.displayBitcoinAmount(4999), '0,0000 4999');
    expect(BitcoinUnit.btc.displayBitcoinAmount(5000), '0,0000 5000');

    final wallets = _Wallets(
      items: [WalletMock.createSingleSigWalletItem(id: 22, name: 'Comma-')],
      balances: const {22: 4999},
      transactions: const {},
      utxos: const {},
    );
    final viewModel = _viewModel(wallets, _Preferences(BitcoinUnit.btc));
    await _pump(
      tester,
      viewModel,
      HomeItemIds.balanceByWallet,
      _item(HomeItemIds.balanceByWallet),
      const Size(328, 156),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('0,0000 4999 BTC'), findsOneWidget);
    expect(find.text('0.0000 BTC'), findsNothing);
    viewModel.dispose();
  });

  testWidgets('sats and bip177 keep the full integer on the same widget', (tester) async {
    final wallets = _Wallets(
      items: [WalletMock.createSingleSigWalletItem(id: 22, name: 'Integer-')],
      balances: const {22: 4999},
      transactions: const {},
      utxos: const {},
    );
    final sats = _viewModel(wallets, _Preferences(BitcoinUnit.sats));
    await _pump(tester, sats, HomeItemIds.balanceByWallet, _item(HomeItemIds.balanceByWallet), const Size(328, 156));
    expect(tester.takeException(), isNull);
    expect(find.text(_row(BitcoinUnit.sats, 4999)), findsOneWidget);
    expect(find.text('4,999 sats'), findsOneWidget);
    expect(find.text('0.0000 BTC'), findsNothing);

    final bip177 = _viewModel(wallets, _Preferences(BitcoinUnit.bip177));
    await _pump(tester, bip177, HomeItemIds.balanceByWallet, _item(HomeItemIds.balanceByWallet), const Size(328, 156));
    expect(tester.takeException(), isNull);
    expect(find.text(_row(BitcoinUnit.bip177, 4999)), findsOneWidget);
    expect(find.text('₿ 4,999'), findsOneWidget);
    sats.dispose();
    bip177.dispose();
  });

  test('null sums every wallet, and an empty or fully stale explicit selection does not', () {
    final wallets = _scopeWallets();
    final viewModel = _viewModel(
      wallets,
      _Preferences(BitcoinUnit.btc),
      targetSatsOf: (id) => id == _alphaId ? 100000 : null,
    );
    final today = DateTime(2026, 10, 22);
    final older = DateTime(today.year, today.month - 1, today.day);
    final spanned =
        DateTime.utc(
          today.year,
          today.month,
          today.day,
        ).difference(DateTime.utc(older.year, older.month, older.day)).inDays +
        1;

    expect(viewModel.totalBalance(null), 4999 + _normalSats);
    expect(viewModel.totalBalance(const []), 0);
    expect(viewModel.totalBalance(const [_alphaId]), 4999);
    expect(viewModel.totalBalance(const [_alphaId, _staleId]), 4999);
    expect(viewModel.totalBalance(const [_staleId]), 0);

    expect(viewModel.balanceShares(walletIds: null, othersName: 'others').map((share) => share.walletId).toList(), [
      _betaId,
      _alphaId,
    ]);
    expect(viewModel.balanceShares(walletIds: const [], othersName: 'others'), isEmpty);
    expect(
      viewModel.balanceShares(walletIds: const [_alphaId, _staleId], othersName: 'others').single.walletId,
      _alphaId,
    );
    expect(viewModel.balanceShares(walletIds: const [_staleId], othersName: 'others'), isEmpty);

    expect(viewModel.recentTransactions(walletIds: null).map((tx) => tx.walletId), containsAll([_alphaId, _betaId]));
    expect(viewModel.recentTransactions(walletIds: const []), isEmpty);
    expect(viewModel.recentTransactions(walletIds: const [_alphaId]).single.walletId, _alphaId);
    expect(viewModel.recentTransactions(walletIds: const [_staleId]), isEmpty);

    expect(viewModel.utxoBuckets(walletIds: null).total, 1);
    expect(viewModel.utxoBuckets(walletIds: const []).total, 0);
    expect(viewModel.utxoBuckets(walletIds: const [_staleId]).total, 0);
    expect(viewModel.utxoBuckets(walletIds: const [_staleId]).counts, [0, 0, 0, 0]);

    expect(viewModel.activityTotals(walletIds: const [_staleId]).receivedCount, 0);
    expect(viewModel.activityTotals(walletIds: null).receivedCount, greaterThan(0));
    expect(viewModel.dailyActivity(walletIds: const [_staleId]).fold<int>(0, (sum, day) => sum + day.received), 0);
    expect(viewModel.dailyBalances(walletIds: const [_staleId]), everyElement(0));
    expect(viewModel.savingsGoal(walletIds: const [_staleId]), isNull);
    expect(viewModel.savingsGoal(walletIds: const [_alphaId])?.balance, 4999);
    expect(viewModel.savingsGoal(walletIds: null)?.balance, 4999);

    expect(viewModel.daysSinceFirstTransaction(walletIds: null), spanned);
    expect(viewModel.daysSinceFirstTransaction(walletIds: const []), HomeWidgetsViewModel.defaultDays);
    expect(viewModel.daysSinceFirstTransaction(walletIds: const [_staleId]), HomeWidgetsViewModel.defaultDays);
    expect(spanned, greaterThan(HomeWidgetsViewModel.defaultDays));
    viewModel.dispose();
  });

  testWidgets('a stale nonempty selection renders empty states and does not name the other wallets', (tester) async {
    final wallets = _scopeWallets();
    final viewModel = _viewModel(
      wallets,
      _Preferences(BitcoinUnit.btc),
      targetSatsOf: (id) => id == _alphaId ? 100000 : null,
    );
    final stale = const [_staleId];

    await _pump(
      tester,
      viewModel,
      HomeItemIds.balanceByWallet,
      _item(HomeItemIds.balanceByWallet, walletIds: stale, storeWalletIds: true),
      const Size(328, 156),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('DisposableAlpha-$_alphaId'), findsNothing);
    expect(find.text('DisposableBeta-$_betaId'), findsNothing);
    expect(find.byKey(const ValueKey('balance-by-wallet-entry-$_alphaId')), findsNothing);
    expect(find.byKey(const ValueKey('balance-by-wallet-entry-$_betaId')), findsNothing);
    expect(
      find.descendant(of: find.byKey(const Key('balance-by-wallet-total')), matching: find.text('0')),
      findsOneWidget,
    );

    await _pump(
      tester,
      viewModel,
      HomeItemIds.recentTransactions,
      _item(HomeItemIds.recentTransactions, walletIds: stale, storeWalletIds: true),
      const Size(328, 156),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('recent-transactions-empty')), findsOneWidget);
    expect(find.text('DisposableAlpha-$_alphaId'), findsNothing);
    expect(find.text('DisposableBeta-$_betaId'), findsNothing);

    await _pump(
      tester,
      viewModel,
      HomeItemIds.transactionActivity,
      _item(HomeItemIds.transactionActivity, walletIds: stale, storeWalletIds: true),
      const Size(328, 156),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('transaction-activity-empty')), findsOneWidget);

    await _pump(
      tester,
      viewModel,
      HomeItemIds.savingsGoal,
      _item(HomeItemIds.savingsGoal, walletIds: stale, storeWalletIds: true, span: HomeSpan.small),
      const Size(156, 156),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('savings-goal-empty')), findsOneWidget);

    await _pump(
      tester,
      viewModel,
      HomeItemIds.utxoStatus,
      _item(HomeItemIds.utxoStatus, walletIds: stale, storeWalletIds: true, span: HomeSpan.small),
      const Size(156, 156),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('1 (100.0%)'), findsNothing);
    expect(find.text('0 (0%)'), findsNWidgets(4));

    await _pump(
      tester,
      viewModel,
      HomeItemIds.balanceByWallet,
      _item(HomeItemIds.balanceByWallet, walletIds: const [_alphaId], storeWalletIds: true),
      const Size(328, 156),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('DisposableAlpha-$_alphaId'), findsOneWidget);
    expect(find.text('DisposableBeta-$_betaId'), findsNothing);
    expect(find.text(_row(BitcoinUnit.btc, 4999)), findsWidgets);
    viewModel.dispose();
  });

  test('a saved nonempty wallet list that matches nothing stays a selection, not every wallet', () {
    final items = _scopeWallets().items;
    WidgetConfigureViewModel open(HomeWidgetSettings? initial) {
      final viewModel = WidgetConfigureViewModel(
        spec: const HomeWidgetSettingsSpec(wallets: true),
        wallets: items,
        preferenceProvider: _Preferences(BitcoinUnit.btc),
        initial: initial,
      );
      addTearDown(viewModel.dispose);
      return viewModel;
    }

    final all = open(null);
    expect(all.allWallets, isTrue);
    expect(all.settings.walletIds, isNull);

    final omitted = open(const HomeWidgetSettings());
    expect(omitted.allWallets, isTrue);
    expect(omitted.settings.walletIds, isNull);

    final mixed = open(const HomeWidgetSettings(walletIds: [_alphaId, _staleId]));
    expect(mixed.allWallets, isFalse);
    expect(mixed.settings.walletIds, [_alphaId]);
    expect(mixed.isWalletSelected(_betaId), isFalse);

    final stale = open(const HomeWidgetSettings(walletIds: [_staleId]));
    expect(stale.allWallets, isFalse);
    expect(stale.settings.walletIds, isEmpty);
    expect(stale.isWalletSelected(_alphaId), isFalse);
    expect(stale.isWalletSelected(_betaId), isFalse);

    final empty = open(const HomeWidgetSettings(walletIds: []));
    expect(empty.allWallets, isFalse);
    expect(empty.settings.walletIds, isEmpty);
  });
}
