import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/app/theme/app_cupertino_theme.dart';
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
import 'package:coconut_wallet/model/home/home_item_definition.dart';
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
import 'package:coconut_wallet/screens/home/wallet_balance_history_screen.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_item_card.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_item_card.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_history_period_chips.dart';
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
import 'package:coconut_wallet/widgets/features/home/home_cube_pager.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoApp, CupertinoPageScaffold, CupertinoScrollBehavior, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
  bool get isFiatBalanceHidden => false;

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
  bool? disableAnimations,
  bool? accessibleNavigation,
  TargetPlatform? platform,
  CoconutThemeVariant variant = CoconutThemeVariant.dark,
  ValueNotifier<CoconutThemeVariant>? themeChanges,
  List<HomeItemDefinition>? widgetDefinitions,
  Key? captureKey,
  bool cupertinoShell = false,
  Color? sourceMarkerColor,
  DateTime? dataNow,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
  final repository = HomeConfigurationRepository(prefs);
  await repository.save(HomeConfiguration(items: const []));
  final now = dataNow ?? DateTime.now();
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
  final homeViewModel = HomeViewModel(
    repository: repository,
    wallets: () => wallets,
    onShortcutTap: (_, __) {},
    widgetDefinitions: widgetDefinitions,
  );
  final widgetsViewModel =
      _widgetsViewModel = HomeWidgetsViewModel(
        walletProvider: _Wallets(wallets, transactions, loadState: loadState),
        preferenceProvider: _Preferences(isFakeBalanceActive: fake, unit: unit),
        priceProvider: _Prices(available: pricesAvailable),
        targetSatsOf: (id) => id == 1 ? 100000000 : null,
        historicalPriceService: _History(),
        now: dataNow == null ? null : () => dataNow,
      );
  Widget home = screen?.call(homeViewModel) ?? const HomeEditScreen(initialTab: HomeEditTab.widgets);
  if (sourceMarkerColor != null) {
    home = Stack(
      children: [
        home,
        Positioned(
          left: 8,
          top: 280,
          child: Text('SOURCE PAGE TEXT', style: TextStyle(color: sourceMarkerColor, fontSize: 28)),
        ),
      ],
    );
  }
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>.value(value: _Wallets(wallets, transactions, loadState: loadState)),
        ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences(isFakeBalanceActive: fake)),
        ChangeNotifierProvider.value(value: homeViewModel),
        ChangeNotifierProvider.value(value: widgetsViewModel),
      ],
      child:
          cupertinoShell
              ? CupertinoApp(
                localizationsDelegates: const [
                  DefaultMaterialLocalizations.delegate,
                  DefaultWidgetsLocalizations.delegate,
                  DefaultCupertinoLocalizations.delegate,
                ],
                builder:
                    (context, child) =>
                        themeChanges == null
                            ? Theme(
                              data: buildCoconutThemeData(variant: variant).copyWith(platform: platform),
                              child: MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  disableAnimations: disableAnimations,
                                  accessibleNavigation: accessibleNavigation,
                                ),
                                child: captureKey == null ? child! : RepaintBoundary(key: captureKey, child: child!),
                              ),
                            )
                            : ValueListenableBuilder<CoconutThemeVariant>(
                              valueListenable: themeChanges,
                              builder:
                                  (context, current, _) => CoconutAppTheme(
                                    variant: current,
                                    materialTheme: buildCoconutThemeData(variant: current),
                                    cupertinoTheme: buildAppCupertinoTheme(variant: current),
                                    child:
                                        captureKey == null ? child! : RepaintBoundary(key: captureKey, child: child!),
                                  ),
                            ),
                home: home,
              )
              : MaterialApp(
                theme: buildCoconutThemeData(variant: variant).copyWith(platform: platform),
                navigatorObservers: [if (routeObserver != null) routeObserver],
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(disableAnimations: disableAnimations, accessibleNavigation: accessibleNavigation),
                      child: captureKey == null ? child! : RepaintBoundary(key: captureKey, child: child!),
                    ),
                home: home,
              ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

List<Map<String, Object?>> _heroTextOverlaps(WidgetTester tester) {
  final totals = find.byKey(const Key('hodl-insights-utxo-total')).evaluate();
  if (totals.isEmpty) return [];
  FadeTransition? nearest;
  Element? fadeElement;
  totals.single.visitAncestorElements((element) {
    if (element.widget is FadeTransition) {
      nearest = element.widget as FadeTransition;
      fadeElement = element;
      return false;
    }
    return true;
  });
  if (nearest == null) return [];
  final stack = fadeElement!.findAncestorWidgetOfExactType<Stack>();
  if (stack == null) return [];
  final layers = stack.children.whereType<FadeTransition>().toList();
  if (layers.length != 2) return [];
  if (layers.any((layer) => layer.opacity.value <= .01)) return [];
  final clip = tester.getRect(find.byWidget(stack));
  List<(String, Rect)> glyphs(FadeTransition layer) => [
    for (final element in find.descendant(of: find.byWidget(layer), matching: find.byType(RichText)).evaluate())
      ...(() {
        final paragraph = element.findRenderObject()! as RenderParagraph;
        final text = paragraph.text.toPlainText();
        return [
          for (final box in paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length)))
            (text, MatrixUtils.transformRect(paragraph.getTransformTo(null), box.toRect()).intersect(clip)),
        ];
      })(),
  ];
  return [
    for (final source in glyphs(layers[0]))
      for (final destination in glyphs(layers[1]))
        if (!source.$2.isEmpty && !destination.$2.isEmpty && source.$2.overlaps(destination.$2))
          {
            'source': source.$1,
            'destination': destination.$1,
            'sourceOpacity': layers[0].opacity.value,
            'destinationOpacity': layers[1].opacity.value,
            'intersection': source.$2.intersect(destination.$2).toString(),
          },
  ];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final entry
        in {
          'Pretendard': ['Regular', 'Bold'],
          'SpaceGrotesk': ['Light', 'Regular', 'Medium', 'Bold'],
        }.entries) {
      final loader = FontLoader(entry.key);
      for (final weight in entry.value) {
        loader.addFont(
          Future.value(ByteData.sublistView(File('assets/fonts/${entry.key}-$weight.ttf').readAsBytesSync())),
        );
      }
      await loader.load();
    }
  });

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
            matching: find.text(TextUtils.preventLineBreakInsideWords(definition.displayName())),
          ),
          findsAtLeastNWidgets(1),
          reason: definition.id,
        );
      }
      expect(find.text(TextUtils.preventLineBreakInsideWords(t.home_widgets.recent_transactions)), findsOneWidget);
      for (final definition in builtinHomeWidgets()) {
        final name = find.byKey(ValueKey('home-edit-widget-name-${definition.id}'));
        final title = tester.widget<Text>(name);
        final paragraph = tester.renderObject<RenderParagraph>(name);
        // 어절 중간에서 줄을 바꾸지 않도록 단어 안에 word joiner를 넣는다.
        expect(title.data, TextUtils.preventLineBreakInsideWords(definition.displayName()), reason: definition.id);
        expect(title.style!.fontSize, CoconutTypography.body2_14.fontSize, reason: definition.id);
        expect(title.style!.fontFamily, CoconutTypography.body2_14.fontFamily, reason: definition.id);
        expect(title.maxLines, isNull, reason: definition.id);
        expect(title.overflow, isNot(TextOverflow.ellipsis), reason: definition.id);
        expect(find.ancestor(of: name, matching: find.byType(FittedBox)), findsNothing, reason: definition.id);
        expect(paragraph.didExceedMaxLines, isFalse, reason: definition.id);
        for (final box in paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: title.data!.length),
        )) {
          final titleRect = tester.getRect(name);
          final cardRect = tester.getRect(find.byKey(ValueKey('home-edit-widget-${definition.id}')));
          expect(titleRect.left + box.left, greaterThanOrEqualTo(cardRect.left), reason: definition.id);
          expect(titleRect.left + box.right, lessThanOrEqualTo(cardRect.right), reason: definition.id);
          expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + 0.1), reason: definition.id);
        }
        final add = find.byKey(ValueKey('home-edit-add-${definition.id}'));
        expect(tester.getRect(add).left, greaterThanOrEqualTo(tester.getRect(name).right), reason: definition.id);
        expect(tester.getCenter(add).dy, closeTo(tester.getCenter(name).dy, 0.5), reason: definition.id);
        expect(tester.getSize(add).shortestSide, greaterThanOrEqualTo(48), reason: definition.id);
        // 이름의 왼쪽 시작과 + 아이콘의 오른쪽 끝은 카드 가장자리에서 같은 거리에 놓인다.
        final cardRect = tester.getRect(find.byKey(ValueKey('home-edit-widget-${definition.id}')));
        final iconRect = tester.getRect(find.descendant(of: add, matching: find.byType(Icon)));
        expect(
          cardRect.right - iconRect.right,
          closeTo(tester.getRect(name).left - cardRect.left, 0.5),
          reason: definition.id,
        );
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

  testWidgets(
    'an added built-in widget keeps its title, status and preview on one line with text capped at the tile scale',
    (tester) async {
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _openWidgetsTab(
        tester,
        fake: false,
        size: const Size(320, 6000),
        widgetDefinitions: [builtinHomeWidgets().singleWhere((definition) => definition.id == HomeItemIds.fiatValues)],
      );
      final viewModel = tester.element(find.byType(HomeEditScreen)).read<HomeViewModel>();
      final definition = viewModel.registry.byId(HomeItemIds.fiatValues)!;
      final add = find.byKey(const ValueKey('home-edit-add-${HomeItemIds.fiatValues}'));
      final name = find.byKey(const ValueKey('home-edit-widget-name-${HomeItemIds.fiatValues}'));
      final added = find.byKey(const ValueKey('home-edit-added-${HomeItemIds.fiatValues}'));
      final remove = find.byKey(const ValueKey('home-edit-remove-${HomeItemIds.fiatValues}'));

      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const Key('widget-configure-submit')), findsOneWidget);
      for (final fiat in [FiatCode.USD, FiatCode.JPY, FiatCode.EUR]) {
        await tester.tap(find.byKey(ValueKey('widget-configure-fiat-${fiat.code}')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('widget-configure-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(viewModel.isOnHome(definition), isTrue);
      expect(viewModel.itemOf(definition)!.configuration['fiats'], ['KRW']);

      for (final scale in [1.3, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.ensureVisible(remove);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        final title = tester.widget<Text>(name);
        final status = tester.widget<Text>(added);
        final titleParagraph = tester.renderObject<RenderParagraph>(name);
        final statusParagraph = tester.renderObject<RenderParagraph>(added);
        final footerRect = tester.getRect(remove).expandToInclude(tester.getRect(added));
        final cardRect = tester.getRect(find.byKey(const ValueKey('home-edit-widget-${HomeItemIds.fiatValues}')));

        expect(title.style!.fontSize, CoconutTypography.body2_14.fontSize);
        expect(title.style!.fontFamily, CoconutTypography.body2_14.fontFamily);
        expect(status.style!.fontSize, CoconutTypography.body3_12.fontSize);
        expect(status.style!.fontFamily, CoconutTypography.body3_12.fontFamily);
        // 고정 크기 타일과 그 이름 줄은 시스템 글자 배율을 kHomeTileMaxTextScale에서 멈춘다.
        final tileScale = math.min(scale, kHomeTileMaxTextScale);
        expect(titleParagraph.textScaler.scale(14), closeTo(14 * tileScale, 0.01));
        expect(statusParagraph.textScaler.scale(12), closeTo(12 * tileScale, 0.01));
        final previewText = find.descendant(
          of: find.byKey(const ValueKey('home-edit-widget-shadow-${HomeItemIds.fiatValues}')),
          matching: find.byType(Text),
        );
        expect(
          tester.renderObject<RenderParagraph>(previewText.first).textScaler.scale(10),
          closeTo(10 * tileScale, 0.01),
        );
        expect(titleParagraph.text.toPlainText(), TextUtils.preventLineBreakInsideWords(definition.displayName()));
        expect(titleParagraph.didExceedMaxLines, isFalse);
        expect(statusParagraph.didExceedMaxLines, isFalse);
        expect(footerRect.left, greaterThanOrEqualTo(tester.getRect(name).right));
        expect(tester.getCenter(remove).dy, closeTo(tester.getCenter(name).dy, 0.5));
        expect(tester.getCenter(added).dy, closeTo(tester.getCenter(name).dy, 0.5));
        expect(footerRect.left, greaterThanOrEqualTo(cardRect.left));
        expect(footerRect.right, lessThanOrEqualTo(cardRect.right));
        expect(tester.getSize(remove).shortestSide, greaterThanOrEqualTo(48));
        if (scale == 2) {
          expect(
            titleParagraph
                .getBoxesForSelection(
                  TextSelection(baseOffset: 0, extentOffset: titleParagraph.text.toPlainText().length),
                )
                .length,
            greaterThan(1),
            reason: 'the narrow catalog wraps the complete title instead of shrinking it',
          );
        }
        expect(tester.takeException(), isNull, reason: 'scale $scale');
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(remove);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(viewModel.isOnHome(definition), isFalse);
      expect(added, findsNothing);
      expect(add, findsOneWidget);
      expect(tester.takeException(), isNull);
      await _close(tester);
    },
  );

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

    for (final variant in CoconutThemeVariant.values) {
      testWidgets('$variant widget entry centers and highlights the target with the themed foreground', (tester) async {
        await _openWidgetsTab(
          tester,
          fake: false,
          variant: variant,
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
        final highlight = find.byKey(const ValueKey('hodl-insights-highlight-utxo'));
        final color = tester.element(highlight).coconutColors.primaryText;
        expect(overlay().a, greaterThan(0));
        expect(overlay().withValues(alpha: 1), color);
        final decoration =
            tester
                    .widget<DecoratedBox>(find.descendant(of: highlight, matching: find.byType(DecoratedBox)).first)
                    .decoration
                as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(20));
        await tester.pump(const Duration(milliseconds: 1300));
        expect(overlay().a, 0);
        await _close(tester);
      });
    }

    test('balance, goal, utxo, activity and safety widgets open their screens, others do not', () {
      const opening = {
        HomeItemIds.bitcoinBalanceTrend,
        HomeItemIds.balanceByWallet,
        HomeItemIds.savingsGoal,
        HomeItemIds.utxoStatus,
        HomeItemIds.transactionActivity,
        HomeItemIds.safetyStatusSmall,
        HomeItemIds.safetyStatusWide,
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

    testWidgets('balance chart opens Hero detail, preserves period, toggles focus and zooms while focused', (
      tester,
    ) async {
      await _openWidgetsTab(tester, fake: false, screen: insights, dataNow: DateTime(2026, 10, 20, 12));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('hodl-insights-period-month')).first);
      await tester.pump();
      await tester.tap(find.byKey(const Key('hodl-insights-balance-chart')));
      await tester.pumpAndSettle();
      expect(find.byType(WalletBalanceHistoryScreen), findsOneWidget);
      expect(
        tester
            .widget<BalanceHistoryPeriodChips>(
              find.descendant(
                of: find.byType(WalletBalanceHistoryScreen),
                matching: find.byType(BalanceHistoryPeriodChips),
              ),
            )
            .selected,
        HomeWidgetPeriod.month,
      );
      final chart = find.byKey(const Key('balance-history-interactive-chart'));
      expect(find.byKey(const Key('hodl-insights-balance-readout')), findsNothing);
      await tester.tap(chart);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hodl-insights-balance-readout')), findsOneWidget);
      final bounds = tester.getRect(chart);
      final one = await tester.startGesture(bounds.center - const Offset(30, 0), pointer: 1);
      final two = await tester.startGesture(bounds.center + const Offset(30, 0), pointer: 2);
      await one.moveBy(const Offset(-30, 0));
      await two.moveBy(const Offset(30, 0));
      await tester.pump();
      await one.moveBy(const Offset(-90, 0));
      await two.moveBy(const Offset(90, 0));
      await tester.pump();
      await one.up();
      await two.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hodl-insights-balance-readout')), findsOneWidget);
      expect(
        tester
            .widget<BalanceHistoryPeriodChips>(
              find.descendant(
                of: find.byType(WalletBalanceHistoryScreen),
                matching: find.byType(BalanceHistoryPeriodChips),
              ),
            )
            .selected,
        HomeWidgetPeriod.week,
      );
      await tester.tap(chart);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hodl-insights-balance-readout')), findsNothing);
      final chips = find.descendant(
        of: find.byType(WalletBalanceHistoryScreen),
        matching: find.byType(BalanceHistoryPeriodChips),
      );
      for (final period in HomeWidgetPeriod.values) {
        final chip = find.descendant(of: chips, matching: find.byKey(ValueKey('hodl-insights-period-${period.name}')));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.widget<BalanceHistoryPeriodChips>(chips).selected, period);
      }
      final latest = tester.getRect(chart);
      await tester.tapAt(Offset(latest.right - 1, latest.center.dy));
      await tester.pumpAndSettle();
      expect(find.byType(WalletItemCard), findsWidgets);
      await tester.tap(find.byType(WalletItemCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(TransactionItemCard), findsWidgets);
      await tester.tap(find.byType(WalletItemCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(TransactionItemCard), findsNothing);
      Navigator.of(tester.element(chart)).pop();
      await tester.pumpAndSettle();
      expect(find.byType(WalletBalanceHistoryScreen), findsNothing);
      expect(find.byKey(const Key('hodl-insights-balance-chart')), findsOneWidget);
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

    testWidgets('the balance trend opens insights without scaling the total label or period filters', (tester) async {
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
                          configuration: {
                            'walletIds': [1],
                            'period': 'month',
                          },
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
      final sizes = <String, List<Size>>{'hodl-insights-total-label': [], 'hodl-insights-balance-periods': []};
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 80));
        for (final entry in sizes.entries) {
          entry.value.add(tester.getRect(find.byKey(Key(entry.key))).size);
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('hodl-insights-balance')), findsOneWidget);
      for (final entry in sizes.entries) {
        final settled = tester.getRect(find.byKey(Key(entry.key))).size;
        for (final size in entry.value) {
          expect(size.width, closeTo(settled.width, 0.01), reason: '${entry.key} width during entry');
          expect(size.height, closeTo(settled.height, 0.01), reason: '${entry.key} height during entry');
        }
      }
      final insights = tester.element(find.byKey(const Key('hodl-insights-list'))).read<HodlInsightsViewModel>();
      expect(insights.walletIds, [1]);
      expect(insights.balancePeriod, HomeWidgetPeriod.month);

      await tester.tap(find.byKey(const Key('hodl-insights-balance-chart')));
      await tester.pumpAndSettle();
      expect(find.byType(WalletBalanceHistoryScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(WalletBalanceHistoryScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(WalletBalanceHistoryScreen), findsNothing);

      Navigator.of(tester.element(find.byKey(const Key('hodl-insights-list')))).pop();
      await tester.pump();
      await tester.pump(HodlInsightsScreen.transitionDuration ~/ 2);
      await tester.pump(HodlInsightsScreen.transitionDuration);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('home-widget-tap-trend')), findsOneWidget);
      await _close(tester);
    });

    testWidgets('reduced motion shows completed section values without the delayed fill animation', (tester) async {
      await _openWidgetsTab(tester, fake: false, screen: insights, disableAnimations: true);
      expect(tester.widget<BalanceByWalletView>(find.byKey(const Key('hodl-insights-balance-by-wallet'))).reveal, 1);
      expect(find.text(t.hodl_insights.total_utxos(count: 2)), findsOneWidget);
      final fill = tester.getSize(find.byKey(const Key('goal-progress-fill'))).width;
      expect(fill, greaterThan(0));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.getSize(find.byKey(const Key('goal-progress-fill'))).width, fill);
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    for (final accessible in [false, true]) {
      testWidgets(
        '${accessible ? 'accessible navigation' : 'reduced motion'} snaps a running highlight and fill to their settled state',
        (tester) async {
          addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
          await _openWidgetsTab(
            tester,
            fake: false,
            size: const Size(400, 800),
            screen:
                (_) => ChangeNotifierProvider(
                  create: (_) => HodlInsightsViewModel(_widgetsViewModel!, initialSection: HodlInsightsSection.utxo),
                  child: const HodlInsightsScreen(),
                ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pump(const Duration(milliseconds: 50));
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
          double reveal() =>
              tester.widget<BalanceByWalletView>(find.byKey(const Key('hodl-insights-balance-by-wallet'))).reveal;
          expect(overlay().a, greaterThan(0));
          expect(reveal(), lessThan(1));
          tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
            disableAnimations: !accessible,
            accessibleNavigation: accessible,
          );
          await tester.pump();
          expect(overlay().a, 0);
          expect(reveal(), 1);
          await tester.pump(const Duration(milliseconds: 1300));
          expect(overlay().a, 0);
          expect(reveal(), 1);
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
          await tester.pump();
          expect(overlay().a, 0);
          expect(reveal(), 1);
          expect(tester.takeException(), isNull);
          await _close(tester);
        },
      );

      testWidgets(
        '${accessible ? 'accessible navigation' : 'reduced motion'} enters with final values and no highlight veil',
        (tester) async {
          await _openWidgetsTab(
            tester,
            fake: false,
            disableAnimations: !accessible,
            accessibleNavigation: accessible,
            screen:
                (_) => ChangeNotifierProvider(
                  create: (_) => HodlInsightsViewModel(_widgetsViewModel!, initialSection: HodlInsightsSection.utxo),
                  child: const HodlInsightsScreen(),
                ),
          );
          await tester.pump(const Duration(milliseconds: 450));
          expect(
            tester.widget<BalanceByWalletView>(find.byKey(const Key('hodl-insights-balance-by-wallet'))).reveal,
            1,
          );
          final box = tester.widget<DecoratedBox>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('hodl-insights-highlight-utxo')),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          expect((box.decoration as BoxDecoration).color!.a, 0);
          expect(tester.takeException(), isNull);
          await _close(tester);
        },
      );
    }

    testWidgets('repeated scroll and edge pulls reuse settled section paint layers', (tester) async {
      await _openWidgetsTab(
        tester,
        fake: false,
        size: const Size(400, 800),
        screen:
            (viewModel) => ScrollConfiguration(behavior: const CupertinoScrollBehavior(), child: insights(viewModel)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      final list = find.byKey(const Key('hodl-insights-list'));
      final boundaries = [
        for (final section in HodlInsightsSection.values)
          tester.renderObject<RenderRepaintBoundary>(find.byKey(ValueKey('hodl-insights-repaint-${section.name}'))),
      ];
      for (final boundary in boundaries) {
        boundary.debugResetMetrics();
      }
      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.drag(list, const Offset(0, -100));
        await tester.pumpAndSettle();
        await tester.drag(list, const Offset(0, 240));
        await tester.pumpAndSettle();
      }
      expect(boundaries.first.debugAsymmetricPaintCount, greaterThan(0));
      expect(boundaries.first.debugSymmetricPaintCount, 0, reason: 'scroll moves the cached layer without repainting');
      for (final boundary in boundaries) {
        expect(boundary.debugNeedsPaint, isFalse);
      }
      expect(tester.takeException(), isNull);
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

    for (final pair in [
      (CoconutThemeVariant.dark, CoconutThemeVariant.light),
      (CoconutThemeVariant.light, CoconutThemeVariant.coconutTheme),
      (CoconutThemeVariant.coconutTheme, CoconutThemeVariant.dark),
    ]) {
      testWidgets('theme changing during actual UTXO Hero keeps landing palette continuous $pair', (tester) async {
        Directory('.omo/evidence/theme-transition-frames').createSync(recursive: true);
        final changes = ValueNotifier(pair.$1);
        addTearDown(changes.dispose);
        await _openWidgetsTab(
          tester,
          fake: false,
          cupertinoShell: true,
          themeChanges: changes,
          captureKey: const ValueKey('theme-hero-capture'),
          size: const Size(344, 800),
          screen:
              (vm) => CupertinoPageScaffold(
                child: HomeCubePager(
                  allFeaturesBuilder: (_) => const SizedBox(),
                  home: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 174,
                      height: 174,
                      child: Builder(
                        builder:
                            (context) => vm.registry
                                .byId(HomeItemIds.utxoStatus)!
                                .build(
                                  context,
                                  const HomeItem(
                                    id: 'source',
                                    definitionId: HomeItemIds.utxoStatus,
                                    kind: HomeItemKind.widget,
                                    order: 0,
                                    span: HomeSpan.small,
                                  ),
                                ),
                      ),
                    ),
                  ),
                ),
              ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        changes.value = pair.$2;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 64));
        await tester.tap(find.byKey(const ValueKey('home-widget-tap-source')));
        await tester.pump();
        final colors = <String>[];
        for (var frame = 0; frame < 31; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final paragraph = tester.renderObject<RenderParagraph>(find.byKey(const Key('hodl-insights-utxo-total')));
          expect(_heroTextOverlaps(tester), isEmpty);
          if (frame >= 29) {
            colors.add(paragraph.text.style!.color.toString());
            await tester.runAsync(() async {
              final image =
                  await tester
                      .renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('theme-hero-capture')))
                      .toImage();
              final png = await image.toByteData(format: ui.ImageByteFormat.png);
              File(
                '.omo/evidence/theme-transition-frames/hero-${pair.$1.name}-${pair.$2.name}-${(frame + 1) * 16}.png',
              ).writeAsBytesSync(png!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        File(
          '.omo/evidence/theme-transition-hero-${pair.$1.name}-${pair.$2.name}.json',
        ).writeAsStringSync(jsonEncode(colors));
        expect(colors[1], colors[0], reason: '480ms overlay and 496ms landed text must share final palette');
        await tester.pumpAndSettle();
        expect(find.text(t.hodl_insights.total_utxos(count: 2)), findsOneWidget);
        changes.value = pair.$1;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 64));
        Navigator.of(tester.element(find.byKey(const Key('hodl-insights-utxo-total')))).pop();
        for (var frame = 0; frame < 32; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull, reason: 'live theme during reverse keeps original Hero context valid');
          final total = find.byKey(const Key('hodl-insights-utxo-total'));
          if (total.evaluate().isNotEmpty) {
            expect(
              tester.renderObject<RenderParagraph>(total).text.toPlainText(),
              t.hodl_insights.total_utxos(count: 2),
              reason: 'live theme reverse preserves already revealed count',
            );
          }
        }
        expect(find.byKey(const ValueKey('home-widget-tap-source')), findsOneWidget);
        changes.value = pair.$2;
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('home-widget-tap-source')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 112));
        Navigator.of(tester.element(find.byKey(const Key('hodl-insights-utxo-total')))).pop();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'theme and interrupted push cancel cleanly');
        expect(find.byKey(const ValueKey('home-widget-tap-source')), findsOneWidget);
        await _close(tester);
      });
    }

    for (final scenario in [
      for (final stall in [160, 240, 320, 400])
        (stall, HomeItemIds.utxoStatus, 'hodl-insights-utxo-total', const Size(414, 896)),
      (400, HomeItemIds.balanceByWallet, 'hodl-insights-balance-by-wallet', const Size(414, 1200)),
      (400, HomeItemIds.transactionActivity, 'hodl-insights-activity', const Size(414, 896)),
    ]) {
      final (stall, definition, targetKey, viewport) = scenario;
      testWidgets('cold first frame stall probe $definition $stall', (tester) async {
        const capture = ValueKey('cold-stall-capture');
        final evidenceDir = Platform.environment['HODL_COLD_EVIDENCE_DIR'];
        if (evidenceDir != null) Directory(evidenceDir).createSync(recursive: true);
        await _openWidgetsTab(
          tester,
          fake: false,
          cupertinoShell: true,
          size: viewport,
          captureKey: capture,
          screen:
              (vm) => CupertinoPageScaffold(
                child: HomeCubePager(
                  allFeaturesBuilder: (_) => const SizedBox(),
                  home: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: definition == HomeItemIds.utxoStatus ? 174 : 348,
                      height: 174,
                      child: Builder(
                        builder:
                            (context) => vm.registry
                                .byId(definition)!
                                .build(
                                  context,
                                  HomeItem(
                                    id: 'source',
                                    definitionId: definition,
                                    kind: HomeItemKind.widget,
                                    order: 0,
                                    span: definition == HomeItemIds.utxoStatus ? HomeSpan.small : HomeSpan.wide,
                                  ),
                                ),
                      ),
                    ),
                  ),
                ),
              ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(const ValueKey('home-widget-tap-source')));
        await tester.pump();
        final records = <Map<String, Object?>>[];
        var elapsed = 0;
        for (final delta in [
          stall,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
          16,
        ]) {
          elapsed += delta;
          await tester.pump(Duration(milliseconds: delta));
          final total = find.byKey(ValueKey(targetKey));
          final rows = <Map<String, Object?>>[];
          for (final element in total.evaluate()) {
            final p = element.findRenderObject()! as RenderBox;
            final r = MatrixUtils.transformRect(p.getTransformTo(null), Offset.zero & p.size);
            var opacity = 1.0;
            element.visitAncestorElements((e) {
              if (e.widget is FadeTransition) opacity *= (e.widget as FadeTransition).opacity.value;
              return true;
            });
            rows.add({
              'text': p is RenderParagraph ? p.text.toPlainText() : targetKey,
              'rect': [r.left, r.top, r.right, r.bottom],
              'effectiveWidgetOpacity': opacity,
            });
          }
          records.add({'elapsedMs': elapsed, 'rows': rows});
          if (evidenceDir != null && records.length <= 3) {
            await tester.runAsync(() async {
              final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(capture)).toImage();
              final png = await image.toByteData(format: ui.ImageByteFormat.png);
              File('$evidenceDir/$definition-stall-$stall-$elapsed.png').writeAsBytesSync(png!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
        if (evidenceDir != null) {
          File('$evidenceDir/$definition-stall-$stall.json').writeAsStringSync(jsonEncode(records));
        }
        final visible =
            records
                .where(
                  (f) =>
                      (f['rows'] as List).isNotEmpty &&
                      ((f['rows'] as List).first['effectiveWidgetOpacity'] as double) > .02,
                )
                .toList();
        expect(visible.length, greaterThan(1), reason: 'visible destination samples must not disappear');
        expect((visible.last['elapsedMs'] as int) - (visible[visible.length - 2]['elapsedMs'] as int), 16);
        for (var i = 1; i < visible.length; i++) {
          final prev = (visible[i - 1]['rows'] as List).first['rect'] as List;
          final next = (visible[i]['rows'] as List).first['rect'] as List;
          expect(
            ((next[1] as double) - (prev[1] as double)).abs(),
            lessThan(50),
            reason: 'cold high-opacity destination must not teleport between adjacent16ms frames',
          );
        }
        expect(tester.takeException(), isNull);
        final target = tester.element(find.byKey(ValueKey(targetKey)));
        final position = Scrollable.of(target).position;
        expect(position.pixels, inInclusiveRange(position.minScrollExtent, position.maxScrollExtent));
        if (definition == HomeItemIds.balanceByWallet) {
          final section = tester.getRect(find.byKey(const ValueKey('hodl-insights-repaint-balanceByWallet')));
          final viewportRect = tester.getRect(find.byType(CustomScrollView));
          expect(
            section.center.dy,
            closeTo(viewportRect.center.dy, 1),
            reason: 'leading space centers the measured section',
          );
          final before = position.pixels;
          await tester.drag(find.byKey(ValueKey(targetKey)), const Offset(0, -80));
          await tester.pump();
          expect(position.pixels, greaterThan(before), reason: 'synthetic leading space preserves scroll hit testing');
          final sectionFinder = find.byKey(const ValueKey('hodl-insights-repaint-balanceByWallet'));
          final shifted = tester.getRect(sectionFinder);
          final expectedOffset = (position.pixels +
                  shifted.top -
                  viewportRect.top -
                  (viewportRect.height - shifted.height) * .4)
              .clamp(position.minScrollExtent, position.maxScrollExtent);
          await Scrollable.ensureVisible(tester.element(sectionFinder), alignment: .4);
          await tester.pump();
          expect(
            position.pixels,
            closeTo(expectedOffset, 1),
            reason: 'ensureVisible includes the actual leading-space scroll offset',
          );
        }
        await _close(tester);
      });
    }

    for (final variant in CoconutThemeVariant.values) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('UTXO Hero landing preserves rendered text and paint continuity $variant ${scale}x', (
          tester,
        ) async {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final evidenceDir = Platform.environment['HODL_ENTRY_EVIDENCE_DIR'];
          final prefix = '${variant.name}-${scale}x';
          if (evidenceDir != null) Directory(evidenceDir).createSync(recursive: true);
          const capture = ValueKey('utxo-flight-capture');
          await _openWidgetsTab(
            tester,
            fake: false,
            variant: variant,
            cupertinoShell: true,
            size: const Size(344, 800),
            captureKey: capture,
            screen:
                (vm) => CupertinoPageScaffold(
                  child: HomeCubePager(
                    allFeaturesBuilder: (_) => const SizedBox(),
                    home: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 174,
                        height: 174,
                        child: Builder(
                          builder:
                              (context) => vm.registry
                                  .byId(HomeItemIds.utxoStatus)!
                                  .build(
                                    context,
                                    const HomeItem(
                                      id: 'source',
                                      definitionId: HomeItemIds.utxoStatus,
                                      kind: HomeItemKind.widget,
                                      order: 0,
                                      span: HomeSpan.small,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text(t.home_widgets.utxo_count(count: 2)), findsOneWidget);
          if (evidenceDir != null) {
            final source = find.descendant(
              of: find.byKey(const ValueKey('home-widget-tap-source')),
              matching: find.byType(Text),
            );
            File('$evidenceDir/$prefix-source.json').writeAsStringSync(
              jsonEncode([
                for (final element in source.evaluate())
                  {
                    'text': (element.findRenderObject()! as RenderParagraph).text.toPlainText(),
                    'style': (element.findRenderObject()! as RenderParagraph).text.style.toString(),
                  },
              ]),
            );
          }
          await tester.tap(find.byKey(const ValueKey('home-widget-tap-source')));
          await tester.pump();
          final landingPixels = <List<int>>[];
          final records = <Map<String, Object?>>[];
          for (var frame = 0; frame < 50; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            final finder = find.byKey(const Key('hodl-insights-utxo-total'));
            final values = <Map<String, Object?>>[];
            for (final element in finder.evaluate()) {
              final paragraph = element.findRenderObject()! as RenderParagraph;
              final rect = MatrixUtils.transformRect(paragraph.getTransformTo(null), Offset.zero & paragraph.size);
              values.add({
                'text': paragraph.text.toPlainText(),
                'rect': [rect.left, rect.top, rect.width, rect.height],
                'style': paragraph.text.style.toString(),
              });
            }
            final rowRects = <List<double>>[];
            final rowValues = <List<String>>[];
            for (var row = 0; row < 4; row++) {
              final label = find.descendant(
                of: find.byKey(ValueKey('hodl-insights-utxo-label-$row')),
                matching: find.byType(Text),
              );
              expect(label, findsOneWidget, reason: 'exactly one rendered destination label during flight');
              final paragraph = tester.renderObject<RenderParagraph>(label);
              final rect = MatrixUtils.transformRect(paragraph.getTransformTo(null), Offset.zero & paragraph.size);
              rowRects.add([rect.left, rect.top, rect.width, rect.height]);
              rowValues.add(
                find
                    .descendant(of: find.byKey(ValueKey('hodl-insights-utxo-row-$row')), matching: find.byType(Text))
                    .evaluate()
                    .map((e) => (e.findRenderObject()! as RenderParagraph).text.toPlainText())
                    .toList(),
              );
            }
            expect(values, hasLength(1), reason: 'one visible total per frame');
            records.add({
              'ms': (frame + 1) * 16,
              'total': values,
              'rowRects': rowRects,
              'rowValues': rowValues,
              'textOverlaps': _heroTextOverlaps(tester),
            });
            if ((frame >= 8 && frame <= 22) || (frame >= 26 && frame <= 33)) {
              await tester.runAsync(() async {
                final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(capture)).toImage();
                if (evidenceDir != null) {
                  final png = await image.toByteData(format: ui.ImageByteFormat.png);
                  File('$evidenceDir/$prefix-${(frame + 1) * 16}.png').writeAsBytesSync(png!.buffer.asUint8List());
                }
                if (frame == 14) {
                  final shuttle = find.byWidgetPredicate(
                    (widget) => widget is Stack && widget.children.whereType<FadeTransition>().length == 2,
                  );
                  final rect = tester.getRect(shuttle);
                  final point = Offset(rect.right - 8, rect.center.dy);
                  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
                  final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
                  final actual = Color.fromARGB(
                    raw!.getUint8(offset + 3),
                    raw.getUint8(offset),
                    raw.getUint8(offset + 1),
                    raw.getUint8(offset + 2),
                  );
                  final expected = HomeCardSurface.of(
                    tester.element(find.byKey(const Key('hodl-insights-utxo-total'))),
                  );
                  expect(actual, expected, reason: 'crossover keeps opaque card paint while text layers exchange');
                }
                if (frame == 29 || frame == 30) {
                  final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
                  final rect = tester.getRect(find.byKey(const Key('hodl-insights-utxo'))).inflate(12);
                  final dots = [
                    for (var row = 0; row < 4; row++)
                      tester.getRect(
                        find.descendant(
                          of: find.byKey(ValueKey('hodl-insights-utxo-row-$row')),
                          matching: find.byWidgetPredicate(
                            (widget) =>
                                widget is Container &&
                                widget.decoration is BoxDecoration &&
                                (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
                          ),
                        ),
                      ),
                  ];
                  // Shuttle compositing changes only circle-edge antialiasing; retain exact text/interior pixels.
                  bool circleEdge(int x, int y) =>
                      dots.any((dot) => ((Offset(x + .5, y + .5) - dot.center).distance - dot.width / 2).abs() <= 1.25);
                  landingPixels.add([
                    for (
                      var y = rect.top.ceil().clamp(0, image.height);
                      y < rect.bottom.floor().clamp(0, image.height);
                      y++
                    )
                      for (
                        var x = rect.left.ceil().clamp(0, image.width);
                        x < rect.right.floor().clamp(0, image.width);
                        x++
                      )
                        if (!circleEdge(x, y))
                          for (var channel = 0; channel < 4; channel++)
                            raw!.getUint8((y * image.width + x) * 4 + channel),
                  ]);
                }
                image.dispose();
              });
            }
          }
          if (evidenceDir != null) File('$evidenceDir/$prefix-trace.json').writeAsStringSync(jsonEncode(records));
          for (final frame in records) {
            expect(
              (frame['total'] as List).single['text'],
              t.hodl_insights.total_utxos(count: 2),
              reason: 'selected positive Home UTXO Hero retains the source total at every frame',
            );
            final rows = frame['rowValues']! as List<List<String>>;
            for (var bucket = 0; bucket < 4; bucket++) {
              expect(
                rows[bucket][1],
                bucket == 0 ? '2 (100.0%)' : '0 (0.0%)',
                reason: 'selected Hero keeps each bucket count',
              );
              expect(
                rows[bucket][2],
                bucket == 0 ? '0.4 BTC' : '0 BTC',
                reason: 'selected Hero keeps each bucket amount',
              );
            }
          }

          expect(
            records.where((frame) => (frame['textOverlaps']! as List).isNotEmpty),
            isEmpty,
            reason: 'source and destination glyphs must never overlap while both painted',
          );
          final before = records[28]['total']! as List<Map<String, Object?>>;
          final after = records[30]['total']! as List<Map<String, Object?>>;
          expect(after.single['text'], before.single['text'], reason: 'landing must not reset visible count');
          expect(after.single['style'], before.single['style'], reason: 'landing must preserve actual text style');
          final landingBefore = records[29]['total']! as List<Map<String, Object?>>;
          expect(after.single['rect'], landingBefore.single['rect'], reason: 'actual total glyph bounds at handoff');
          expect(records[30]['rowRects'], records[29]['rowRects'], reason: 'actual four label glyph bounds at handoff');
          expect(
            landingPixels[1],
            orderedEquals(landingPixels[0]),
            reason: 'actual card paint must not flash at Hero removal',
          );
          await tester.pumpAndSettle();
          expect(
            find.text(t.hodl_insights.total_utxos(count: 2)),
            findsOneWidget,
            reason: 'entry count-up still reaches real data',
          );
          Navigator.of(tester.element(find.byKey(const Key('hodl-insights-list')))).pop();
          await tester.pump();
          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(_heroTextOverlaps(tester), isEmpty, reason: 'reverse must not overlap source/destination glyphs');
            final total = find.byKey(const Key('hodl-insights-utxo-total'));
            if (total.evaluate().isNotEmpty) {
              final paragraph = tester.renderObject<RenderParagraph>(total);
              expect(
                paragraph.text.toPlainText(),
                t.hodl_insights.total_utxos(count: 2),
                reason: 'reverse flight preserves revealed values',
              );
              expect(
                paragraph.text.style!.decoration,
                TextDecoration.none,
                reason: 'reverse flight inherits Material text',
              );
            }
          }
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('home-widget-tap-source')), findsOneWidget);
          await _close(tester);
        });
      }
    }

    for (final variant in CoconutThemeVariant.values) {
      testWidgets('UTXO entry fully occludes outgoing page text $variant', (tester) async {
        final samples = <List<List<int>>>[];
        for (final marker in [const Color(0xFFFF0000), const Color(0xFF00FF00)]) {
          const capture = ValueKey('utxo-flight-capture');
          await _openWidgetsTab(
            tester,
            fake: false,
            variant: variant,
            cupertinoShell: true,
            size: const Size(344, 800),
            captureKey: capture,
            sourceMarkerColor: marker,
            screen:
                (vm) => CupertinoPageScaffold(
                  child: HomeCubePager(
                    allFeaturesBuilder: (_) => const SizedBox(),
                    home: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: 174,
                        height: 174,
                        child: Builder(
                          builder:
                              (context) => vm.registry
                                  .byId(HomeItemIds.utxoStatus)!
                                  .build(
                                    context,
                                    const HomeItem(
                                      id: 'source',
                                      definitionId: HomeItemIds.utxoStatus,
                                      kind: HomeItemKind.widget,
                                      order: 0,
                                      span: HomeSpan.small,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
          );

          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.byKey(const ValueKey('home-widget-tap-source')));
          await tester.pump();
          final frames = <List<int>>[];
          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            if ([0, 4, 9, 14, 19, 29].contains(frame)) {
              await tester.runAsync(() async {
                final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(capture)).toImage();
                final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
                frames.add(bytes!.buffer.asUint8List().toList());
                image.dispose();
              });
            }
          }
          samples.add(frames);
          await _close(tester);
        }
        for (var frame = 0; frame < samples[0].length; frame++) {
          var changed = 0;
          for (var byte = 0; byte < samples[0][frame].length; byte++) {
            if (samples[0][frame][byte] != samples[1][frame][byte]) changed++;
          }
          expect(changed, 0, reason: 'outgoing text color must not affect actual viewport pixels at sample $frame');
        }
      });
    }

    for (final popAt in [const Duration(milliseconds: 112), const Duration(milliseconds: 900)]) {
      testWidgets('UTXO Hero interrupted pop preserves visible progress at $popAt', (tester) async {
        const variant = CoconutThemeVariant.dark;
        const capture = ValueKey('utxo-flight-capture');
        await _openWidgetsTab(
          tester,
          fake: false,
          variant: variant,
          cupertinoShell: true,
          size: const Size(344, 800),
          captureKey: capture,
          screen:
              (vm) => CupertinoPageScaffold(
                child: HomeCubePager(
                  allFeaturesBuilder: (_) => const SizedBox(),
                  home: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 174,
                      height: 174,
                      child: Builder(
                        builder:
                            (context) => vm.registry
                                .byId(HomeItemIds.utxoStatus)!
                                .build(
                                  context,
                                  const HomeItem(
                                    id: 'source',
                                    definitionId: HomeItemIds.utxoStatus,
                                    kind: HomeItemKind.widget,
                                    order: 0,
                                    span: HomeSpan.small,
                                  ),
                                ),
                      ),
                    ),
                  ),
                ),
              ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(const ValueKey('home-widget-tap-source')));
        await tester.pump();

        for (var elapsed = 0; elapsed < popAt.inMilliseconds; elapsed += 16) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final total = find.byKey(const Key('hodl-insights-utxo-total'));
        final before = tester.renderObject<RenderParagraph>(total).text.toPlainText();
        Navigator.of(tester.element(find.byKey(const Key('hodl-insights-list')))).pop();
        await tester.pump();
        for (var frame = 0; frame < 32; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(_heroTextOverlaps(tester), isEmpty, reason: 'interrupted flight must not overlap glyph layers');
          if (total.evaluate().isNotEmpty) {
            final paragraph = tester.renderObject<RenderParagraph>(total);
            expect(paragraph.text.toPlainText(), before, reason: 'pop must retain the value visible at interruption');
            expect(paragraph.text.style!.decoration, TextDecoration.none);
          }
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('home-widget-tap-source')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _close(tester);
      });
    }

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
        // Sliver scroll offsets are applied during layout; sample the flight's actual frames.
        // A single 240ms pump skips the layout/tick pair that retargets a moving Hero destination.
        Rect? previousRect;
        for (var frame = 0; frame < 15; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (target.$1 == HomeItemIds.balanceByWallet) {
            final context = tester.element(find.byKey(Key(target.$3)));
            expect(
              HomeCardSurface.of(context),
              context.coconutColors.homeBackground,
              reason: 'the flying wallet card retains its LowerBand surface override',
            );
            expect(
              find.text(t.hodl_insights.total_utxos(count: 0)),
              findsOneWidget,
              reason: 'non-selected UTXO summary retains its original entry count-up',
            );
          }
          final rect = tester.getRect(find.byKey(Key(target.$3)));
          expect(rect.left, greaterThanOrEqualTo(0), reason: '${target.$1} frame $frame');
          expect(rect.right, lessThanOrEqualTo(400), reason: '${target.$1} frame $frame');
          expect(rect.top, greaterThanOrEqualTo(0), reason: '${target.$1} frame $frame');
          expect(rect.bottom, lessThanOrEqualTo(800), reason: '${target.$1} frame $frame');
          if (previousRect != null) {
            expect(rect.top, greaterThanOrEqualTo(previousRect.top - .01), reason: 'flight must not reverse abruptly');
          }
          previousRect = rect;
        }
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

        if (target.$1 == HomeItemIds.balanceByWallet) {
          await tester.pump(const Duration(seconds: 2));
          expect(
            find.text(t.hodl_insights.total_utxos(count: 2)),
            findsOneWidget,
            reason: 'non-selected UTXO summary still completes its delayed count-up',
          );
        }
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

    group('HODL real-font edge contract', () {
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        for (final shortContent in [false, true]) {
          testWidgets(
            '$platform ${shortContent ? "short" : "long"} content preserves bounce across refresh, release and regrab',
            (tester) async {
              final size = Size(platform == TargetPlatform.iOS ? 390 : 360, shortContent ? 4000 : 800);
              const bottomInset = 34.0;
              tester.view.padding = const FakeViewPadding(bottom: bottomInset);
              tester.view.viewPadding = const FakeViewPadding(bottom: bottomInset);
              await _openWidgetsTab(
                tester,
                fake: false,
                size: size,
                platform: platform,
                screen:
                    (viewModel) =>
                        ScrollConfiguration(behavior: const CupertinoScrollBehavior(), child: insights(viewModel)),
              );
              await tester.pumpAndSettle();
              final list = find.byKey(const Key('hodl-insights-list'));
              final position =
                  tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable))).position;
              expect(position.physics, isA<BouncingScrollPhysics>());
              expect(position.maxScrollExtent, shortContent ? 0 : greaterThan(0));
              final viewport = tester.getRect(list);
              expect(viewport.bottom, lessThanOrEqualTo(size.height - bottomInset));
              for (final bottom in [false, true]) {
                final edge = bottom ? position.maxScrollExtent : position.minScrollExtent;
                for (final cancel in [false, true]) {
                  position.jumpTo(edge);
                  await tester.pumpAndSettle();
                  final card = find.byKey(const Key('transaction-activity-summary'));
                  if (bottom) {
                    final bounds = tester.getRect(card);
                    expect(bounds.top, greaterThanOrEqualTo(viewport.top));
                    expect(bounds.bottom, lessThanOrEqualTo(size.height - bottomInset));
                  }
                  final origin = Offset(viewport.left + 6, viewport.center.dy);
                  final gesture = await tester.startGesture(origin);
                  for (var step = 0; step < 6; step++) {
                    await gesture.moveBy(Offset(0, bottom ? -20 : 20));
                    await tester.pump(const Duration(milliseconds: 16));
                  }
                  final held = position.pixels;
                  if (shortContent) {
                    expect(held, edge, reason: 'native physics does not drag content that fits');
                  } else {
                    expect((held - edge).abs(), greaterThan(20), reason: 'keep the original outward pull effect');
                    expect(position.activity, isA<DragScrollActivity>());
                  }
                  final activity = position.activity;
                  final dimensions = [position.minScrollExtent, position.maxScrollExtent, position.viewportDimension];
                  final heldCard = tester.getRect(card);
                  for (var refresh = 0; refresh < 3; refresh++) {
                    _widgetsViewModel!.refresh();
                    await tester.pump(const Duration(milliseconds: 80));
                    expect(
                      position.pixels,
                      closeTo(held, .01),
                      reason: 'same-shaped refresh must not reset a held pull',
                    );
                    expect(position.activity, same(activity));
                    expect(tester.getRect(card), heldCard);
                    expect([
                      position.minScrollExtent,
                      position.maxScrollExtent,
                      position.viewportDimension,
                    ], dimensions);
                  }
                  await tester.pump(const Duration(milliseconds: 250));
                  final simulation = position.physics.createBallisticSimulation(position, 0);
                  if (cancel) {
                    await gesture.cancel();
                  } else {
                    await gesture.up();
                  }
                  final returning = position.activity;
                  var previousDistance = (held - edge).abs();
                  for (var frame = 0; frame < 45; frame++) {
                    if (frame % 3 == 0) _widgetsViewModel!.refresh();
                    await tester.pump(const Duration(milliseconds: 16));
                    final distance = (position.pixels - edge).abs();
                    expect(
                      distance,
                      lessThanOrEqualTo(previousDistance + .01),
                      reason: 'one continuous return, frame $frame',
                    );
                    if (!shortContent && !simulation!.isDone(frame * .016)) {
                      expect(
                        position.pixels,
                        closeTo(simulation.x(frame * .016), .02),
                        reason: 'relayout must not interrupt native spring at frame $frame',
                      );
                      expect(position.activity, same(returning));
                    }
                    previousDistance = distance;
                  }
                  await tester.pumpAndSettle();
                  expect(position.pixels, closeTo(edge, .01));
                  if (!shortContent) {
                    final pull = await tester.startGesture(origin);
                    for (var step = 0; step < 5; step++) {
                      await pull.moveBy(Offset(0, bottom ? -20 : 20));
                      await tester.pump(const Duration(milliseconds: 16));
                    }
                    await tester.pump(const Duration(milliseconds: 250));
                    await pull.up();
                    await tester.pump();
                    await tester.pump(const Duration(milliseconds: 64));
                    final beforeRegrab = position.pixels;
                    final regrab = await tester.startGesture(origin);
                    _widgetsViewModel!.refresh();
                    await tester.pump(const Duration(milliseconds: 64));
                    expect(
                      position.pixels,
                      closeTo(beforeRegrab, .01),
                      reason: 'pointer down must hold the current return position',
                    );
                    for (var step = 0; step < 3; step++) {
                      await regrab.moveBy(Offset(0, bottom ? 60 : -60));
                      await tester.pump(const Duration(milliseconds: 16));
                    }
                    expect(
                      position.pixels,
                      bottom ? lessThan(edge) : greaterThan(edge),
                      reason: 'reverse regrab follows the pointer into the content',
                    );
                    await regrab.cancel();
                    await tester.pumpAndSettle();
                  }
                }
              }
              expect(tester.takeException(), isNull);
              await _close(tester);
            },
          );
        }

        for (final bottom in [false, true]) {
          testWidgets('$platform ${bottom ? "bottom" : "top"} bounce stays held during entry reveal relayout', (
            tester,
          ) async {
            await _openWidgetsTab(
              tester,
              fake: false,
              size: Size(platform == TargetPlatform.iOS ? 390 : 360, 800),
              platform: platform,
              screen:
                  (viewModel) =>
                      ScrollConfiguration(behavior: const CupertinoScrollBehavior(), child: insights(viewModel)),
            );
            final list = find.byKey(const Key('hodl-insights-list'));
            final position =
                tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable))).position;
            final edge = bottom ? position.maxScrollExtent : position.minScrollExtent;
            position.jumpTo(edge);
            await tester.pump(const Duration(milliseconds: 150));
            final viewport = tester.getRect(list);
            final gesture = await tester.startGesture(Offset(viewport.left + 6, viewport.center.dy));
            for (var step = 0; step < 6; step++) {
              await gesture.moveBy(Offset(0, bottom ? -20 : 20));
              await tester.pump(const Duration(milliseconds: 16));
            }
            final held = position.pixels;
            expect((held - edge).abs(), greaterThan(20));
            final activity = position.activity;
            for (var frame = 0; frame < 120; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
              expect(
                position.pixels,
                closeTo(held, .01),
                reason: 'entry reveal frame $frame must not reset held offset',
              );
              expect(position.activity, same(activity));
            }
            await gesture.up();
            await tester.pumpAndSettle();
            expect(position.pixels, closeTo(edge, .01));
            expect(tester.takeException(), isNull);
            await _close(tester);
          });
        }

        testWidgets('$platform native bounce survives a wallet filter changing content extent', (tester) async {
          await _openWidgetsTab(
            tester,
            fake: false,
            size: Size(platform == TargetPlatform.iOS ? 390 : 360, 800),
            platform: platform,
            screen:
                (viewModel) =>
                    ScrollConfiguration(behavior: const CupertinoScrollBehavior(), child: insights(viewModel)),
          );
          await tester.pumpAndSettle();
          final list = find.byKey(const Key('hodl-insights-list'));
          final state = tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)));
          final position = state.position;
          expect(state.widget.controller, same(PrimaryScrollController.maybeOf(tester.element(list))));
          final viewModel = tester.element(list).read<HodlInsightsViewModel>();
          final viewport = tester.getRect(list);
          for (final ids in [
            <int>[2],
            <int>[1, 2],
          ]) {
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();
            final oldExtent = position.maxScrollExtent;
            final gesture = await tester.startGesture(Offset(viewport.left + 6, viewport.center.dy));
            for (var step = 0; step < 6; step++) {
              await gesture.moveBy(const Offset(0, -20));
              await tester.pump(const Duration(milliseconds: 16));
            }
            expect(position.pixels, greaterThan(oldExtent));
            viewModel.setWalletIds(ids);
            await tester.pump();
            expect(
              position.maxScrollExtent,
              isNot(oldExtent),
              reason: 'fixture must exercise an actual content size change',
            );
            expect(state.position, same(position), reason: 'filter updates retain the scroll position object');
            await gesture.up();
            await tester.pumpAndSettle();
            expect(position.pixels, inInclusiveRange(position.minScrollExtent, position.maxScrollExtent));
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();
            final card = tester.getRect(find.byKey(const Key('transaction-activity-summary')));
            expect(card.bottom, lessThanOrEqualTo(viewport.bottom));
          }
          expect(tester.takeException(), isNull);
          await _close(tester);
        });

        testWidgets('$platform initial section positioning remains visible with native bounce', (tester) async {
          for (final section in HodlInsightsSection.values) {
            await _openWidgetsTab(
              tester,
              fake: false,
              size: Size(platform == TargetPlatform.iOS ? 390 : 360, 800),
              platform: platform,
              screen:
                  (_) => ScrollConfiguration(
                    behavior: const CupertinoScrollBehavior(),
                    child: ChangeNotifierProvider(
                      create: (_) => HodlInsightsViewModel(_widgetsViewModel!, initialSection: section),
                      child: const HodlInsightsScreen(),
                    ),
                  ),
            );
            await tester.pumpAndSettle();
            final viewport = tester.getRect(find.byKey(const Key('hodl-insights-list')));
            final card = tester.getRect(find.byKey(ValueKey('hodl-insights-highlight-${section.name}')));
            expect(card.top, greaterThanOrEqualTo(viewport.top - .01));
            expect(card.bottom, lessThanOrEqualTo(viewport.bottom + .01));
            final position =
                tester
                    .state<ScrollableState>(
                      find.descendant(
                        of: find.byKey(const Key('hodl-insights-list')),
                        matching: find.byType(Scrollable),
                      ),
                    )
                    .position;
            position.jumpTo(position.maxScrollExtent);
            await tester.pumpAndSettle();
            final manuallySelectedOffset = position.pixels;
            _widgetsViewModel!.refresh();
            await tester.pumpAndSettle();
            expect(position.pixels, manuallySelectedOffset, reason: 'refresh must not rerun initial ensureVisible');
            expect(tester.takeException(), isNull);
            await _close(tester);
          }
        });
      }
    });
  });
}
