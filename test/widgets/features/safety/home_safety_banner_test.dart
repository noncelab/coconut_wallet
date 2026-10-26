import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/widgets/common/buttons/positioned_card_close_button.dart';
import 'package:coconut_wallet/widgets/features/home/card/home_alert_card.dart';
import 'package:coconut_wallet/widgets/features/safety/home_safety_banner.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart' show safetyKoText;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/safety/safety_fakes.dart';

/// 무한 애니메이션 등으로 멈추면 공유 레인을 오래 잡지 않게
const _timeout = Timeout(Duration(seconds: 60));

final _now = DateTime(2026, 10, 20);

SafetyIncident _incident(String txid, {IncidentState state = IncidentState.detected}) =>
    SafetyIncident(walletId: 1, txid: txid, detectedAt: _now, state: state);

SafetyCheckResult _critical(SafetyCheckId id, {int? walletId}) =>
    SafetyCheckResult(id, SafetyOutcome.failed, walletId: walletId, severity: SafetySeverity.critical);

class _Routes extends NavigatorObserver {
  final names = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => names.add(route.settings.name);
}

/// 단계별로 펌프하는 배너 화면. provider는 바깥에서 만들어 다시 그려도 같은 것을 쓴다.
Widget _bannerApp({
  required SafetyProvider safety,
  required SafetyWalletsFake wallets,
  bool reduceMotion = false,
  NavigatorObserver? observer,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<SafetyProvider>.value(value: safety),
    ChangeNotifierProvider<WalletProvider>.value(value: wallets),
    ChangeNotifierProvider<AuthProvider>.value(value: SafetyAuthFake()),
  ],
  child: MaterialApp(
    theme: buildCoconutThemeData(),
    navigatorObservers: [if (observer != null) observer],
    // 거래 상세 같은 이름 있는 경로는 빈 화면으로 받는다
    onGenerateRoute: (settings) => MaterialPageRoute<void>(settings: settings, builder: (_) => const SizedBox()),
    home: Builder(
      builder:
          (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: const Scaffold(body: HomeSafetyBanner()),
          ),
    ),
  ),
);

double _opacity(WidgetTester tester) =>
    tester
        .widget<Opacity>(find.descendant(of: find.byType(HomeAlertCard), matching: find.byType(Opacity)).first)
        .opacity;

WalletHealthReport _report({List<SafetyIncident> incidents = const [], List<SafetyCheckResult> review = const []}) =>
    WalletHealthReport(
      status:
          incidents.isNotEmpty || review.any((item) => item.severity == SafetySeverity.critical)
              ? WalletHealthStatus.criticalOverride
              : WalletHealthStatus.scored,
      score: 80,
      criticalIncidents: incidents,
      reviewItems: review,
      evaluatedAt: _now,
    );

Future<void> _pump(
  WidgetTester tester, {
  WalletHealthReport? report,
  bool withSafety = true,
  bool arranging = false,
  SafetyWalletsFake? wallets,
  SafetyAuthFake? auth,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        if (withSafety) ChangeNotifierProvider<SafetyProvider>.value(value: SafetyProvider.fixed(report)),
        ChangeNotifierProvider<WalletProvider>.value(value: wallets ?? SafetyWalletsFake([safetyWallet(id: 1)])),
        ChangeNotifierProvider<AuthProvider>.value(value: auth ?? SafetyAuthFake()),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: Scaffold(body: HomeSafetyBanner(isArranging: arranging)),
      ),
    ),
  );
  // 백업·앱 잠금은 2초 뒤에 나타나기 시작하고 240ms 동안 펼쳐진다
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
  });

  testWidgets('a critical incident shows a red banner with no close button', (tester) async {
    await _pump(tester, report: _report(incidents: [_incident('a')]));

    expect(find.text(safetyKoText(t.wallet_health.incident.outgoing_title)), findsOneWidget);
    expect(
      find.text(
        safetyKoText(
          '${t.wallet_health.incident.outgoing_body(wallet: 'Test')}\n${t.wallet_health.incident.tap_to_review}',
        ),
      ),
      findsOneWidget,
    );
    final card = tester.widget<HomeAlertCard>(find.byType(HomeAlertCard));
    expect(card.type, HomeAlertCardType.securityIncident);
    expect(card.onClosed, isNull);
    expect(find.byType(PositionedCardCloseButton), findsNothing);
  }, timeout: _timeout);

  testWidgets('several incidents share one banner; a critical check without an incident names the cause', (
    tester,
  ) async {
    await _pump(tester, report: _report(incidents: [_incident('a'), _incident('b')]));
    expect(find.text(safetyKoText(t.wallet_health.incident.outgoing_multiple_title(n: 2))), findsOneWidget);

    await _pump(
      tester,
      report: _report(
        review: const [
          SafetyCheckResult(SafetyCheckId.serverCert, SafetyOutcome.failed, severity: SafetySeverity.critical),
        ],
      ),
    );
    expect(find.text(safetyKoText(t.wallet_health.incident.server_identity_title)), findsOneWidget);
    expect(find.byType(PositionedCardCloseButton), findsNothing);
  }, timeout: _timeout);

  // POLISH §5·E15: 가장 좁은 폰(320dp에서 홈 좌우 16을 뺀 288)과 큰 글자
  testWidgets('every banner fits the 320dp home at 1.3× and 2.0× text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(288, 800);
    addTearDown(tester.view.reset);
    SafetyWalletsFake funded({bool backedUp = false}) =>
        SafetyWalletsFake([safetyWallet(id: 1, hot: true, backedUp: backedUp)])..balances[1] = Balance(1000, 0);
    final cases = <(String, WalletHealthReport, SafetyWalletsFake?, SafetyAuthFake?)>[
      ('incident', _report(incidents: [_incident('a')]), null, null),
      ('incidents', _report(incidents: [_incident('a'), _incident('b')]), null, null),
      ('watch-only', _report(review: [_critical(SafetyCheckId.watchOnlyVerify, walletId: 1)]), null, null),
      ('multisig', _report(review: [_critical(SafetyCheckId.multisigConfig, walletId: 1)]), null, null),
      ('server', _report(review: [_critical(SafetyCheckId.serverCert)]), null, null),
      ('backup', _report(), funded(), null),
      ('app lock', _report(), funded(backedUp: true), SafetyAuthFake()..enabled = false),
    ];
    for (final scale in [1.3, 2.0]) {
      for (final (name, report, wallets, auth) in cases) {
        await _pump(tester, report: report, wallets: wallets, auth: auth, textScale: scale);
        expect(find.byType(HomeAlertCard), findsOneWidget, reason: '$name ×$scale');
        expect(tester.takeException(), isNull, reason: '$name ×$scale');
        await tester.pumpWidget(const SizedBox());
      }
    }
  }, timeout: _timeout);

  testWidgets('nothing while arranging or without the safety provider', (tester) async {
    await _pump(tester, report: _report(incidents: [_incident('a')]), arranging: true);
    expect(find.byType(HomeAlertCard), findsNothing);

    await _pump(tester, report: _report(incidents: [_incident('a')]), withSafety: false);
    expect(find.byType(HomeAlertCard), findsNothing);
  }, timeout: _timeout);

  testWidgets('without an incident an unbacked funded hot wallet gets the closable backup warning', (tester) async {
    final wallets = SafetyWalletsFake([safetyWallet(id: 1, hot: true)])..balances[1] = Balance(1000, 0);
    await _pump(tester, report: _report(), wallets: wallets);

    expect(find.text(safetyKoText(t.wallet_home_screen.unbacked_hot_wallet_warning.title)), findsOneWidget);
    expect(tester.widget<HomeAlertCard>(find.byType(HomeAlertCard)).type, HomeAlertCardType.mnemonicBackup);

    await tester.tap(find.byType(PositionedCardCloseButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.byType(HomeAlertCard), findsNothing);
  }, timeout: _timeout);

  testWidgets('the incident wins over the backup warning; app lock off shows the app lock warning', (tester) async {
    final unbacked = SafetyWalletsFake([safetyWallet(id: 1, hot: true)])..balances[1] = Balance(1000, 0);
    await _pump(tester, report: _report(incidents: [_incident('a')]), wallets: unbacked);
    expect(find.text(safetyKoText(t.wallet_health.incident.outgoing_title)), findsOneWidget);
    expect(find.text(safetyKoText(t.wallet_home_screen.unbacked_hot_wallet_warning.title)), findsNothing);

    final backedUp = SafetyWalletsFake([safetyWallet(id: 1, hot: true, backedUp: true)])
      ..balances[1] = Balance(1000, 0);
    await _pump(tester, report: _report(), wallets: backedUp, auth: SafetyAuthFake()..enabled = false);
    expect(find.text(safetyKoText(t.wallet_home_screen.app_lock_warning.title)), findsOneWidget);
    expect(tester.widget<HomeAlertCard>(find.byType(HomeAlertCard)).type, HomeAlertCardType.appLock);
  }, timeout: _timeout);

  // 보이기 타이머(0ms 포함)는 시간이 흘러야 돈다: pump()가 아니라 pump(Duration.zero)
  testWidgets('reduced motion shows and closes banners at once, also when switched on mid-reveal', (tester) async {
    final critical = SafetyProvider.fixed(_report(incidents: [_incident('a')]));
    final wallets = SafetyWalletsFake([safetyWallet(id: 1)]);
    await tester.pumpWidget(_bannerApp(safety: critical, wallets: wallets, reduceMotion: true));
    await tester.pump(Duration.zero);
    await tester.pump();
    expect(_opacity(tester), 1);
    await tester.pumpWidget(const SizedBox());

    // 펼치는 도중에 켜지면 바로 끝 모습
    await tester.pumpWidget(_bannerApp(safety: critical, wallets: wallets));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 60));
    expect(_opacity(tester), lessThan(1));
    await tester.pumpWidget(_bannerApp(safety: critical, wallets: wallets, reduceMotion: true));
    await tester.pump(Duration.zero);
    expect(_opacity(tester), 1);
    await tester.pumpWidget(const SizedBox());

    // 백업 경고: 지연 없이 나타나고 X는 접는 움직임 없이 바로 닫는다
    final unbacked = SafetyWalletsFake([safetyWallet(id: 1, hot: true)])..balances[1] = Balance(1000, 0);
    await tester.pumpWidget(_bannerApp(safety: SafetyProvider.fixed(_report()), wallets: unbacked, reduceMotion: true));
    await tester.pump(Duration.zero);
    await tester.pump();
    expect(_opacity(tester), 1);
    await tester.tap(find.byType(PositionedCardCloseButton));
    await tester.pump();
    await tester.pump();
    expect(find.byType(HomeAlertCard), findsNothing);
  }, timeout: _timeout);

  testWidgets('tapping the critical banner opens the incident, the guide, the alert list or Wallet Health', (
    tester,
  ) async {
    final responding = _incident('a', state: IncidentState.responding);
    final cases = <(String, SafetyProvider, bool Function(String?))>[
      (
        'one detected incident → its transaction',
        SafetyProvider.fixed(_report(incidents: [_incident('a')])),
        (name) => name == AppRouteNames.transactionDetail,
      ),
      (
        'one incident already being handled → the guide',
        SafetyProvider.fixed(
          _report(incidents: [responding]),
          state: SafetyState.initial().copyWith(incidents: [responding]),
        ),
        (name) => name?.startsWith('/safety-guide/') ?? false,
      ),
      (
        'several incidents → the alert list',
        SafetyProvider.fixed(_report(incidents: [_incident('a'), _incident('b')])),
        (name) => name == '/wallet-health/alerts',
      ),
      (
        'server identity changed → Electrum server settings',
        SafetyProvider.fixed(_report(review: [_critical(SafetyCheckId.serverCert)])),
        (name) => name == AppRouteNames.electrumServer,
      ),
      (
        'watch-only mismatch → its verification screen',
        SafetyProvider.fixed(_report(review: [_critical(SafetyCheckId.watchOnlyVerify, walletId: 1)])),
        (name) => name == '/wallet-health/watch-only-verification',
      ),
      (
        'multisig mismatch → the wallet info configuration',
        SafetyProvider.fixed(_report(review: [_critical(SafetyCheckId.multisigConfig, walletId: 1)])),
        (name) => name == AppRouteNames.walletInfo,
      ),
    ];
    for (final (label, safety, expected) in cases) {
      final routes = _Routes();
      final wallets = SafetyWalletsFake([safetyWallet(id: 1)])..replaced['a'] = safetyTx('a');
      await tester.pumpWidget(_bannerApp(safety: safety, wallets: wallets, observer: routes));
      await tester.pump(Duration.zero);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byType(HomeAlertCard));
      await tester.pump();
      await tester.pump();
      expect(routes.names, isNotEmpty, reason: label);
      expect(expected(routes.names.last), isTrue, reason: '$label: ${routes.names}');
      await tester.pumpWidget(const SizedBox());
    }
  }, timeout: _timeout);

  testWidgets('with several critical causes the banner shows the engine-order winner', (tester) async {
    // 엔진(_byPriority)은 심각도 → SafetyCheckId 순서로 정렬한다. 이 enum 순서가 곧 UI_SPEC §3.4의 배너 순서다
    expect(SafetyCheckId.watchOnlyVerify.index, lessThan(SafetyCheckId.multisigConfig.index));
    expect(SafetyCheckId.multisigConfig.index, lessThan(SafetyCheckId.serverCert.index));
    final review = [
      _critical(SafetyCheckId.serverCert),
      _critical(SafetyCheckId.multisigConfig, walletId: 2),
      _critical(SafetyCheckId.watchOnlyVerify, walletId: 1),
    ]..sort((a, b) => a.id.index.compareTo(b.id.index));

    await _pump(tester, report: _report(review: review));
    expect(find.text(safetyKoText(t.wallet_health.incident.watch_only_mismatch_title)), findsOneWidget);
    expect(find.text(safetyKoText(t.wallet_health.incident.watch_only_mismatch_body(wallet: 'Test'))), findsOneWidget);
    expect(find.text(safetyKoText(t.wallet_health.incident.server_identity_title)), findsNothing);
    expect(find.text(safetyKoText(t.wallet_health.incident.multisig_mismatch_title)), findsNothing);
    expect(find.byType(HomeAlertCard), findsOneWidget);

    // 출금 사건이 있으면 사건이 이긴다(두 줄 본문은 이때만)
    await _pump(tester, report: _report(incidents: [_incident('a')], review: review));
    expect(find.text(safetyKoText(t.wallet_health.incident.outgoing_title)), findsOneWidget);
    expect(find.textContaining(safetyKoText(t.wallet_health.incident.tap_to_review)), findsOneWidget);
    await _pump(tester, report: _report(review: review));
    expect(find.textContaining(safetyKoText(t.wallet_health.incident.tap_to_review)), findsNothing);
  }, timeout: _timeout);
}
