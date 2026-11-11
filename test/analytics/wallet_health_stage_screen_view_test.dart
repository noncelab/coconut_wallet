import 'dart:async';

import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../mock/wallet_mock.dart';
import '../screens/safety/wallet_health_fixtures.dart';
import 'screen_view_recorder.dart';

/// 백그라운드 재평가처럼 보고서를 바꿀 수 있는 provider
class _SwitchableSafety extends FakeSafetyProvider {
  _SwitchableSafety(super.report) : _current = report;

  WalletHealthReport? _current;

  @override
  WalletHealthReport? get report => _current;

  void show(WalletHealthReport next) {
    _current = next;
    notifyListeners();
  }
}

/// 홈 같은 시작 화면에서 [WalletHealthScreen.open]으로 연다(앱과 같은 경로 이름)
Future<ScreenViewRecorder> _open(
  WidgetTester tester,
  FakeSafetyProvider safety, {
  bool startCheck = false,
  PremiumState? premium,
}) async {
  final recorder = ScreenViewRecorder();
  await pumpWalletHealthApp(
    tester,
    Builder(
      builder:
          (context) => TextButton(
            onPressed: () => WalletHealthScreen.open(context, startCheck: startCheck),
            child: const Text('open'),
          ),
    ),
    safety: safety,
    premium: premium,
    wallets: [WalletMock.createSingleSigWalletItem(id: 1)],
    extra: [Provider<AnalyticsService>.value(value: recorder)],
    navigatorObservers: [recorder.observer],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return recorder;
}

/// (화면 이름, stage)
List<(String, Object?)> _stages(ScreenViewRecorder recorder) => [
  for (final (name, parameters) in recorder.views) (name, parameters[AnalyticsParameterNames.stage]),
];

void main() {
  // T5-02 · 결정 #10: 이름은 그대로(/wallet-health) 두고 지금 보이는 상태를 stage로 남긴다. 점수·등급은 보내지 않는다
  for (final (report, stage) in [
    (scoredReport(), 'scored'),
    (notEnoughDataReport(), 'notEnoughData'),
    (noWalletReport(), 'noWallet'),
    (criticalReport(), 'criticalOverride'),
  ]) {
    testWidgets('analytics: Wallet Health records stage=$stage', (tester) async {
      final recorder = await _open(tester, FakeSafetyProvider(report));
      expect(_stages(recorder), [('/', null), ('/wallet-health', stage)]);
      expect(recorder.views.last.$2.keys, [AnalyticsParameterNames.stage]);
    });
  }

  // "Safety Check 결과" = checking 다음에 보인 stage. 바로가기 진입은 전환 중에도 checking이다
  testWidgets('analytics: the Safety Check entry records checking, then the result once', (tester) async {
    final recorder = await _open(tester, FakeSafetyProvider(scoredReport()), startCheck: true);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(_stages(recorder), [('/', null), ('/wallet-health', 'checking'), ('/wallet-health', 'scored')]);
  });

  // 가려진 채로 바뀐 상태는 그때 남기지 않고, Wallet Health가 다시 보일 때 한 번 남긴다
  testWidgets('analytics: a change while covered is recorded once when Wallet Health shows again', (tester) async {
    final safety = _SwitchableSafety(scoredReport());
    final recorder = await _open(tester, safety);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(settings: const RouteSettings(name: '/cover'), builder: (_) => const Scaffold()),
      ),
    );
    await tester.pumpAndSettle();
    safety.show(criticalReport());
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(_stages(recorder), [
      ('/', null),
      ('/wallet-health', 'scored'),
      ('/cover', null),
      ('/wallet-health', 'criticalOverride'),
    ]);
  });

  // 보이는 채로 바뀌면(백그라운드 재평가) 그 자리에서 한 번 남긴다
  testWidgets('analytics: a change while visible is recorded once', (tester) async {
    final safety = _SwitchableSafety(scoredReport());
    final recorder = await _open(tester, safety);
    safety.show(criticalReport());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(_stages(recorder), [('/', null), ('/wallet-health', 'scored'), ('/wallet-health', 'criticalOverride')]);
  });

  // T5-05: Wallet Health의 Premium 카드(보통·위급)에서 연 페이월은 각각 source=whCard·whCritical로 남는다
  for (final (report, source) in [(scoredReport(), 'whCard'), (criticalReport(), 'whCritical')]) {
    testWidgets('analytics: the Wallet Health Premium card opens the paywall with source $source', (tester) async {
      final recorder = await _open(tester, FakeSafetyProvider(report), premium: const PremiumState(PremiumStatus.none));
      final card = find.byKey(const Key('wallet-health-premium-card'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(
        {
          for (final (name, parameters) in recorder.views)
            if (name == '/premium/paywall') parameters[AnalyticsParameterNames.source],
        },
        {source},
      );
    });
  }
}
