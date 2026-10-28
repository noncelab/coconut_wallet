import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/services/safety/home_safety_status_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

WalletHealthReport _report(WalletHealthStatus status, {int? score, List<SafetySeverity> review = const []}) =>
    WalletHealthReport(
      status: status,
      score: score,
      reviewItems: [
        for (final severity in review)
          SafetyCheckResult(SafetyCheckId.addressReuse, SafetyOutcome.failed, severity: severity),
      ],
      evaluatedAt: DateTime(2026, 10, 20),
    );

HomeSafetyStatus _resolve(
  WalletHealthReport? report, {
  NetworkStatus network = NetworkStatus.online,
  bool reconnected = false,
  bool syncing = false,
}) => resolveHomeSafetyStatus(report: report, networkStatus: network, showReconnected: reconnected, isSyncing: syncing);

void main() {
  final critical = _report(WalletHealthStatus.criticalOverride, score: 80, review: [SafetySeverity.actionNeeded]);
  final attention = _report(
    WalletHealthStatus.scored,
    score: 70,
    review: [SafetySeverity.actionNeeded, SafetySeverity.warning, SafetySeverity.recommended, SafetySeverity.none],
  );
  final scored = _report(WalletHealthStatus.scored, score: 95, review: [SafetySeverity.recommended]);

  test('critical wins over a connection problem, items, reconnect and sync', () {
    for (final network in NetworkStatus.values) {
      expect(
        _resolve(critical, network: network, reconnected: true, syncing: true).kind,
        HomeSafetyStatusKind.critical,
      );
    }
  });

  test('a connection or sync failure comes before items, reconnect and sync and keeps its network status', () {
    for (final network in [NetworkStatus.offline, NetworkStatus.connectionFailed, NetworkStatus.vpnBlocked]) {
      for (final report in [attention, scored, null]) {
        expect(
          _resolve(report, network: network, reconnected: true, syncing: true),
          HomeSafetyStatus(HomeSafetyStatusKind.connectionProblem, networkStatus: network),
        );
      }
    }
  });

  test('items to check count action-needed and warning only, and beat reconnect and sync', () {
    expect(
      _resolve(attention, reconnected: true, syncing: true),
      const HomeSafetyStatus(HomeSafetyStatusKind.actionNeeded, count: 2),
    );
  });

  test('reconnected beats updating, updating beats the idle states', () {
    expect(_resolve(scored, reconnected: true, syncing: true).kind, HomeSafetyStatusKind.reconnected);
    expect(_resolve(scored, syncing: true).kind, HomeSafetyStatusKind.updating);
    expect(_resolve(null, syncing: true).kind, HomeSafetyStatusKind.updating);
  });

  test('idle: no issues with a score, up to date without one', () {
    expect(_resolve(scored).kind, HomeSafetyStatusKind.noIssues);
    for (final report in [_report(WalletHealthStatus.notEnoughData), _report(WalletHealthStatus.noWallet), null]) {
      expect(_resolve(report).kind, HomeSafetyStatusKind.noScore);
    }
  });
}
