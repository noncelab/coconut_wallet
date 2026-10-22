import 'dart:async';

import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/wallet_appearance_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/card_detail/wallet_card_detail_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/wallet/wallet_background_photo_store.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card_background.dart';
import 'package:coconut_wallet/screens/home/wallet_balance_history_screen.dart';
import 'package:coconut_wallet/widgets/wallet_balance_history_chart.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/widgets/features/home/card/home_alert_card.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';

import '../../../mock/transaction_mock.dart';
import '../../../mock/utxo_mock.dart';
import '../../../mock/wallet_mock.dart';
import 'package:coconut_wallet/repository/realm/converter/utxo.dart';

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  final List<WalletItemBase> wallets;
  List<UtxoState> utxos = const [];
  List<TransactionRecord> transactions = const [];
  final Map<int, int> balances = {};

  _Wallets(this.wallets);

  @override
  WalletLoadState get walletLoadState => WalletLoadState.loadCompleted;
  @override
  late final ValueNotifier<WalletLoadState> walletLoadStateNotifier = ValueNotifier(WalletLoadState.loadCompleted);
  @override
  late final ValueNotifier<List<WalletItemBase>> walletItemListNotifier = ValueNotifier(wallets);
  @override
  List<WalletItemBase> get walletItemList => wallets;
  @override
  WalletItemBase getWalletById(int id) => wallets.firstWhere((wallet) => wallet.id == id);
  @override
  Balance getWalletBalance(int walletId) => Balance(balances[walletId] ?? walletId * 10000000, 0);
  @override
  List<TransactionRecord> getTransactionRecordList(int walletId) => transactions;
  @override
  List<UtxoState> getUtxoList(int walletId) => utxos;
}

class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {
  final loadedWalletIds = <int>[];

  @override
  void initTxList(int walletId) => loadedWalletIds.add(walletId);
  @override
  List<TransactionRecord> get txList => const [];
}

class _Node extends Fake with ChangeNotifier implements NodeProvider {
  @override
  NodeProviderState get state => NodeProviderState.initial();
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) => const Stream.empty();
  @override
  Stream<NodeSyncState> get syncStateStream => const Stream.empty();
  @override
  final ValueNotifier<BlockTimestamp?> currentBlockNotifier = ValueNotifier(null);
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  FiatCode get selectedFiat => FiatCode.KRW;
  @override
  List<int> get walletOrder => const [];
  @override
  bool get isFakeBalanceActive => false;
  @override
  UtxoTierTheme get utxoTierTheme => UtxoTierThemes.pastelWallet;
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => 100000000;
  @override
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) => '₩ $satoshiAmount';
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

class _Auth extends Fake with ChangeNotifier implements AuthProvider {
  @override
  bool get isAuthEnabled => true;
}

class _Analytics extends Fake implements AnalyticsService {
  final events = <String>[];

  @override
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async => events.add(eventName);
}

void main() {
  late _Wallets walletProvider;
  late WalletAppearanceProvider appearances;
  late _Analytics analytics;
  late _Transactions transactions;
  late List<String> pushedRoutes;

  setUpAll(() => CoconutWalletApp.kFaucetHost = 'https://faucet.invalid');

  setUp(() async {
    SharedPreferences.setMockInitialValues({SharedPrefKeys.kBalanceHistoryGestureGuideDismissed: true});
    final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    walletProvider = _Wallets([
      WalletMock.createSingleSigWalletItem(id: 1, name: 'First'),
      WalletMock.createSingleSigWalletItem(id: 2, name: 'Second'),
    ]);
    appearances = WalletAppearanceProvider(
      repository: WalletAppearanceRepository(prefs),
      photoStore: WalletBackgroundPhotoStore(),
    );
    analytics = _Analytics();
    transactions = _Transactions();
    pushedRoutes = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    int id = 1,
    bool focusRecentTransactions = false,
    String? focusedTransactionHash,
    Size size = const Size(390, 1400),
    CoconutThemeVariant variant = CoconutThemeVariant.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: walletProvider),
          ChangeNotifierProvider<TransactionProvider>.value(value: transactions),
          ChangeNotifierProvider<NodeProvider>.value(value: _Node()),
          ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences()),
          ChangeNotifierProvider<PriceProvider>.value(value: _Prices()),
          ChangeNotifierProvider<ConnectivityProvider>.value(value: _Connectivity()),
          ChangeNotifierProvider<AuthProvider>.value(value: _Auth()),
          ChangeNotifierProvider<WalletAppearanceProvider>.value(value: appearances),
          Provider<AnalyticsService>.value(value: analytics),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: variant),
          home: WalletCardDetailScreen(
            id: id,
            entryPoint: '/wallet-list',
            focusRecentTransactions: focusRecentTransactions,
            focusedTransactionHash: focusedTransactionHash,
          ),
          onGenerateRoute: (settings) {
            pushedRoutes.add(settings.name!);
            return MaterialPageRoute(settings: settings, builder: (_) => const Scaffold());
          },
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the focused wallet card, UTXO and recent transaction sections', (tester) async {
    await pump(tester);

    expect(find.byKey(const ValueKey('wallet-detail-card-1')), findsOneWidget);
    expect(find.byKey(const Key('wallet-detail-utxo-header')), findsOneWidget);
    expect(find.byKey(const Key('wallet-detail-transactions-header')), findsOneWidget);
    expect(find.byKey(const Key('wallet-detail-move-to-vault')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('wallet-detail-card-1')),
        matching: find.byKey(const Key('wallet-card-glyph-watch-only')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart card flips in place and opens one week history for the focused wallet', (tester) async {
    await SharedPrefsRepository().setWalletTargetSats(2, 50000000);
    await pump(tester, id: 2);
    await tester.pumpAndSettle();
    expect(find.byType(WalletBalanceHistoryChart), findsNothing);
    final front = find.byKey(const ValueKey('wallet-detail-card-2'));
    final frontRect = tester.getRect(front);
    expect(find.descendant(of: front, matching: find.byKey(const Key('wallet-detail-action-details'))), findsNothing);
    await tester.tap(find.byKey(const Key('wallet-detail-action-chart')).hitTestable());
    await tester.pump(const Duration(milliseconds: 150));
    final transform = tester.widget<Transform>(
      find.ancestor(of: front, matching: find.byKey(const Key('wallet-detail-card-flip'))).first,
    );
    expect(transform.transform.entry(3, 2), isNot(0));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('wallet-detail-chart-card'))), frontRect);
    final chart = tester.widget<WalletBalanceHistoryChart>(find.byType(WalletBalanceHistoryChart));
    expect(chart.targetSats, 50000000);
    expect(chart.cardPresentation, isTrue);
    expect(chart.points.last.balance, 20000000);
    expect(chart.points.length, HomeWidgetPeriod.week.days);
    final previewLine = tester.widget<HomeSparkline>(
      find.descendant(of: find.byType(WalletBalanceHistoryChart), matching: find.byType(HomeSparkline)),
    );
    expect(previewLine.selectedIndex, isNull);
    expect(
      find.descendant(of: find.byKey(const Key('wallet-balance-chart-value-axis')), matching: find.byType(Text)),
      findsNWidgets(3),
    );
    expect(
      find.descendant(of: find.byKey(const Key('wallet-balance-chart-dates')), matching: find.byType(Text)),
      findsNWidgets(3),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('wallet-balance-chart-dates'))).dy,
      lessThan(tester.getTopLeft(find.byType(HomeSparkline)).dy),
    );
    expect(find.byKey(const Key('wallet-detail-balance-goal')), findsOneWidget);
    await tester.tap(find.byKey(const Key('wallet-detail-balance-history')));
    await tester.pumpAndSettle();
    final history = tester.widget<WalletBalanceHistoryScreen>(find.byType(WalletBalanceHistoryScreen));
    expect(find.byKey(const ValueKey('balance-history-wallet-all')), findsNothing);
    expect(find.byKey(const ValueKey('balance-history-wallet-1')), findsNothing);
    expect(find.text(t.wallet_list.balance_history_detail.period_summary), findsOneWidget);
    expect(history.viewModel.walletIds, [2]);
    expect(history.viewModel.balancePeriod, HomeWidgetPeriod.week);
    expect(find.byKey(const Key('balance-history-wallet-chips')), findsNothing);
    expect(find.byKey(const ValueKey('balance-history-wallet-2')), findsNothing);
    Navigator.of(tester.element(find.byType(WalletBalanceHistoryScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wallet-detail-chart-back')));
    await tester.pumpAndSettle();
    expect(front, findsOneWidget);
    expect(find.byKey(const Key('wallet-detail-chart-card')), findsNothing);
    await tester.tap(find.byKey(const Key('wallet-detail-action-chart')).hitTestable());
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('wallet-detail-carousel')), const Offset(300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wallet-detail-action-chart')).hitTestable());
    await tester.pumpAndSettle();
    final switchedChart = tester.widget<WalletBalanceHistoryChart>(find.byType(WalletBalanceHistoryChart));
    expect(switchedChart.points.last.balance, 10000000);
    expect(switchedChart.targetSats, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart goal summary updates its completion percentage', (tester) async {
    await SharedPrefsRepository().setWalletTargetSats(1, 10000000);
    await pump(tester);
    await tester.tap(find.byKey(const Key('wallet-detail-action-chart')).hitTestable());
    await tester.pumpAndSettle();
    final label = find.byKey(const Key('wallet-detail-balance-goal'));
    final trendButton = find.byKey(const Key('wallet-detail-balance-history'));
    final trendText = find.descendant(of: trendButton, matching: find.byType(Text));
    expect(tester.getTopLeft(trendText).dx, closeTo(tester.getTopLeft(label).dx, 0.01));
    expect(tester.getTopLeft(trendButton).dx, closeTo(tester.getTopLeft(label).dx - 8, 0.01));
    expect(tester.widget<InkWell>(trendButton).borderRadius, BorderRadius.circular(12));
    expect(tester.widget<Text>(label).data, endsWith('100%'));
    for (final balance in [15000000, 5000000]) {
      walletProvider.balances[1] = balance;
      walletProvider.walletItemListNotifier.notifyListeners();
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(label).data, endsWith('${balance ~/ 100000}%'));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart card has no goal when the focused wallet has no target', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('wallet-detail-action-chart')).hitTestable());
    await tester.pumpAndSettle();
    expect(tester.widget<WalletBalanceHistoryChart>(find.byType(WalletBalanceHistoryChart)).targetSats, isNull);
    expect(find.byKey(const Key('wallet-detail-balance-goal')), findsNothing);
  });

  testWidgets('chart card fits a narrow dark screen in English with reduced motion', (tester) async {
    final previousLocale = LocaleSettings.currentLocale;
    LocaleSettings.setLocale(AppLocale.en);
    addTearDown(() => LocaleSettings.setLocale(previousLocale));
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await SharedPrefsRepository().setWalletTargetSats(1, 10000000);
    await pump(tester, size: const Size(360, 900), variant: CoconutThemeVariant.dark);
    final chartButtonSize = tester.getSize(find.byKey(const Key('wallet-detail-action-chart')).hitTestable());
    await tester.tap(find.byKey(const Key('wallet-detail-action-chart')).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Wallet Card'), findsNothing);
    expect(tester.getSize(find.byKey(const Key('wallet-detail-chart-back'))), chartButtonSize);
    expect(find.text('View balance trend >'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('wallet-detail-chart-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-detail-card-1')), findsOneWidget);
  });

  for (final unbacked in [false, true]) {
    testWidgets('home transaction entry scrolls and highlights with unbacked warning: $unbacked', (tester) async {
      if (unbacked) {
        final wallet = walletProvider.wallets.first;
        walletProvider.wallets[0] = SinglesigWalletItem(
          id: wallet.id,
          name: wallet.name,
          descriptor: wallet.descriptor,
          colorIndex: wallet.colorIndex,
          iconIndex: wallet.iconIndex,
          hotWalletMetadata: HotWalletMetadata(
            walletId: wallet.id,
            secureStorageKey: 'test',
            masterFingerprint: '12345678',
            derivationPath: 'test',
            accountIndex: 0,
            backupVerified: false,
            enterPassphraseWhenSigning: false,
            createdAt: DateTime.now(),
          ),
        );
      }
      walletProvider.transactions = [
        TransactionMock.createMockTransactionRecord(transactionHash: 'selected', timestamp: DateTime.now()),
        TransactionMock.createMockTransactionRecord(transactionHash: 'other', timestamp: DateTime.now()),
      ];
      await pump(tester, size: const Size(390, 800), focusRecentTransactions: true, focusedTransactionHash: 'selected');
      final scroll = tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
      await tester.pump(const Duration(milliseconds: 499));
      expect(scroll.offset, 0);
      final initialExtent = scroll.position.maxScrollExtent;
      if (unbacked) {
        expect(find.byType(HomeAlertCard), findsOneWidget);
        expect(tester.widget<HomeAlertCard>(find.byType(HomeAlertCard)).reserveSpaceOnShow, isTrue);
      }
      var highlighted = false;
      var peaks = 0;
      var previousAlpha = 0.0;
      var rising = false;
      for (var frame = 0; frame < 45; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(scroll.position.maxScrollExtent, closeTo(initialExtent, 1));
        expect(scroll.offset, inInclusiveRange(scroll.position.minScrollExtent, scroll.position.maxScrollExtent));
        final row = find.byKey(const ValueKey('recent-transaction-highlight-selected'));
        if (row.evaluate().isNotEmpty) {
          final decoration = tester.widget<DecoratedBox>(row).decoration as BoxDecoration;
          expect(decoration.border, isNull);
          final alpha = decoration.color?.a ?? 0;
          highlighted |= alpha > 0;
          if (alpha > previousAlpha) rising = true;
          if (alpha < previousAlpha && rising) {
            peaks++;
            rising = false;
          }
          previousAlpha = alpha;
        }
        expect(find.byKey(const ValueKey('recent-transaction-highlight-other')), findsNothing);
      }
      expect(highlighted, isTrue);
      expect(peaks, 1);
      final header = find.byKey(const Key('wallet-detail-transactions-header'));
      expect(tester.getRect(header).top, greaterThanOrEqualTo(kToolbarHeight));
      expect(tester.getRect(header).bottom, lessThan(800));
      final decoration =
          tester.widget<DecoratedBox>(find.byKey(const ValueKey('recent-transaction-highlight-selected'))).decoration
              as BoxDecoration;
      expect(decoration.color!.a, 0);
      expect(find.byKey(const Key('wallet-detail-transactions-highlight')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('opens on the wallet it was entered with', (tester) async {
    await pump(tester, id: 2);

    final carousel = tester.widget<PageView>(find.byKey(const Key('wallet-detail-carousel')));
    expect(carousel.controller!.initialPage, 1);
  });

  testWidgets('flipping the card wheel focuses the next wallet and its background', (tester) async {
    await appearances.setBackground(2, const WalletSkinBackground('mint'));
    await pump(tester);
    expect(find.byType(WalletCardBackground), findsNothing);

    await tester.drag(find.byKey(const Key('wallet-detail-carousel')), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.byType(WalletCardBackground), findsWidgets);
  });

  testWidgets('card actions open receive, send, organize and details', (tester) async {
    await pump(tester);

    for (final key in ['receive', 'send', 'organize', 'details']) {
      await tester.tap(find.byKey(Key('wallet-detail-action-$key')).first);
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
    }

    expect(pushedRoutes, [
      AppRouteNames.receiveAddress,
      AppRouteNames.send,
      AppRouteNames.utxoOrganizer,
      AppRouteNames.walletInfo,
    ]);
  });

  testWidgets('section headers open the UTXO overview and transaction list', (tester) async {
    walletProvider.utxos = [mapRealmToUtxoState(UtxoMock.createMockUtxo(walletId: 1, address: 'a', amount: 1000))];
    walletProvider.transactions = [TransactionMock.createMockTransactionRecord()];
    await pump(tester);

    await tester.tap(
      find.descendant(of: find.byKey(const Key('wallet-detail-utxo-header')), matching: find.byType(GestureDetector)),
    );
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('wallet-detail-transactions-header')),
        matching: find.byType(GestureDetector),
      ),
    );
    await tester.pumpAndSettle();

    expect(pushedRoutes, [AppRouteNames.utxoOverview, AppRouteNames.transactionList]);
  });

  testWidgets('the default background fills the whole screen with the wallet list background color', (tester) async {
    await pump(tester);

    final screen = tester.getSize(find.byType(WalletCardDetailScreen));
    final background = find.byWidgetPredicate((widget) => widget is ColoredBox && widget.child == null);
    expect(tester.getSize(background.first), screen);
    final colors = tester.element(find.byType(WalletCardDetailScreen)).coconutColors;
    expect(tester.widget<ColoredBox>(background.first).color, colors.homeBackground);
  });

  testWidgets('pulling down reloads the focused wallet', (tester) async {
    await pump(tester);
    expect(transactions.loadedWalletIds, [1]);

    await tester.fling(find.byKey(const Key('wallet-detail-carousel')), const Offset(0, 400), 1500);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(transactions.loadedWalletIds, [1, 1]);
  });

  testWidgets('the UTXO card uses the same summary as Hodl Insights', (tester) async {
    walletProvider.utxos = [
      UtxoMock.createMockUtxoState(id: 'u20000000', amount: 20000000),
      UtxoMock.createMockUtxoState(id: 'u2000000', amount: 2000000),
      UtxoMock.createMockUtxoState(id: 'u3000000', amount: 3000000),
      UtxoMock.createMockUtxoState(id: 'u50000', amount: 50000),
    ];
    await pump(tester);

    expect(find.byKey(const Key('wallet-detail-utxo')), findsOneWidget);
    expect(find.text(t.hodl_insights.total_utxos(count: 4)), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('wallet-detail-utxo-count-1')), matching: find.text('2 (50.0%)')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('"more" is disabled when there are no UTXOs or transactions', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey(('more', Key('wallet-detail-utxo-header')))));
    await tester.tap(find.byKey(const ValueKey(('more', Key('wallet-detail-transactions-header')))));
    await tester.pumpAndSettle();

    expect(pushedRoutes, isEmpty);
  });

  testWidgets('the type label sits as far from the right edge as from the top', (tester) async {
    await pump(tester);

    final card = find.byKey(const ValueKey('wallet-detail-card-1'));
    final cardRect = tester.getRect(card);
    final label = tester.getRect(
      find.descendant(of: card, matching: find.byKey(const Key('wallet-card-glyph-watch-only'))),
    );
    expect(cardRect.right - label.right, moreOrLessEquals(label.top - cardRect.top, epsilon: 0.5));
  });

  testWidgets('scrolling the card away shows its balance and fiat value in the app bar', (tester) async {
    await pump(tester, size: const Size(390, 700));

    double appBarOpacity() =>
        tester
            .widget<Opacity>(
              find
                  .ancestor(of: find.byKey(const Key('wallet-detail-appbar-balance')), matching: find.byType(Opacity))
                  .first,
            )
            .opacity;
    expect(find.byKey(const Key('wallet-detail-appbar-balance')), findsNothing);

    await tester.drag(find.byKey(const Key('wallet-detail-utxo-header')), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wallet-detail-appbar-balance')), findsOneWidget);
    expect(appBarOpacity(), 1);
    expect(
      find.descendant(of: find.byKey(const Key('wallet-detail-appbar-balance')), matching: find.byType(FiatPrice)),
      findsOneWidget,
    );

    await tester.drag(find.byKey(const Key('wallet-detail-utxo-header')), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-detail-appbar-balance')), findsNothing);
  });

  testWidgets('an empty wallet card offers receive and chart with details in the app bar', (tester) async {
    walletProvider.balances[1] = 0;
    await pump(tester);

    final card = find.byKey(const ValueKey('wallet-detail-card-1'));
    Finder action(String name) => find.descendant(of: card, matching: find.byKey(Key('wallet-detail-action-$name')));
    expect(action('receive'), findsOneWidget);
    expect(action('details'), findsNothing);
    expect(action('chart'), findsOneWidget);
    expect(find.byKey(const Key('wallet-detail-action-details')), findsOneWidget);
    expect(action('send'), findsNothing);
    expect(action('organize'), findsNothing);
  });

  testWidgets('the background blends with the swipe and settles on the next wallet', (tester) async {
    const red = Color(0xFFFF0000);
    const blue = Color(0xFF0000FF);
    await appearances.setBackground(1, WalletColorBackground.of(red));
    await appearances.setBackground(2, WalletColorBackground.of(blue));
    await pump(tester);
    List<Color> backgrounds() =>
        tester
            .widgetList<WalletCardBackground>(find.byType(WalletCardBackground))
            .map((widget) => (widget.background as WalletColorBackground).color)
            .toList();
    expect(backgrounds(), [red]);

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('wallet-detail-carousel'))));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(backgrounds(), [red, blue]);
    final blend = tester.widget<Opacity>(
      find.ancestor(of: find.byType(WalletCardBackground), matching: find.byType(Opacity)).first,
    );
    expect(blend.opacity, inExclusiveRange(0, 1));

    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(backgrounds(), [blue]);
  });

  Color headerColor(WidgetTester tester) =>
      tester
          .widget<Text>(
            find.descendant(of: find.byKey(const Key('wallet-detail-utxo-header')), matching: find.byType(Text)).first,
          )
          .style!
          .color!;

  testWidgets('cards keep the app theme over a light skin, text flips only when it would vanish', (tester) async {
    await appearances.setBackground(1, const WalletSkinBackground('mint'));
    await pump(tester, variant: CoconutThemeVariant.dark);

    final card = find.byKey(const ValueKey('wallet-detail-card-1'));
    final cardBox = tester.widget<DecoratedBox>(find.descendant(of: card, matching: find.byType(DecoratedBox)).first);
    expect((cardBox.decoration as BoxDecoration).color, CoconutThemeExtension.dark().colors.homeSurface);
    expect(headerColor(tester), CoconutThemeExtension.light().colors.primaryText);
  });

  testWidgets('text that already stands out keeps the theme color', (tester) async {
    await appearances.setBackground(1, const WalletSkinBackground('mint'));
    await pump(tester, variant: CoconutThemeVariant.coconutTheme);

    expect(headerColor(tester), CoconutThemeExtension.coconutTheme().colors.primaryText);
  });

  testWidgets('cards are lifted with a shadow only when the background swallows their edge', (tester) async {
    Finder outline() => find.byKey(const Key('wallet-detail-lifted-surface'));
    await pump(tester, variant: CoconutThemeVariant.dark);
    expect(outline(), findsNothing);

    await appearances.setBackground(1, WalletColorBackground.of(CoconutThemeExtension.dark().colors.homeSurface));
    await tester.pump();
    expect(outline(), findsWidgets);
  });
}
