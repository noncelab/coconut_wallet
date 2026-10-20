import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:equatable/equatable.dart';

enum WalletHealthStatus { noWallet, notEnoughData, scored, criticalOverride }

enum WalletHealthLabel {
  excellent,
  good,
  needsAttention,
  actionNeeded;

  /// 90 / 75 / 50 경계(SPEC §7.2)
  static WalletHealthLabel of(int score) =>
      score >= 90
          ? excellent
          : score >= 75
          ? good
          : score >= 50
          ? needsAttention
          : actionNeeded;
}

/// 카테고리 기본 가중치 %(App/Recovery/Activity/Privacy). 점수 없는 카테고리는 빼고 다시 나눈다.
enum WeightProfile {
  hotFunded(20, 45, 25, 10),
  watchOnlyOnly(10, 40, 30, 20),
  mixed(15, 45, 25, 15);

  const WeightProfile(this.app, this.recovery, this.activity, this.privacy);

  final int app, recovery, activity, privacy;

  int weightOf(SafetyCategory category) => switch (category) {
    SafetyCategory.app => app,
    SafetyCategory.recovery => recovery,
    SafetyCategory.activity => activity,
    SafetyCategory.privacy => privacy,
  };
}

/// `AnalyticsWalletType.of`와 같은 분류(hot = hasLocalKey)
enum SafetyWalletKind { hot, watchOnly, multisig, taproot }

class CategoryScore extends Equatable {
  const CategoryScore({
    required this.category,
    this.score,
    this.weightPercent = 0,
    this.issueCount = 0,
    this.waitingReason,
  });

  final SafetyCategory category;

  /// null = 점수 없음(적용되는 점검이 없음)
  final int? score;

  /// 재정규화 뒤 실제 쓰인 가중치 %(점수 없으면 0)
  final double weightPercent;

  /// 이 카테고리의 검토 항목 수. 지갑 활동은 위급 사건 수를 더한다
  final int issueCount;

  /// 점수가 없을 때 무엇이 필요한지
  final NotApplicableReason? waitingReason;

  @override
  List<Object?> get props => [category, score, weightPercent, issueCount, waitingReason];
}

class WalletRecoveryContribution extends Equatable {
  const WalletRecoveryContribution({
    required this.walletId,
    required this.kind,
    required this.balanceSats,
    required this.score,
    required this.weight,
    this.failing = const [],
  });

  final int walletId;
  final SafetyWalletKind kind;
  final int balanceSats;
  final int score;
  final double weight;
  final List<SafetyCheckId> failing;

  @override
  List<Object?> get props => [walletId, kind, balanceSats, score, weight, failing];
}

/// 점수 밖 추천 항목. 추천 점검([id]) 또는 권장 점검 결과([check]: 메타데이터 백업, 인증서 만료 임박)
class RecommendedItem extends Equatable {
  const RecommendedItem({this.id, this.check, this.done = false});

  final RecommendedCheckId? id;
  final SafetyCheckResult? check;
  final bool done;

  @override
  List<Object?> get props => [id, check, done];
}

/// 엔진 평가 결과. 목록 규칙(lead 승인):
/// - [reviewItems]: 실패한 점검 중 심각도 critical·actionNeeded·warning. 심각도 → 점검 순서 → 지갑(앱 전체 먼저) 순.
///   사건이 아닌 위급(보기 전용 confirmedMismatch, 자금·이력 있는 다중서명 구성 불일치, CA가 보증하지 않는 인증서 변경)도 여기 있다.
///   unrecognizedOutgoing 실패는 넣지 않는다. 모르는 출금은 [criticalIncidents]·[infoIncidents]로만 나온다.
/// - [allGoodItems]: 통과한 점검. [notIncluded]: notApplicable·unknown(이유 = [SafetyCheckResult.reason]).
/// - [recommended]: 해당하는 rec.* + 메모·태그 백업(check, done = 통과) + 30일 안에 만료되는 서버 인증서. 모두 점수 밖.
/// - 지갑별 결과(walletId 있음): mnemonicBackup, passphraseVerify, watchOnlyVerify(points 100/60/0), multisigConfig, bsmsBackup,
///   pendingOutgoingAtBaseline·unexpectedSelfTransfer(subjects = txid, 인지하거나 사건이 될 때까지),
///   실패한 txConflict·addressReuse·possibleDusting(subjects = txid·주소·utxoId).
/// - 앱 전체 결과(walletId null): appLock, appUpdate, serverCert, metadataBackup, 그리고 unrecognizedOutgoing·txConflict·
///   addressReuse·possibleDusting의 "발견되지 않음" 또는 해당 없음 한 줄(열린 사건이 있으면 unrecognizedOutgoing 줄은 없음).
/// - [categories]의 waitingReason: 지갑 0개면 복구 noWallet·활동 noHistory·개인정보 noReceiveHistory, 자금·이력이 없으면 복구 noFunds.
/// - 세부 상태는 [SafetyCheckResult.detail]·[SafetyCheckResult.count].
class WalletHealthReport extends Equatable {
  const WalletHealthReport({
    required this.status,
    this.score,
    this.label,
    required this.profile,
    this.categories = const {},
    this.recovery = const [],
    this.criticalIncidents = const [],
    this.infoIncidents = const [],
    this.reviewItems = const [],
    this.allGoodItems = const [],
    this.notIncluded = const [],
    this.recommended = const [],
    this.walletCount = 0,
    this.fundedWalletCount = 0,
    required this.evaluatedAt,
    this.lastSuccessfulSyncAt,
    this.isConnected = true,
  });

  final WalletHealthStatus status;

  /// criticalOverride에서도 점수를 보존한다
  final int? score;
  final WalletHealthLabel? label;
  final WeightProfile profile;
  final Map<SafetyCategory, CategoryScore> categories;
  final List<WalletRecoveryContribution> recovery;

  /// 열린 사건 중 거래가 대기·확정 상태
  final List<SafetyIncident> criticalIncidents;

  /// 열린 사건 중 거래가 대체·드롭됨("멤풀에서 사라짐")
  final List<SafetyIncident> infoIncidents;
  final List<SafetyCheckResult> reviewItems, allGoodItems, notIncluded;
  final List<RecommendedItem> recommended;
  final int walletCount, fundedWalletCount;
  final DateTime evaluatedAt;
  final DateTime? lastSuccessfulSyncAt;
  final bool isConnected;

  bool get isCritical => status == WalletHealthStatus.criticalOverride;
  int get actionNeededCount => reviewItems.where((r) => r.severity == SafetySeverity.actionNeeded).length;

  /// 조치 필요·경고 항목 수(권장 점검·사건 제외). 홈 상태칩과 Wallet Health 머리가 같은 숫자를 쓴다(COPY ②)
  int get attentionCount =>
      reviewItems
          .where((r) => r.severity == SafetySeverity.actionNeeded || r.severity == SafetySeverity.warning)
          .length;

  /// [evaluatedAt]은 비교에서 뺀다(결과가 같으면 같은 보고서).
  @override
  List<Object?> get props => [
    status,
    score,
    label,
    profile,
    categories,
    recovery,
    criticalIncidents,
    infoIncidents,
    reviewItems,
    allGoodItems,
    notIncluded,
    recommended,
    walletCount,
    fundedWalletCount,
    lastSuccessfulSyncAt,
    isConnected,
  ];
}
