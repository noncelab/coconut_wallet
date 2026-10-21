import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:equatable/equatable.dart';

/// 홈 앱바 상태칩. 선언 순서가 우선순위다(SPEC v2: 위급 > 연결·동기화 실패 > 조치 필요 > 재연결 > 업데이트 중 > 정상).
enum HomeSafetyStatusKind { critical, connectionProblem, actionNeeded, reconnected, updating, noIssues, upToDate }

class HomeSafetyStatus extends Equatable {
  const HomeSafetyStatus(this.kind, {this.count = 0, this.networkStatus = NetworkStatus.online, this.label});

  final HomeSafetyStatusKind kind;

  /// [HomeSafetyStatusKind.actionNeeded]일 때 확인할 항목 수
  final int count;

  /// [HomeSafetyStatusKind.connectionProblem]일 때 문구를 고르는 데 쓴다
  final NetworkStatus networkStatus;

  /// [HomeSafetyStatusKind.noIssues]일 때 점수 라벨(매우 좋음·양호 색을 나눈다)
  final WalletHealthLabel? label;

  @override
  List<Object?> get props => [kind, count, networkStatus, label];
}

HomeSafetyStatus resolveHomeSafetyStatus({
  required WalletHealthReport? report,
  required NetworkStatus networkStatus,
  required bool showReconnected,
  required bool isSyncing,
}) {
  HomeSafetyStatus status(HomeSafetyStatusKind kind, [int count = 0]) =>
      HomeSafetyStatus(kind, count: count, networkStatus: networkStatus, label: report?.label);

  if (report?.isCritical ?? false) return status(HomeSafetyStatusKind.critical);
  if (networkStatus != NetworkStatus.online) return status(HomeSafetyStatusKind.connectionProblem);
  final count = report?.attentionCount ?? 0;
  if (count > 0) return status(HomeSafetyStatusKind.actionNeeded, count);
  if (showReconnected) return status(HomeSafetyStatusKind.reconnected);
  if (isSyncing) return status(HomeSafetyStatusKind.updating);
  return status(report?.score != null ? HomeSafetyStatusKind.noIssues : HomeSafetyStatusKind.upToDate);
}
