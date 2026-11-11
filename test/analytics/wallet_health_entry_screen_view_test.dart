import 'dart:async';

import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_safety_status_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../mock/wallet_mock.dart';
import '../screens/safety/wallet_health_fixtures.dart';
import 'screen_view_recorder.dart';

/// Wallet Health 화면 기록에 남은 source들
Set<Object?> _sources(ScreenViewRecorder recorder) => {
  for (final (name, parameters) in recorder.views)
    if (name == '/wallet-health') parameters[AnalyticsParameterNames.source],
};

Future<(ScreenViewRecorder, BuildContext Function())> _pump(
  WidgetTester tester, {
  Widget? child,
  WalletHealthReport? report,
}) async {
  final recorder = ScreenViewRecorder();
  late BuildContext origin;
  await pumpWalletHealthApp(
    tester,
    Builder(
      builder: (context) {
        origin = context;
        return Scaffold(body: child ?? const SizedBox());
      },
    ),
    report: report ?? scoredReport(),
    wallets: [WalletMock.createSingleSigWalletItem(id: 1)],
    extra: [Provider<AnalyticsService>.value(value: recorder)],
    navigatorObservers: [recorder.observer],
  );
  return (recorder, () => origin);
}

void main() {
  // 지갑 상세의 안전 상태 알약은 위급인데 사건이 없는 지갑(예: 서명 기기 불일치 확인)일 때만 Wallet Health를 연다
  testWidgets('analytics: the wallet detail safety pill records source walletDetail', (tester) async {
    final (recorder, _) = await _pump(
      tester,
      child: const WalletSafetyStatusPill(walletId: 1),
      report: WalletHealthReport(
        status: WalletHealthStatus.criticalOverride,
        score: 76,
        label: WalletHealthLabel.good,
        categories: categories(privacyIssues: 0),
        reviewItems: const [
          SafetyCheckResult(
            SafetyCheckId.watchOnlyVerify,
            SafetyOutcome.failed,
            walletId: 1,
            severity: SafetySeverity.critical,
            detail: SafetyCheckDetail.mismatch,
          ),
        ],
        walletCount: 1,
        fundedWalletCount: 1,
        evaluatedAt: DateTime.now(),
      ),
    );
    await tester.tap(find.byKey(const Key('wallet-safety-status-pill')));
    await tester.pumpAndSettle();
    expect(_sources(recorder), {'walletDetail'});
  });

  testWidgets('analytics: the wallet contribution sheet records source contributionSheet', (tester) async {
    final (recorder, origin) = await _pump(tester);
    unawaited(showWalletContributionSheet(origin(), 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wallet-health-view-all')));
    await tester.pumpAndSettle();
    expect(_sources(recorder), {'contributionSheet'});
  });
}
