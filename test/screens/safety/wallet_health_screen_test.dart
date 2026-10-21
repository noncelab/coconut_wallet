import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart';
import 'package:coconut_wallet/screens/settings/pin_setting_screen.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_score_gauge.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../mock/wallet_mock.dart';
import 'wallet_health_fixtures.dart';

/// 글자 찾기. 앱은 한국어 단어가 중간에서 끊기지 않게 글자 사이에 U+2060을 넣으므로(safetyKoText) 그 문자를 빼고 비교한다
Finder _text(String text) =>
    find.byWidgetPredicate((w) => w is Text && (w.data ?? w.textSpan?.toPlainText())?.replaceAll('\u2060', '') == text);

/// 글자 일부 찾기(U+2060 이음 문자를 빼고 비교)
Finder _textContaining(Pattern pattern) => find.byWidgetPredicate(
  (w) => w is Text && ((w.data ?? w.textSpan?.toPlainText())?.replaceAll('\u2060', '').contains(pattern) ?? false),
);

Future<FakeSafetyProvider> _pump(
  WidgetTester tester,
  WalletHealthReport? report, {
  CoconutThemeVariant variant = CoconutThemeVariant.light,
  AppLocale locale = AppLocale.ko,
  double width = 390,
  PremiumState? premium,
  bool entitlement = true,
  FakeRescueReady? rescue,
  bool startCheck = false,
  double textScale = 1,
  double height = 2400,
  List<SingleChildWidget> extra = const [],
}) => pumpWalletHealthApp(
  tester,
  WalletHealthScreen(startCheck: startCheck),
  report: report,
  variant: variant,
  locale: locale,
  width: width,
  height: height,
  textScale: textScale,
  // 앱에서는 늘 있는 EntitlementService. entitlement: false = 없는 하네스
  premium: entitlement ? premium ?? const PremiumState(PremiumStatus.none) : null,
  rescue: rescue,
  wallets: _wallets,
  extra: extra,
  settle: !startCheck,
);

/// 홈 상태칩이 읽는 연결 상태(C46)
class _Connectivity extends ChangeNotifier implements ConnectivityProvider {
  _Connectivity({this.internet = true, this.vpn = false});

  final bool internet, vpn;

  @override
  bool get isInternetOn => internet;
  @override
  bool get isInternetOff => !internet;
  @override
  bool get isVpnActive => vpn;
  @override
  bool get isVpnInactive => !vpn;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SingleChildWidget _connectivity({bool internet = true, bool vpn = false}) =>
    ChangeNotifierProvider<ConnectivityProvider>.value(value: _Connectivity(internet: internet, vpn: vpn));

/// 지갑 1 "Daily1"(보기 전용), 지갑 2 "Savings2"
final _wallets = [
  WalletMock.createSingleSigWalletItem(id: 1, name: 'Daily'),
  WalletMock.createSingleSigWalletItem(id: 2, name: 'Savings'),
];

Finder _inGauge(String text) => find.descendant(of: find.byType(HealthGauge), matching: _text(text));

Finder _svg(String asset) => find.byWidgetPredicate(
  (w) => w is SvgPicture && w.bytesLoader is SvgAssetLoader && (w.bytesLoader as SvgAssetLoader).assetName == asset,
);

final _premiumCard = find.byKey(const Key('wallet-health-premium-card'));
final _checkAgain = find.byKey(const Key('wallet-health-check-again'));
final _addWallet = find.byKey(const Key('wallet-health-add-wallet'));

void main() {
  setUpAll(() => VisibilityDetectorController.instance.updateInterval = Duration.zero);
  tearDownAll(() => VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 500));
  for (final variant in CoconutThemeVariant.values) {
    group(variant.name, () {
      testWidgets('S1 scored + review: number, label, review rows, Free Premium card, all good, recommended', (
        tester,
      ) async {
        await _pump(tester, scoredReport(), variant: variant);
        expect(_inGauge('86'), findsOneWidget);
        expect(_inGauge(t.wallet_health.score_label.good), findsOneWidget);
        expect(_checkAgain, findsOneWidget);
        expect(_text(t.wallet_health.section.review_needed), findsOneWidget);
        expect(_text(t.wallet_health.check.watch_only_verify.issue_not_verified), findsOneWidget);
        expect(_text(t.wallet_health.category.addresses_reused(n: 2)), findsNWidgets(2)); // 카드 상태 줄 + 행
        expect(_premiumCard, findsOneWidget);
        // C4: 판매 카드 안에는 칩이 없다(Premium 바탕 위에서 묻히고 젬이 두 번 나온다). 머리 줄은 PremiumMark 20
        expect(find.descendant(of: _premiumCard, matching: find.byType(PremiumChip)), findsNothing);
        expect(find.descendant(of: _premiumCard, matching: find.byType(PremiumMark)), findsOneWidget);
        expect(_text(t.wallet_health.section.all_good), findsOneWidget);
        expect(_text(t.wallet_health.section.recommended), findsOneWidget);
        expect(_text(t.wallet_health.recommended.mnemonic_stored), findsOneWidget);
        // Free 문구는 상시 감시를 약속하지 않는다
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          expect((text.data ?? '').replaceAll('\u2060', ''), isNot(contains('모니터링')));
        }
      });

      testWidgets('S2 all good: no review section, Premium card still after the cards', (tester) async {
        await _pump(tester, scoredReport(issues: false), variant: variant);
        expect(_text(t.wallet_health.section.review_needed), findsNothing);
        expect(_premiumCard, findsOneWidget);
      });

      testWidgets('S4 not enough data: dash, explanation, how-it-works link, waiting checks, no sales or unlock card', (
        tester,
      ) async {
        await _pump(tester, notEnoughDataReport(), variant: variant);
        expect(_inGauge(t.wallet_health.hero.not_enough_data_title), findsOneWidget);
        expect(find.descendant(of: find.byType(HealthGauge), matching: _textContaining(RegExp(r'\d'))), findsNothing);
        expect(_text(t.wallet_health.hero.not_enough_data_body), findsOneWidget);
        expect(_text(t.wallet_health.hero.how_score_works), findsOneWidget);
        expect(_text(t.wallet_health.section.available_now), findsOneWidget);
        expect(_text(t.wallet_health.section.not_included_yet), findsOneWidget);
        expect(_text(t.wallet_health.check.passphrase_verify.name), findsNothing); // 해당 없음은 "아직"이 아니다
        // "더 많은 점검을 하려면"은 S0 전용(UI 브리프 WH-S4에는 없다). S4는 판매 카드 대신 비상 이동 줄만(POLISH §4 D4)
        expect(find.byType(WalletHealthUnlockCard), findsNothing);
        expect(_text(t.wallet_health.section.unlock_more), findsNothing);
        expect(_premiumCard, findsNothing);
        expect(_checkAgain, findsOneWidget);
      });

      testWidgets('S0 no wallet: no number or label, [지갑 추가] instead of check again, no Premium', (tester) async {
        await _pump(tester, noWalletReport(), variant: variant);
        expect(_inGauge(t.wallet_health.hero.no_wallet_title), findsOneWidget);
        expect(find.descendant(of: find.byType(HealthGauge), matching: _textContaining(RegExp(r'\d'))), findsNothing);
        for (final label in WalletHealthLabel.values) {
          expect(_text(walletHealthLabelText(label)), findsNothing);
        }
        expect(_addWallet, findsOneWidget);
        expect(_text(t.home_widgets.add_wallet), findsOneWidget);
        expect(_checkAgain, findsNothing);
        expect(_text(t.wallet_health.hero.no_wallet_body), findsOneWidget);
        expect(_text(t.wallet_health.category.available), findsOneWidget);
        expect(_text(t.wallet_health.section.after_adding_wallet), findsOneWidget);
        expect(_text(t.wallet_health.section.not_included_footer_no_wallet), findsOneWidget);
        expect(_premiumCard, findsNothing);
        expect(find.byKey(const Key('wallet-health-premium-active')), findsNothing);
        // 할 일 안내: 세 줄 모두 중립 동그라미, 완료 체크는 없다
        final unlock = find.byType(WalletHealthUnlockCard);
        expect(unlock, findsOneWidget);
        expect(find.descendant(of: unlock, matching: _svg(CommonActionIconPath.check)), findsNothing);
        expect(find.descendant(of: unlock, matching: _svg(CommonFormIconPath.circle)), findsNWidgets(3));
      });

      testWidgets('S3 critical: siren hero, incident card, [거래 검토] above the Premium variant, other checks', (
        tester,
      ) async {
        await _pump(tester, criticalReport(incidents: 2), variant: variant);
        expect(_text(t.wallet_health.critical.title), findsOneWidget);
        expect(_text(t.wallet_health.incident.outgoing_multiple_title(n: 2)), findsOneWidget);
        expect(_inGauge('76'), findsNothing);
        expect(find.byKey(const Key('wallet-health-incident-card')), findsOneWidget);
        expect(_text(t.wallet_health.critical.more_alerts(n: 1)), findsOneWidget);
        expect(_text(t.wallet_health.critical.review_transaction), findsOneWidget);
        expect(_text(t.premium.card.critical_title), findsOneWidget);
        // 무료 대응 버튼이 Premium 카드보다 위
        expect(
          tester.getTopLeft(find.byKey(const Key('wallet-health-critical-review'))).dy,
          lessThan(tester.getTopLeft(_premiumCard).dy),
        );
        expect(_text(t.wallet_health.critical.other_checks), findsOneWidget);
        expect(_text(t.wallet_health.check.app_lock.issue), findsOneWidget);
        expect(_checkAgain, findsNothing);
      });
    });
  }

  testWidgets('label for 0–49 is "조치 필요", never "Critical"', (tester) async {
    await _pump(tester, scoredReport(score: 40));
    expect(_inGauge('조치 필요'), findsOneWidget);
    expect(_textContaining('Critical'), findsNothing);

    await _pump(tester, scoredReport(score: 40), locale: AppLocale.en);
    expect(_inGauge('Action needed'), findsOneWidget);
    expect(_textContaining('Critical'), findsNothing);
  });

  testWidgets('check again shows the checking state for at least 700 ms, then returns', (tester) async {
    final safety = await _pump(tester, scoredReport());
    await tester.tap(_checkAgain);
    await tester.pump();
    expect(safety.checks, 1);
    expect(_text(t.wallet_health.summary.checking), findsNWidgets(2)); // 게이지 + 버튼
    expect(find.byKey(const Key('wallet-health-card-skeleton')), findsNWidgets(4));
    // 누른 채로 또 눌러도 한 번만
    await tester.tap(_checkAgain, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 600));
    expect(safety.checks, 1);
    expect(_text(t.wallet_health.summary.checking), findsNWidgets(2));
    // provider 최소 1.2초 + 화면 최소 700ms(Stopwatch는 실제 시간이라 테스트에서는 700ms를 다 기다린다)
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(_text(t.wallet_health.summary.checking), findsNothing);
    expect(_text(t.wallet_health.summary.check_again), findsOneWidget);
  });

  testWidgets('open(startCheck: true) starts one check on entry', (tester) async {
    final started = await _pump(tester, scoredReport(), startCheck: true);
    await tester.pump();
    expect(started.checks, 1); // 다시 검사 안의 평가는 provider가 한다
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(started.checks, 1);
  });

  testWidgets('startCheck waits for the push transition, not the offstage first frame', (tester) async {
    final safety = await pumpWalletHealthApp(
      tester,
      Builder(
        builder:
            (context) => TextButton(
              onPressed: () => WalletHealthScreen.open(context, startCheck: true),
              child: const Text('open'),
            ),
      ),
      report: scoredReport(),
      wallets: _wallets,
      reduceMotion: false,
    );
    await tester.tap(_text('open'));
    await tester.pump(); // 첫 프레임은 Hero 측정용 offstage
    await tester.pump(const Duration(milliseconds: 300)); // 아직 밀려 들어오는 중
    expect(safety.checks, 0);
    await tester.pump(const Duration(milliseconds: 400)); // Cupertino 전환(500ms) 끝
    await tester.pump();
    expect(safety.checks, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(_text(t.wallet_health.summary.check_again), findsOneWidget);
  });

  group('C1: review sheets follow balance hide / fake balance', () {
    final dust = UtxoState(
      transactionHash: 'd' * 64,
      index: 0,
      amount: 546,
      derivationPath: "m/84'/1'/0'/0/0",
      blockHeight: 100,
      to: 'bc1qdust',
      timestamp: DateTime(2026, 10, 1),
    );
    final dustCheck = SafetyCheckResult(
      SafetyCheckId.possibleDusting,
      SafetyOutcome.failed,
      walletId: 1,
      severity: SafetySeverity.warning,
      evidence: SafetyEvidence.heuristic,
      subjects: [dust.utxoId],
    );
    final reuseCheck = scoredReport().reviewItems.firstWhere((r) => r.id == SafetyCheckId.addressReuse);

    Future<void> open(
      WidgetTester tester,
      SafetyCheckResult check,
      PreferenceProvider? preferences, {
      List<UtxoState>? utxos,
    }) async {
      await tester.pumpWidget(const SizedBox()); // 앞서 연 시트를 닫고 새로 시작
      await pumpWalletHealthApp(
        tester,
        Builder(
          builder:
              (context) =>
                  TextButton(onPressed: () => showSafetyReviewItemSheet(context, check), child: const Text('open')),
        ),
        report: scoredReport(),
        wallets: _wallets,
        utxos: {
          1: utxos ?? [dust],
        },
        preferences: preferences,
      );
      await tester.tap(_text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('C42: each reused address lists its remaining UTXOs, five then "외 N건"', (tester) async {
      final address = reuseCheck.subjects.first;
      final left = [
        for (var i = 0; i < 7; i++)
          UtxoState(
            transactionHash: '${'e' * 63}$i',
            index: i,
            amount: 1000 + i,
            derivationPath: "m/84'/1'/0'/0/1",
            blockHeight: 100,
            to: address,
            timestamp: DateTime(2026, 10, 2),
          ),
      ];
      final sheet = find.byKey(const Key('wallet-health-review-sheet'));
      await open(tester, reuseCheck, FakePreferences(), utxos: left);
      expect(find.descendant(of: sheet, matching: find.byType(SafetyPressRow)), findsNWidgets(5));
      expect(_text(t.wallet_health.widget.more_items(n: 2)), findsOneWidget);
      expect(_textContaining('1,000'), findsOneWidget);
      // 남은 개수 글은 없다(줄이 보여 준다)
      expect(_text(t.wallet_health.review.address_reuse.utxos_left(n: 7)), findsNothing);
      // 숨김이면 금액 대신 "숨김", 동작은 그대로
      await open(tester, reuseCheck, FakePreferences(isBalanceHidden: true), utxos: left);
      expect(_textContaining('1,000'), findsNothing);
      expect(find.descendant(of: sheet, matching: _text(t.premium.assist.hidden)), findsNWidgets(5));
    });

    testWidgets('visible: dust amount and reused addresses are shown', (tester) async {
      await open(tester, dustCheck, FakePreferences());
      expect(_textContaining('546'), findsOneWidget);
      await open(tester, reuseCheck, FakePreferences());
      expect(_textContaining('bc1qreuse000'), findsNWidgets(2));
    });

    for (final (mode, preferences) in [
      ('hidden balance', FakePreferences(isBalanceHidden: true)),
      ('fake balance', FakePreferences(isFakeBalanceActive: true)),
      ('no preference provider', null),
    ]) {
      testWidgets('$mode: no real amount or address fragment, explanation and actions stay', (tester) async {
        await open(tester, dustCheck, preferences);
        expect(_textContaining('546'), findsNothing);
        expect(_textContaining(t.wallet_health.review.dusting.unlocked), findsOneWidget);
        expect(_text(t.wallet_health.review.dusting.view_utxo), findsOneWidget);

        await open(tester, reuseCheck, preferences);
        expect(_textContaining('bc1qreuse'), findsNothing);
        expect(_text(t.wallet_health.review.address_reuse.body), findsOneWidget);
        expect(_text(t.wallet_health.review.address_reuse.view_utxos), findsOneWidget);
      });
    }
  });

  testWidgets('C2: an incident plus a critical certificate change keeps the certificate actionable', (tester) async {
    final base = criticalReport();
    const cert = SafetyCheckResult(
      SafetyCheckId.serverCert,
      SafetyOutcome.failed,
      severity: SafetySeverity.critical,
      detail: SafetyCheckDetail.identityChanged,
      subjects: ['AA:BB', 'CC:DD'],
    );
    final report = WalletHealthReport(
      status: base.status,
      score: base.score,
      label: base.label,
      profile: base.profile,
      categories: base.categories,
      criticalIncidents: base.criticalIncidents,
      reviewItems: [cert, ...base.reviewItems],
      walletCount: 1,
      evaluatedAt: DateTime.now(),
    );
    await _pump(tester, report);
    expect(_text(t.wallet_health.incident.outgoing_title), findsOneWidget); // 머리 = 사건
    expect(find.byKey(Key('wallet-health-review-${cert.key}')), findsOneWidget);
    expect(_text(t.wallet_health.incident.server_identity_title), findsOneWidget);
  });

  testWidgets('C2: two non-incident criticals: the hero shows one, the other stays in review', (tester) async {
    const watchOnly = SafetyCheckResult(
      SafetyCheckId.watchOnlyVerify,
      SafetyOutcome.failed,
      walletId: 1,
      severity: SafetySeverity.critical,
      detail: SafetyCheckDetail.mismatch,
    );
    const cert = SafetyCheckResult(
      SafetyCheckId.serverCert,
      SafetyOutcome.failed,
      severity: SafetySeverity.critical,
      detail: SafetyCheckDetail.identityChanged,
      subjects: ['AA:BB', 'CC:DD'],
    );
    final report = WalletHealthReport(
      status: WalletHealthStatus.criticalOverride,
      score: 80,
      label: WalletHealthLabel.good,
      profile: WeightProfile.watchOnlyOnly,
      categories: categories(),
      reviewItems: const [watchOnly, cert],
      walletCount: 1,
      evaluatedAt: DateTime.now(),
    );
    await _pump(tester, report);
    expect(_text(t.wallet_health.incident.watch_only_mismatch_title), findsOneWidget); // 머리
    expect(find.byKey(Key('wallet-health-review-${watchOnly.key}')), findsNothing);
    expect(find.byKey(Key('wallet-health-review-${cert.key}')), findsOneWidget);
  });

  testWidgets('C3: without EntitlementService no paywall card is offered (the paywall needs it)', (tester) async {
    await _pump(tester, scoredReport(), entitlement: false);
    expect(_premiumCard, findsNothing);
    expect(_text(t.wallet_health.section.all_good), findsOneWidget);
    await _pump(tester, criticalReport(), entitlement: false);
    expect(_premiumCard, findsNothing);
    expect(_text(t.wallet_health.critical.other_checks), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('C4: pending or blocked drafts are not shown as ready', (tester) async {
    const active = PremiumState(PremiumStatus.active);
    await _pump(
      tester,
      scoredReport(),
      premium: active,
      rescue: FakeRescueReady(statuses: {1: RescueStatus.pending, 2: RescueStatus.pending}),
    );
    expect(_text(t.premium.rescue.draft_pending), findsOneWidget);
    expect(_textContaining(t.premium.rescue.ready_body), findsNothing);
    expect(_text(t.premium.rescue.health_row(n: 0)), findsNothing);

    for (final (status, text) in [
      (RescueStatus.noBalance, t.premium.rescue.draft_no_balance),
      (RescueStatus.tooSmall, t.premium.rescue.draft_too_small),
      (RescueStatus.unavailable, t.premium.rescue.draft_unavailable),
    ]) {
      await _pump(
        tester,
        scoredReport(),
        premium: active,
        rescue: FakeRescueReady(statuses: {1: RescueStatus.ready, 2: status}, drafts: {1: readyDraft()}),
      );
      expect(_text(t.premium.rescue.ready_partial(ready: 1, total: 2)), findsOneWidget, reason: '$status');
      expect(_text(text), findsOneWidget, reason: '$status');
    }
  });

  testWidgets('C5: the app-lock action opens PIN setup that closes only itself, not Wallet Health', (tester) async {
    final base = scoredReport();
    const appLock = SafetyCheckResult(
      SafetyCheckId.appLock,
      SafetyOutcome.failed,
      severity: SafetySeverity.actionNeeded,
    );
    final report = WalletHealthReport(
      status: base.status,
      score: base.score,
      label: base.label,
      profile: base.profile,
      categories: base.categories,
      reviewItems: const [appLock],
      walletCount: 1,
      evaluatedAt: DateTime.now(),
    );
    await pumpWalletHealthApp(
      tester,
      const WalletHealthScreen(),
      report: report,
      wallets: _wallets,
      extra: [ChangeNotifierProvider<AuthProvider>.value(value: FakeAuth())],
    );
    await tester.tap(find.byKey(Key('wallet-health-review-${appLock.key}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.widget<PinSettingScreen>(find.byType(PinSettingScreen)).popParentOnComplete, isFalse);
  });

  testWidgets('C6: a check that finishes at once still shows checking for 700 ms', (tester) async {
    final safety = InstantSafetyProvider(scoredReport());
    await pumpWalletHealthApp(tester, const WalletHealthScreen(), safety: safety, wallets: _wallets);
    await tester.tap(_checkAgain);
    await tester.pump();
    expect(safety.checks, 1);
    await tester.pump(const Duration(milliseconds: 650));
    expect(_text(t.wallet_health.summary.checking), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(_text(t.wallet_health.summary.checking), findsNothing);
    expect(_text(t.wallet_health.summary.check_again), findsOneWidget);
  });

  testWidgets('C6: a check that fails at once also waits 700 ms, then says it failed', (tester) async {
    final safety = InstantSafetyProvider(scoredReport(), error: StateError('offline'));
    await pumpWalletHealthApp(tester, const WalletHealthScreen(), safety: safety, wallets: _wallets);
    await tester.tap(_checkAgain);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    expect(_text(t.wallet_health.summary.checking), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(_text(t.wallet_health.summary.checking), findsNothing);
    expect(_text(t.wallet_health.toast.check_failed), findsOneWidget);
    await tester.pump(const Duration(seconds: 4)); // 토스트가 사라질 때까지
    await tester.pumpAndSettle();
  });

  testWidgets('wallet contribution sheet ends with "지갑 상태 전체 보기" that opens Wallet Health', (tester) async {
    await pumpWalletHealthApp(
      tester,
      Builder(
        builder:
            (context) =>
                TextButton(onPressed: () => showWalletContributionSheet(context, 1), child: const Text('open')),
      ),
      report: scoredReport(),
      wallets: _wallets,
    );
    await tester.tap(_text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-wallet-sheet')), findsOneWidget);
    expect(_text(t.wallet_health.wallet_info.view_all), findsOneWidget);
    // C2: 목록 끝 밑줄 글이 아니라 시트 아래에 고정한 앱 표준 버튼(목록을 내리지 않아도 보인다)
    final viewAll = find.byKey(const Key('wallet-health-view-all'));
    expect(find.ancestor(of: viewAll, matching: find.byType(FixedBottomButton)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('wallet-health-wallet-sheet')), matching: viewAll), findsNothing);
    expect(_text(t.wallet_health.wallet_info.view_all).hitTestable(), findsOneWidget);
    await tester.tap(_text(t.wallet_health.wallet_info.view_all));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-wallet-sheet')), findsNothing);
    expect(find.byType(WalletHealthScreen), findsOneWidget);
  });

  testWidgets('plain open only refreshes', (tester) async {
    final plain = await _pump(tester, scoredReport());
    expect(plain.checks, 0);
    expect(plain.refreshes, 1);
  });

  testWidgets('Premium line only with an active entitlement; the Rescue-ready row for everyone, outside the score', (
    tester,
  ) async {
    final allReady = FakeRescueReady(
      statuses: {1: RescueStatus.ready, 2: RescueStatus.ready},
      drafts: {1: readyDraft(), 2: readyDraft()},
    );
    await _pump(tester, scoredReport(), premium: const PremiumState(PremiumStatus.none), rescue: allReady);
    expect(_premiumCard, findsOneWidget);
    // 무료에게도 자리를 보인다(POLISH §4 D1): 칩이 붙은 비상 이동 줄
    expect(
      find.descendant(of: find.byKey(const Key('wallet-health-rescue-ready')), matching: find.byType(PremiumChip)),
      findsOneWidget,
    );

    await _pump(tester, scoredReport(), premium: const PremiumState(PremiumStatus.active), rescue: allReady);
    expect(_premiumCard, findsNothing);
    expect(find.byKey(const Key('wallet-health-premium-active')), findsOneWidget);
    expect(_text(t.premium.subscription.active_title), findsOneWidget);
    expect(_text(t.premium.name), findsOneWidget); // 구역 하나 "Coconut Premium"(POLISH §4 D1)
    expect(_text(t.premium.rescue.health_row(n: 2)), findsOneWidget);
    expect(_textContaining(t.premium.rescue.ready_body), findsOneWidget);
    expect(_inGauge('86'), findsOneWidget); // 점수는 Premium과 무관
  });

  testWidgets('S4 keeps the Premium line and the Rescue-ready entry before any funds', (tester) async {
    await _pump(
      tester,
      notEnoughDataReport(),
      premium: const PremiumState(PremiumStatus.active),
      rescue: FakeRescueReady(),
    );
    expect(find.byKey(const Key('wallet-health-premium-active')), findsOneWidget);
    expect(find.byKey(const Key('wallet-health-rescue-ready')), findsOneWidget);
    expect(_text(t.premium.rescue.none_body), findsOneWidget); // 목적지 없음 상태도 열 수 있다(R05)
    expect(_inGauge(t.wallet_health.hero.not_enough_data_title), findsOneWidget); // 점수는 여전히 없다
  });

  group('C3: one Coconut Premium section, status before sales (POLISH §4)', () {
    final rescueRow = find.byKey(const Key('wallet-health-rescue-ready'));
    final premiumTitle = _text(t.premium.name);

    testWidgets('free S1: the rescue row (with the Premium chip) comes before the sales card', (tester) async {
      await _pump(tester, scoredReport(), rescue: FakeRescueReady());
      expect(premiumTitle, findsOneWidget);
      expect(find.descendant(of: rescueRow, matching: find.byType(PremiumChip)), findsOneWidget);
      expect(find.descendant(of: rescueRow, matching: _text(t.premium.rescue.name)), findsOneWidget);
      expect(tester.getTopLeft(rescueRow).dy, lessThan(tester.getTopLeft(_premiumCard).dy)); // 상태가 먼저, 광고는 그다음
    });

    testWidgets('free S4: the rescue row only, no sales card', (tester) async {
      await _pump(tester, notEnoughDataReport(), rescue: FakeRescueReady());
      expect(rescueRow, findsOneWidget);
      expect(_premiumCard, findsNothing);
    });

    testWidgets('verifying: no sales card and no chip (the first screen must not flash an ad)', (tester) async {
      await _pump(
        tester,
        scoredReport(),
        premium: const PremiumState(PremiumStatus.verifying),
        rescue: FakeRescueReady(),
      );
      expect(_premiumCard, findsNothing);
      expect(rescueRow, findsOneWidget);
      expect(find.descendant(of: rescueRow, matching: find.byType(PremiumChip)), findsNothing);
    });

    testWidgets('expired with a destination left: the paused row stays, the sales card is hidden', (tester) async {
      await _pump(
        tester,
        scoredReport(),
        premium: const PremiumState(PremiumStatus.expired),
        rescue: FakeRescueReady(statuses: {1: RescueStatus.paused}),
      );
      expect(find.descendant(of: rescueRow, matching: _text(t.premium.rescue.paused_title)), findsOneWidget);
      expect(_premiumCard, findsNothing);
    });

    testWidgets('subscriber: "Premium 사용 중" (gem) then the rescue row (feature icon), no sales card', (tester) async {
      await _pump(tester, scoredReport(), premium: const PremiumState(PremiumStatus.active), rescue: FakeRescueReady());
      final active = find.byKey(const Key('wallet-health-premium-active'));
      expect(find.descendant(of: active, matching: _text(t.premium.subscription.active_title)), findsOneWidget);
      expect(find.descendant(of: active, matching: find.byType(PremiumMark)), findsOneWidget);
      expect(find.ancestor(of: active, matching: find.byType(PremiumSurface)), findsOneWidget);
      expect(find.ancestor(of: rescueRow, matching: find.byType(PremiumSurface)), findsOneWidget);
      expect(find.descendant(of: rescueRow, matching: find.byType(PremiumMark)), findsNothing);
      expect(tester.getTopLeft(active).dy, lessThan(tester.getTopLeft(rescueRow).dy));
      expect(_premiumCard, findsNothing);
    });
  });

  testWidgets('Rescue-ready line covers partial, none, failed and paused', (tester) async {
    const active = PremiumState(PremiumStatus.active);
    await _pump(
      tester,
      scoredReport(),
      premium: active,
      rescue: FakeRescueReady(statuses: {1: RescueStatus.ready}, drafts: {1: readyDraft()}),
    );
    expect(_text(t.premium.rescue.ready_partial(ready: 1, total: 2)), findsOneWidget);
    expect(_text(t.premium.rescue.partial_body), findsOneWidget);

    await _pump(tester, scoredReport(), premium: active, rescue: FakeRescueReady());
    expect(_text(t.premium.rescue.none_body), findsOneWidget);

    await _pump(
      tester,
      scoredReport(),
      premium: active,
      rescue: FakeRescueReady(statuses: {1: RescueStatus.failed, 2: RescueStatus.ready}),
    );
    final title = tester.widget<Text>(_text(t.premium.rescue.needs_check_title));
    expect(title.style!.color, resolveCoconutThemeExtension(variant: CoconutThemeVariant.light).colors.warningText);
    expect(_text(t.premium.rescue.fee_failed), findsOneWidget);

    // 구독이 끝나도 정해 둔 목적지가 있으면 "멈춤" 줄(초안·지갑은 그대로)
    await _pump(
      tester,
      scoredReport(),
      premium: const PremiumState(PremiumStatus.expired),
      rescue: FakeRescueReady(statuses: {1: RescueStatus.paused}),
    );
    expect(_premiumCard, findsNothing); // 남은 초안 옆 광고는 볼모처럼 읽힌다(POLISH §4 D5)
    expect(_text(t.premium.rescue.paused_title), findsOneWidget);
  });

  testWidgets('S3: a ready rescue draft shows [지금 이동] in the Premium slot, below [거래 검토]', (tester) async {
    await _pump(
      tester,
      criticalReport(),
      premium: const PremiumState(PremiumStatus.expired),
      rescue: FakeRescueReady(statuses: {1: RescueStatus.paused}, drafts: {1: readyDraft()}),
    );
    final card = find.byKey(const Key('wallet-health-rescue-card'));
    expect(card, findsOneWidget);
    expect(_text(t.premium.rescue.card_title), findsOneWidget);
    expect(_text(t.premium.rescue.move_now), findsOneWidget);
    expect(_premiumCard, findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('wallet-health-critical-review'))).dy,
      lessThan(tester.getTopLeft(card).dy),
    );
    // 지갑 · 거래 상태 줄, 잔액을 모르면 금액 대신 "보낸 거래"
    expect(_text('Daily1 · ${t.wallet_health.incident.tx_state.unconfirmed}'), findsOneWidget);
    expect(_text(t.wallet_health.critical.sent_transaction), findsOneWidget);

    await _pump(tester, criticalReport(), premium: const PremiumState(PremiumStatus.active), rescue: FakeRescueReady());
    expect(find.byKey(const Key('wallet-health-assist-card')), findsOneWidget);
    expect(_text(t.premium.card.prepare_response), findsOneWidget);
  });

  testWidgets('S3 without an incident: server identity change shows the server card and [인증서 검토]', (tester) async {
    final report = WalletHealthReport(
      status: WalletHealthStatus.criticalOverride,
      score: 90,
      label: WalletHealthLabel.excellent,
      profile: WeightProfile.hotFunded,
      categories: categories(recoveryIssues: 0, privacyIssues: 0),
      reviewItems: const [
        SafetyCheckResult(
          SafetyCheckId.serverCert,
          SafetyOutcome.failed,
          severity: SafetySeverity.critical,
          detail: SafetyCheckDetail.identityChanged,
          subjects: ['AA:BB:CC:DD:EE:FF:00:11', '12:34:56:78:9A:BC:DE:F0'],
        ),
      ],
      walletCount: 1,
      evaluatedAt: DateTime.now(),
    );
    await _pump(tester, report);
    expect(_text(t.wallet_health.incident.server_identity_title), findsOneWidget);
    expect(find.byKey(const Key('wallet-health-critical-check-card')), findsOneWidget);
    expect(_text('${t.wallet_health.review.server_cert.fingerprint} 12345678…'), findsOneWidget);
    expect(_text(t.wallet_health.critical.review_certificate), findsOneWidget);
    expect(_text(t.wallet_health.critical.other_checks), findsOneWidget);
    expect(_text(t.wallet_health.section.review_needed), findsNothing); // 위급 항목은 머리에서만
  });

  testWidgets('mempool-dropped incident is an info row in the review card, wallet rows carry the wallet', (
    tester,
  ) async {
    final base = scoredReport();
    final report = WalletHealthReport(
      status: base.status,
      score: base.score,
      label: base.label,
      profile: base.profile,
      categories: base.categories,
      reviewItems: base.reviewItems,
      allGoodItems: base.allGoodItems,
      recommended: base.recommended,
      infoIncidents: [
        SafetyIncident(walletId: 2, txid: 'b' * 64, detectedAt: DateTime.now(), txState: IncidentTxState.dropped),
      ],
      walletCount: 2,
      evaluatedAt: DateTime.now(),
    );
    await _pump(tester, report);
    expect(_text(t.wallet_health.section.mempool_dropped), findsOneWidget);
    expect(_text('Savings2 · ${t.wallet_home_screen.wallet_filter.watch_only}'), findsOneWidget);
    expect(_text('Daily1 · ${t.wallet_home_screen.wallet_filter.watch_only}'), findsNWidgets(2));
    expect(_text(t.wallet_health.section.recommended_progress(done: 0, total: 1)), findsOneWidget);
  });

  testWidgets('info button opens the About sheet with the v2 categories and no "pts"', (tester) async {
    await _pump(tester, scoredReport());
    await tester.tap(find.byKey(const Key('wallet-health-info')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-about-sheet')), findsOneWidget);
    // C16: 시트 제목은 짧게(화면 제목과 같은 "지갑 상태"), 문장 제목은 본문 첫 줄 18 Bold
    expect(_text(t.wallet_health.title), findsNWidgets(2)); // 화면 앱바 + 시트 머리
    final heading = find.descendant(
      of: find.byKey(const Key('wallet-health-about-sheet')),
      matching: _text(t.wallet_health.about.title),
    );
    expect(heading, findsOneWidget);
    expect(tester.widget<Text>(heading).style!.fontSize, 18);
    for (final label in WalletHealthLabel.values) {
      expect(_text(walletHealthLabelText(label)), findsWidgets);
    }
    expect(_text('45%'), findsOneWidget);
    expect(_textContaining('pts'), findsNothing);
    expect(_text(t.wallet_health.about.coverage_body), findsOneWidget);
    expect(_text(t.wallet_health.about.data_note), findsOneWidget);
    expect(_text(t.wallet_health.about.weight_largest_wallet), findsOneWidget);
  });

  testWidgets('category card opens its detail sheet; a failing row inside it opens the review sheet', (tester) async {
    await _pump(tester, scoredReport());
    await tester.tap(find.byKey(const Key('wallet-health-category-privacy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-category-sheet-privacy')), findsOneWidget);
    expect(_text(t.wallet_health.about.weight_privacy), findsOneWidget);
    // 실패 행: 이름 + 짧은 결과 + 꺾쇠
    expect(_text(t.wallet_health.check.address_reuse.count(n: 2)), findsOneWidget);
    final reuseRow = find.byKey(Key('wallet-health-check-row-${scoredReport().reviewItems[1].key}'));
    expect(reuseRow, findsOneWidget);
    await tester.tap(reuseRow);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-category-sheet-privacy')), findsNothing);
    expect(find.byKey(const Key('wallet-health-review-sheet')), findsOneWidget);
    // C16: 시트 머리는 점검 이름, 문장 제목은 본문 첫 줄(긴 de/es/ja 제목이 말줄임되지 않게)
    final heading = find.descendant(
      of: find.byKey(const Key('wallet-health-review-sheet')),
      matching: _text(t.wallet_health.review.address_reuse.title),
    );
    expect(heading, findsOneWidget);
    expect(tester.widget<Text>(heading).style!.fontSize, 18);
    expect(_text(safetyCheckName(SafetyCheckId.addressReuse)), findsWidgets);
  });

  // 앱 뿌리가 CupertinoApp이라 Android에서도 튕김 스크롤(CupertinoScrollBehavior)로 당겨진다. 이 틀은 MaterialApp이라
  // 같은 스크롤 동작을 깔고 기본 플랫폼(Android)에서 확인한다
  testWidgets('C15: in S3 pulling down shows the standard refresh indicator; scored layouts keep the sweep', (
    tester,
  ) async {
    Future<void> pump(WalletHealthReport report) => pumpWalletHealthApp(
      tester,
      const ScrollConfiguration(behavior: CupertinoScrollBehavior(), child: WalletHealthScreen()),
      report: report,
      premium: const PremiumState(PremiumStatus.none),
      wallets: _wallets,
    );
    await pump(criticalReport(incidents: 1));
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 300));
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await pump(scoredReport());
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, 300));
    await tester.pump();
    expect(find.byType(CupertinoActivityIndicator), findsNothing); // 게이지 스윕이 진행 표시
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('review row opens the review item sheet', (tester) async {
    await _pump(tester, scoredReport());
    await tester.tap(_text(t.wallet_health.category.addresses_reused(n: 2)).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-review-sheet')), findsOneWidget);
    expect(_text(t.wallet_health.review.address_reuse.body), findsOneWidget);
  });

  testWidgets('recommended check is marked done by the user from its sheet', (tester) async {
    final safety = await _pump(tester, scoredReport());
    await tester.tap(_text(t.wallet_health.recommended.mnemonic_stored));
    await tester.pumpAndSettle();
    expect(_text(t.wallet_health.recommended.intro), findsOneWidget);
    await tester.tap(find.byKey(const Key('wallet-health-recommended-toggle')));
    await tester.pumpAndSettle();
    expect(safety.recommendedDone, {RecommendedCheckId.hotPhysicalBackup: true});
  });

  for (final locale in [AppLocale.ko, AppLocale.en]) {
    testWidgets('320 dp ${locale.languageCode}: every state wraps without overflow or shrunk body text', (
      tester,
    ) async {
      for (final report in [scoredReport(), notEnoughDataReport(), noWalletReport(), criticalReport(incidents: 2)]) {
        await _pump(tester, report, locale: locale, width: 320);
        expect(tester.takeException(), isNull);
      }
      await _pump(tester, scoredReport(), locale: locale, width: 320);
      // 본문 글은 줄을 바꾸고 줄이지 않는다
      for (final text in [t.wallet_health.check.watch_only_verify.issue_not_verified, t.premium.card.body]) {
        expect(find.ancestor(of: _text(text), matching: find.byType(FittedBox)), findsNothing, reason: text);
      }
      // 한 줄 이름·숫자만 줄여 맞춘다(POLISH R2·C22): 카드 머리 폭에서 단어 중간에 줄이 바뀌지 않게
      expect(
        find.ancestor(of: _text(t.wallet_health.category.recovery_readiness), matching: find.byType(FittedBox)),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('wallet-health-info')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  group('P1 polish', () {
    WalletHealthReport report({
      List<SafetyCheckResult>? reviewItems,
      List<SafetyCheckResult>? allGoodItems,
      DateTime? lastSuccessfulSyncAt,
    }) {
      final base = scoredReport();
      return WalletHealthReport(
        status: base.status,
        score: base.score,
        label: base.label,
        profile: base.profile,
        categories: base.categories,
        recovery: base.recovery,
        reviewItems: reviewItems ?? base.reviewItems,
        allGoodItems: allGoodItems ?? base.allGoodItems,
        notIncluded: base.notIncluded,
        recommended: base.recommended,
        walletCount: base.walletCount,
        fundedWalletCount: base.fundedWalletCount,
        evaluatedAt: base.evaluatedAt,
        lastSuccessfulSyncAt: lastSuccessfulSyncAt,
      );
    }

    testWidgets('C40: a check is "정상" only when no wallet fails it', (tester) async {
      await _pump(
        tester,
        report(
          reviewItems: const [
            SafetyCheckResult(
              SafetyCheckId.mnemonicBackup,
              SafetyOutcome.failed,
              walletId: 2,
              severity: SafetySeverity.actionNeeded,
            ),
          ],
          allGoodItems: const [
            SafetyCheckResult(SafetyCheckId.mnemonicBackup, SafetyOutcome.passed, walletId: 1),
            SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.passed),
          ],
        ),
      );
      final passed = [for (final row in tester.widgetList<SafetyPassedRow>(find.byType(SafetyPassedRow))) row.item.id];
      expect(passed, isNot(contains(SafetyCheckId.mnemonicBackup)));
      expect(passed, contains(SafetyCheckId.appLock));
    });

    testWidgets('C45: About shows "—" for the last update until a sync succeeded', (tester) async {
      final about = find.byKey(const Key('wallet-health-about-sheet'));
      await _pump(tester, report());
      await tester.tap(find.byKey(const Key('wallet-health-info')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: about, matching: _text('—')), findsOneWidget);

      await tester.pumpWidget(const SizedBox()); // 열린 시트 경로를 지운다(같은 MaterialApp이면 남는다)
      await _pump(tester, report(lastSuccessfulSyncAt: DateTime(2026, 10, 20, 9)));
      await tester.tap(find.byKey(const Key('wallet-health-info')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: about, matching: _text('—')), findsNothing);
    });

    testWidgets('C3: the free row says what it does; verifying with a destination says it is checking', (tester) async {
      final row = find.byKey(const Key('wallet-health-rescue-ready'));
      await _pump(tester, scoredReport(), rescue: FakeRescueReady());
      expect(find.descendant(of: row, matching: _text(t.premium.rescue.free_body)), findsOneWidget);
      await _pump(
        tester,
        scoredReport(),
        premium: const PremiumState(PremiumStatus.verifying),
        rescue: FakeRescueReady(statuses: {1: RescueStatus.ready}),
      );
      expect(find.descendant(of: row, matching: _text(t.premium.rescue.verifying)), findsOneWidget);
    });

    Future<void> openRecommended(
      WidgetTester tester,
      RecommendedCheckId id, {
      double width = 390,
      double height = 2400,
      double textScale = 1,
    }) async {
      await tester.pumpWidget(const SizedBox());
      await pumpWalletHealthApp(
        tester,
        Builder(
          builder:
              (context) => TextButton(
                onPressed: () => showSafetyRecommendedSheet(context, RecommendedItem(id: id)),
                child: const Text('open'),
              ),
        ),
        report: scoredReport(),
        wallets: _wallets,
        width: width,
        height: height,
        textScale: textScale,
      );
      await tester.tap(_text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('C43: own titles for hot storage and multisig separation; title, guide, then the common intro', (
      tester,
    ) async {
      final r = t.wallet_health.recommended;
      await openRecommended(tester, RecommendedCheckId.hotSafeStorage);
      expect(_text(r.safe_storage), findsOneWidget);
      expect(tester.getTopLeft(_text(r.safe_storage_body)).dy, lessThan(tester.getTopLeft(_text(r.intro)).dy));
      await openRecommended(tester, RecommendedCheckId.multisigBackupSeparation);
      expect(_text(r.recovery_separate), findsOneWidget);
      expect(_text(r.recovery_separate_body), findsOneWidget);
      expect(r.safe_storage, isNot(r.recovery_separate));
    });

    testWidgets('C38: at 320×568 and 2.0× the recommended sheet scrolls to its button', (tester) async {
      await openRecommended(tester, RecommendedCheckId.hotPhysicalBackup, width: 320, height: 568, textScale: 2.0);
      expect(tester.takeException(), isNull);
      final toggle = find.byKey(const Key('wallet-health-recommended-toggle'));
      await tester.scrollUntilVisible(
        toggle,
        80,
        scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
      );
      expect(toggle.hitTestable(), findsOneWidget);
    });

    for (final scale in [1.3, 2.0]) {
      testWidgets('320 dp × $scale: every state and the About sheet fit without overflow', (tester) async {
        for (final r in [
          scoredReport(),
          scoredReport(connected: false),
          notEnoughDataReport(),
          noWalletReport(),
          criticalReport(incidents: 2),
        ]) {
          await _pump(tester, r, width: 320, textScale: scale, rescue: FakeRescueReady(), extra: [_connectivity()]);
          expect(tester.takeException(), isNull);
        }
        for (final r in [scoredReport(), noWalletReport()]) {
          await tester.pumpWidget(const SizedBox()); // 앞 시트를 닫고 새로 연다
          await _pump(tester, r, width: 320, textScale: scale, rescue: FakeRescueReady());
          await tester.tap(find.byKey(const Key('wallet-health-info')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  });

  group('P2 polish', () {
    final about = find.byKey(const Key('wallet-health-about-sheet'));

    Future<void> openAbout(WidgetTester tester, WalletHealthReport report, {double width = 390}) async {
      await tester.pumpWidget(const SizedBox()); // 앞에서 연 시트 경로가 남지 않게
      await _pump(tester, report, width: width);
      await tester.tap(find.byKey(const Key('wallet-health-info')));
      await tester.pumpAndSettle();
    }

    testWidgets('C41: S0 lists the four checks a wallet adds, in the brief order, without reasons or 거래 충돌', (
      tester,
    ) async {
      await _pump(tester, noWalletReport());
      final card = find.byType(WalletHealthNotIncludedCard);
      final names = [
        safetyCheckName(SafetyCheckId.addressReuse),
        safetyCheckName(SafetyCheckId.possibleDusting),
        safetyCheckName(SafetyCheckId.unrecognizedOutgoing),
        t.wallet_health.category.recovery_readiness,
      ];
      expect(find.descendant(of: card, matching: find.byIcon(CupertinoIcons.clock)), findsNWidgets(4));
      final tops = [for (final name in names) tester.getTopLeft(find.descendant(of: card, matching: _text(name))).dy];
      expect(tops, [...tops]..sort());
      expect(find.descendant(of: card, matching: _text(safetyCheckName(SafetyCheckId.txConflict))), findsNothing);
      expect(find.descendant(of: card, matching: _text(safetyReasonText(NotApplicableReason.noWallet))), findsNothing);
      expect(
        find.descendant(of: card, matching: _text(t.wallet_health.section.not_included_footer_no_wallet)),
        findsOneWidget,
      );
    });

    testWidgets('C47: with no wallet the About sheet splits what works now from what a wallet adds', (tester) async {
      await openAbout(tester, noWalletReport());
      expect(find.descendant(of: about, matching: _text(t.wallet_health.section.available_now)), findsOneWidget);
      expect(find.descendant(of: about, matching: find.byType(SafetyPassedRow)), findsNWidgets(2)); // 앱 잠금·업데이트
      expect(find.descendant(of: about, matching: _text(t.wallet_health.section.after_adding_wallet)), findsOneWidget);
      final card = find.descendant(of: about, matching: find.byType(WalletHealthNotIncludedCard));
      final names = safetyNoWalletCheckNames(about: true);
      expect(names.take(4), safetyNoWalletCheckNames()); // 앞 넷은 화면 S0와 같은 순서(C41)
      final tops = [for (final name in names) tester.getTopLeft(find.descendant(of: card, matching: _text(name))).dy];
      expect(tops, [...tops]..sort());
      // "점수에 포함되지 않은 항목"은 지갑이 없으면 위 목록과 겹치므로 없다
      expect(find.descendant(of: about, matching: _text(t.wallet_health.about.not_included_title)), findsNothing);

      await openAbout(tester, scoredReport());
      expect(find.descendant(of: about, matching: _text(t.wallet_health.section.after_adding_wallet)), findsNothing);
      expect(find.descendant(of: about, matching: find.byType(WalletHealthNotIncludedCard)), findsNothing);
      expect(find.descendant(of: about, matching: _text(t.wallet_health.about.not_included_title)), findsOneWidget);
    });

    testWidgets('C46: offline, the header says why under the offline line, in the home chip words', (tester) async {
      final header = find.byType(WalletHealthHeaderCard);
      final chip = t.wallet_health.status_chip;
      for (final (provider, cause) in [
        (_connectivity(internet: false), chip.offline),
        (_connectivity(vpn: true), chip.vpn),
        (_connectivity(), chip.connection_failed),
      ]) {
        await _pump(tester, scoredReport(connected: false), extra: [provider]);
        final line = find.descendant(of: header, matching: _text(cause));
        expect(line, findsOneWidget, reason: cause);
        final offline = find.descendant(of: header, matching: _text(t.wallet_health.hero.offline_line));
        expect(tester.getTopLeft(line).dy, greaterThan(tester.getBottomLeft(offline).dy));
        expect(tester.widget<Text>(line).style!.fontSize, 12);
      }
      await _pump(tester, scoredReport(), extra: [_connectivity(internet: false)]);
      expect(_text(chip.offline), findsNothing);
    });

    testWidgets('C39: the About "포함" boxes go one per row when a box would be narrower than 150', (tester) async {
      Finder box(SafetyCategory category) => find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_IncludedBox' && (w as dynamic).category == category,
      );
      await openAbout(tester, scoredReport(), width: 320);
      final (recovery, activity) = (
        tester.getTopLeft(box(SafetyCategory.recovery)),
        tester.getTopLeft(box(SafetyCategory.activity)),
      );
      expect(activity.dx, recovery.dx);
      expect(activity.dy, greaterThan(recovery.dy));

      await openAbout(tester, scoredReport());
      final (wideRecovery, wideActivity) = (
        tester.getTopLeft(box(SafetyCategory.recovery)),
        tester.getTopLeft(box(SafetyCategory.activity)),
      );
      expect(wideActivity.dy, wideRecovery.dy);
      expect(wideActivity.dx, greaterThan(wideRecovery.dx));
    });
  });

  group('fix round (POLISH §10)', () {
    testWidgets('X11: the wallet sheet starts with the wallet-detail caution banner, only for a wallet in caution', (
      tester,
    ) async {
      final sheet = find.byKey(const Key('wallet-health-wallet-sheet'));
      final banner = find.descendant(of: sheet, matching: find.byKey(const Key('safety-caution-banner')));
      Future<void> open(SafetyState state, {double width = 390, double textScale = 1}) async {
        await tester.pumpWidget(const SizedBox()); // 앞 시트 경로를 지운다
        await pumpWalletHealthApp(
          tester,
          Builder(
            builder:
                (context) =>
                    TextButton(onPressed: () => showWalletContributionSheet(context, 1), child: const Text('open')),
          ),
          report: scoredReport(),
          state: state,
          wallets: _wallets,
          width: width,
          textScale: textScale,
        );
        await tester.tap(_text('open'));
        await tester.pumpAndSettle();
      }

      await open(const SafetyState(cautionWalletIds: {1}));
      expect(banner, findsOneWidget);
      // 지갑 머리 줄 위, 시트 맨 위
      final header = find.descendant(of: sheet, matching: _textContaining('Daily')).first;
      expect(tester.getBottomLeft(banner).dy, lessThanOrEqualTo(tester.getTopLeft(header).dy));
      expect(_text(t.safety_guide.caution.remove_link), findsOneWidget);

      await open(const SafetyState(cautionWalletIds: {2}));
      expect(banner, findsNothing);

      await open(const SafetyState(cautionWalletIds: {1}), width: 320, textScale: 2.0);
      expect(banner, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('X3: category card status lines wrap at 2.0× instead of ending in "…"', (tester) async {
      for (final report in [notEnoughDataReport(), noWalletReport()]) {
        await _pump(tester, report, width: 375, textScale: 2.0);
        for (final category in SafetyCategory.values) {
          final card = find.byKey(Key('wallet-health-category-${category.name}'));
          for (final text in tester.widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))) {
            expect(text.overflow, isNot(TextOverflow.ellipsis), reason: category.name);
            expect(text.maxLines, isNot(2), reason: category.name);
          }
        }
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('X5: the About "포함" boxes go one per row when larger text leaves a box under 150 × scale', (
      tester,
    ) async {
      Finder box(SafetyCategory category) => find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_IncludedBox' && (w as dynamic).category == category,
        skipOffstage: false,
      );
      Future<(Offset, Offset)> boxes(double scale) async {
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, scoredReport(), textScale: scale, height: 4000);
        await tester.tap(find.byKey(const Key('wallet-health-info')));
        await tester.pumpAndSettle();
        return (tester.getTopLeft(box(SafetyCategory.recovery)), tester.getTopLeft(box(SafetyCategory.activity)));
      }

      final (recovery, activity) = await boxes(2.0); // 390 폭: 상자 169 < 150 × 2
      expect(activity.dx, recovery.dx);
      expect(activity.dy, greaterThan(recovery.dy));
      final (plainRecovery, plainActivity) = await boxes(1.0); // 169 ≥ 150
      expect(plainActivity.dy, plainRecovery.dy);
      expect(tester.takeException(), isNull);
    });

    // X13: 큰 글자(1.3배~)에서는 칩을 부제 아래 왼쪽에(나란히면 칩이 폭의 35%를 차지해 글이 여섯 줄로 좁아진다)
    for (final locale in [AppLocale.ko, AppLocale.de]) {
      testWidgets(
        'X13 ${locale.name}: the free rescue row chip sits beside the text at 1.0× and under the subtitle from 1.3×',
        (tester) async {
          for (final scale in [1.0, 1.3, 2.0]) {
            await _pump(
              tester,
              notEnoughDataReport(),
              locale: locale,
              width: 320,
              height: 6000, // de 2.0배에서 Premium 구역이 2400 아래로 내려간다
              textScale: scale,
              rescue: FakeRescueReady(),
            );
            final row = find.byKey(const Key('wallet-health-rescue-ready'));
            final chip = tester.getRect(find.descendant(of: row, matching: find.byType(PremiumChip)));
            final subtitle = tester.getRect(find.descendant(of: row, matching: _text(t.premium.rescue.free_body)));
            if (scale < 1.3) {
              expect(chip.left, greaterThanOrEqualTo(subtitle.right), reason: '$scale');
            } else {
              expect(chip.top, greaterThanOrEqualTo(subtitle.bottom), reason: '$scale');
              expect(chip.left, closeTo(subtitle.left, 0.5), reason: '$scale');
            }
            expect(tester.takeException(), isNull, reason: '$scale');
          }
        },
      );
    }

    testWidgets('X12: when the report turns critical, Health scrolls back up to the critical hero', (tester) async {
      final list = find.descendant(of: find.byType(WalletHealthScreen), matching: find.byType(Scrollable)).first;
      double pixels() => tester.state<ScrollableState>(list).position.pixels;
      await _pump(tester, scoredReport(), height: 700);
      await tester.drag(list, const Offset(0, -500));
      await tester.pumpAndSettle();
      final scrolled = pixels();
      expect(scrolled, greaterThan(300));

      // 같은 화면(상태 유지)에 다른 정상 보고서: 자리를 지킨다
      await _pump(tester, scoredReport(score: 80), height: 700);
      expect(pixels(), scrolled);

      // 위급으로 바뀌면 맨 위로(사이렌 머리와 [검토] 버튼이 보인다)
      await _pump(tester, criticalReport(), height: 700);
      await tester.pumpAndSettle();
      expect(pixels(), 0);
      expect(find.byKey(const Key('wallet-health-critical-review')).hitTestable(), findsOneWidget);
    });
  });
}
