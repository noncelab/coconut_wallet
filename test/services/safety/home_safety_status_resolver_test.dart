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
  bool completed = false,
}) => resolveHomeSafetyStatus(
  report: report,
  networkStatus: network,
  showReconnected: reconnected,
  isSyncing: syncing,
  showUpdateCompleted: completed,
);

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
        _resolve(critical, network: network, reconnected: true, syncing: true, completed: true).kind,
        HomeSafetyStatusKind.critical,
      );
    }
  });

  test('a connection or sync failure comes before items, reconnect and sync and keeps its network status', () {
    for (final network in [NetworkStatus.offline, NetworkStatus.connectionFailed, NetworkStatus.vpnBlocked]) {
      for (final report in [attention, scored, null]) {
        expect(
          _resolve(report, network: network, reconnected: true, syncing: true, completed: true),
          HomeSafetyStatus(HomeSafetyStatusKind.connectionProblem, networkStatus: network),
        );
      }
    }
  });

  test('items to check count action-needed and warning only, and beat reconnect and sync', () {
    expect(
      _resolve(attention, reconnected: true, syncing: true, completed: true),
      const HomeSafetyStatus(HomeSafetyStatusKind.actionNeeded, count: 2),
    );
  });

  test('reconnected beats updating, updating beats the idle states', () {
    expect(_resolve(scored, reconnected: true, syncing: true, completed: true).kind, HomeSafetyStatusKind.reconnected);
    expect(_resolve(scored, syncing: true, completed: true).kind, HomeSafetyStatusKind.updating);
    expect(_resolve(null, syncing: true).kind, HomeSafetyStatusKind.updating);
  });

  test('completed remains visible before returning to scored or unscored idle', () {
    for (final report in [scored, null]) {
      expect(_resolve(report, completed: true).kind, HomeSafetyStatusKind.updateCompleted);
      expect(_resolve(report).kind, report == null ? HomeSafetyStatusKind.noScore : HomeSafetyStatusKind.noIssues);
    }
  });

  // M11: 점수가 있는 보고서에 확인 전 점검이 남으면 "확인 전 N건". 일시 상태(재연결·업데이트) 뒤, "점검 이상 없음" 앞
  test('unchecked checks on a scored report come after the transient states and before no issues', () {
    const unknown = [
      SafetyCheckResult(SafetyCheckId.appUpdate, SafetyOutcome.unknown),
      SafetyCheckResult(SafetyCheckId.serverCert, SafetyOutcome.unknown),
    ];
    WalletHealthReport report(WalletHealthStatus status, {int? score, List<SafetySeverity> review = const []}) =>
        WalletHealthReport(
          status: status,
          score: score,
          reviewItems: [
            for (final severity in review)
              SafetyCheckResult(SafetyCheckId.addressReuse, SafetyOutcome.failed, severity: severity),
          ],
          notIncluded: unknown,
          evaluatedAt: DateTime(2026, 10, 20),
        );
    final unchecked = report(WalletHealthStatus.scored, score: 100);
    expect(_resolve(unchecked), const HomeSafetyStatus(HomeSafetyStatusKind.unchecked, count: 2));
    expect(_resolve(unchecked, completed: true).kind, HomeSafetyStatusKind.updateCompleted);
    expect(_resolve(unchecked, syncing: true).kind, HomeSafetyStatusKind.updating);
    expect(_resolve(unchecked, reconnected: true).kind, HomeSafetyStatusKind.reconnected);
    expect(_resolve(unchecked, network: NetworkStatus.offline).kind, HomeSafetyStatusKind.connectionProblem);
    expect(
      _resolve(report(WalletHealthStatus.scored, score: 80, review: [SafetySeverity.warning])),
      const HomeSafetyStatus(HomeSafetyStatusKind.actionNeeded, count: 1),
    );
    // 점수가 없는 S0·S4는 그대로
    for (final status in [WalletHealthStatus.noWallet, WalletHealthStatus.notEnoughData]) {
      expect(_resolve(report(status)).kind, HomeSafetyStatusKind.noScore);
    }
  });

  test('idle: no issues with a score, up to date without one', () {
    expect(_resolve(scored).kind, HomeSafetyStatusKind.noIssues);
    for (final report in [_report(WalletHealthStatus.notEnoughData), _report(WalletHealthStatus.noWallet), null]) {
      expect(_resolve(report).kind, HomeSafetyStatusKind.noScore);
    }
  });
}
