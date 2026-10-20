import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart';
import 'package:coconut_wallet/screens/settings/pin_setting_screen.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_score_gauge.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../mock/wallet_mock.dart';
import 'wallet_health_fixtures.dart';

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
}) => pumpWalletHealthApp(
  tester,
  WalletHealthScreen(startCheck: startCheck),
  report: report,
  variant: variant,
  locale: locale,
  width: width,
  // 앱에서는 늘 있는 EntitlementService. entitlement: false = 없는 하네스
  premium: entitlement ? premium ?? const PremiumState(PremiumStatus.none) : null,
  rescue: rescue,
  wallets: _wallets,
  settle: !startCheck,
);

/// 지갑 1 "Daily1"(보기 전용), 지갑 2 "Savings2"
final _wallets = [
  WalletMock.createSingleSigWalletItem(id: 1, name: 'Daily'),
  WalletMock.createSingleSigWalletItem(id: 2, name: 'Savings'),
];

Finder _inGauge(String text) => find.descendant(of: find.byType(HealthGauge), matching: find.text(text));

Finder _svg(String asset) => find.byWidgetPredicate(
  (w) => w is SvgPicture && w.bytesLoader is SvgAssetLoader && (w.bytesLoader as SvgAssetLoader).assetName == asset,
);

final _premiumCard = find.byKey(const Key('wallet-health-premium-card'));
final _checkAgain = find.byKey(const Key('wallet-health-check-again'));
final _addWallet = find.byKey(const Key('wallet-health-add-wallet'));

void main() {
  for (final variant in CoconutThemeVariant.values) {
    group(variant.name, () {
      testWidgets('S1 scored + review: number, label, review rows, Free Premium card, all good, recommended', (
        tester,
      ) async {
        await _pump(tester, scoredReport(), variant: variant);
        expect(_inGauge('86'), findsOneWidget);
        expect(_inGauge(t.wallet_health.score_label.good), findsOneWidget);
        expect(_checkAgain, findsOneWidget);
        expect(find.text(t.wallet_health.section.review_needed), findsOneWidget);
        expect(find.text(t.wallet_health.check.watch_only_verify.issue_not_verified), findsOneWidget);
        expect(find.text(t.wallet_health.category.addresses_reused(n: 2)), findsNWidgets(2)); // 카드 상태 줄 + 행
        expect(_premiumCard, findsOneWidget);
        expect(find.byType(PremiumChip), findsOneWidget);
        expect(find.text(t.wallet_health.section.all_good), findsOneWidget);
        expect(find.text(t.wallet_health.section.recommended), findsOneWidget);
        expect(find.text(t.wallet_health.recommended.mnemonic_stored), findsOneWidget);
        // Free 문구는 상시 감시를 약속하지 않는다
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          expect(text.data ?? '', isNot(contains('모니터링')));
        }
      });

      testWidgets('S2 all good: no review section, Premium card still after the cards', (tester) async {
        await _pump(tester, scoredReport(issues: false), variant: variant);
        expect(find.text(t.wallet_health.section.review_needed), findsNothing);
        expect(_premiumCard, findsOneWidget);
      });

      testWidgets('S4 not enough data: dash, explanation, how-it-works link, waiting checks, Premium, no unlock card', (
        tester,
      ) async {
        await _pump(tester, notEnoughDataReport(), variant: variant);
        expect(_inGauge(t.wallet_health.hero.not_enough_data_title), findsOneWidget);
        expect(
          find.descendant(of: find.byType(HealthGauge), matching: find.textContaining(RegExp(r'\d'))),
          findsNothing,
        );
        expect(find.text(t.wallet_health.hero.not_enough_data_body), findsOneWidget);
        expect(find.text(t.wallet_health.hero.how_score_works), findsOneWidget);
        expect(find.text(t.wallet_health.section.available_now), findsOneWidget);
        expect(find.text(t.wallet_health.section.not_included_yet), findsOneWidget);
        expect(find.text(t.wallet_health.check.passphrase_verify.name), findsNothing); // 해당 없음은 "아직"이 아니다
        // "더 많은 점검을 하려면"은 S0 전용(UI 브리프 WH-S4에는 없다). 판매 카드는 S0에서만 뺀다(H07)
        expect(find.byType(WalletHealthUnlockCard), findsNothing);
        expect(find.text(t.wallet_health.section.unlock_more), findsNothing);
        expect(_premiumCard, findsOneWidget);
        expect(_checkAgain, findsOneWidget);
      });

      testWidgets('S0 no wallet: no number or label, [지갑 추가] instead of check again, no Premium', (tester) async {
        await _pump(tester, noWalletReport(), variant: variant);
        expect(_inGauge(t.wallet_health.hero.no_wallet_title), findsOneWidget);
        expect(
          find.descendant(of: find.byType(HealthGauge), matching: find.textContaining(RegExp(r'\d'))),
          findsNothing,
        );
        for (final label in WalletHealthLabel.values) {
          expect(find.text(walletHealthLabelText(label)), findsNothing);
        }
        expect(_addWallet, findsOneWidget);
        expect(find.text(t.home_widgets.add_wallet), findsOneWidget);
        expect(_checkAgain, findsNothing);
        expect(find.text(t.wallet_health.hero.no_wallet_body), findsOneWidget);
        expect(find.text(t.wallet_health.category.available), findsOneWidget);
        expect(find.text(t.wallet_health.section.after_adding_wallet), findsOneWidget);
        expect(find.text(t.wallet_health.section.not_included_footer_no_wallet), findsOneWidget);
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
        expect(find.text(t.wallet_health.critical.title), findsOneWidget);
        expect(find.text(t.wallet_health.incident.outgoing_multiple_title(n: 2)), findsOneWidget);
        expect(_inGauge('76'), findsNothing);
        expect(find.byKey(const Key('wallet-health-incident-card')), findsOneWidget);
        expect(find.text(t.wallet_health.critical.more_alerts(n: 1)), findsOneWidget);
        expect(find.text(t.wallet_health.critical.review_transaction), findsOneWidget);
        expect(find.text(t.premium.card.critical_title), findsOneWidget);
        // 무료 대응 버튼이 Premium 카드보다 위
        expect(
          tester.getTopLeft(find.byKey(const Key('wallet-health-critical-review'))).dy,
          lessThan(tester.getTopLeft(_premiumCard).dy),
        );
        expect(find.text(t.wallet_health.critical.other_checks), findsOneWidget);
        expect(find.text(t.wallet_health.check.app_lock.issue), findsOneWidget);
        expect(_checkAgain, findsNothing);
      });
    });
  }

  testWidgets('label for 0–49 is "조치 필요", never "Critical"', (tester) async {
    await _pump(tester, scoredReport(score: 40));
    expect(_inGauge('조치 필요'), findsOneWidget);
    expect(find.textContaining('Critical'), findsNothing);

    await _pump(tester, scoredReport(score: 40), locale: AppLocale.en);
    expect(_inGauge('Action needed'), findsOneWidget);
    expect(find.textContaining('Critical'), findsNothing);
  });

  testWidgets('check again shows the checking state for at least 700 ms, then returns', (tester) async {
    final safety = await _pump(tester, scoredReport());
    await tester.tap(_checkAgain);
    await tester.pump();
    expect(safety.checks, 1);
    expect(find.text(t.wallet_health.summary.checking), findsNWidgets(2)); // 게이지 + 버튼
    expect(find.byKey(const Key('wallet-health-card-skeleton')), findsNWidgets(4));
    // 누른 채로 또 눌러도 한 번만
    await tester.tap(_checkAgain, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 600));
    expect(safety.checks, 1);
    expect(find.text(t.wallet_health.summary.checking), findsNWidgets(2));
    // provider 최소 1.2초 + 화면 최소 700ms(Stopwatch는 실제 시간이라 테스트에서는 700ms를 다 기다린다)
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text(t.wallet_health.summary.checking), findsNothing);
    expect(find.text(t.wallet_health.summary.check_again), findsOneWidget);
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
    await tester.tap(find.text('open'));
    await tester.pump(); // 첫 프레임은 Hero 측정용 offstage
    await tester.pump(const Duration(milliseconds: 300)); // 아직 밀려 들어오는 중
    expect(safety.checks, 0);
    await tester.pump(const Duration(milliseconds: 400)); // Cupertino 전환(500ms) 끝
    await tester.pump();
    expect(safety.checks, 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(t.wallet_health.summary.check_again), findsOneWidget);
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

    Future<void> open(WidgetTester tester, SafetyCheckResult check, PreferenceProvider? preferences) async {
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
          1: [dust],
        },
        preferences: preferences,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('visible: dust amount and reused addresses are shown', (tester) async {
      await open(tester, dustCheck, FakePreferences());
      expect(find.textContaining('546'), findsOneWidget);
      await open(tester, reuseCheck, FakePreferences());
      expect(find.textContaining('bc1qreuse000'), findsNWidgets(2));
    });

    for (final (mode, preferences) in [
      ('hidden balance', FakePreferences(isBalanceHidden: true)),
      ('fake balance', FakePreferences(isFakeBalanceActive: true)),
      ('no preference provider', null),
    ]) {
      testWidgets('$mode: no real amount or address fragment, explanation and actions stay', (tester) async {
        await open(tester, dustCheck, preferences);
        expect(find.textContaining('546'), findsNothing);
        expect(find.textContaining(t.wallet_health.review.dusting.unlocked), findsOneWidget);
        expect(find.text(t.wallet_health.review.dusting.view_utxo), findsOneWidget);

        await open(tester, reuseCheck, preferences);
        expect(find.textContaining('bc1qreuse'), findsNothing);
        expect(find.text(t.wallet_health.review.address_reuse.body), findsOneWidget);
        expect(find.text(t.wallet_health.review.address_reuse.view_utxos), findsOneWidget);
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
    expect(find.text(t.wallet_health.incident.outgoing_title), findsOneWidget); // 머리 = 사건
    expect(find.byKey(Key('wallet-health-review-${cert.key}')), findsOneWidget);
    expect(find.text(t.wallet_health.incident.server_identity_title), findsOneWidget);
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
    expect(find.text(t.wallet_health.incident.watch_only_mismatch_title), findsOneWidget); // 머리
    expect(find.byKey(Key('wallet-health-review-${watchOnly.key}')), findsNothing);
    expect(find.byKey(Key('wallet-health-review-${cert.key}')), findsOneWidget);
  });

  testWidgets('C3: without EntitlementService no paywall card is offered (the paywall needs it)', (tester) async {
    await _pump(tester, scoredReport(), entitlement: false);
    expect(_premiumCard, findsNothing);
    expect(find.text(t.wallet_health.section.all_good), findsOneWidget);
    await _pump(tester, criticalReport(), entitlement: false);
    expect(_premiumCard, findsNothing);
    expect(find.text(t.wallet_health.critical.other_checks), findsOneWidget);
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
    expect(find.text(t.premium.rescue.draft_pending), findsOneWidget);
    expect(find.textContaining(t.premium.rescue.ready_body), findsNothing);
    expect(find.text(t.premium.rescue.health_row(n: 0)), findsNothing);

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
      expect(find.text(t.premium.rescue.ready_partial(ready: 1, total: 2)), findsOneWidget, reason: '$status');
      expect(find.text(text), findsOneWidget, reason: '$status');
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
    expect(find.text(t.wallet_health.summary.checking), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text(t.wallet_health.summary.checking), findsNothing);
    expect(find.text(t.wallet_health.summary.check_again), findsOneWidget);
  });

  testWidgets('C6: a check that fails at once also waits 700 ms, then says it failed', (tester) async {
    final safety = InstantSafetyProvider(scoredReport(), error: StateError('offline'));
    await pumpWalletHealthApp(tester, const WalletHealthScreen(), safety: safety, wallets: _wallets);
    await tester.tap(_checkAgain);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    expect(find.text(t.wallet_health.summary.checking), findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.text(t.wallet_health.summary.checking), findsNothing);
    expect(find.text(t.wallet_health.toast.check_failed), findsOneWidget);
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
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-wallet-sheet')), findsOneWidget);
    expect(find.text(t.wallet_health.wallet_info.view_all), findsOneWidget);
    await tester.tap(find.byKey(const Key('wallet-health-view-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-wallet-sheet')), findsNothing);
    expect(find.byType(WalletHealthScreen), findsOneWidget);
  });

  testWidgets('plain open only refreshes', (tester) async {
    final plain = await _pump(tester, scoredReport());
    expect(plain.checks, 0);
    expect(plain.refreshes, 1);
  });

  testWidgets('Premium line only with an active entitlement; Rescue-ready line outside the score', (tester) async {
    final allReady = FakeRescueReady(
      statuses: {1: RescueStatus.ready, 2: RescueStatus.ready},
      drafts: {1: readyDraft(), 2: readyDraft()},
    );
    await _pump(tester, scoredReport(), premium: const PremiumState(PremiumStatus.none), rescue: allReady);
    expect(_premiumCard, findsOneWidget);
    expect(find.byKey(const Key('wallet-health-rescue-ready')), findsNothing);

    await _pump(tester, scoredReport(), premium: const PremiumState(PremiumStatus.active), rescue: allReady);
    expect(_premiumCard, findsNothing);
    expect(find.byKey(const Key('wallet-health-premium-active')), findsOneWidget);
    expect(find.text(t.premium.card.active_title), findsOneWidget);
    expect(find.text(t.premium.rescue.name), findsOneWidget);
    expect(find.text(t.premium.rescue.health_row(n: 2)), findsOneWidget);
    expect(find.textContaining(t.premium.rescue.ready_body), findsOneWidget);
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
    expect(find.text(t.premium.rescue.none_body), findsOneWidget); // 목적지 없음 상태도 열 수 있다(R05)
    expect(_inGauge(t.wallet_health.hero.not_enough_data_title), findsOneWidget); // 점수는 여전히 없다
  });

  testWidgets('Rescue-ready line covers partial, none, failed and paused', (tester) async {
    const active = PremiumState(PremiumStatus.active);
    await _pump(
      tester,
      scoredReport(),
      premium: active,
      rescue: FakeRescueReady(statuses: {1: RescueStatus.ready}, drafts: {1: readyDraft()}),
    );
    expect(find.text(t.premium.rescue.ready_partial(ready: 1, total: 2)), findsOneWidget);
    expect(find.text(t.premium.rescue.partial_body), findsOneWidget);

    await _pump(tester, scoredReport(), premium: active, rescue: FakeRescueReady());
    expect(find.text(t.premium.rescue.none_body), findsOneWidget);

    await _pump(
      tester,
      scoredReport(),
      premium: active,
      rescue: FakeRescueReady(statuses: {1: RescueStatus.failed, 2: RescueStatus.ready}),
    );
    final title = tester.widget<Text>(find.text(t.premium.rescue.needs_check_title));
    expect(title.style!.color, resolveCoconutThemeExtension(variant: CoconutThemeVariant.light).colors.warningText);
    expect(find.text(t.premium.rescue.fee_failed), findsOneWidget);

    // 구독이 끝나도 정해 둔 목적지가 있으면 "멈춤" 줄(초안·지갑은 그대로)
    await _pump(
      tester,
      scoredReport(),
      premium: const PremiumState(PremiumStatus.expired),
      rescue: FakeRescueReady(statuses: {1: RescueStatus.paused}),
    );
    expect(_premiumCard, findsOneWidget);
    expect(find.text(t.premium.rescue.paused_title), findsOneWidget);
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
    expect(find.text(t.premium.rescue.card_title), findsOneWidget);
    expect(find.text(t.premium.rescue.move_now), findsOneWidget);
    expect(_premiumCard, findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('wallet-health-critical-review'))).dy,
      lessThan(tester.getTopLeft(card).dy),
    );
    // 지갑 · 거래 상태 줄, 잔액을 모르면 금액 대신 "보낸 거래"
    expect(find.text('Daily1 · ${t.wallet_health.incident.tx_state.unconfirmed}'), findsOneWidget);
    expect(find.text(t.wallet_health.critical.sent_transaction), findsOneWidget);

    await _pump(tester, criticalReport(), premium: const PremiumState(PremiumStatus.active), rescue: FakeRescueReady());
    expect(find.byKey(const Key('wallet-health-assist-card')), findsOneWidget);
    expect(find.text(t.premium.card.prepare_response), findsOneWidget);
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
    expect(find.text(t.wallet_health.incident.server_identity_title), findsOneWidget);
    expect(find.byKey(const Key('wallet-health-critical-check-card')), findsOneWidget);
    expect(find.text('${t.wallet_health.review.server_cert.fingerprint} 12345678…'), findsOneWidget);
    expect(find.text(t.wallet_health.critical.review_certificate), findsOneWidget);
    expect(find.text(t.wallet_health.critical.other_checks), findsOneWidget);
    expect(find.text(t.wallet_health.section.review_needed), findsNothing); // 위급 항목은 머리에서만
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
    expect(find.text(t.wallet_health.section.mempool_dropped), findsOneWidget);
    expect(find.text('Savings2 · ${t.wallet_home_screen.wallet_filter.watch_only}'), findsOneWidget);
    expect(find.text('Daily1 · ${t.wallet_home_screen.wallet_filter.watch_only}'), findsNWidgets(2));
    expect(find.text(t.wallet_health.section.recommended_progress(done: 0, total: 1)), findsOneWidget);
  });

  testWidgets('info button opens the About sheet with the v2 categories and no "pts"', (tester) async {
    await _pump(tester, scoredReport());
    await tester.tap(find.byKey(const Key('wallet-health-info')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-about-sheet')), findsOneWidget);
    expect(find.text(t.wallet_health.about.title), findsOneWidget);
    for (final label in WalletHealthLabel.values) {
      expect(find.text(walletHealthLabelText(label)), findsWidgets);
    }
    expect(find.text('45%'), findsOneWidget);
    expect(find.textContaining('pts'), findsNothing);
    expect(find.text(t.wallet_health.about.coverage_body), findsOneWidget);
    expect(find.text(t.wallet_health.about.data_note), findsOneWidget);
    expect(find.text(t.wallet_health.about.weight_largest_wallet), findsOneWidget);
  });

  testWidgets('category card opens its detail sheet; a failing row inside it opens the review sheet', (tester) async {
    await _pump(tester, scoredReport());
    await tester.tap(find.byKey(const Key('wallet-health-category-privacy')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-category-sheet-privacy')), findsOneWidget);
    expect(find.text(t.wallet_health.about.weight_privacy), findsOneWidget);
    // 실패 행: 이름 + 짧은 결과 + 꺾쇠
    expect(find.text(t.wallet_health.check.address_reuse.count(n: 2)), findsOneWidget);
    final reuseRow = find.byKey(Key('wallet-health-check-row-${scoredReport().reviewItems[1].key}'));
    expect(reuseRow, findsOneWidget);
    await tester.tap(reuseRow);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-category-sheet-privacy')), findsNothing);
    expect(find.byKey(const Key('wallet-health-review-sheet')), findsOneWidget);
    expect(find.text(t.wallet_health.review.address_reuse.title), findsOneWidget);
  });

  testWidgets('review row opens the review item sheet', (tester) async {
    await _pump(tester, scoredReport());
    await tester.tap(find.text(t.wallet_health.category.addresses_reused(n: 2)).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-review-sheet')), findsOneWidget);
    expect(find.text(t.wallet_health.review.address_reuse.body), findsOneWidget);
  });

  testWidgets('recommended check is marked done by the user from its sheet', (tester) async {
    final safety = await _pump(tester, scoredReport());
    await tester.tap(find.text(t.wallet_health.recommended.mnemonic_stored));
    await tester.pumpAndSettle();
    expect(find.text(t.wallet_health.recommended.intro), findsOneWidget);
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
      for (final text in [
        t.wallet_health.check.watch_only_verify.issue_not_verified,
        t.premium.card.body,
        t.wallet_health.category.recovery_readiness,
      ]) {
        expect(find.ancestor(of: find.text(text), matching: find.byType(FittedBox)), findsNothing, reason: text);
      }
      await tester.tap(find.byKey(const Key('wallet-health-info')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
