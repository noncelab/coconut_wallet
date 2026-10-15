/// 지갑 재동기화 진행 단계
enum ResyncPhase { wiping, scanning, restoringMetadata, completed, failed }

/// 지갑 재동기화 진행 상태
class ResyncProgress {
  final ResyncPhase phase;

  /// scanning 단계 중 fetch 총량이 확정된 이후에만 채워진다(null이면 아직 총량 미확정).
  final int? fetchCompleted;
  final int? fetchTotal;

  final String? errorMessage;

  const ResyncProgress({required this.phase, this.fetchCompleted, this.fetchTotal, this.errorMessage});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResyncProgress &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          fetchCompleted == other.fetchCompleted &&
          fetchTotal == other.fetchTotal &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(phase, fetchCompleted, fetchTotal, errorMessage);
}
