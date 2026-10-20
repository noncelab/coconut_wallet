import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/widgets/features/home/home_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 무한 애니메이션 등으로 멈추면 공유 레인을 오래 잡지 않게
const _timeout = Timeout(Duration(seconds: 60));

final _at = DateTime(2026, 10, 20);
final _incident = SafetyIncident(walletId: 1, txid: 'a', detectedAt: _at);

WalletHealthReport _report({
  List<SafetyIncident> critical = const [],
  List<SafetyIncident> info = const [],
  List<SafetySeverity> review = const [],
}) => WalletHealthReport(
  status: critical.isEmpty ? WalletHealthStatus.scored : WalletHealthStatus.criticalOverride,
  score: 80,
  profile: WeightProfile.hotFunded,
  criticalIncidents: critical,
  infoIncidents: info,
  reviewItems: [
    for (final severity in review) SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.failed, severity: severity),
  ],
  evaluatedAt: _at,
);

/// 홈 화면과 같은 연결: 점은 hasUnreadAlerts, 건수는 읽지 않은 알림 항목 수
Future<bool> _hasDot(WidgetTester tester, SafetyProvider safety) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            HomeAppBar(
              networkStatus: NetworkStatus.online,
              showReconnected: false,
              isSyncing: false,
              isArranging: false,
              addWalletButtonLink: LayerLink(),
              onArrangeDone: () {},
              onAddWallet: () {},
              onSettings: () {},
              onAlerts: () {},
              unreadAlerts: safety.hasUnreadAlerts ? safety.alertItems.where((item) => item.unread).length : 0,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  return find.byKey(const Key('home-alerts-unread-dot')).evaluate().isNotEmpty;
}

void main() {
  testWidgets('the bell dot is only for unread critical incidents and action-needed items', (tester) async {
    expect(await _hasDot(tester, SafetyProvider.fixed(_report(critical: [_incident]))), isTrue);
    expect(await _hasDot(tester, SafetyProvider.fixed(_report(review: [SafetySeverity.actionNeeded]))), isTrue);

    final read = SafetyState.initial().copyWith(readItemIds: {'incident:${_incident.id}'});
    expect(await _hasDot(tester, SafetyProvider.fixed(_report(critical: [_incident]), state: read)), isFalse);

    final dropped = _incident.withTxState(IncidentTxState.dropped);
    expect(await _hasDot(tester, SafetyProvider.fixed(_report(info: [dropped]))), isFalse);
    expect(
      await _hasDot(
        tester,
        SafetyProvider.fixed(_report(review: [SafetySeverity.warning, SafetySeverity.recommended])),
      ),
      isFalse,
    );
    expect(await _hasDot(tester, SafetyProvider.fixed(null)), isFalse);
  }, timeout: _timeout);
}
