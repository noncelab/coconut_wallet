import 'dart:async';

import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../mock/wallet_mock.dart';
import '../screens/safety/wallet_health_fixtures.dart';
import 'screen_view_recorder.dart';

void main() {
  // T5-10 · 결정 #10: 모든 점검·권장 종류가 서로 다른 고정 이름을 갖는다(kebab-case, 값·지갑 정보 없음)
  test('analytics: every check and recommendation has its own sheet name', () {
    final review = [for (final id in SafetyCheckId.values) WalletHealthSheetNames.review(id)];
    final recommended = [for (final id in RecommendedCheckId.values) WalletHealthSheetNames.recommended(id)];
    expect(review.toSet(), hasLength(SafetyCheckId.values.length));
    expect(recommended.toSet(), hasLength(RecommendedCheckId.values.length));
    for (final name in review) {
      expect(name, matches(RegExp(r'^/wallet-health/review/[a-z]+(-[a-z]+)*$')));
    }
    for (final name in recommended) {
      expect(name, matches(RegExp(r'^/wallet-health/recommended/[a-z]+(-[a-z]+)*$')));
    }
  });

  testWidgets('analytics: review and recommended sheets are recorded by type', (tester) async {
    final recorder = ScreenViewRecorder();
    late BuildContext origin;
    await pumpWalletHealthApp(
      tester,
      Builder(
        builder: (context) {
          origin = context;
          return const Scaffold(body: Text('wallet health'));
        },
      ),
      report: scoredReport(),
      wallets: [WalletMock.createSingleSigWalletItem(id: 1)],
      extra: [Provider<AnalyticsService>.value(value: recorder)],
      navigatorObservers: [recorder.observer],
    );
    Future<void> openAndClose(Future<void> Function() open) async {
      unawaited(open());
      await tester.pumpAndSettle();
      Navigator.of(origin).pop();
      await tester.pumpAndSettle();
    }

    final addressReuse = scoredReport().reviewItems.firstWhere((item) => item.id == SafetyCheckId.addressReuse);
    await openAndClose(() => showSafetyReviewItemSheet(origin, addressReuse));
    await openAndClose(
      () => showSafetyRecommendedSheet(origin, const RecommendedItem(id: RecommendedCheckId.hotPhysicalBackup)),
    );
    // 권장 항목이 점검 결과를 담고 있으면 검토 시트를 다시 쓰고, 이름도 그 점검의 검토 이름이다
    await openAndClose(
      () => showSafetyRecommendedSheet(
        origin,
        const RecommendedItem(
          check: SafetyCheckResult(
            SafetyCheckId.metadataBackup,
            SafetyOutcome.failed,
            severity: SafetySeverity.warning,
          ),
        ),
      ),
    );

    expect(recorder.names, [
      '/',
      '/wallet-health/review/address-reuse',
      '/',
      '/wallet-health/recommended/hot-physical-backup',
      '/',
      '/wallet-health/review/metadata-backup',
      '/',
    ]);
  });
}
