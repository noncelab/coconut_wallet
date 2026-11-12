import 'dart:async';

import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/incident_sheets.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart';
import 'package:coconut_wallet/widgets/features/safety/transaction_safety_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../screens/safety/safety_test_harness.dart';
import 'screen_view_recorder.dart';

/// 거래 상세 자리. 앱의 라우트 이름(/transaction-detail)은 그대로인지 함께 본다
Widget _detail(BuildContext context) =>
    Scaffold(key: const Key('detail'), body: Text(ModalRoute.of(context)?.settings.name ?? ''));

/// 실제 거래 상세처럼 안전 배너를 둔다. 배너가 상세를 연 뒤 인지 시트("이 거래를 알고 있나요?")를 스스로 띄운다
Widget _detailWithBanner(BuildContext context) {
  final args = ModalRoute.of(context)!.settings.arguments! as TransactionDetailRouteArgs;
  return Scaffold(body: TransactionSafetyBanner(walletId: args.id, txHash: args.txHash));
}

Future<ScreenViewRecorder> _pump(WidgetTester tester, {SafetyProvider? safety, WidgetBuilder detail = _detail}) async {
  final recorder = ScreenViewRecorder();
  await tester.pumpWidget(
    safetyTestApp(
      origin(),
      safety: safety ?? fixedSafety(incidents: [testIncident()]),
      wallets: FakeWallets(const [], records: {kTxid}),
      routes: {AppRouteNames.transactionDetail: detail},
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

  // T5-07: 상세가 스스로 띄우는 인지 시트도 사건과 기준점 검토를 나눈다. 사건은 지금처럼 /incident/recognize
  testWidgets('analytics: an incident\'s recognize sheet stays /incident/recognize', (tester) async {
    final recorder = await _pump(tester, detail: _detailWithBanner);
    unawaited(
      openSafetyIncident(
        originContext(tester),
        walletId: kWalletId,
        txid: kTxid,
        purpose: TransactionDetailPurpose.incident,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(recorder.names, ['/', '/incident/detail', '/incident/recognize']);
  });

  // 기준점 검토(지갑을 추가할 때 이미 대기 중이던 출금 / 코코넛 밖 자기 앞 전송)는 사건이 아니라서 따로 센다
  for (final (check, baseline) in [
    (
      SafetyCheckId.pendingOutgoingAtBaseline,
      WalletBaseline(height: 1000, at: DateTime(2026, 10, 1), pendingSentAtBaseline: const {kTxid}),
    ),
    (
      SafetyCheckId.unexpectedSelfTransfer,
      WalletBaseline(height: 1000, at: DateTime(2026, 10, 1), unexpectedSelfTxids: const {kTxid}),
    ),
  ]) {
    testWidgets('analytics: a baseline review (${check.name}) recognize sheet is /wallet-health/review/recognize', (
      tester,
    ) async {
      final recorder = await _pump(
        tester,
        safety: SafetyProvider.fixed(null, state: SafetyState(baselines: {kWalletId: baseline})),
        detail: _detailWithBanner,
      );
      unawaited(
        openSafetyCheckAction(
          originContext(tester),
          SafetyCheckResult(
            check,
            SafetyOutcome.failed,
            walletId: kWalletId,
            severity: SafetySeverity.actionNeeded,
            subjects: const [kTxid],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(recorder.names, ['/', '/wallet-health/review/detail', '/wallet-health/review/recognize']);
    });
  }

  // 기준점 검토에서 "내 거래예요"를 눌렀는데 같은 거래가 다른 지갑에도 열려 있으면 묻는 팝업도 검토 이름이다
  testWidgets(
    'analytics: a baseline review shared-transaction popup is /wallet-health/review/recognize-shared-dialog',
    (tester) async {
      final safety = SafetyProvider.fixed(
        null,
        state: SafetyState(
          baselines: {
            kWalletId: WalletBaseline(height: 1000, at: DateTime(2026, 10, 1), pendingSentAtBaseline: const {kTxid}),
          },
          // 같은 거래가 다른 지갑(2)에서는 사건으로 열려 있다
          incidents: [SafetyIncident(walletId: 2, txid: kTxid, detectedAt: DateTime(2026, 10, 20, 9))],
        ),
      );
      final recorder = await _pump(tester, safety: safety);
      unawaited(
        showRecognizeSheet(
          originContext(tester),
          SafetyIncident(walletId: kWalletId, txid: kTxid, detectedAt: DateTime(2026, 10, 20, 9)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('incident-recognize-yes')));
      await tester.pumpAndSettle();
      await tester.tap(findText(t.cancel));
      await tester.pumpAndSettle();
      expect(recorder.names, [
        '/',
        '/wallet-health/review/recognize',
        '/wallet-health/review/recognize-shared-dialog',
        '/wallet-health/review/recognize',
      ]);
    },
  );

  // 기준점이 있어도 이 거래가 그 안에 없고 사건도 없으면 사건 이름이다(기준점이 있다는 것만으로 검토가 아니다)
  testWidgets('analytics: a wallet baseline without this transaction keeps /incident/recognize', (tester) async {
    final safety = SafetyProvider.fixed(
      null,
      state: SafetyState(
        baselines: {
          kWalletId: WalletBaseline(height: 1000, at: DateTime(2026, 10, 1), pendingSentAtBaseline: const {'other'}),
        },
      ),
    );
    final recorder = await _pump(tester, safety: safety);
    unawaited(showRecognizeSheet(originContext(tester), testIncident()));
    await tester.pumpAndSettle();
    expect(recorder.names, ['/', '/incident/recognize']);
  });
}
