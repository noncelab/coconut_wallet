import 'dart:async';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/safety_alerts_screen.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart' show SafetyReviewRow;
import 'package:flutter_test/flutter_test.dart';

import 'safety_test_harness.dart';

/// 읽음 저장이 실패하거나 늦게 끝나는 제공자(D10)
class _ReadControlled extends SafetyProvider {
  _ReadControlled(super.report, {super.state, this.fail = false}) : super.fixed();

  final bool fail;
  final saved = Completer<void>();
  int calls = 0;

  @override
  Future<void> markAlertsRead() async {
    calls++;
    if (fail) throw StateError('disk full');
    await saved.future;
    await super.markAlertsRead();
  }
}

double _dot(WidgetTester tester, String incidentId) =>
    tester.widget<AnimatedOpacity>(find.byKey(Key('safety-alert-unread-$incidentId'))).opacity;

void main() {
  final strings = t.wallet_health;

  testWidgets('lists incidents by section and reads them once the screen is open', (tester) async {
    usePhoneSize(tester);
    final detected = testIncident(txid: 'a');
    final responding = testIncident(txid: 'b', state: IncidentState.responding, guideStep: 2);
    final recognized = testIncident(txid: 'c', state: IncidentState.recognized);
    final dropped = testIncident(txid: 'd', txState: IncidentTxState.dropped);
    final safety = SafetyProvider.fixed(
      WalletHealthReport(
        status: WalletHealthStatus.criticalOverride,
        profile: WeightProfile.hotFunded,
        criticalIncidents: [detected, responding],
        infoIncidents: [dropped],
        evaluatedAt: DateTime(2026, 10, 20, 9),
      ),
      state: SafetyState(incidents: [detected, responding, recognized, dropped]),
    );
    expect(safety.hasUnreadAlerts, isTrue);
    await tester.pumpWidget(safetyTestApp(origin(), safety: safety));

    unawaited(SafetyAlertsScreen.open(originContext(tester)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_dot(tester, detected.id), 1); // 들어오는 동안은 점이 보인다
    await tester.pumpAndSettle();

    expect(safety.hasUnreadAlerts, isFalse);
    expect(safety.state.readItemIds, containsAll(['incident:${detected.id}', 'incident:${responding.id}']));
    expect(_dot(tester, detected.id), 0);
    expect(find.byKey(Key('safety-alert-unread-${recognized.id}')), findsNothing);
    expect(find.byKey(Key('safety-alert-unread-${dropped.id}')), findsNothing); // 사라짐은 점 없음
    expect(findText(strings.incident.dropped_title), findsOneWidget); // 정보 행 제목
    expect(findTextContaining(strings.incident.dropped_subtitle), findsOneWidget);
    for (final text in [
      strings.incident.state.dropped,
      strings.alerts.section_security,
      strings.alerts.section_earlier,
      strings.incident.state.detected,
      strings.incident.state.responding,
      strings.incident.state.recognized,
    ]) {
      expect(findText(text), findsOneWidget, reason: text);
    }
    expect(find.byKey(const Key('safety-alerts-empty')), findsNothing);
  });

  testWidgets('a responding incident resumes the guide from the list', (tester) async {
    usePhoneSize(tester);
    final responding = testIncident(state: IncidentState.responding, guideStep: 3);
    final safety = fixedSafety(incidents: [responding]);
    await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
    unawaited(SafetyAlertsScreen.open(originContext(tester)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('safety-alert-incident-${responding.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-step3')), findsOneWidget);
  });

  for (final variant in CoconutThemeVariant.values) {
    testWidgets('${variant.name} empty list explains when Coconut checks', (tester) async {
      final colors = resolveCoconutThemeExtension(variant: variant).colors;
      await tester.pumpWidget(safetyTestApp(origin(), safety: fixedSafety(), variant: variant));
      unawaited(SafetyAlertsScreen.open(originContext(tester)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('safety-alerts-empty')), findsOneWidget);
      expect(findText(strings.alerts.empty_title), findsOneWidget);
      expect(tester.widget<Text>(findText(strings.alerts.empty_body)).style!.color, colors.secondaryText);
      expect(
        tester.widget<Scaffold>(find.byKey(const Key('safety-alerts-screen'))).backgroundColor,
        colors.homeBackground,
      );
    });
  }

  // D1: 거래가 사라진 대응 중 사건을 다시 열어도 저장된 단계를 지킨다
  testWidgets('a responding incident whose transaction vanished resumes at its saved step', (tester) async {
    usePhoneSize(tester);
    final incident = testIncident(state: IncidentState.responding, txState: IncidentTxState.dropped, guideStep: 4);
    final safety = fixedSafety(incidents: [incident]);
    await tester.pumpWidget(safetyTestApp(origin(), safety: safety, wallets: FakeWallets(const [])));
    unawaited(SafetyAlertsScreen.open(originContext(tester)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('safety-alert-incident-${incident.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('safety-guide-step4')), findsOneWidget);
    expect(findText(t.safety_guide.recognize.title), findsNothing);
    expect(safety.incidentFor(kWalletId, kTxid)!.guideStep, 4);
  });

  // D5: 사라진(대체·추방) 사건은 보안 경고가 아니라 지난 알림
  for (final txState in [IncidentTxState.dropped, IncidentTxState.replaced]) {
    testWidgets('a ${txState.name} incident is listed under earlier alerts', (tester) async {
      final incident = testIncident(txState: txState);
      await tester.pumpWidget(safetyTestApp(origin(), safety: fixedSafety(incidents: [incident])));
      unawaited(SafetyAlertsScreen.open(originContext(tester)));
      await tester.pumpAndSettle();

      expect(findText(strings.alerts.section_security), findsNothing);
      expect(findText(strings.alerts.section_earlier), findsOneWidget);
      expect(find.byKey(Key('safety-alert-incident-${incident.id}')), findsOneWidget);
      expect(findText(strings.incident.state.dropped), findsOneWidget);
      if (txState == IncidentTxState.replaced) {
        expect(findTextContaining(strings.incident.tx_state.replaced), findsOneWidget);
      }
    });
  }

  // D6: 경고 수준 검토 항목도 확인할 항목에 보인다(읽지 않음 점은 없음)
  testWidgets('a warning-only review item shows under items to check without an unread dot', (tester) async {
    final safety = SafetyProvider.fixed(
      WalletHealthReport(
        status: WalletHealthStatus.scored,
        profile: WeightProfile.hotFunded,
        reviewItems: const [
          SafetyCheckResult(SafetyCheckId.appUpdate, SafetyOutcome.failed, severity: SafetySeverity.warning),
        ],
        evaluatedAt: DateTime(2026, 10, 20, 9),
      ),
    );
    expect(safety.hasUnreadAlerts, isFalse);
    await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
    unawaited(SafetyAlertsScreen.open(originContext(tester)));
    await tester.pumpAndSettle();

    expect(findText(strings.alerts.section_attention), findsOneWidget);
    expect(find.byType(SafetyReviewRow), findsOneWidget);
    expect(find.byKey(const Key('safety-alerts-empty')), findsNothing);
  });

  // D10: 읽음 저장이 끝난 뒤에만 점을 지우고, 실패·중간 이탈에도 오류가 새지 않는다
  group('marking alerts read', () {
    final detected = testIncident(txid: 'a');
    WalletHealthReport report() => WalletHealthReport(
      status: WalletHealthStatus.criticalOverride,
      profile: WeightProfile.hotFunded,
      criticalIncidents: [detected],
      evaluatedAt: DateTime(2026, 10, 20, 9),
    );

    testWidgets('clears the dot only after the save completes', (tester) async {
      final safety = _ReadControlled(report(), state: SafetyState(incidents: [detected]));
      await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
      unawaited(SafetyAlertsScreen.open(originContext(tester)));
      await tester.pumpAndSettle();
      expect(safety.calls, 1);
      expect(_dot(tester, detected.id), 1); // 저장 전

      safety.saved.complete();
      await tester.pumpAndSettle();
      expect(_dot(tester, detected.id), 0);
      expect(safety.hasUnreadAlerts, isFalse);
    });

    testWidgets('keeps the dot when saving fails, with no uncaught error', (tester) async {
      final safety = _ReadControlled(report(), state: SafetyState(incidents: [detected]), fail: true);
      await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
      unawaited(SafetyAlertsScreen.open(originContext(tester)));
      await tester.pumpAndSettle();
      expect(safety.calls, 1);
      expect(_dot(tester, detected.id), 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('leaving before the save finishes is safe', (tester) async {
      final safety = _ReadControlled(report(), state: SafetyState(incidents: [detected]));
      await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
      unawaited(SafetyAlertsScreen.open(originContext(tester)));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(SafetyAlertsScreen))).pop();
      await tester.pumpAndSettle();

      safety.saved.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(safety.hasUnreadAlerts, isFalse);
    });
  });

  // D6/M8: 상태 칩은 줄 폭의 35%까지(긴 독일어·큰 글자면 줄을 바꾼다). 제목 열이 먼저 폭을 받는다
  for (final scale in [1.3, 2.0]) {
    testWidgets('the incident status chip stays within its share of the row at ${scale}x on 320dp (German)', (
      tester,
    ) async {
      useSmallPhone(tester, scale);
      useLocale(AppLocale.de);
      final recognized = testIncident(state: IncidentState.recognized);
      final safety = SafetyProvider.fixed(
        WalletHealthReport(
          status: WalletHealthStatus.scored,
          profile: WeightProfile.hotFunded,
          evaluatedAt: DateTime(2026, 10, 20, 9),
        ),
        state: SafetyState(incidents: [recognized]),
      );
      await tester.pumpWidget(safetyTestApp(origin(), safety: safety));
      unawaited(SafetyAlertsScreen.open(originContext(tester)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final row = find.byKey(Key('safety-alert-incident-${recognized.id}'));
      final chip = find.descendant(of: row, matching: findText(t.wallet_health.incident.state.recognized));
      expect(chip, findsOneWidget); // 줄을 바꿀 뿐 글자를 자르지 않는다
      expect(tester.getRect(chip).width, lessThanOrEqualTo(tester.getRect(row).width * 0.35));
    });
  }
}
