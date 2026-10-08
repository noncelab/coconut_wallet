import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/converter/utxo.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/home_edit_screen.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/screens/home/hodl_insights_screen.dart';
import 'package:coconut_wallet/providers/view_model/home/hodl_insights_view_model.dart';
import 'package:coconut_wallet/screens/home/home_preset_preview_screen.dart';
import 'package:coconut_wallet/services/home/home_presets.dart';
import 'package:coconut_wallet/services/historical_bitcoin_price_service.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';

import '../../mock/utxo_mock.dart';
import '../../mock/wallet_mock.dart';

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  final List<WalletItemBase> wallets;
  final List<TransactionRecord> transactions;
  WalletLoadState loadState;

  _Wallets(this.wallets, this.transactions, {this.loadState = WalletLoadState.loadCompleted});

  @override
  WalletLoadState get walletLoadState => loadState;

  @override
  late final ValueNotifier<WalletLoadState> walletLoadStateNotifier = ValueNotifier(WalletLoadState.loadCompleted);

  @override
  late final ValueNotifier<List<WalletItemBase>> walletItemListNotifier = ValueNotifier(wallets);

  @override
  List<WalletItemBase> get walletItemList => wallets;

  @override
  Balance getWalletBalance(int walletId) => Balance(walletId * 10000000, 0);

  @override
  List<TransactionRecord> getTransactionRecordList(int walletId) => transactions;

  @override
  Map<int, List<TransactionRecord>> getPendingAndDaysAgoTransactions(List<int> walletIds, int days) => {
    for (final id in walletIds) id: transactions,
  };

  @override
  List<TransactionRecord> getConfirmedTransactionRecordListWithinDateRange(
    List<int> walletIds,
    Tuple2<DateTime, DateTime> dateRange,
  ) => transactions;

  @override
  List<UtxoState> getUtxoList(int walletId) => [
    mapRealmToUtxoState(UtxoMock.createMockUtxo(walletId: walletId, address: 'a$walletId', amount: 20000000)),
  ];
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  final bool isFakeBalanceActive;
  final BitcoinUnit unit;

  _Preferences({this.isFakeBalanceActive = false, this.unit = BitcoinUnit.btc});

  @override
  BitcoinUnit get currentUnit => unit;

  @override
  FiatCode get selectedFiat => FiatCode.KRW;

  @override
  List<int> get walletOrder => const [];

  @override
  List<int> get excludedFromTotalBalanceWalletIds => const [];

  @override
  double getFakeBalance(int walletId) => 12345678;

  @override
  UtxoTierTheme get utxoTierTheme => UtxoTierThemes.pastelWallet;

  @override
  int? get fakeBalanceTotalAmount => null;
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  bool available;

  _Prices({this.available = true});

  @override
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => !available || fiatCode == FiatCode.JPY ? null : 100000000;
}

class _History extends Fake implements HistoricalBitcoinPriceService {
  @override
  Future<List<double>?> fetchDailyCloses(FiatCode fiatCode) async => [for (var i = 0; i < 31; i++) 90000000.0 + i];
}

HomeWidgetsViewModel? _widgetsViewModel;

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  _widgetsViewModel?.dispose();
  _widgetsViewModel = null;
}

Future<void> _openWidgetsTab(
  WidgetTester tester, {
  required bool fake,
  Widget Function(HomeViewModel viewModel)? screen,
  WalletLoadState loadState = WalletLoadState.loadCompleted,
  bool pricesAvailable = true,
  BitcoinUnit unit = BitcoinUnit.btc,
  Size size = const Size(800, 6000),
  List<WalletItemBase>? walletList,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
  final repository = HomeConfigurationRepository(prefs);
  await repository.save(HomeConfiguration(items: const []));
  final now = DateTime.now();
  final wallets =
      walletList ?? [WalletMock.createSingleSigWalletItem(id: 1), WalletMock.createMultiSigWalletItem(id: 2)];
  final transactions = [
    TransactionRecord(
      'a',
      now.subtract(const Duration(hours: 2)),
      1,
      TransactionType.received,
      null,
      5000000,
      0,
      const [],
      const [],
      0,
      now,
    ),
    TransactionRecord(
      'b',
      now.subtract(const Duration(days: 3)),
      1,
      TransactionType.sent,
      null,
      -1000000,
      0,
      const [],
      const [],
      0,
      now,
    ),
  ];
  final homeViewModel = HomeViewModel(repository: repository, wallets: () => wallets, onShortcutTap: (_, __) {});
  final widgetsViewModel =
      _widgetsViewModel = HomeWidgetsViewModel(
        walletProvider: _Wallets(wallets, transactions, loadState: loadState),
        preferenceProvider: _Preferences(isFakeBalanceActive: fake, unit: unit),
        priceProvider: _Prices(available: pricesAvailable),
        targetSatsOf: (id) => id == 1 ? 100000000 : null,
        historicalPriceService: _History(),
      );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences(isFakeBalanceActive: fake)),
        ChangeNotifierProvider.value(value: homeViewModel),
        ChangeNotifierProvider.value(value: widgetsViewModel),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        home: screen?.call(homeViewModel) ?? const HomeEditScreen(initialTab: HomeEditTab.widgets),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  for (final fake in [false, true]) {
    testWidgets('every built-in widget renders with its title in the widgets tab (fake balance: $fake)', (
      tester,
    ) async {
      await _openWidgetsTab(tester, fake: fake);

      expect(tester.takeException(), isNull);
      for (final definition in builtinHomeWidgets()) {
        expect(find.byKey(ValueKey('home-edit-widget-${definition.id}')), findsOneWidget, reason: definition.id);
        expect(
          find.descendant(
            of: find.byKey(ValueKey('home-edit-widget-${definition.id}')),
            matching: find.text(definition.displayName()),
          ),
          findsAtLeastNWidgets(1),
          reason: definition.id,
        );
      }
      expect(find.text(t.home_widgets.recent_transactions), findsOneWidget);
      for (final definition in builtinHomeWidgets()) {
        final name = find.byKey(ValueKey('home-edit-widget-name-${definition.id}'));
        expect(tester.widget<Text>(name).maxLines, 1, reason: definition.id);
        expect(tester.renderObject<RenderParagraph>(name).didExceedMaxLines, isFalse, reason: definition.id);
      }
      await _close(tester);
    });
  }

  testWidgets('while wallets load, every widget that needs wallet data shows a skeleton', (tester) async {
    await _openWidgetsTab(tester, fake: false, loadState: WalletLoadState.loadingFromDB);

    for (final definition in builtinHomeWidgets()) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('home-edit-widget-${definition.id}')),
          matching: find.byKey(const Key('home-widget-skeleton')),
        ),
        {HomeItemIds.fiatValues, HomeItemIds.fiatPriceTrend}.contains(definition.id) ? findsNothing : findsOneWidget,
        reason: definition.id,
      );
    }
    await _close(tester);
  });

  testWidgets('without a price, price widgets show a skeleton only for a while', (tester) async {
    await _openWidgetsTab(tester, fake: false, pricesAvailable: false);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-edit-widget-${HomeItemIds.fiatValues}')),
        matching: find.byKey(const Key('home-widget-skeleton')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-edit-widget-${HomeItemIds.utxoStatus}')),
        matching: find.byKey(const Key('home-widget-skeleton')),
      ),
      findsNothing,
    );

    await tester.pump(HomeWidgetsViewModel.priceWaitLimit + const Duration(seconds: 1));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('home-widget-skeleton')), findsNothing);
    await _close(tester);
  });

  testWidgets('every widget preview in Edit Home has a shadow from the home widget shadow token', (tester) async {
    await _openWidgetsTab(tester, fake: false);
    final shadowColor = tester.element(find.byType(HomeEditScreen)).coconutColors.homeWidgetShadow;

    for (final definition in builtinHomeWidgets()) {
      final box = tester.widget<DecoratedBox>(find.byKey(ValueKey('home-edit-widget-shadow-${definition.id}')));
      expect((box.decoration as BoxDecoration).boxShadow!.single.color, shadowColor, reason: definition.id);
    }
    await _close(tester);
  });

  testWidgets('wallet widgets: all-wallet, watch-only and hot stacks once each, shown as 4×2', (tester) async {
    await _openWidgetsTab(tester, fake: false);
    Rect rectOf(String id) => tester.getRect(find.byKey(ValueKey('home-edit-widget-$id')));

    final all = rectOf(HomeItemIds.allWalletStack);
    final watch = rectOf(HomeItemIds.watchOnlyWalletStack);
    final hot = rectOf(HomeItemIds.hotWalletStack);
    expect(all.top, lessThan(watch.top));
    expect(watch.top, lessThan(hot.top));
    expect(all.width, rectOf(HomeItemIds.balanceByWallet).width);
    expect(rectOf(HomeItemIds.balanceByWallet).top, greaterThan(hot.top));
    await _close(tester);
  });

  testWidgets('an added widget keeps a gap between its name and "added", which ignores the system text size', (
    tester,
  ) async {
    await _openWidgetsTab(tester, fake: false);
    final viewModel = tester.element(find.byType(HomeEditScreen)).read<HomeViewModel>();
    viewModel.addItem(viewModel.registry.byId(HomeItemIds.bitcoinBalanceTrend)!);
    await tester.pump();

    final name = tester.getRect(find.byKey(const ValueKey('home-edit-widget-name-${HomeItemIds.bitcoinBalanceTrend}')));
    final added = find.byKey(const ValueKey('home-edit-added-${HomeItemIds.bitcoinBalanceTrend}'));
    expect(tester.getRect(added).left - name.right, greaterThanOrEqualTo(8));
    expect(tester.widget<Text>(added).textScaler, TextScaler.noScaling);
    await _close(tester);
  });

  for (final preset in builtinHomePresets()) {
    testWidgets('the ${preset.id} preset preview renders the real home grid', (tester) async {
      await _openWidgetsTab(tester, fake: false, screen: (_) => HomePresetPreviewScreen(preset: preset));

      expect(tester.takeException(), isNull);
      expect(find.text(preset.name()), findsOneWidget);
      expect(find.byKey(const Key('home-preset-preview-apply')), findsOneWidget);
      final button = tester.widget<FixedBottomButton>(find.byType(FixedBottomButton));
      expect(button.showSurroundings, isTrue);
      expect(
        button.surroundingsColor,
        tester.element(find.byType(HomePresetPreviewScreen)).coconutColors.homeBackground,
      );

      await tester.drag(find.byKey(const Key('home-preset-preview-scroll')), const Offset(0, -5000));
      await tester.pumpAndSettle();
      final lastItemBottom = tester.getRect(find.byType(HomeItemsView)).bottom;
      final buttonTop = tester.getRect(find.byKey(const Key('home-preset-preview-apply'))).top;
      expect(lastItemBottom, lessThanOrEqualTo(buttonTop));
      await _close(tester);
    });
  }

  group('widget settings', () {
    HomeViewModel homeViewModelOf(WidgetTester tester) =>
        tester.element(find.byType(HomeEditScreen)).read<HomeViewModel>();

    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('a balance widget asks for its settings before it is added', (tester) async {
      await _openWidgetsTab(tester, fake: false);
      await tapKey(tester, const ValueKey('home-edit-add-${HomeItemIds.bitcoinBalanceByFiat}'));

      expect(find.text(t.home_edit.configure_widget), findsOneWidget);
      expect(find.text(t.home_edit.configure_widget_description_add), findsOneWidget);
      expect(find.text(t.home_edit.currency_default), findsOneWidget);
      expect(find.byKey(const Key('widget-configure-fake-balance')), findsOneWidget);
      expect(homeViewModelOf(tester).configuration.items, isEmpty);

      await tapKey(tester, const ValueKey('widget-configure-fiat-USD'));
      await tapKey(tester, const ValueKey('widget-configure-wallet-2'));
      await tapKey(tester, const Key('widget-configure-submit'));

      final item =
          homeViewModelOf(tester).itemOf(homeViewModelOf(tester).registry.byId(HomeItemIds.bitcoinBalanceByFiat)!)!;
      expect(item.configuration, {
        'walletIds': [2],
        'fiats': ['KRW', 'JPY', 'EUR'],
      });
      expect(find.text(t.home_edit.configure_widget), findsNothing);
      await _close(tester);
    });

    testWidgets('fiat price trend offers only one week and one month, activity offers all four', (tester) async {
      await _openWidgetsTab(tester, fake: false);
      await tapKey(tester, const ValueKey('home-edit-add-${HomeItemIds.fiatPriceTrend}'));
      expect(find.byKey(const ValueKey('widget-configure-period-month')), findsOneWidget);
      expect(find.byKey(const ValueKey('widget-configure-period-threeMonths')), findsNothing);
      expect(find.byKey(const ValueKey('widget-configure-period-year')), findsNothing);
      Navigator.of(tester.element(find.byKey(const Key('widget-configure-submit')))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await tapKey(tester, const ValueKey('home-edit-add-${HomeItemIds.transactionActivity}'));
      await tapKey(tester, const ValueKey('widget-configure-period-year'));
      await tapKey(tester, const Key('widget-configure-submit'));
      expect(homeViewModelOf(tester).configuration.items.single.configuration['period'], 'year');
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    testWidgets('closing the settings sheet adds nothing', (tester) async {
      await _openWidgetsTab(tester, fake: false);
      await tapKey(tester, const ValueKey('home-edit-add-${HomeItemIds.bitcoinBalanceTrend}'));
      expect(find.byKey(const ValueKey('widget-configure-period-month')), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const Key('widget-configure-submit')))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(homeViewModelOf(tester).configuration.items, isEmpty);
      await _close(tester);
    });

    testWidgets('every widget with settings opens its sheet on +', (tester) async {
      await _openWidgetsTab(tester, fake: false);
      for (final definition in builtinHomeWidgets()) {
        expect(definition.needsConfigureBeforeAdd, !definition.settings.isEmpty, reason: definition.id);
      }

      await tapKey(tester, const ValueKey('home-edit-add-${HomeItemIds.utxoStatus}'));
      expect(find.text(t.home_edit.configure_widget), findsOneWidget);
      expect(homeViewModelOf(tester).configuration.items, isEmpty);
      await tapKey(tester, const Key('widget-configure-submit'));
      expect(homeViewModelOf(tester).configuration.items.single.definitionId, HomeItemIds.utxoStatus);

      await _close(tester);
    });

    testWidgets('adding a wallet stack asks for 4×2 or 2×2 with a preview of the chosen size', (tester) async {
      await _openWidgetsTab(tester, fake: false);
      await tapKey(tester, const ValueKey('home-edit-add-${HomeItemIds.hotWalletStack}'));

      expect(find.byKey(const ValueKey('widget-configure-size-4x2')), findsOneWidget);
      final widePreview = tester.getRect(find.byKey(const ValueKey('widget-configure-preview-4x2')));
      await tapKey(tester, const ValueKey('widget-configure-size-2x2'));
      final smallPreview = tester.getRect(find.byKey(const ValueKey('widget-configure-preview-2x2')));
      expect(smallPreview.width, lessThan(widePreview.width));
      expect(smallPreview.height, closeTo(widePreview.height, 0.5));

      await tapKey(tester, const Key('widget-configure-submit'));
      final item = homeViewModelOf(tester).configuration.items.single;
      expect(item.definitionId, HomeItemIds.hotWalletStack);
      expect(item.span, HomeSpan.small);
      await _close(tester);
    });

    testWidgets('tapping an added widget opens its saved settings and saves changes', (tester) async {
      await _openWidgetsTab(tester, fake: false);
      final viewModel = homeViewModelOf(tester);
      viewModel.addItem(
        viewModel.registry.byId(HomeItemIds.utxoStatus)!,
        configuration: const {
          'walletIds': [1],
        },
      );
      await tester.pump();

      await tapKey(tester, const ValueKey('home-edit-widget-tap-${HomeItemIds.utxoStatus}'));
      expect(find.text(t.home_edit.save_changes), findsOneWidget);
      expect(find.byKey(const ValueKey('widget-configure-fiat-KRW')), findsNothing);
      expect(find.byKey(const Key('widget-configure-fake-balance')), findsNothing);

      await tapKey(tester, const Key('widget-configure-all-wallets'));
      await tapKey(tester, const Key('widget-configure-submit'));
      expect(viewModel.configuration.items.single.configuration, isEmpty);
      await _close(tester);
    });

    testWidgets('fiat values asks only for up to three currencies', (tester) async {
      await _openWidgetsTab(tester, fake: false);
      await tapKey(tester, const ValueKey('home-edit-add-${HomeItemIds.fiatValues}'));

      expect(find.byKey(const Key('widget-configure-all-wallets')), findsNothing);
      expect(find.byKey(const Key('widget-configure-fake-balance')), findsNothing);
      expect(find.text(t.home_edit.currencies_limit(count: 3)), findsOneWidget);
      await tapKey(tester, const ValueKey('widget-configure-fiat-EUR'));
      await tapKey(tester, const Key('widget-configure-submit'));
      expect(homeViewModelOf(tester).configuration.items.single.configuration, {
        'fiats': ['KRW', 'USD', 'JPY'],
      });
      await _close(tester);
    });

    testWidgets('the bitcoin balance trend draws the small view at 2×2 and the change view at 4×2', (tester) async {
      await _openWidgetsTab(tester, fake: false);
      final viewModel = homeViewModelOf(tester);
      final definition = viewModel.registry.byId(HomeItemIds.bitcoinBalanceTrend)!;
      expect(definition.supportedSpans, [HomeSpan.small, HomeSpan.wide]);
      expect(definition.settings.sizes, [HomeSpan.wide, HomeSpan.small]);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-edit-widget-${HomeItemIds.bitcoinBalanceTrend}')),
          matching: find.byType(BalanceChangeOverTimeView),
        ),
        findsOneWidget,
      );
      await tapKey(tester, const ValueKey('home-edit-add-${HomeItemIds.bitcoinBalanceTrend}'));
      await tapKey(tester, const ValueKey('widget-configure-size-2x2'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('widget-configure-preview-2x2')),
          matching: find.byType(BitcoinBalanceTrendView),
        ),
        findsOneWidget,
      );
      await tapKey(tester, const Key('widget-configure-submit'));
      expect(viewModel.configuration.items.single.span, HomeSpan.small);
      await _close(tester);
    });

    testWidgets('month-long trend widgets render with sampled day labels', (tester) async {
      await _openWidgetsTab(tester, fake: false);
      final viewModel = homeViewModelOf(tester);
      for (final id in [HomeItemIds.bitcoinBalanceTrend, HomeItemIds.fiatPriceTrend]) {
        viewModel.addItem(
          viewModel.registry.byId(id)!,
          configuration: const {
            'period': 'month',
            'fiats': ['USD'],
          },
          span: HomeSpan.wide,
        );
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
      final labels = find.descendant(
        of: find.byKey(const ValueKey('home-edit-widget-${HomeItemIds.bitcoinBalanceTrend}')),
        matching: find.byWidgetPredicate((widget) => widget is Text && RegExp(r'\d').hasMatch(widget.data ?? '')),
      );
      expect(labels, findsWidgets);
      await _close(tester);
    });
  });

  test('a transaction that arrives after the first lookup shows up once the node reports a wallet update', () {
    final now = DateTime.now();
    final transactions = <TransactionRecord>[];
    final updates = ValueNotifier(0);
    final viewModel = HomeWidgetsViewModel(
      walletProvider: _Wallets([WalletMock.createSingleSigWalletItem(id: 1)], transactions),
      preferenceProvider: _Preferences(),
      priceProvider: _Prices(),
      targetSatsOf: (_) => null,
      historicalPriceService: _History(),
      walletUpdates: updates,
    );
    addTearDown(viewModel.dispose);

    expect(viewModel.recentTransactions(), isEmpty);
    transactions.add(
      TransactionRecord(
        'c',
        now.subtract(const Duration(minutes: 5)),
        1,
        TransactionType.received,
        null,
        3000,
        0,
        const [],
        const [],
        0,
        now,
      ),
    );
    expect(viewModel.recentTransactions(), isEmpty);
    updates.value++;
    expect(viewModel.recentTransactions().single.amount, 3000);
  });

  test('recent transactions merge every wallet, keep pending ones first, and stop at the limit', () {
    final now = DateTime.now();
    TransactionRecord tx(String hash, Duration ago, int blockHeight) => TransactionRecord(
      hash,
      now.subtract(ago),
      blockHeight,
      TransactionType.received,
      null,
      1000,
      0,
      const [],
      const [],
      0,
      now,
    );
    final transactions = [
      for (var i = 0; i < 8; i++) tx('c$i', Duration(days: 40 + i), 100),
      tx('p', const Duration(days: 50), 0),
    ];
    final viewModel = HomeWidgetsViewModel(
      walletProvider: _Wallets([
        WalletMock.createSingleSigWalletItem(id: 1),
        WalletMock.createSingleSigWalletItem(id: 2),
      ], transactions),
      preferenceProvider: _Preferences(),
      priceProvider: _Prices(),
      targetSatsOf: (_) => null,
      historicalPriceService: _History(),
    );
    addTearDown(viewModel.dispose);

    final recent = viewModel.recentTransactions();
    expect(recent.length, HomeWidgetsViewModel.recentTransactionLimit);
    expect(recent.take(2).map((tx) => tx.status), everyElement(TransactionStatus.receiving));
    expect(recent.take(2).map((tx) => tx.walletId).toSet(), {1, 2});
    expect(now.difference(recent[2].time).inDays, 40);
  });

  test('fake balance changes home widgets only; the insights copy keeps real balances', () {
    final home = HomeWidgetsViewModel(
      walletProvider: _Wallets([WalletMock.createSingleSigWalletItem(id: 1)], const []),
      preferenceProvider: _Preferences(isFakeBalanceActive: true),
      priceProvider: _Prices(),
      targetSatsOf: (_) => null,
      historicalPriceService: _History(),
    );
    final insights = home.withoutFakeBalance();
    addTearDown(home.dispose);
    addTearDown(insights.dispose);

    expect(home.balanceOf(1), 12345678);
    expect(insights.isFakeBalance, isFalse);
    expect(insights.balanceOf(1), 10000000);
  });

  group('hodl insights', () {
    Widget insights(HomeViewModel _) => ChangeNotifierProvider(
      create: (_) => HodlInsightsViewModel(_widgetsViewModel!),
      child: const HodlInsightsScreen(),
    );

    for (final fake in [false, true]) {
      testWidgets('every section renders for every period (fake balance: $fake)', (tester) async {
        await _openWidgetsTab(tester, fake: fake, screen: insights);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('balance-by-wallet-entry-1')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('hodl-insights-activity')),
            matching: find.byWidgetPredicate((w) => w is Text && (w.data ?? '').contains('~')),
          ),
          findsNothing,
        );
        expect(
          find.descendant(of: find.byKey(const Key('hodl-insights-activity')), matching: find.byType(HomeWidgetCard)),
          findsNothing,
        );
        expect(find.byKey(const Key('transaction-activity-summary')), findsOneWidget);
        for (final key in [
          'hodl-insights-balance',
          'hodl-insights-balance-chart',
          'hodl-insights-goal',
          'hodl-insights-utxo',
          'hodl-insights-activity',
        ]) {
          expect(find.byKey(Key(key)), findsOneWidget, reason: key);
        }
        for (final period in HomeWidgetPeriod.values) {
          await tester.tap(
            find.descendant(
              of: find.byKey(const Key('hodl-insights-balance-periods')),
              matching: find.byKey(ValueKey('hodl-insights-period-${period.name}')),
            ),
          );
          await tester.tap(
            find.descendant(
              of: find.byKey(const Key('hodl-insights-activity-periods')),
              matching: find.byKey(ValueKey('hodl-insights-period-${period.name}')),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: period.name);
        }
        await _close(tester);
      });
    }

    testWidgets('fits a narrow phone without overflow', (tester) async {
      await _openWidgetsTab(tester, fake: false, screen: insights);
      tester.view.physicalSize = const Size(360, 4000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 4; i++) {
        final label = tester.getRect(
          find.descendant(of: find.byKey(ValueKey('hodl-insights-utxo-label-$i')), matching: find.byType(Text)),
        );
        final count = tester.getRect(
          find.descendant(of: find.byKey(ValueKey('hodl-insights-utxo-count-$i')), matching: find.byType(Text)),
        );
        expect(count.left - label.right, greaterThanOrEqualTo(8), reason: 'row $i');
      }
      await _close(tester);
    });

    testWidgets('the balance rows line up on their baselines with equal gaps and a regular label', (tester) async {
      await _openWidgetsTab(tester, fake: false, screen: insights);
      await tester.pump(const Duration(milliseconds: 300));
      double baseline(String key) {
        final box = tester.renderObject<RenderBox>(find.byKey(Key(key)));
        RenderObject.debugCheckingIntrinsics = true;
        try {
          return box.localToGlobal(Offset.zero).dy + box.getDistanceToBaseline(TextBaseline.alphabetic)!;
        } finally {
          RenderObject.debugCheckingIntrinsics = false;
        }
      }

      expect(baseline('hodl-insights-balance'), closeTo(baseline('hodl-insights-balance-rate'), 0.5));
      expect(baseline('hodl-insights-balance-fiat'), closeTo(baseline('hodl-insights-balance-delta'), 0.5));

      final label = tester.getRect(find.byKey(const Key('hodl-insights-total-label')));
      final amount = tester.getRect(find.byKey(const Key('hodl-insights-balance')));
      final fiat = tester.getRect(find.byKey(const Key('hodl-insights-balance-fiat')));
      expect(amount.top - label.bottom, closeTo(fiat.top - amount.bottom, 1));

      final labelText = tester.widget<Text>(find.byKey(const Key('hodl-insights-total-label')));
      expect(labelText.style!.fontWeight, FontWeight.w400);
      expect(MediaQuery.of(tester.element(find.byKey(const Key('hodl-insights-total-label')))).boldText, isFalse);
      await _close(tester);
    });

    for (final unit in BitcoinUnit.values) {
      testWidgets('the whole balance fits on a narrow phone in ${unit.name}', (tester) async {
        await _openWidgetsTab(tester, fake: false, screen: insights, unit: unit);
        tester.view.physicalSize = const Size(320, 4000);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final paragraph = tester.renderObject<RenderParagraph>(find.byKey(const Key('hodl-insights-balance')));
        RenderObject.debugCheckingIntrinsics = true;
        final needed = paragraph.getMaxIntrinsicWidth(double.infinity);
        RenderObject.debugCheckingIntrinsics = false;
        expect(needed, lessThanOrEqualTo(paragraph.size.width + 0.5));
        expect(tester.takeException(), isNull);
        await _close(tester);
      });
    }

    testWidgets('opened from a widget it scrolls to that section and highlights it for a moment', (tester) async {
      await _openWidgetsTab(
        tester,
        fake: false,
        screen:
            (_) => ChangeNotifierProvider(
              create: (_) => HodlInsightsViewModel(_widgetsViewModel!, initialSection: HodlInsightsSection.utxo),
              child: const HodlInsightsScreen(),
            ),
        size: const Size(400, 800),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 50));

      final list = tester.getRect(find.byKey(const Key('hodl-insights-list')));
      final utxo = tester.getRect(find.byKey(const Key('hodl-insights-utxo')));
      final position =
          tester
              .state<ScrollableState>(
                find.descendant(of: find.byKey(const Key('hodl-insights-list')), matching: find.byType(Scrollable)),
              )
              .position;
      expect(position.pixels, greaterThan(0));
      expect(utxo.top < list.top + 120 || position.pixels == position.maxScrollExtent, isTrue);
      expect(utxo.bottom, lessThanOrEqualTo(list.bottom));

      Color overlay() =>
          (tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: find.byKey(const ValueKey('hodl-insights-highlight-utxo')),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      expect(overlay().a, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(overlay().a, 0);
      await _close(tester);
    });

    test('balance, goal, utxo and activity widgets open the insights, others do not', () {
      const opening = {
        HomeItemIds.bitcoinBalanceTrend,
        HomeItemIds.bitcoinBalanceByFiat,
        HomeItemIds.balanceByWallet,
        HomeItemIds.savingsGoal,
        HomeItemIds.utxoStatus,
        HomeItemIds.transactionActivity,
      };
      for (final definition in builtinHomeWidgets().whereType<BuiltinHomeWidget>()) {
        expect(definition.onTap != null, opening.contains(definition.id), reason: definition.id);
      }
    });

    testWidgets('with no wallets it introduces the insights and offers to add the first wallet', (tester) async {
      await _openWidgetsTab(tester, fake: false, screen: insights, walletList: const [], size: const Size(390, 844));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('hodl-insights-no-wallets')), findsOneWidget);
      expect(find.text(TextUtils.preventLineBreakInsideWords(t.hodl_insights.empty.title)), findsOneWidget);
      for (final title in [
        t.hodl_insights.empty.balance_title,
        t.hodl_insights.empty.goal_title,
        t.hodl_insights.empty.by_wallet_title,
        t.hodl_insights.empty.utxo_title,
        t.hodl_insights.empty.activity_title,
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.byKey(const Key('wallet-onboarding-add')), findsOneWidget);
      expect(find.byKey(const Key('hodl-insights-settings')), findsNothing);
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    test('a long period is drawn with at most the chart point limit and keeps the first and last day', () {
      final values = List.generate(400, (i) => i);
      final sampled = HodlInsightsViewModel.sampleEvenly(values, HodlInsightsViewModel.maxChartPoints);
      expect(sampled.length, HodlInsightsViewModel.maxChartPoints);
      expect(sampled.first, 0);
      expect(sampled.last, 399);
    });
  });
}
