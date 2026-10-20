import 'package:equatable/equatable.dart';

/// Wallet Health 점수 카테고리(App Protection / Recovery / Activity / Privacy)
enum SafetyCategory { app, recovery, activity, privacy }

/// 엔진이 판정하는 점검. [category]가 null이면 점수 밖 항목이다.
enum SafetyCheckId {
  appLock(SafetyCategory.app),
  appUpdate(SafetyCategory.app),
  mnemonicBackup(SafetyCategory.recovery),
  passphraseVerify(SafetyCategory.recovery),
  watchOnlyVerify(SafetyCategory.recovery),
  multisigConfig(SafetyCategory.recovery),
  bsmsBackup(SafetyCategory.recovery),
  unrecognizedOutgoing(SafetyCategory.activity),
  txConflict(SafetyCategory.activity),
  addressReuse(SafetyCategory.privacy),
  possibleDusting(SafetyCategory.privacy),
  pendingOutgoingAtBaseline(null),
  unexpectedSelfTransfer(null),
  serverCert(null),
  metadataBackup(null);

  const SafetyCheckId(this.category);

  final SafetyCategory? category;
}

/// 사용자가 직접 완료 표시하는 추천 점검(점수 밖). [key]로 `SafetyState.recommendedDoneAt`에 저장한다.
enum RecommendedCheckId {
  hotPhysicalBackup,
  hotSafeStorage,
  hotPassphraseOffline,
  multisigQuorumAccess,
  multisigBackupSeparation,
  metadataStoredOffsite;

  String get key => 'rec.$name';
}

/// index가 작을수록 먼저 보여 준다.
enum SafetySeverity { critical, actionNeeded, warning, recommended, none }

enum SafetyEvidence { automatic, userConfirmed, heuristic, recommended }

enum SafetyOutcome { passed, failed, notApplicable, unknown }

/// 점검이 적용되지 않거나 판정을 미룬 이유
enum NotApplicableReason {
  noWallet,
  noFunds,
  noHistory,
  noReceiveHistory,
  noUtxoHistory,
  noPassphrase,
  noLabels,
  notCustomServer,
  updateCheckFailed,
  notSettled,
}

/// 실패한 점검의 세부 상태(문구 선택용)
enum SafetyCheckDetail {
  /// 아직 검증 안 함(보기 전용·BSMS·패스프레이즈)
  notVerified,

  /// 검증했지만 불일치(보기 전용 "다시 스캔"·BSMS 스캔 불일치), 다중서명 구성 불일치. 위급 여부는 심각도로 본다
  mismatch,

  /// 다중서명 구성 정보 일부 없음
  incomplete,

  /// BSMS를 검증하거나 내보낸 뒤 지갑 구성이 바뀜
  updateRequired,

  /// 지금 구성의 BSMS를 내보냈지만 다시 불러와 검증하지 않음(내보내기는 검증이 아니다, REQ A.1 2)
  exportedNotVerified,

  /// 메모·태그를 내보낸 적 없음
  neverExported,

  /// 마지막 내보내기 뒤 메모·태그가 바뀜([SafetyCheckResult.count] = 바뀐 수)
  changed,

  /// CA가 보증하지 않는 서버 인증서 지문 변경
  identityChanged,

  /// 서버 인증서 만료([SafetyCheckResult.count] = 만료 뒤 일수)
  expired,

  /// 30일 안에 만료([SafetyCheckResult.count] = 남은 일수, 0 = 오늘)
  expiresSoon,
}

/// 점검 하나의 결과. 엔진은 문구를 만들지 않고, UI가 [id]·[reason]·[detail]로 `t.wallet_health.*`를 고른다.
class SafetyCheckResult extends Equatable {
  const SafetyCheckResult(
    this.id,
    this.outcome, {
    this.walletId,
    this.severity = SafetySeverity.none,
    this.evidence = SafetyEvidence.automatic,
    this.reason,
    this.subjects = const [],
    this.points,
    this.detail,
    this.count,
  });

  final SafetyCheckId id;
  final SafetyOutcome outcome;

  /// null = 앱 전체 점검
  final int? walletId;
  final SafetySeverity severity;
  final SafetyEvidence evidence;
  final NotApplicableReason? reason;

  /// 재사용 주소 | 더스트 utxoId | txid
  final List<String> subjects;

  /// 예: 보기 전용 검증 100(QR) / 60(사용자 확인)
  final int? points;

  /// 실패의 세부 상태
  final SafetyCheckDetail? detail;

  /// 일수(서버 인증서 만료 뒤·만료까지, 0 = 오늘) 또는 개수(마지막 내보내기 뒤 바뀐 태그+메모)
  final int? count;

  String get key => 'check:${id.name}:${walletId ?? 'app'}';

  @override
  List<Object?> get props => [id, outcome, walletId, severity, evidence, reason, subjects, points, detail, count];
}
