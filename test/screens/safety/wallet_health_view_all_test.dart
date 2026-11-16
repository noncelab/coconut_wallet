import 'dart:async';

import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/safety/safety_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../analytics/screen_view_recorder.dart';
import '../../mock/wallet_mock.dart';
import '../../model/safety/safety_fixtures.dart' as f;
import 'wallet_health_fixtures.dart';

/// 직접 확인한 보기 전용 지갑 하나. 복구 카드에 검토 행이 없어서 카드를 누르면 그 지갑의 시트가 열린다.
WalletHealthReport _userConfirmedReport() => SafetyEngine.evaluate(
  f.inputs(
    wallets: [
      f.wallet(
        1,
        kind: SafetyWalletKind.watchOnly,
        balance: 100000000,
        txs: [f.tx('r', type: TransactionType.received, height: 900)],
      ),
    ],
    state: SafetyState(
      baselines: {1: f.baseline()},
      watchOnlyVerifications: {
        1: WatchOnlyVerification(
          method: VerificationMethod.user,
          result: VerificationResult.match,
          descriptorHash: 'descriptor-1',
          at: f.testNow,
        ),
      },
    ),
  ),
);

Future<(ScreenViewRecorder, BuildContext Function())> _pump(WidgetTester tester) async {
  final recorder = ScreenViewRecorder();
  late BuildContext origin;
  await pumpWalletHealthApp(
    tester,
    Builder(
      builder: (context) {
        origin = context;
        return const Scaffold(body: SizedBox());
      },
    ),
    report: _userConfirmedReport(),
    wallets: [WalletMock.createSingleSigWalletItem(id: 1)],
    extra: [Provider<AnalyticsService>.value(value: recorder)],
    navigatorObservers: [recorder.observer],
  );
  return (recorder, () => origin);
}

int _walletHealthScreens() => find.byType(WalletHealthScreen, skipOffstage: false).evaluate().length;

List<Object?> _walletHealthSources(ScreenViewRecorder recorder) => [
  for (final (name, parameters) in recorder.views)
    if (name == '/wallet-health') parameters[AnalyticsParameterNames.source],
];

void main() {
  testWidgets('the wallet sheet opened inside Wallet Health has no view-all button, so Wallet Health does not stack', (
    tester,
  ) async {
    final (recorder, origin) = await _pump(tester);
    WalletHealthScreen.open(origin(), source: WalletHealthEntry.homeChip);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wallet-health-category-recovery')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-wallet-sheet')), findsOneWidget);
    expect(find.byKey(const Key('wallet-health-view-all')), findsNothing);
    expect(_walletHealthScreens(), 1);

    // 시트를 닫으면 같은 지갑 점검으로 돌아온다. 홈까지는 뒤로 한 번이다
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-wallet-sheet')), findsNothing);
    expect(_walletHealthScreens(), 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_walletHealthScreens(), 0);
    // 시트를 닫고 돌아오면 같은 지갑 점검이 다시 기록된다(homeChip). 전체 보기로 새로 연 기록(contributionSheet)은 없다
    expect(_walletHealthSources(recorder).toSet(), {'homeChip'});
  });

  testWidgets('the wallet sheet opened outside Wallet Health keeps view-all and opens Wallet Health once', (
    tester,
  ) async {
    final (recorder, origin) = await _pump(tester);
    // 지갑 정보·지갑 상세의 "안전 상태" 줄이 여는 것과 같은 호출
    unawaited(showWalletContributionSheet(origin(), 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-view-all')), findsOneWidget);

    await tester.tap(find.byKey(const Key('wallet-health-view-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-health-wallet-sheet')), findsNothing);
    expect(_walletHealthScreens(), 1);
    expect(_walletHealthSources(recorder), ['contributionSheet']);
  });
}
