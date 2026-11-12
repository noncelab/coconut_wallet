import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/services/safety/safety_assist.dart';
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/transaction_safety_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../screens/safety/safety_test_harness.dart';

void main() {
  testWidgets('draws nothing without SafetyProvider or for a transaction that is not an incident', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: const Scaffold(body: TransactionSafetyBanner(walletId: kWalletId, txHash: kTxid)),
      ),
    );
    expect(find.byType(SafetyStatusBanner), findsNothing);

    await tester.pumpWidget(
      safetyTestApp(
        origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: 'other')),
        safety: fixedSafety(incidents: [testIncident()]),
      ),
    );
    expect(find.byType(SafetyStatusBanner), findsNothing);
  });

  for (final variant in CoconutThemeVariant.values) {
    final colors = resolveCoconutThemeExtension(variant: variant).colors;
    final cases = [
      ('unreviewed', testIncident(), colors.dangerSurface, true),
      ('recognized', testIncident(state: IncidentState.recognized), colors.successSurface, false),
      ('responding', testIncident(state: IncidentState.responding, guideStep: 2), colors.dangerSurface, true),
      ('completed', testIncident(state: IncidentState.completed), colors.surface, true), // 가이드 다시 보기
      // 확인 전에 거래가 사라지거나 대체된 정보 배너에도 "이 거래 검토"(M08 후속)
      ('info', testIncident(txState: IncidentTxState.dropped), colors.surface, true),
      ('info', testIncident(txState: IncidentTxState.replaced), colors.surface, true),
    ];
    // D5: 대응 중이어도 거래가 사라지면 중립 정보 배너(가이드를 이어 갈 링크는 남김)
    for (final txState in [IncidentTxState.dropped, IncidentTxState.replaced]) {
      testWidgets('${variant.name} responding + ${txState.name} shows the neutral banner', (tester) async {
        await tester.pumpWidget(
          safetyTestApp(
            origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: kTxid)),
            safety: fixedSafety(
              incidents: [testIncident(state: IncidentState.responding, txState: txState, guideStep: 2)],
            ),
            variant: variant,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('transaction-safety-banner-info')), findsOneWidget);
        expect(tester.widget<SafetyStatusBanner>(find.byType(SafetyStatusBanner)).background, colors.surface);
        expect(findText(t.safety_guide.tx_banner.continue_guide), findsOneWidget);
        expect(findText(t.safety_guide.tx_banner.review), findsNothing, reason: '대응 중이면 가이드 링크만');
      });
    }
    for (final (name, incident, background, hasLink) in cases) {
      // 정보 배너는 사라짐·대체 두 경우라 이름에 거래 상태를 붙인다(실패를 구분하고 하나만 돌릴 수 있게)
      final label = incident.txState == IncidentTxState.pending ? name : '$name (${incident.txState.name})';
      testWidgets('${variant.name} $label banner', (tester) async {
        await tester.pumpWidget(
          safetyTestApp(
            origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: kTxid)),
            safety: fixedSafety(incidents: [incident]),
            variant: variant,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(Key('transaction-safety-banner-$name')), findsOneWidget);
        expect(tester.widget<SafetyStatusBanner>(find.byType(SafetyStatusBanner)).background, background);
        expect(find.byType(CoconutUnderlinedButton), hasLink ? findsOneWidget : findsNothing);
      });
    }
  }

  // 레드팀 §9(5): 사라진 거래 배너는 같은 지갑의 남은 위급 출금을 알리고 알림 목록으로 이끈다
  testWidgets('a dropped banner points to the alerts when the wallet has other outgoing to review', (tester) async {
    final safety = fixedSafety(
      incidents: [testIncident(txState: IncidentTxState.dropped), testIncident(txid: 'replacement')],
    );
    await tester.pumpWidget(
      safetyTestApp(origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: kTxid)), safety: safety),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transaction-safety-banner-info')), findsOneWidget);
    expect(findTextContaining(t.safety_guide.tx_banner.dropped_other_outgoing), findsOneWidget);

    expect(findText(t.safety_guide.tx_banner.review), findsNothing, reason: '남은 위급 출금이 있으면 알림 보기만');
    await tester.tap(findText(t.safety_guide.tx_banner.view_alerts));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-alerts-screen')), findsOneWidget);
  });

  testWidgets('a dropped banner has no extra line when nothing else is outstanding', (tester) async {
    await tester.pumpWidget(
      safetyTestApp(
        origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: kTxid)),
        safety: fixedSafety(incidents: [testIncident(txState: IncidentTxState.dropped)]),
      ),
    );
    await tester.pumpAndSettle();
    expect(findTextContaining(t.safety_guide.tx_banner.dropped_other_outgoing), findsNothing);
    expect(findText(t.safety_guide.tx_banner.view_alerts), findsNothing);
  });

  // M08 후속(리뷰 지적 1): 확인 전에 거래가 대체되면(정보 배너) 그 거래를 검토할 길이 없어 사건이 열린 채 남고, 지갑이 계속
  // "옮길 곳"에서 빠졌다. 이제 "이 거래 검토" → 인지 시트 → "내 거래예요"로 닫고, 그러면 다시 목적지로 고를 수 있다
  testWidgets('a detected incident whose transaction was replaced can be reviewed and closed from its banner', (
    tester,
  ) async {
    final safety = fixedSafety(incidents: [testIncident(txState: IncidentTxState.replaced)]);
    await tester.pumpWidget(
      safetyTestApp(origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: kTxid)), safety: safety),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transaction-safety-banner-info')), findsOneWidget);
    expect(SafetyAssist.unsafeWalletIds(safety.state, const []), contains(kWalletId), reason: '열린 사건이라 목적지에서 빠짐');

    await tester.tap(findText(t.safety_guide.tx_banner.review));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('incident-recognize-yes')));
    await tester.pumpAndSettle();

    expect(safety.state.incidents.single.state, IncidentState.recognized);
    expect(SafetyAssist.unsafeWalletIds(safety.state, const []), isNot(contains(kWalletId)));
    await settleToasts(tester);
  });

  // 같은 링크에서 "모르는 거래예요"를 고르면 대응 중이 되고(열린 사건) 지갑은 계속 목적지에서 빠진다. 배너에는 가이드 링크만 남는다
  testWidgets('a replaced incident marked as not mine from its banner moves to responding and stays excluded', (
    tester,
  ) async {
    usePhoneSize(tester);
    final safety = fixedSafety(incidents: [testIncident(txState: IncidentTxState.replaced)]);
    await tester.pumpWidget(
      safetyTestApp(origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: kTxid)), safety: safety),
    );
    await tester.pumpAndSettle();
    await tester.tap(findText(t.safety_guide.tx_banner.review));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('incident-recognize-no')));
    await tester.pumpAndSettle();

    expect(safety.state.incidents.single.state, IncidentState.responding);
    expect(SafetyAssist.unsafeWalletIds(safety.state, const []), contains(kWalletId));
    expect(findText(t.safety_guide.unknown.what_to_do), findsOneWidget, reason: '다음 안내(지금 할 일)');
    expect(findText(t.safety_guide.tx_banner.continue_guide), findsOneWidget);
    expect(findText(t.safety_guide.tx_banner.review), findsNothing);
  });

  // 시트를 그냥 닫으면(뒤로 가기) 아무것도 바뀌지 않는다: 감지 그대로, 목적지 제외 그대로, 링크 그대로
  testWidgets('closing the review sheet opened from a replaced banner changes nothing', (tester) async {
    final safety = fixedSafety(incidents: [testIncident(txState: IncidentTxState.replaced)]);
    final before = safety.state;
    await tester.pumpWidget(
      safetyTestApp(origin(child: const TransactionSafetyBanner(walletId: kWalletId, txHash: kTxid)), safety: safety),
    );
    await tester.pumpAndSettle();
    await tester.tap(findText(t.safety_guide.tx_banner.review));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byKey(const Key('incident-recognize-yes')))).pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('incident-recognize-yes')), findsNothing);
    expect(safety.state, before);
    expect(SafetyAssist.unsafeWalletIds(safety.state, const []), contains(kWalletId));
    expect(findText(t.safety_guide.tx_banner.review), findsOneWidget);
  });
}
