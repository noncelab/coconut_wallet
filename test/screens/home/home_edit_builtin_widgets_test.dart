import 'dart:math' as math;

import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
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
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart' show kEntryPointWalletHome;
import 'package:coconut_wallet/services/home/home_presets.dart';
import 'package:coconut_wallet/services/historical_bitcoin_price_service.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/home/configure/home_configure_parts.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
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

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
  }
}

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
  NavigatorObserver? routeObserver,
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
        navigatorObservers: [if (routeObserver != null) routeObserver],
        home: screen?.call(homeViewModel) ?? const HomeEditScreen(initialTab: HomeEditTab.widgets),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('a recent transaction row opens wallet detail with the same fade duration', (tester) async {
    final routeObserver = _RouteObserver();
    await _openWidgetsTab(
      tester,
      fake: false,
      routeObserver: routeObserver,
      size: const Size(400, 800),
      screen: (viewModel) {
        final definition = viewModel.registry.byId(HomeItemIds.recentTransactions)!;
        return Scaffold(
          body: SizedBox(
            width: 352,
            height: 172,
            child: Builder(
              builder:
                  (context) => definition.build(
                    context,
                    const HomeItem(
                      id: 'recent',
                      definitionId: HomeItemIds.recentTransactions,
                      kind: HomeItemKind.widget,
                      order: 0,
                      span: HomeSpan.wide,
                    ),
                  ),
            ),
          ),
        );
      },
    );

    await tester.tap(find.byKey(const ValueKey('recent-transactions-row-0')));
    expect(routeObserver.lastPushed, isA<PageRouteBuilder<void>>());
    final route = routeObserver.lastPushed! as PageRouteBuilder<void>;
    expect(route.settings.name, AppRouteNames.walletDetail);
    expect((route.settings.arguments! as WalletDetailRouteArgs).entryPoint, kEntryPointWalletHome);
    expect(route.transitionDuration, HodlInsightsScreen.transitionDuration);
    await _close(tester);
  });

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

  testWidgets('default preset cards share their top edge and built-in cards use the same padding', (tester) async {
    final preset = builtinHomePresets().first;
    await _openWidgetsTab(tester, fake: false, screen: (_) => HomePresetPreviewScreen(preset: preset));

    final price = tester.getRect(find.byKey(const ValueKey('home-item-preset-default-1')));
    final utxo = tester.getRect(find.byKey(const ValueKey('home-item-preset-default-2')));
    expect(price.top, utxo.top);
    expect(price.bottom, utxo.bottom);
    for (final card in tester.widgetList<HomeWidgetCard>(find.byType(HomeWidgetCard))) {
      expect(card.padding, const EdgeInsets.all(16));
    }
    await _close(tester);
  });

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
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet).last);
      expect(sheet.shape, const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))));
      expect(sheet.clipBehavior, Clip.antiAlias);
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

    testWidgets('fake balance input scrolls to the bottom when the keyboard opens', (tester) async {
      await _openWidgetsTab(tester, fake: false, size: const Size(400, 800));
      await tapKey(tester, const ValueKey('home-edit-add-${HomeItemIds.bitcoinBalanceByFiat}'));
      await tapKey(tester, const Key('widget-configure-fake-balance'));

      final input = find.byKey(const Key('widget-configure-fake-balance-input'));
      await tester.ensureVisible(input);
      await tester.tap(input);
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final scrollView = find.descendant(
        of: find.byType(HomeConfigureSheetLayout),
        matching: find.byType(SingleChildScrollView),
      );
      final scrollController = tester.widget<SingleChildScrollView>(scrollView.first).controller!;
      expect(scrollController.position.pixels, closeTo(scrollController.position.maxScrollExtent, 0.1));
      expect(tester.getBottomLeft(input).dy, lessThan(480));
      expect(tester.takeException(), isNull);
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

    testWidgets('fiat price trend shows the period used for its rate', (tester) async {
      await _openWidgetsTab(tester, fake: false);
      await tester.pump(const Duration(milliseconds: 300));
      FiatPriceTrendView trend() => tester.widget<FiatPriceTrendView>(find.byType(FiatPriceTrendView).first);

      expect(trend().pairLabel, 'KRW · ${t.home_edit.periods.week}');
      final pairLabel = find.descendant(
        of: find.byType(FiatPriceTrendView).first,
        matching: find.text('KRW · ${t.home_edit.periods.week}'),
      );
      expect(tester.widget<Text>(pairLabel).style?.fontFamily, 'Pretendard');
      await tapKey(tester, const ValueKey('home-edit-add-${HomeItemIds.fiatPriceTrend}'));
      await tapKey(tester, const ValueKey('widget-configure-period-month'));
      await tapKey(tester, const Key('widget-configure-submit'));
      expect(trend().pairLabel, 'KRW · ${t.home_edit.periods.month}');
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

    testWidgets('fiat values allows and displays all four currencies', (tester) async {
      await _openWidgetsTab(tester, fake: false);
      await tapKey(tester, const ValueKey('home-edit-add-${HomeItemIds.fiatValues}'));

      expect(find.byKey(const Key('widget-configure-all-wallets')), findsNothing);
      expect(find.byKey(const Key('widget-configure-fake-balance')), findsNothing);
      expect(find.text(t.home_edit.currencies_limit(count: 3)), findsNothing);
      for (final fiat in FiatCode.values) {
        expect(find.byKey(ValueKey('widget-configure-fiat-${fiat.code}')), findsOneWidget);
      }
      await tapKey(tester, const Key('widget-configure-submit'));
      expect(homeViewModelOf(tester).configuration.items.single.configuration, {
        'fiats': ['KRW', 'USD', 'JPY', 'EUR'],
      });
      expect(
        tester.widget<FiatValuesView>(find.byType(FiatValuesView).first).rows.map((row) => row.fiat),
        FiatCode.values,
      );
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

    testWidgets('UTXO rows show count with percentage followed by amount', (tester) async {
      await _openWidgetsTab(tester, fake: false, screen: insights);
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byKey(const Key('hodl-insights-utxo-ranges-unit')), findsOneWidget);
      expect(find.text(t.hodl_insights.utxo_ranges_unit), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        final texts =
            tester
                .widgetList<Text>(
                  find.descendant(of: find.byKey(ValueKey('hodl-insights-utxo-row-$i')), matching: find.byType(Text)),
                )
                .toList();
        expect(texts, hasLength(3));
        expect(texts[0].data, UtxoStatusView.bucketLabels[i]);
        expect(texts[1].data, matches(RegExp(r'^\d+ \(\d+\.\d%\)$')));
        expect(texts[1].style?.fontFamily, 'Pretendard');
        expect(texts[2].data, isNotEmpty);
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
      final section =
          tester
              .element(find.byKey(const ValueKey('hodl-insights-highlight-utxo')))
              .findAncestorWidgetOfExactType<Column>()!;
      expect((tester.getRect(find.byWidget(section)).center.dy - list.center.dy).abs(), lessThan(10));
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

    testWidgets('touching the balance chart shows that day\'s balance until the finger lifts', (tester) async {
      await _openWidgetsTab(tester, fake: false, screen: insights);
      await tester.pump(const Duration(milliseconds: 300));
      final chart = find.byKey(const Key('hodl-insights-balance-chart'));

      final gesture = await tester.startGesture(tester.getCenter(chart));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byKey(const Key('hodl-insights-balance-readout')), findsOneWidget);
      await gesture.moveBy(const Offset(60, 0));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(find.byKey(const Key('hodl-insights-balance-readout')), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(find.byKey(const Key('hodl-insights-balance-readout')), findsNothing);
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    testWidgets('balance by wallet sits on a fading band with an inverted card; later cards keep their color', (
      tester,
    ) async {
      await _openWidgetsTab(tester, fake: false, screen: insights);
      await tester.pump(const Duration(milliseconds: 300));
      final colors = tester.element(find.byKey(const Key('hodl-insights-list'))).coconutColors;

      final band = find.byKey(const Key('hodl-insights-lower-band'));
      expect(band, findsOneWidget);
      expect(
        find.descendant(of: band, matching: find.byKey(const ValueKey('hodl-insights-highlight-balanceByWallet'))),
        findsOneWidget,
      );
      expect(
        find.descendant(of: band, matching: find.byKey(const ValueKey('hodl-insights-highlight-goal'))),
        findsNothing,
      );
      expect(
        find.descendant(of: band, matching: find.byKey(const ValueKey('hodl-insights-highlight-utxo'))),
        findsNothing,
      );
      final summary = tester.widget<Container>(find.byKey(const Key('transaction-activity-summary')));
      expect((summary.decoration! as BoxDecoration).color, colors.homeSurface);
      await _close(tester);
    });

    testWidgets('balance by wallet, UTXO summary and activity are spaced evenly', (tester) async {
      await _openWidgetsTab(tester, fake: false, screen: insights);
      await tester.pump(const Duration(milliseconds: 300));
      Rect rect(Finder finder) => tester.getRect(finder);

      final first =
          rect(find.text(t.hodl_insights.utxo_summary)).top -
          rect(find.byKey(const ValueKey('hodl-insights-highlight-balanceByWallet'))).bottom;
      final second =
          rect(find.text(t.hodl_insights.transaction_activity)).top -
          rect(find.byKey(const ValueKey('hodl-insights-highlight-utxo'))).bottom;
      expect(first, closeTo(second, 0.5));
      await _close(tester);
    });

    testWidgets('the goal bar, wallet donut and UTXO summary count up from zero when the screen opens', (tester) async {
      await _openWidgetsTab(tester, fake: false, screen: insights);
      await tester.pump();
      double width() => tester.getSize(find.byKey(const Key('goal-progress-fill'))).width;
      expect(tester.widget<BalanceByWalletView>(find.byKey(const Key('hodl-insights-balance-by-wallet'))).reveal, 0);
      expect(find.text(t.hodl_insights.total_utxos(count: 0)), findsOneWidget);

      final start = width();
      await tester.pump(const Duration(milliseconds: 200));
      expect(width(), start, reason: 'waits a moment before filling');
      await tester.pump(const Duration(milliseconds: 600));
      final middle = width();
      await tester.pump(const Duration(seconds: 2));
      final end = width();

      expect(start, 0);
      expect(start, lessThan(middle));
      expect(
        tester.widget<BalanceByWalletView>(find.byKey(const Key('hodl-insights-balance-by-wallet'))).reveal,
        greaterThan(0),
      );
      expect(middle, lessThan(end));
      expect(find.text(t.hodl_insights.total_utxos(count: 2)), findsOneWidget);
      final segments = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('hodl-insights-utxo-segment-'),
      );
      expect(segments, findsWidgets);
      for (var i = 0; i < segments.evaluate().length; i++) {
        expect(tester.getSize(segments.at(i)).height, 12);
      }
      expect(end, greaterThan(0));
      await _close(tester);
    });

    testWidgets('Transaction Activity bars, counts and amounts rise from zero after opening', (tester) async {
      await _openWidgetsTab(tester, fake: false, screen: insights);

      final barFinder = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('transaction-activity-bar-'),
      );
      double tallestBar() {
        var height = 0.0;
        for (var i = 0; i < barFinder.evaluate().length; i++) {
          height = math.max(height, tester.getSize(barFinder.at(i)).height);
        }
        return height;
      }

      String receivedCount() => tester.widget<Text>(find.byKey(const Key('transaction-activity-count-received'))).data!;
      String receivedAmount() =>
          tester.widget<Text>(find.byKey(const Key('transaction-activity-amount-received'))).data!;

      expect(tallestBar(), 0);
      expect(receivedCount(), '0');
      final startAmount = receivedAmount();

      await tester.pump(const Duration(milliseconds: 200));
      expect(tallestBar(), 0, reason: 'starts after a short pause');
      await tester.pump(const Duration(milliseconds: 600));
      final middleHeight = tallestBar();
      expect(middleHeight, greaterThan(0));
      expect(receivedAmount(), isNot(startAmount));

      await tester.pump(const Duration(seconds: 2));
      expect(tallestBar(), greaterThan(middleHeight));
      expect(int.parse(receivedCount()), greaterThan(0));
      expect(receivedAmount(), isNot(startAmount));
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    testWidgets('the balance trend widget flies into the total balance card and back', (tester) async {
      await _openWidgetsTab(
        tester,
        fake: false,
        size: const Size(400, 800),
        screen: (viewModel) {
          final definition = viewModel.registry.byId(HomeItemIds.bitcoinBalanceTrend)!;
          return Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 352,
                height: 172,
                child: Builder(
                  builder:
                      (context) => definition.build(
                        context,
                        const HomeItem(
                          id: 'trend',
                          definitionId: HomeItemIds.bitcoinBalanceTrend,
                          kind: HomeItemKind.widget,
                          order: 0,
                          span: HomeSpan.wide,
                        ),
                      ),
                ),
              ),
            ),
          );
        },
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byKey(const ValueKey('home-widget-tap-trend')));
      await tester.pump();
      await tester.pump(HodlInsightsScreen.transitionDuration ~/ 2);
      expect(tester.takeException(), isNull);
      await tester.pump(HodlInsightsScreen.transitionDuration);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('hodl-insights-balance')), findsOneWidget);

      Navigator.of(tester.element(find.byKey(const Key('hodl-insights-list')))).pop();
      await tester.pump();
      await tester.pump(HodlInsightsScreen.transitionDuration ~/ 2);
      await tester.pump(HodlInsightsScreen.transitionDuration);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('home-widget-tap-trend')), findsOneWidget);
      await _close(tester);
    });

    testWidgets('bitcoin balance stays informational while its price is loading', (tester) async {
      await _openWidgetsTab(
        tester,
        fake: false,
        pricesAvailable: false,
        size: const Size(400, 800),
        screen: (viewModel) {
          final definition = viewModel.registry.byId(HomeItemIds.bitcoinBalanceByFiat)!;
          return Scaffold(
            body: SizedBox(
              width: 172,
              height: 172,
              child: Builder(
                builder:
                    (context) => definition.build(
                      context,
                      const HomeItem(
                        id: 'loading-balance',
                        definitionId: HomeItemIds.bitcoinBalanceByFiat,
                        kind: HomeItemKind.widget,
                        order: 0,
                        span: HomeSpan.small,
                      ),
                    ),
              ),
            ),
          );
        },
      );

      expect(find.byKey(const Key('home-widget-skeleton')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-widget-tap-loading-balance')), findsNothing);
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    testWidgets('bitcoin balance stays informational in the editable home grid', (tester) async {
      await _openWidgetsTab(
        tester,
        fake: false,
        size: const Size(400, 800),
        screen:
            (viewModel) => Scaffold(
              body: HomeItemsView(
                configuration: HomeConfiguration(
                  items: const [
                    HomeItem(
                      id: 'balance-grid',
                      definitionId: HomeItemIds.bitcoinBalanceByFiat,
                      kind: HomeItemKind.widget,
                      order: 0,
                      span: HomeSpan.small,
                    ),
                  ],
                ),
                registry: viewModel.registry,
                onMoveToCell: (_, __) {},
                menuItemsOf: (_) => [],
              ),
            ),
      );

      expect(find.byType(BitcoinBalanceByFiatView), findsOneWidget);
      expect(find.byKey(const ValueKey('home-widget-tap-balance-grid')), findsNothing);
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    for (final target in [
      (
        HomeItemIds.balanceByWallet,
        HomeSpan.wide,
        'hodl-insights-balance-by-wallet',
        HodlInsightsSection.balanceByWallet,
      ),
      (HomeItemIds.transactionActivity, HomeSpan.wide, 'hodl-insights-activity', null),
      (HomeItemIds.savingsGoal, HomeSpan.small, 'hodl-insights-goal', HodlInsightsSection.goal),
      (HomeItemIds.utxoStatus, HomeSpan.small, 'hodl-insights-utxo', HodlInsightsSection.utxo),
    ]) {
      testWidgets('${target.$1} flies into its insights card and back', (tester) async {
        await _openWidgetsTab(
          tester,
          fake: false,
          size: const Size(400, 800),
          screen: (viewModel) {
            final definition = viewModel.registry.byId(target.$1)!;
            return Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: target.$2 == HomeSpan.wide ? 352 : 172,
                  height: 172,
                  child: Builder(
                    builder:
                        (context) => definition.build(
                          context,
                          HomeItem(
                            id: 'source',
                            definitionId: target.$1,
                            kind: HomeItemKind.widget,
                            order: 0,
                            span: target.$2,
                          ),
                        ),
                  ),
                ),
              ),
            );
          },
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byWidgetPredicate((widget) => widget is Hero && widget.tag == insightsHeroTag('source')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('home-widget-tap-source')));
        await tester.pump();
        await tester.pump(HodlInsightsScreen.transitionDuration ~/ 2);
        expect(tester.takeException(), isNull);
        final targetRect = tester.getRect(find.byKey(Key(target.$3)));
        expect(targetRect.top, lessThan(800), reason: '${target.$1}: $targetRect');
        await tester.pump(HodlInsightsScreen.transitionDuration);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(Key(target.$3)), findsOneWidget);
        if (target.$4 case final HodlInsightsSection centeredSection) {
          final viewportCenter = tester.getRect(find.byKey(const Key('hodl-insights-list'))).center.dy;
          final highlight = find.byKey(ValueKey('hodl-insights-highlight-${centeredSection.name}'));
          final section = tester.element(highlight).findAncestorWidgetOfExactType<Column>()!;
          final sectionCenter = tester.getRect(find.byWidget(section)).center.dy;
          expect((sectionCenter - viewportCenter).abs(), lessThan(10), reason: '${target.$1} should be centered');
        }
        expect(
          find.byWidgetPredicate((widget) => widget is Hero && widget.tag == insightsHeroTag('source')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        Navigator.of(tester.element(find.byKey(const Key('hodl-insights-list')))).pop();
        await tester.pump();
        await tester.pump(HodlInsightsScreen.transitionDuration);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('home-widget-tap-source')), findsOneWidget);
        await _close(tester);
      });
    }

    test('a long period is drawn with at most the chart point limit and keeps the first and last day', () {
      final values = List.generate(400, (i) => i);
      final sampled = HodlInsightsViewModel.sampleEvenly(values, HodlInsightsViewModel.maxChartPoints);
      expect(sampled.length, HodlInsightsViewModel.maxChartPoints);
      expect(sampled.first, 0);
      expect(sampled.last, 399);
    });
  });
}
