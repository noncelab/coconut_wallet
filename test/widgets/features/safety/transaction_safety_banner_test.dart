import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
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
      ('info', testIncident(txState: IncidentTxState.dropped), colors.surface, false),
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
      });
    }
    for (final (name, incident, background, hasLink) in cases) {
      testWidgets('${variant.name} $name banner', (tester) async {
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
}
