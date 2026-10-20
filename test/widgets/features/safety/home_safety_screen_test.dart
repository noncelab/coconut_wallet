import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
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
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/buttons/positioned_card_close_button.dart';
import 'package:coconut_wallet/widgets/features/home/card/home_alert_card.dart';
import 'package:coconut_wallet/widgets/features/home/home_connection_status_indicator.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/safety/home_safety_status_chip.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_status_widget_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/safety/safety_fakes.dart';

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
  profile: WeightProfile.hotFunded,
  walletCount: walletCount,
  evaluatedAt: DateTime.now(),
);

const _safetyTile = HomeItem(
  id: 'safety-1',
  definitionId: HomeItemIds.safetyStatusSmall,
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
        Provider<AnalyticsService>.value(value: SafetyAnalyticsFake()),
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

        expect(find.byKey(const Key('home-alerts-button')), withSafety ? findsOneWidget : findsNothing);
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

  testWidgets('Edit Home sits at the bottom even with no items, opens /home-edit, and hides while arranging', (
    tester,
  ) async {
    final routes = _Routes();
    await _pumpHome(tester, safety: SafetyProvider.fixed(_scored()), observer: routes);

    final entry = find.byKey(const Key('home-edit-entry'));
    expect(tester.getRect(entry).bottom, moreOrLessEquals(_height - 16, epsilon: 1));
    expect(find.byKey(const Key('home-edit-button')), findsNothing);

    _homeViewModel(tester).startArranging();
    await tester.pump();
    expect(entry, findsNothing);
    expect(find.byType(HomeSafetyStatusChip), findsNothing);
    expect(find.byKey(const Key('home-alerts-button')), findsNothing);

    _homeViewModel(tester).finishArranging();
    await tester.pump();
    await tester.tap(entry);
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
    expect(tester.getRect(hint).top, greaterThanOrEqualTo(chip.bottom));
    expect(tester.getRect(_tailOf(hint)).center.dx - chip.left, moreOrLessEquals(16, epsilon: 0.5));

    await tester.tap(find.bySemanticsLabel(t.wallet_health.first_hint.close_a11y));
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
      matching: find.text(t.wallet_health.summary.no_issues_found),
    );
    expect(title, findsOneWidget);
    expect(tester.renderObject<RenderParagraph>(title).textScaler.scale(10), moreOrLessEquals(12));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, timeout: _timeout);

  // 회귀: 새 홈은 CupertinoPageScaffold라 Material이 없어서 경고 카드의 닫기 X(InkWell)가 "No Material widget found"로 깨졌다
  testWidgets('on the real home the backup warning renders, closes from its X and snoozes', (tester) async {
    final safety = SafetyProvider.fixed(_scored(), state: SafetyState.initial().copyWith(hintDismissed: true));
    await _pumpHome(tester, safety: safety, wallets: [safetyWallet(id: 1, hot: true)], balances: {1: 100000});
    // 백업·앱 잠금 경고는 2초 뒤에 나타나 240ms 동안 펼쳐진다
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text(t.wallet_home_screen.unbacked_hot_wallet_warning.title), findsOneWidget);

    await tester.tap(find.byType(PositionedCardCloseButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(HomeAlertCard), findsNothing);
    expect(SharedPrefsRepository().getInt(SharedPrefKeys.kUnbackedHotWalletWarningDismissedAt), greaterThan(0));
    await tester.pumpWidget(const SizedBox());
  }, timeout: _timeout);
}
