/// 직접 출금(단독 출금)을 시작하기 전 확인 정보
class ArkExitEstimate {
  const ArkExitEstimate({
    required this.vtxoIds,
    required this.amountSats,
    required this.expiredSats,
    required this.feeSats,
    required this.txCount,
    required this.feeRateSatPerVb,
    required this.blocksUntilFirstExpiry,
    required this.firstExpiryHeight,
  });

  /// 출금할 VTXO: 만료되지 않고 잠기지 않았으며 갱신 중이 아닌 것
  final List<String> vtxoIds;
  final int amountSats;

  /// 이미 만료돼 단독 출금으로는 꺼낼 수 없는 잔액(갱신으로 돌려받아야 함)
  final int expiredSats;

  /// 출금 거래 수수료 + 회수 거래 수수료 추정치
  final int feeSats;
  final int txCount;
  final int feeRateSatPerVb;

  /// 출금할 VTXO 중 가장 빠른 만료까지 남은 블록
  final int? blocksUntilFirstExpiry;
  final int? firstExpiryHeight;

  /// 수수료 지갑으로 옮길 금액, 추정치에 여유를 둠
  int get fundingSats => (feeSats * 3 / 2).ceil();
}

/// 직접 출금을 시작할 수 없는 이유
enum ArkExitBlocker { nothingToExit, tooCloseToExpiry, notEnoughOnchain, selectUtxo, notEnoughSelected }

/// 직접 출금 진행 단계, 앱을 다시 켜도 이어 가도록 기기에 저장
enum ArkExitPhase { funding, exiting, waiting, claiming, done, failed }

enum ArkExitFailure { expired, spent, unknown }

/// 시작한 직접 출금 하나. 받을 주소는 시작할 때 정해 둠
class ArkExitSession {
  const ArkExitSession({
    required this.walletId,
    required this.vtxoIds,
    required this.amountSats,
    required this.destination,
    required this.destinationPath,
    required this.fundingTxid,
    required this.fundingSats,
    required this.feeRateSatPerVb,
    required this.firstExpiryHeight,
    required this.startedAt,
    this.phase = ArkExitPhase.funding,
    this.claimableHeight,
    this.claimTxid,
    this.receivedSats,
    this.failure,
    this.feeReturned = false,
    this.feeReturnTxid,
  });

  final int walletId;
  final List<String> vtxoIds;
  final int amountSats;
  final String destination;
  final String destinationPath;
  final String fundingTxid;
  final int fundingSats;
  final int feeRateSatPerVb;

  /// 이 높이 전에 출금 거래가 확정되지 않으면 서버가 회수해 실패
  final int? firstExpiryHeight;
  final DateTime startedAt;
  final ArkExitPhase phase;
  final int? claimableHeight;
  final String? claimTxid;
  final int? receivedSats;
  final ArkExitFailure? failure;

  /// 남은 수수료를 돌려보냈거나 돌려줄 게 없음
  final bool feeReturned;

  /// 남은 수수료를 돌려보낸 거래, 돌려줄 게 없었으면 null
  final String? feeReturnTxid;

  /// 이 출금에 딸린 온체인 거래 중 받은 거래 말고 나머지
  List<String> get relatedTxids => [fundingTxid, if (feeReturnTxid != null) feeReturnTxid!];

  bool get isActive => phase != ArkExitPhase.done && phase != ArkExitPhase.failed;

  ArkExitSession copyWith({
    ArkExitPhase? phase,
    int? claimableHeight,
    String? claimTxid,
    int? receivedSats,
    ArkExitFailure? failure,
    bool? feeReturned,
    String? feeReturnTxid,
  }) => ArkExitSession(
    walletId: walletId,
    vtxoIds: vtxoIds,
    amountSats: amountSats,
    destination: destination,
    destinationPath: destinationPath,
    fundingTxid: fundingTxid,
    fundingSats: fundingSats,
    feeRateSatPerVb: feeRateSatPerVb,
    firstExpiryHeight: firstExpiryHeight,
    startedAt: startedAt,
    phase: phase ?? this.phase,
    claimableHeight: claimableHeight ?? this.claimableHeight,
    claimTxid: claimTxid ?? this.claimTxid,
    receivedSats: receivedSats ?? this.receivedSats,
    failure: failure ?? this.failure,
    feeReturned: feeReturned ?? this.feeReturned,
    feeReturnTxid: feeReturnTxid ?? this.feeReturnTxid,
  );

  Map<String, dynamic> toJson() => {
    'walletId': walletId,
    'vtxoIds': vtxoIds,
    'amountSats': amountSats,
    'destination': destination,
    'destinationPath': destinationPath,
    'fundingTxid': fundingTxid,
    'fundingSats': fundingSats,
    'feeRate': feeRateSatPerVb,
    'firstExpiryHeight': firstExpiryHeight,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'phase': phase.name,
    'claimableHeight': claimableHeight,
    'claimTxid': claimTxid,
    'receivedSats': receivedSats,
    'failure': failure?.name,
    'feeReturned': feeReturned,
    'feeReturnTxid': feeReturnTxid,
  };

  factory ArkExitSession.fromJson(Map<String, dynamic> json) => ArkExitSession(
    walletId: json['walletId'] as int,
    vtxoIds: (json['vtxoIds'] as List).cast<String>(),
    amountSats: json['amountSats'] as int,
    destination: json['destination'] as String,
    destinationPath: json['destinationPath'] as String,
    fundingTxid: json['fundingTxid'] as String,
    fundingSats: json['fundingSats'] as int,
    feeRateSatPerVb: json['feeRate'] as int,
    firstExpiryHeight: json['firstExpiryHeight'] as int?,
    startedAt: DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int),
    phase: ArkExitPhase.values.byName(json['phase'] as String),
    claimableHeight: json['claimableHeight'] as int?,
    claimTxid: json['claimTxid'] as String?,
    receivedSats: json['receivedSats'] as int?,
    failure: json['failure'] == null ? null : ArkExitFailure.values.byName(json['failure'] as String),
    feeReturned: json['feeReturned'] as bool? ?? false,
    feeReturnTxid: json['feeReturnTxid'] as String?,
  );
}
