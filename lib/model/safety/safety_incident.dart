import 'package:equatable/equatable.dart';

enum IncidentState { detected, recognized, responding, completed }

enum IncidentTxState { pending, confirmed, replaced, dropped }

enum IncidentResponseMode { free, premium }

/// 코코넛이 만들지 않은 출금 거래 하나(SPEC §7.3). 잘못된 상태 전이는 [StateError].
class SafetyIncident extends Equatable {
  const SafetyIncident({
    required this.walletId,
    required this.txid,
    required this.detectedAt,
    this.state = IncidentState.detected,
    this.txState = IncidentTxState.pending,
    this.responseMode,
    this.guideStep = 0,
    this.assistStartedAt,
    this.resolvedAt,
  });

  final int walletId;
  final String txid;
  final DateTime detectedAt;
  final IncidentState state;
  final IncidentTxState txState;
  final IncidentResponseMode? responseMode;
  final int guideStep;
  final DateTime? assistStartedAt, resolvedAt;

  String get id => '$walletId:$txid';

  bool get isOpen => state == IncidentState.detected || state == IncidentState.responding;
  bool get isCritical => isOpen && (txState == IncidentTxState.pending || txState == IncidentTxState.confirmed);

  /// 사라짐 → 정보, 위급 해제. 다시 나타나면 위급
  bool get isInfo => isOpen && !isCritical;

  /// detected|responding → recognized. 호출한 쪽이 txid를 `recognizedTxids`에 넣는다.
  SafetyIncident recognize(DateTime now) {
    if (!isOpen) throw StateError('recognize: ${state.name}');
    return _copy(state: IncidentState.recognized, resolvedAt: now);
  }

  /// detected → responding. 대응 중이면 모드만 바꾼다(Free 가이드 중 Premium 구매, Premium 만료 뒤 Free로 계속). 단계·시작 시각은 그대로
  SafetyIncident respond(IncidentResponseMode mode) {
    if (!isOpen) throw StateError('respond: ${state.name}');
    return _copy(state: IncidentState.responding, responseMode: mode);
  }

  /// responding → completed
  SafetyIncident complete(DateTime now) {
    if (state != IncidentState.responding) throw StateError('complete: ${state.name}');
    return _copy(state: IncidentState.completed, resolvedAt: now);
  }

  SafetyIncident withTxState(IncidentTxState txState) => _copy(txState: txState);

  SafetyIncident withGuideStep(int step, {DateTime? assistStartedAt}) =>
      _copy(guideStep: step, assistStartedAt: assistStartedAt);

  SafetyIncident _copy({
    IncidentState? state,
    IncidentTxState? txState,
    IncidentResponseMode? responseMode,
    int? guideStep,
    DateTime? assistStartedAt,
    DateTime? resolvedAt,
  }) => SafetyIncident(
    walletId: walletId,
    txid: txid,
    detectedAt: detectedAt,
    state: state ?? this.state,
    txState: txState ?? this.txState,
    responseMode: responseMode ?? this.responseMode,
    guideStep: guideStep ?? this.guideStep,
    assistStartedAt: assistStartedAt ?? this.assistStartedAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
  );

  Map<String, Object?> toJson() => {
    'walletId': walletId,
    'txid': txid,
    'detectedAt': detectedAt.toIso8601String(),
    'state': state.name,
    'txState': txState.name,
    'responseMode': responseMode?.name,
    'guideStep': guideStep,
    'assistStartedAt': assistStartedAt?.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
  };

  /// 모르는 값이면 예외. `SafetyState.fromJson`이 받아서 초기 상태로 되돌린다.
  factory SafetyIncident.fromJson(Map<String, Object?> j) => SafetyIncident(
    walletId: j['walletId'] as int,
    txid: j['txid'] as String,
    detectedAt: DateTime.parse(j['detectedAt'] as String),
    state: IncidentState.values.byName(j['state'] as String),
    txState: IncidentTxState.values.byName(j['txState'] as String),
    responseMode: j['responseMode'] == null ? null : IncidentResponseMode.values.byName(j['responseMode'] as String),
    guideStep: j['guideStep'] as int? ?? 0,
    assistStartedAt: j['assistStartedAt'] == null ? null : DateTime.parse(j['assistStartedAt'] as String),
    resolvedAt: j['resolvedAt'] == null ? null : DateTime.parse(j['resolvedAt'] as String),
  );

  @override
  List<Object?> get props => [
    walletId,
    txid,
    detectedAt,
    state,
    txState,
    responseMode,
    guideStep,
    assistStartedAt,
    resolvedAt,
  ];
}
