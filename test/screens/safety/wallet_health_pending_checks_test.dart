import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart';
import 'package:coconut_wallet/screens/safety/watch_only_verification_screen.dart';
import 'package:coconut_wallet/services/safety/safety_engine.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../model/safety/safety_fixtures.dart' as f;
import '../../services/safety/safety_fakes.dart' show safetyWallet;
import 'wallet_health_fixtures.dart' as h;

Finder _text(String text) =>
    find.byWidgetPredicate((w) => w is Text && (w.data ?? w.textSpan?.toPlainText())?.replaceAll('\u2060', '') == text);

WalletHealthReport _report({
  AppUpdateStatus update = AppUpdateStatus.upToDate,
  ServerCertObservation? cert,
  VerificationMethod? watchMethod,
  bool connected = true,
  bool baseline = true,
  bool critical = false,
}) => SafetyEngine.evaluate(
  f.inputs(
    wallets: [
      f.wallet(
        1,
        kind: watchMethod == null ? SafetyWalletKind.hot : SafetyWalletKind.watchOnly,
        balance: 1000000,
        backupVerified: true,
        txs: [f.tx('received', type: TransactionType.received, height: 900)],
      ),
    ],
    state: SafetyState(
      incidents: critical ? [SafetyIncident(walletId: 1, txid: 'unknown-outgoing', detectedAt: f.testNow)] : const [],
      baselines:
          baseline
              ? {
                1: f.baseline(known: {'received'}),
              }
              : const {},
      watchOnlyVerifications:
          watchMethod == null
              ? const {}
              : {
                1: WatchOnlyVerification(
                  method: watchMethod,
                  result: VerificationResult.match,
                  descriptorHash: 'descriptor-1',
                  at: f.testNow,
                ),
              },
    ),
    update: update,
    cert: cert,
    connected: connected,
  ),
);

const _pendingKey = Key('wallet-health-pending-link');
const _appKey = Key('wallet-health-category-app');
const _recoveryKey = Key('wallet-health-category-recovery');

ScrollPosition _position(WidgetTester tester) =>
    tester
        .state<ScrollableState>(
          find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
        )
        .position;

class _ChangingSafetyProvider extends h.FakeSafetyProvider {
  _ChangingSafetyProvider(this.current) : super(current);
  WalletHealthReport current;
  @override
  WalletHealthReport get report => current;
  void update(WalletHealthReport next) {
    current = next;
    notifyListeners();
  }
}

void main() {
  setUp(() {
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
  });
  setUpAll(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf')))
          .load();
    }
  });
  tearDownAll(() => VisibilityDetectorController.instance.updateInterval = const Duration(milliseconds: 500));

  testWidgets('unknown update keeps the calculated score but never claims the app checks are clear', (tester) async {
    final report = _report(update: AppUpdateStatus.unknown);
    expect(report.score, 100);
    await h.pumpWalletHealthApp(tester, const WalletHealthScreen(), report: report, height: 844);
    expect(find.descendant(of: find.byKey(_appKey), matching: _text('확인 전 1건')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(_appKey), matching: _text(t.wallet_health.summary.no_issues_found)),
      findsNothing,
    );
    expect(find.byKey(_pendingKey), findsOneWidget);
    await tester.tap(find.byKey(_pendingKey));
    await tester.pumpAndSettle();
    expect(_text(t.wallet_health.section.not_included_yet).hitTestable(), findsOneWidget);
    expect(_text(t.wallet_health.about.excluded_update_unknown).hitTestable(), findsOneWidget);
    expect(_text(t.wallet_health.check.passphrase_verify.name), findsNothing);
  });

  testWidgets('score-independent certificate warning is visible next to the score and opens review', (tester) async {
    final report = _report(
      cert: ServerCertObservation(
        applicable: true,
        pinned: 'aa',
        actual: 'aa',
        endValidity: f.testNow.subtract(const Duration(days: 1)),
        caValid: false,
      ),
    );
    expect(report.score, 100);
    await h.pumpWalletHealthApp(tester, const WalletHealthScreen(), report: report, height: 844);
    expect(
      find.descendant(of: find.byKey(_pendingKey), matching: _text(t.wallet_health.status_chip.attention(n: 1))),
      findsOneWidget,
    );
    await tester.tap(find.byKey(_pendingKey));
    await tester.pumpAndSettle();
    expect(_text(t.wallet_health.section.review_needed).hitTestable(), findsOneWidget);
  });

  testWidgets('warning and unknown are both summarized, with review taking navigation priority', (tester) async {
    final report = _report(
      update: AppUpdateStatus.unknown,
      cert: ServerCertObservation(
        applicable: true,
        pinned: 'aa',
        actual: 'aa',
        endValidity: f.testNow.subtract(const Duration(days: 1)),
        caValid: false,
      ),
    );
    await h.pumpWalletHealthApp(tester, const WalletHealthScreen(), report: report, height: 844);
    expect(_text('${t.wallet_health.status_chip.attention(n: 1)} · 확인 전 1건'), findsOneWidget);
    await tester.tap(find.byKey(_pendingKey));
    await tester.pumpAndSettle();
    expect(_text(t.wallet_health.section.review_needed).hitTestable(), findsOneWidget);
  });

  testWidgets(
    'manual watch-only comparison explains its partial score and can be upgraded without recording on cancel',
    (tester) async {
      final report = _report(watchMethod: VerificationMethod.user);
      expect(report.score, 84);
      final provider = await h.pumpWalletHealthApp(
        tester,
        const WalletHealthScreen(),
        report: report,
        wallets: [safetyWallet(hot: false)],
        height: 844,
      );
      expect(
        find.descendant(of: find.byKey(_recoveryKey), matching: _text(t.wallet_health.evidence.completed_by_you)),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(_recoveryKey));
      await tester.tap(find.byKey(_recoveryKey));
      await tester.pumpAndSettle();
      final verify = find.byKey(const Key('wallet-health-check-row-check:watchOnlyVerify:1'));
      expect(verify, findsOneWidget);
      await tester.ensureVisible(verify);
      await tester.tap(verify);
      await tester.pumpAndSettle();
      expect(find.byType(WatchOnlyVerificationScreen), findsOneWidget);
      final before = provider.state;
      Navigator.of(tester.element(find.byType(WatchOnlyVerificationScreen))).pop();
      await tester.pumpAndSettle();
      expect(provider.state, before);
    },
  );

  testWidgets('about inclusion grid distinguishes failed update from a passed check', (tester) async {
    await h.pumpWalletHealthApp(
      tester,
      Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(onPressed: () => showWalletHealthAboutSheet(context), child: const Text('about')),
            ),
      ),
      report: _report(update: AppUpdateStatus.available),
    );
    await tester.tap(_text('about'));
    await tester.pumpAndSettle();
    final row = find.ancestor(of: _text(t.wallet_health.check.app_update.name), matching: find.byType(Row)).first;
    final icon = tester.widget<SvgPicture>(find.descendant(of: row, matching: find.byType(SvgPicture)));
    expect((icon.bytesLoader as SvgAssetLoader).assetName, FeatureWalletHealthIconPath.triangleWarningFilled);
  });

  testWidgets('offline about sheet says the existing score uses stored data', (tester) async {
    await h.pumpWalletHealthApp(
      tester,
      Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(onPressed: () => showWalletHealthAboutSheet(context), child: const Text('about')),
            ),
      ),
      report: _report(connected: false),
    );
    await tester.tap(_text('about'));
    await tester.pumpAndSettle();
    expect(_text(t.wallet_health.about.offline_not_scored), findsNothing);
    expect(_text(t.wallet_health.hero.offline_line), findsOneWidget);
  });

  testWidgets('healthy and QR-verified reports do not gain pending UI or excluded N/A checks', (tester) async {
    for (final report in [_report(), _report(watchMethod: VerificationMethod.qr)]) {
      expect(report.score, 100);
      await h.pumpWalletHealthApp(tester, const WalletHealthScreen(), report: report);
      expect(find.byKey(_pendingKey), findsNothing);
      expect(_text(t.wallet_health.section.not_included_yet), findsNothing);
    }
  });

  testWidgets('missing baseline and unobserved certificate stay visible as unchecked, rather than N/A', (tester) async {
    final report = _report(
      baseline: false,
      cert: const ServerCertObservation(applicable: true, pinned: 'aa', caValid: false),
    );
    await h.pumpWalletHealthApp(tester, const WalletHealthScreen(), report: report);
    expect(report.score, 100);
    expect(_text('확인 전 2건'), findsOneWidget);
    expect(_text(t.wallet_health.about.excluded_sync_pending), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(WalletHealthNotIncludedCard),
        matching: _text(t.wallet_health.evidence.not_checked),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(const Key('wallet-health-category-activity')), matching: _text('확인 전 1건')),
      findsOneWidget,
    );
  });

  testWidgets('successful recheck removes pending UI and restores the confirmed app status', (tester) async {
    final provider = _ChangingSafetyProvider(_report(update: AppUpdateStatus.unknown));
    addTearDown(provider.dispose);
    await h.pumpWalletHealthApp(tester, const WalletHealthScreen(), safety: provider);
    expect(find.byKey(_pendingKey), findsOneWidget);
    provider.update(_report());
    await tester.pumpAndSettle();
    expect(find.byKey(_pendingKey), findsNothing);
    expect(_text(t.wallet_health.section.not_included_yet), findsNothing);
    expect(
      find.descendant(of: find.byKey(_appKey), matching: _text(t.wallet_health.summary.no_issues_found)),
      findsOneWidget,
    );
  });

  testWidgets('a new critical report cancels pending navigation and keeps the urgent header visible', (tester) async {
    final provider = _ChangingSafetyProvider(_report(update: AppUpdateStatus.unknown));
    addTearDown(provider.dispose);
    await h.pumpWalletHealthApp(tester, const WalletHealthScreen(), safety: provider, height: 844, reduceMotion: false);
    await tester.tap(find.byKey(_pendingKey));
    provider.update(_report(update: AppUpdateStatus.unknown, critical: true));
    await tester.pumpAndSettle();
    expect(find.byKey(_pendingKey), findsNothing);
    expect(_text(t.wallet_health.critical.title).hitTestable(), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first,
    );
    expect(scrollable.position.pixels, 0);
    expect(_text(t.wallet_health.section.not_included_yet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no wallet with an unknown update never navigates to a missing section', (tester) async {
    final report = SafetyEngine.evaluate(f.inputs(update: AppUpdateStatus.unknown));
    await h.pumpWalletHealthApp(tester, const WalletHealthScreen(), report: report, height: 568);
    await tester.ensureVisible(find.byKey(_appKey));
    await tester.pumpAndSettle();
    final before = _position(tester).pixels;
    await tester.tap(find.byKey(_appKey));
    await tester.pumpAndSettle();
    expect(_position(tester).pixels, before);
  });

  testWidgets('checking hides the pending link until the current check finishes', (tester) async {
    final report = _report(update: AppUpdateStatus.unknown);
    await h.pumpWalletHealthApp(
      tester,
      Scaffold(
        body: WalletHealthHeaderCard(
          report: report,
          isChecking: true,
          onCheckAgain: () {},
          onAddWallet: () {},
          onShowPending: () {},
        ),
      ),
      report: report,
    );
    expect(find.byKey(_pendingKey), findsNothing);
  });

  testWidgets('insufficient data shows unchecked details without a scored-header link', (tester) async {
    final report = SafetyEngine.evaluate(f.inputs(wallets: [f.wallet(1)], update: AppUpdateStatus.unknown));
    expect(report.status, WalletHealthStatus.notEnoughData);
    await h.pumpWalletHealthApp(tester, const WalletHealthScreen(), report: report);
    expect(find.byKey(_pendingKey), findsNothing);
    expect(_text(t.wallet_health.section.not_included_yet), findsOneWidget);
    expect(_text(t.wallet_health.about.excluded_update_unknown), findsOneWidget);
  });

  testWidgets('pending navigation stops when the report resolves mid-scroll', (tester) async {
    final provider = _ChangingSafetyProvider(_report(update: AppUpdateStatus.unknown));
    addTearDown(provider.dispose);
    await h.pumpWalletHealthApp(
      tester,
      const WalletHealthScreen(),
      safety: provider,
      height: 568,
      textScale: 2,
      reduceMotion: false,
    );
    await tester.ensureVisible(find.byKey(_pendingKey));
    await tester.tap(find.byKey(_pendingKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    provider.update(_report());
    await tester.pumpAndSettle();
    expect(_position(tester).pixels, lessThan(_position(tester).maxScrollExtent));
  });

  testWidgets('pending navigation yields to a user drag', (tester) async {
    await h.pumpWalletHealthApp(
      tester,
      const WalletHealthScreen(),
      report: _report(update: AppUpdateStatus.unknown),
      height: 568,
      textScale: 2,
      reduceMotion: false,
    );
    await tester.ensureVisible(find.byKey(_pendingKey));
    await tester.tap(find.byKey(_pendingKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(CustomScrollView)));
    try {
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump(const Duration(milliseconds: 16));
      final held = _position(tester).pixels;
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_position(tester).pixels, closeTo(held, .5));
    } finally {
      await gesture.up();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('category navigation stops if its review disappears before the next frame', (tester) async {
    final provider = _ChangingSafetyProvider(_report(update: AppUpdateStatus.available));
    addTearDown(provider.dispose);
    await h.pumpWalletHealthApp(tester, const WalletHealthScreen(), safety: provider, height: 568, reduceMotion: false);
    await tester.ensureVisible(find.byKey(_appKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_appKey));
    provider.update(_report());
    await tester.pumpAndSettle();
    expect(_position(tester).pixels, lessThan(_position(tester).maxScrollExtent));
  });

  testWidgets('category review keeps the centered highlight', (tester) async {
    await h.pumpWalletHealthApp(
      tester,
      const WalletHealthScreen(),
      report: h.scoredReport(),
      height: 844,
      reduceMotion: false,
    );
    final privacy = find.byKey(const Key('wallet-health-category-privacy'));
    await tester.ensureVisible(privacy);
    await tester.tap(privacy);
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('wallet-health-review-check:addressReuse:1'));
    final viewport = tester.getRect(find.byType(CustomScrollView));
    expect(tester.getCenter(row).dy, closeTo(viewport.center.dy, 1));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  for (final variant in CoconutThemeVariant.values) {
    for (final locale in AppLocale.values) {
      testWidgets('pending navigation fits 320dp large text in ${variant.name}/${locale.name}', (tester) async {
        final report = _report(
          update: AppUpdateStatus.unknown,
          cert: ServerCertObservation(
            applicable: true,
            pinned: 'aa',
            actual: 'aa',
            endValidity: f.testNow.subtract(const Duration(days: 1)),
            caValid: false,
          ),
        );
        await h.pumpWalletHealthApp(
          tester,
          const WalletHealthScreen(),
          report: report,
          variant: variant,
          locale: locale,
          width: 320,
          height: 844,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(_pendingKey)).height, greaterThanOrEqualTo(44));
        await tester.tap(find.byKey(_pendingKey));
        await tester.pumpAndSettle();
        expect(_text(t.wallet_health.section.review_needed).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
