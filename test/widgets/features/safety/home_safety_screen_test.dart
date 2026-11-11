import 'dart:async';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/home_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_stack_list_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/feature/feature_launcher.dart';
import 'package:coconut_wallet/services/feature/safety_features.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/services/safety/safety_engine.dart';
import 'package:coconut_wallet/widgets/features/home/card/home_alert_card.dart';
import 'package:coconut_wallet/widgets/features/home/home_cube_pager.dart';
import 'package:coconut_wallet/widgets/features/home/home_connection_status_indicator.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/safety/home_safety_status_chip.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_caution_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart' show safetyKoText;
import 'package:coconut_wallet/widgets/features/safety/safety_status_widget_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../model/safety/safety_fixtures.dart' as f;
import '../../../services/safety/safety_fakes.dart';
import '../../../analytics/screen_view_recorder.dart';

/// 무한 애니메이션 등으로 멈추면 공유 레인을 오래 잡지 않게
const _timeout = Timeout(Duration(seconds: 60));
const _height = 900.0;

class _Node extends SafetyNodeFake {
  @override
  bool get hasConnectionError => false;
  @override
  bool get isInitializing => false;
}

class _Connectivity extends SafetyConnectivityFake {
  @override
  bool get isVpnActive => false;
  @override
  bool get isVpnInactive => true;
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  bool get isFakeBalanceActive => false;
  @override
  bool get isBalanceHidden => false;
  @override
  List<int> get walletOrder => const [];
  @override
  FiatCode get selectedFiat => FiatCode.KRW;
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  List<int> get excludedFromTotalBalanceWalletIds => const [];
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  void setHomeWidgetFiats(Iterable<FiatCode> fiats) {}

  @override
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => null;
}

/// 마운트된 채로 첫 평가 결과를 내보낼 수 있는 provider
class _LateSafety extends SafetyProvider {
  _LateSafety() : super.fixed(null);
  WalletHealthReport? _late;
  @override
  WalletHealthReport? get report => _late;
  set late(WalletHealthReport report) {
    _late = report;
    notifyListeners();
  }
}

class _Routes extends NavigatorObserver {
  final names = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => names.add(route.settings.name);
}

WalletHealthReport _scored({int walletCount = 1}) => WalletHealthReport(
  status: WalletHealthStatus.scored,
  score: 92,
  walletCount: walletCount,
  evaluatedAt: DateTime.now(),
);

/// 지갑 1의 출금 사건 하나(위급)
final _incident = SafetyIncident(walletId: 1, txid: 'a', detectedAt: DateTime(2026, 10, 20));
WalletHealthReport _critical() => WalletHealthReport(
  status: WalletHealthStatus.criticalOverride,
  score: 80,
  walletCount: 1,
  criticalIncidents: [_incident],
  evaluatedAt: DateTime.now(),
);

HomeItem _widgetItem(String id, String definitionId, HomeSpan span, int order) =>
    HomeItem(id: id, definitionId: definitionId, kind: HomeItemKind.widget, order: order, span: span);

const _safetyTile = HomeItem(
  id: 'safety-1',
  definitionId: HomeItemIds.safetyStatus,
  kind: HomeItemKind.widget,
  order: 0,
  span: HomeSpan.small,
);

Future<void> _pumpHome(
  WidgetTester tester, {
  SafetyProvider? safety,
  List<WalletItemBase> wallets = const [],
  Map<int, int> balances = const {},
  List<HomeItem> items = const [],
  double width = 412,
  double textScale = 1,
  NavigatorObserver? observer,
  AnalyticsService? analytics,
}) async {
  tester.view.physicalSize = Size(width, _height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({SharedPrefKeys.kAllFeaturesHintDismissed: true});
  await SharedPrefsRepository().init();
  await HomeConfigurationRepository(SharedPrefsRepository()).save(HomeConfiguration(items: items));
  final node = _Node();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>.value(
          value: SafetyWalletsFake(wallets)
            ..balances.addAll({for (final e in balances.entries) e.key: Balance(e.value, 0)}),
        ),
        ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences()),
        ChangeNotifierProvider<PriceProvider>.value(value: _Prices()),
        ChangeNotifierProvider<NodeProvider>.value(value: node),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: _Connectivity()),
        ChangeNotifierProvider<AuthProvider>.value(value: SafetyAuthFake()),
        Provider<AnalyticsService>.value(value: analytics ?? SafetyAnalyticsFake()),
        if (safety != null) ChangeNotifierProvider<SafetyProvider>.value(value: safety),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        navigatorObservers: [if (observer != null) observer],
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: const HomeScreen(),
      ),
    ),
  );
  // 첫 동기화가 끝나 상태칩이 '업데이트 중'(도는 표시)에서 벗어나게
  node.sync.add(NodeSyncState.completed);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

HomeViewModel _homeViewModel(WidgetTester tester) => tester.element(find.byType(HomeItemsView)).read<HomeViewModel>();

Finder _addWalletHint() => find.byKey(const Key('add-wallet-hint'));

Finder _tailOf(Finder hint) => find.descendant(of: hint, matching: find.byType(CustomPaint)).first;

void main() {
  for (final withSafety in [false, true]) {
    for (final width in [344.0, 412.0]) {
      testWidgets('${withSafety ? 'with' : 'without'} SafetyProvider at ${width.toInt()}dp: the add wallet hint '
          'stays on screen and points at the add wallet button', (tester) async {
        await _pumpHome(
          tester,
          safety: withSafety ? SafetyProvider.fixed(_scored(walletCount: 0)) : null,
          width: width,
        );

        expect(find.byKey(const Key('home-alerts-button')), findsNothing);
        expect(find.byType(HomeSafetyStatusChip), withSafety ? findsOneWidget : findsNothing);
        expect(find.byType(HomeConnectionStatusIndicator), withSafety ? findsNothing : findsOneWidget);
        expect(tester.getRect(_addWalletHint()).right, lessThanOrEqualTo(width));
        expect(
          tester.getRect(_tailOf(_addWalletHint())).center.dx,
          moreOrLessEquals(tester.getCenter(find.byKey(const Key('home-add-wallet-button'))).dx, epsilon: 0.5),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }, timeout: _timeout);
    }
  }

  testWidgets('the app bar edit button opens /home-edit; no bell and no edit entry under the grid', (tester) async {
    final routes = _Routes();
    await _pumpHome(tester, safety: SafetyProvider.fixed(_scored()), observer: routes);

    expect(find.byKey(const Key('home-alerts-button')), findsNothing);
    expect(find.byKey(const Key('home-edit-entry')), findsNothing);

    _homeViewModel(tester).startArranging();
    await tester.pump();
    expect(find.byKey(const Key('home-edit-button')), findsNothing);
    expect(find.byType(HomeSafetyStatusChip), findsNothing);

    _homeViewModel(tester).finishArranging();
    await tester.pump();
    await tester.tap(find.byKey(const Key('home-edit-button')));
    expect(routes.names.last, '/home-edit');
    // 편집 화면이 그려지기 전에 정리한다(이 테스트는 진입만 본다)
    await tester.pumpWidget(const SizedBox());
  }, timeout: _timeout);

  testWidgets('the wallet health hint waits for the add wallet hint, sits under the chip, and X dismisses it', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    // 지갑이 없으면 지갑 추가 말풍선이 먼저
    await _pumpHome(tester, safety: SafetyProvider.fixed(_scored()));
    expect(_addWalletHint(), findsOneWidget);
    expect(find.byKey(const Key('wallet-health-hint')), findsNothing);
    await tester.pumpWidget(const SizedBox());

    final safety = SafetyProvider.fixed(_scored());
    await _pumpHome(tester, safety: safety, wallets: [safetyWallet(id: 1)]);
    final hint = find.byKey(const Key('wallet-health-hint'));
    expect(hint, findsOneWidget);
    final chip = tester.getRect(find.byType(HomeSafetyStatusChip));
    // 꼬리는 칩 가운데, 말풍선은 칩 누름 영역 아래쪽 빈 곳에 8 겹쳐 글자 바로 아래
    expect(tester.getRect(hint).top, moreOrLessEquals(chip.bottom - 8, epsilon: 0.5));
    expect(tester.getRect(_tailOf(hint)).center.dx, moreOrLessEquals(chip.center.dx, epsilon: 0.5));
    expect(
      find.bySemanticsLabel('${t.wallet_health.first_hint.title}, ${t.wallet_health.first_hint.description}'),
      findsOneWidget,
    );

    await tester.tap(find.descendant(of: hint, matching: find.byKey(const Key('add-wallet-hint-close'))));
    await tester.pump();
    await tester.pump();
    expect(hint, findsNothing);
    expect(safety.state.hintDismissed, isTrue);
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  }, timeout: _timeout);

  testWidgets('a registered Safety Status tile caps system text at 1.2× and fills in when the first check lands', (
    tester,
  ) async {
    final safety = _LateSafety();
    await _pumpHome(tester, safety: safety, items: const [_safetyTile], textScale: 2);
    expect(find.byKey(const Key('home-widget-skeleton')), findsOneWidget);

    safety.late = _scored();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // 앱바 칩도 같은 문구라 타일 안에서 찾는다
    final title = find.descendant(
      of: find.byType(SafetyStatusWidgetView),
      matching: find.text(safetyKoText(t.wallet_health.summary.no_issues_found)),
    );
    expect(title, findsOneWidget);
    expect(tester.renderObject<RenderParagraph>(title).textScaler.scale(10), moreOrLessEquals(12));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, timeout: _timeout);

  // M11: 점수가 있어도 확인 전 점검이 남았으면 홈 칩·Safety 타일은 "점검 이상 없음"이 아니라 "확인 전 N건"(중립 색)
  testWidgets('a scored report with an unchecked check reads "확인 전 1건" in the chip and the tile, not no issues', (
    tester,
  ) async {
    // 엔진이 만든 보고서: 백업한 핫월렛, 앱 업데이트 확인 실패(unknown) 하나
    final report = SafetyEngine.evaluate(
      f.inputs(
        wallets: [
          f.wallet(
            1,
            balance: 1000000,
            backupVerified: true,
            txs: [f.tx('received', type: TransactionType.received, height: 900)],
          ),
        ],
        state: SafetyState(
          baselines: {
            1: f.baseline(known: {'received'}),
          },
        ),
        update: AppUpdateStatus.unknown,
      ),
    );
    expect((report.score != null, report.attentionCount, report.uncheckedItems.length), (true, 0, 1));
    final safety = SafetyProvider.fixed(report, state: SafetyState.initial().copyWith(hintDismissed: true));
    await _pumpHome(tester, safety: safety, wallets: [safetyWallet(id: 1, hot: true)], items: const [_safetyTile]);
    // 첫 동기화 뒤 잠깐 보이는 "업데이트 완료"가 지나간 뒤의 평상시 칩
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));

    final unchecked = t.wallet_health.summary.items_unchecked(n: 1);
    final chipText = find.descendant(of: find.byType(HomeSafetyStatusChip), matching: find.text(unchecked));
    expect(chipText, findsOneWidget);
    final tileTitle = find.descendant(
      of: find.byType(SafetyStatusWidgetView),
      matching: find.text(safetyKoText(unchecked)),
    );
    expect(tileTitle, findsOneWidget);
    expect(find.text(t.wallet_health.summary.no_issues_found), findsNothing);
    expect(find.text(safetyKoText(t.wallet_health.summary.no_issues_found)), findsNothing);
    final neutral = tester.element(chipText).coconutColors.secondaryTextStrong;
    expect(tester.widget<Text>(chipText).style!.color, neutral);
    expect(tester.widget<Text>(tileTitle).style!.color, neutral);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, timeout: _timeout);

  testWidgets('the home shows only widgets and shortcuts: no backup warning or safety banner', (tester) async {
    final safety = SafetyProvider.fixed(_scored(), state: SafetyState.initial().copyWith(hintDismissed: true));
    await _pumpHome(tester, safety: safety, wallets: [safetyWallet(id: 1, hot: true)], balances: {1: 100000});
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text(safetyKoText(t.wallet_home_screen.unbacked_hot_wallet_warning.title)), findsNothing);
    expect(find.byType(HomeAlertCard), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, timeout: _timeout);

  for (final scale in [1.3, 2.0]) {
    testWidgets('merge caution: wallet list widget warns only on the affected wallet at ×$scale', (tester) async {
      final safety = SafetyProvider.fixed(
        _scored(walletCount: 2),
        state: const SafetyState(cautionWalletIds: {1}, hintDismissed: true),
      );
      addTearDown(safety.dispose);
      await _pumpHome(
        tester,
        safety: safety,
        wallets: [safetyWallet(id: 1), safetyWallet(id: 2)],
        items: [_widgetItem('list-1', HomeItemIds.walletList, HomeSpan.wide, 0)],
        width: 320,
        textScale: scale,
      );
      final warning = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == t.safety_guide.caution.badge_a11y,
      );
      expect(find.descendant(of: find.byKey(const ValueKey('wallet-list-row-1')), matching: warning), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('wallet-list-row-2')), matching: warning), findsNothing);
      await safety.setCaution(1, false);
      await tester.pump();
      expect(find.descendant(of: find.byKey(const ValueKey('wallet-list-row-1')), matching: warning), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, timeout: _timeout);

    testWidgets('merge caution: switching the wallet wheel to list keeps the warning at ×$scale', (tester) async {
      final safety = SafetyProvider.fixed(
        _scored(walletCount: 2),
        state: const SafetyState(cautionWalletIds: {1}, hintDismissed: true),
      );
      addTearDown(safety.dispose);
      await _pumpHome(
        tester,
        safety: safety,
        wallets: [safetyWallet(id: 1), safetyWallet(id: 2)],
        items: [_widgetItem('stack-1', HomeItemIds.allWalletStack, HomeSpan.small, 0)],
        width: 320,
        textScale: scale,
      );
      final pager = find.byKey(const Key('${HomeItemIds.allWalletStack}-pager'));
      unawaited(WalletStackListScreen.open(tester.element(pager), kind: WalletStackKind.all));
      await tester.pump();
      await tester.pump(WalletStackListScreen.transitionDuration);
      await tester.pump(const Duration(milliseconds: 50));
      final warning = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == t.safety_guide.caution.badge_a11y,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('wallet-stack-list-card-1')), matching: warning),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('wallet-stack-list-mode')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byKey(const ValueKey('wallet-stack-list-wide-card-1')), matching: warning),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const ValueKey('wallet-stack-list-wide-card-2')), matching: warning),
        findsNothing,
      );
      await safety.setCaution(1, false);
      await tester.pump();
      expect(
        find.descendant(of: find.byKey(const ValueKey('wallet-stack-list-wide-card-1')), matching: warning),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, timeout: _timeout);
  }

  // POLISH §5·E5(GPT M2): 가장 좁은 폰(320dp)과 큰 글자에서 새 홈 전체. 사용 주의 배지는 2×2 지갑 카드와
  // 지갑 바퀴에서 아이콘 원(compact), 4×2에서만 글자 배지
  testWidgets('the real home fits 320dp at 1.3×/2.0×, with the icon caution badge on the 2×2 stack and the wheel', (
    tester,
  ) async {
    final items = [
      _safetyTile,
      _widgetItem('stack-1', HomeItemIds.allWalletStack, HomeSpan.small, 1),
      _widgetItem('stack-2', HomeItemIds.watchOnlyWalletStack, HomeSpan.wide, 2),
    ];
    Iterable<bool> compactIn(Finder scope) => tester
        .widgetList<SafetyCautionBadge>(find.descendant(of: scope, matching: find.byType(SafetyCautionBadge)))
        .map((badge) => badge.compact);
    for (final scale in [1.3, 2.0]) {
      final safety = SafetyProvider.fixed(
        _critical(),
        state: SafetyState(incidents: [_incident], cautionWalletIds: const {1}, hintDismissed: true),
      );
      await _pumpHome(
        tester,
        safety: safety,
        wallets: [safetyWallet(id: 1)],
        items: items,
        width: 320,
        textScale: scale,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '×$scale');
      expect(find.byType(HomeAlertCard), findsNothing, reason: '×$scale');
      expect(find.byType(SafetyStatusWidgetView), findsOneWidget, reason: '×$scale');
      expect(compactIn(find.byType(HomeScreen)), unorderedEquals([true, false]), reason: '×$scale');
      expect(find.text(t.safety_guide.caution.badge), findsOneWidget, reason: '×$scale'); // 4×2만 글자

      final pager = find.byKey(const Key('${HomeItemIds.allWalletStack}-pager'));
      await tester.ensureVisible(pager);
      unawaited(WalletStackListScreen.open(tester.element(pager), kind: WalletStackKind.all));
      await tester.pump();
      await tester.pump(WalletStackListScreen.transitionDuration);
      await tester.pump(const Duration(milliseconds: 50));
      expect(compactIn(find.byType(WalletStackListScreen)), [true], reason: 'wheel ×$scale');
      expect(tester.takeException(), isNull, reason: 'wheel ×$scale');
      await tester.pumpWidget(const SizedBox());
    }
  }, timeout: _timeout);

  // T5-03: 홈 안의 입구(앱바 칩·말풍선·Safety Status 위젯)를 Wallet Health 화면 기록의 source로 나눈다
  group('analytics: Wallet Health entry from home', () {
    Set<Object?> sources(ScreenViewRecorder recorder) => {
      for (final (name, parameters) in recorder.views)
        if (name == '/wallet-health') parameters['source'],
    };

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets('analytics: the app bar chip records source homeChip', (tester) async {
      final recorder = ScreenViewRecorder();
      await _pumpHome(
        tester,
        safety: SafetyProvider.fixed(_scored()),
        wallets: [safetyWallet(id: 1)],
        analytics: recorder,
        observer: recorder.observer,
      );
      await tester.tap(find.byType(HomeSafetyStatusChip));
      await settle(tester);
      expect(sources(recorder), {'homeChip'});
      await tester.pumpWidget(const SizedBox());
    }, timeout: _timeout);

    testWidgets('analytics: the first hint records source homeHint', (tester) async {
      final recorder = ScreenViewRecorder();
      await _pumpHome(
        tester,
        safety: SafetyProvider.fixed(_scored()),
        wallets: [safetyWallet(id: 1)],
        analytics: recorder,
        observer: recorder.observer,
      );
      await tester.tap(find.byKey(const Key('wallet-health-hint')));
      await settle(tester);
      expect(sources(recorder), {'homeHint'});
      await tester.pumpWidget(const SizedBox());
    }, timeout: _timeout);

    testWidgets('analytics: the Safety Status widget records source homeWidget', (tester) async {
      final recorder = ScreenViewRecorder();
      await _pumpHome(
        tester,
        safety: SafetyProvider.fixed(_scored()),
        wallets: [safetyWallet(id: 1)],
        items: const [_safetyTile],
        analytics: recorder,
        observer: recorder.observer,
      );
      await tester.tap(find.byType(SafetyStatusWidgetView));
      await settle(tester);
      expect(sources(recorder), {'homeWidget'});
      await tester.pumpWidget(const SizedBox());
    }, timeout: _timeout);

    // 홈 바로가기와 모든 기능의 Safety Check는 같은 기능이다. 연 곳은 홈 화면이 FeatureLauncher에 넘긴다
    testWidgets('analytics: the Safety Check shortcut records source homeShortcut', (tester) async {
      final recorder = ScreenViewRecorder();
      await _pumpHome(
        tester,
        // 첫 안내 말풍선이 바로가기 칸을 덮지 않게 이미 닫은 상태로 둔다
        safety: SafetyProvider.fixed(_scored(), state: SafetyState.initial().copyWith(hintDismissed: true)),
        wallets: [safetyWallet(id: 1)],
        items: [
          HomeItem(
            id: 'check-1',
            definitionId: HomeItemIds.shortcut(SafetyFeatureIds.safetyCheck),
            kind: HomeItemKind.shortcut,
            order: 0,
            span: HomeSpan.shortcut,
          ),
        ],
        analytics: recorder,
        observer: recorder.observer,
      );
      await tester.tap(find.byKey(const ValueKey('shortcut-background-${SafetyFeatureIds.safetyCheck}')));
      await settle(tester);
      // 바로가기는 들어가자마자 다시 검사한다. 검사가 끝날 때까지 돌린다
      await tester.pump(const Duration(seconds: 3));
      expect(sources(recorder), {'homeShortcut'});
      // 연 곳은 기능을 여는 그 순간에만 있다. Wallet Health가 열려 있는 지금은 비어 있어야 한다
      expect(FeatureLauncher.launchingSurface, isNull);
      await tester.pumpWidget(const SizedBox());
    }, timeout: _timeout);

    testWidgets('analytics: Safety Check in All Features records source allFeatures', (tester) async {
      final recorder = ScreenViewRecorder();
      await _pumpHome(
        tester,
        safety: SafetyProvider.fixed(_scored()),
        wallets: [safetyWallet(id: 1)],
        analytics: recorder,
        observer: recorder.observer,
      );
      tester.state<HomeCubePagerState>(find.byType(HomeCubePager)).showAllFeatures();
      await settle(tester);
      // 안전 분류는 목록 아래쪽이라 내려서 보이게 한다
      final item = find.byKey(const ValueKey('all-features-item-${SafetyFeatureIds.safetyCheck}'));
      await tester.scrollUntilVisible(
        item,
        200,
        scrollable: find.descendant(of: find.byKey(const Key('all-features-body')), matching: find.byType(Scrollable)),
      );
      await tester.tap(item);
      await settle(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(sources(recorder), {'allFeatures'});
      expect(FeatureLauncher.launchingSurface, isNull);
      await tester.pumpWidget(const SizedBox());
    }, timeout: _timeout);
  });
}
