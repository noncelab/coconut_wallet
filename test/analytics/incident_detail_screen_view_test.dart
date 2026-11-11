import 'dart:async';

import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/screens/safety/incident_sheets.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/safety/safety_test_harness.dart';
import 'screen_view_recorder.dart';

/// 거래 상세 자리. 앱의 라우트 이름(/transaction-detail)은 그대로인지 함께 본다
Widget _detail(BuildContext context) =>
    Scaffold(key: const Key('detail'), body: Text(ModalRoute.of(context)?.settings.name ?? ''));

Future<ScreenViewRecorder> _pump(WidgetTester tester) async {
  final recorder = ScreenViewRecorder();
  await tester.pumpWidget(
    safetyTestApp(
      origin(),
      safety: fixedSafety(incidents: [testIncident()]),
      wallets: FakeWallets(const [], records: {kTxid}),
      routes: {AppRouteNames.transactionDetail: _detail},
      analytics: recorder,
      navigatorObservers: [recorder.observer],
    ),
  );
  await tester.pumpAndSettle();
  return recorder;
}

void main() {
  // T5-04: 사건으로 연 거래 상세는 /incident/detail로 남는다(라우트 이름은 그대로라 가이드·보내기 뒤 복귀가 동작한다)
  testWidgets('analytics: an incident opens the transaction detail as /incident/detail', (tester) async {
    final recorder = await _pump(tester);
    unawaited(
      openSafetyIncident(
        originContext(tester),
        walletId: kWalletId,
        txid: kTxid,
        autoReview: false,
        purpose: TransactionDetailPurpose.incident,
      ),
    );
    await tester.pumpAndSettle();
    expect(recorder.names, ['/', '/incident/detail']);
    expect(find.text(AppRouteNames.transactionDetail), findsOneWidget);
  });

  // 지갑 추가 때 이미 있던 출금(기준점 검토)은 사건이 아니라 /wallet-health/review/detail로 따로 센다
  testWidgets('analytics: a baseline review opens the transaction detail as /wallet-health/review/detail', (
    tester,
  ) async {
    final recorder = await _pump(tester);
    unawaited(
      openSafetyCheckAction(
        originContext(tester),
        const SafetyCheckResult(
          SafetyCheckId.pendingOutgoingAtBaseline,
          SafetyOutcome.failed,
          walletId: kWalletId,
          severity: SafetySeverity.actionNeeded,
          subjects: [kTxid],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(recorder.names.take(2), ['/', '/wallet-health/review/detail']);
    expect(find.text(AppRouteNames.transactionDetail), findsOneWidget);
  });

  // 평소 거래 상세(지갑 상세·거래 목록 등)는 지금처럼 /transaction-detail이다
  testWidgets('analytics: a normal transaction detail stays /transaction-detail', (tester) async {
    final recorder = await _pump(tester);
    unawaited(
      Navigator.of(originContext(tester)).pushNamed(
        AppRouteNames.transactionDetail,
        arguments: const TransactionDetailRouteArgs(id: kWalletId, txHash: kTxid),
      ),
    );
    await tester.pumpAndSettle();
    expect(recorder.names, ['/', '/transaction-detail']);
  });
}
