/// 서버 없이 출금(단독 출금) 시작 전 예상
class ArkExitQuote {
  const ArkExitQuote({
    required this.vtxoIds,
    required this.amountSats,
    required this.feeSats,
    required this.txCount,
    required this.feeRateSatPerVb,
    required this.firstExpiryHeight,
    this.broadcastFeeSats = 0,
    this.claimFeeSats = 0,
    this.exitDelta = 0,
    this.leftOutSats = 0,
  });

  /// 너무 작아 혼자 체인에 올릴 수 없어 빠진 금액
  final int leftOutSats;

  final List<String> vtxoIds;
  final int amountSats;

  /// 출금 거래와 회수 거래 수수료 합
  final int feeSats;
  final int txCount;
  final int feeRateSatPerVb;
  final int? firstExpiryHeight;

  /// 출금 거래들의 네트워크 수수료, 핫월렛에서 미리 옮겨 둔 돈으로 냄
  final int broadcastFeeSats;

  /// 받을 때 드는 수수료, 받을 금액에서 빠짐
  final int claimFeeSats;

  /// 출금 거래가 확정된 뒤 받기까지 기다리는 블록
  final int exitDelta;

  int get receiveSats => amountSats - claimFeeSats;

  /// 받을 수 있을 때까지 대략의 블록(출금 거래 하나에 블록 하나 + 기다림)
  int get waitBlocks => txCount + exitDelta;

  /// 수수료 지갑으로 옮길 금액, 수수료가 오를 때를 대비해 여유를 둠
  int get fundingSats => (feeSats * 3 / 2).ceil();
}

/// 출금 거래 진행 상황 한 번 읽은 것
class ArkExitProgress {
  const ArkExitProgress({
    required this.spent,
    required this.onChain,
    required this.allClaimable,
    required this.claimableHeight,
    required this.txDone,
    required this.txTotal,
  });

  /// 이미 다른 데 쓰였거나 취소됨
  final bool spent;

  /// 모든 출금 거래가 체인에 올라 대기·회수 단계
  final bool onChain;
  final bool allClaimable;
  final int? claimableHeight;
  final int txDone;
  final int txTotal;
}

enum ArkExitPhase { funding, exiting, waiting, claiming, done, failed }

enum ArkExitFailure { expired, spent }

/// 시작한 출금 하나. 앱을 다시 켜도 이어 가도록 기기에 저장
class ArkExitSession {
  const ArkExitSession({
    required this.vtxoIds,
    required this.amountSats,
    required this.destination,
    required this.fundingSats,
    required this.feeRateSatPerVb,
    required this.firstExpiryHeight,
    required this.startedAt,
    this.phase = ArkExitPhase.funding,
    this.txDone = 0,
    this.txTotal = 0,
    this.claimableHeight,
    this.claimTxid,
    this.receivedSats,
    this.failure,
    this.feeReturned = false,
    this.claimFeeSats = 0,
    this.finishedAt,
    this.fundingFeeSats = 0,
    this.returnedSats,
    this.destinationPath,
    this.feeWalletId,
  });

  final List<String> vtxoIds;
  final int amountSats;

  /// 받을 코코넛 지갑 주소, 시작할 때 정함
  final String destination;

  /// 받을 주소의 파생 경로, 이 정보를 넣기 전에 시작한 출금은 없음
  final String? destinationPath;

  /// 수수료를 가져온 지갑
  final int? feeWalletId;
  final int fundingSats;
  final int feeRateSatPerVb;

  /// 이 높이 전에 출금 거래가 확정되지 않으면 서버가 회수해 실패
  final int? firstExpiryHeight;
  final DateTime startedAt;
  final ArkExitPhase phase;
  final int txDone;
  final int txTotal;
  final int? claimableHeight;
  final String? claimTxid;
  final int? receivedSats;
  final ArkExitFailure? failure;

  /// 남은 수수료를 돌려보냈거나 돌려줄 게 없음
  final bool feeReturned;

  /// 시작할 때 예상한 받는 쪽 수수료
  final int claimFeeSats;
  final DateTime? finishedAt;

  /// 수수료 지갑으로 옮긴 거래의 수수료, 고른 지갑에서 냄
  final int fundingFeeSats;

  /// 수수료 지갑에서 받는 지갑으로 돌려받은 금액
  final int? returnedSats;

  /// 실제로 낸 수수료. 남은 수수료 정리까지 끝나야 알 수 있음
  int? get paidFeeSats {
    if (!isSettled) return null;
    final claimFee = receivedSats == null ? 0 : amountSats - receivedSats!;
    return fundingFeeSats + fundingSats - (returnedSats ?? 0) + claimFee;
  }

  /// 받은 금액, 아직 못 받았으면 예상
  int get receiveSats => receivedSats ?? amountSats - claimFeeSats;

  bool get isActive => phase != ArkExitPhase.done && phase != ArkExitPhase.failed;

  /// 끝났고 남은 수수료 정리도 마침
  bool get isSettled => !isActive && feeReturned;

  ArkExitSession copyWith({
    ArkExitPhase? phase,
    int? txDone,
    int? txTotal,
    int? claimableHeight,
    String? claimTxid,
    int? receivedSats,
    ArkExitFailure? failure,
    bool? feeReturned,
    DateTime? finishedAt,
    int? returnedSats,
  }) => ArkExitSession(
    vtxoIds: vtxoIds,
    amountSats: amountSats,
    destination: destination,
    fundingSats: fundingSats,
    feeRateSatPerVb: feeRateSatPerVb,
    firstExpiryHeight: firstExpiryHeight,
    startedAt: startedAt,
    phase: phase ?? this.phase,
    txDone: txDone ?? this.txDone,
    txTotal: txTotal ?? this.txTotal,
    claimableHeight: claimableHeight ?? this.claimableHeight,
    claimTxid: claimTxid ?? this.claimTxid,
    receivedSats: receivedSats ?? this.receivedSats,
    failure: failure ?? this.failure,
    feeReturned: feeReturned ?? this.feeReturned,
    claimFeeSats: claimFeeSats,
    finishedAt: finishedAt ?? this.finishedAt,
    fundingFeeSats: fundingFeeSats,
    returnedSats: returnedSats ?? this.returnedSats,
    destinationPath: destinationPath,
    feeWalletId: feeWalletId,
  );

  Map<String, dynamic> toJson() => {
    'vtxoIds': vtxoIds,
    'amountSats': amountSats,
    'destination': destination,
    'fundingSats': fundingSats,
    'feeRate': feeRateSatPerVb,
    'firstExpiryHeight': firstExpiryHeight,
    'startedAt': startedAt.toIso8601String(),
    'phase': phase.name,
    'txDone': txDone,
    'txTotal': txTotal,
    'claimableHeight': claimableHeight,
    'claimTxid': claimTxid,
    'receivedSats': receivedSats,
    'failure': failure?.name,
    'feeReturned': feeReturned,
    'claimFeeSats': claimFeeSats,
    'finishedAt': finishedAt?.toIso8601String(),
    'fundingFeeSats': fundingFeeSats,
    'returnedSats': returnedSats,
    'destinationPath': destinationPath,
    'feeWalletId': feeWalletId,
  };

  factory ArkExitSession.fromJson(Map<String, dynamic> json) => ArkExitSession(
    vtxoIds: [for (final id in json['vtxoIds'] as List) id as String],
    amountSats: json['amountSats'] as int,
    destination: json['destination'] as String,
    fundingSats: json['fundingSats'] as int,
    feeRateSatPerVb: json['feeRate'] as int,
    firstExpiryHeight: json['firstExpiryHeight'] as int?,
    startedAt: DateTime.parse(json['startedAt'] as String),
    phase: ArkExitPhase.values.byName(json['phase'] as String),
    txDone: json['txDone'] as int? ?? 0,
    txTotal: json['txTotal'] as int? ?? 0,
    claimableHeight: json['claimableHeight'] as int?,
    claimTxid: json['claimTxid'] as String?,
    receivedSats: json['receivedSats'] as int?,
    failure: switch (json['failure']) {
      final String name => ArkExitFailure.values.byName(name),
      _ => null,
    },
    feeReturned: json['feeReturned'] as bool? ?? false,
    claimFeeSats: json['claimFeeSats'] as int? ?? 0,
    finishedAt: switch (json['finishedAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    fundingFeeSats: json['fundingFeeSats'] as int? ?? 0,
    returnedSats: json['returnedSats'] as int?,
    destinationPath: json['destinationPath'] as String?,
    feeWalletId: json['feeWalletId'] as int?,
  );
}

/// 출금 단계를 넘기는 데 쓰는 bark 쪽 일
abstract interface class ArkExitSteps {
  Future<int> exitFeeConfirmedSats();
  Future<int> exitFeePendingSats();
  Future<void> startExit(List<String> vtxoIds);
  Future<ArkExitProgress> progressExit(List<String> vtxoIds, int feeRateSatPerVb);
  Future<({String txid, int feeSats})> claimExit(String address, int feeRateSatPerVb);

  /// 남은 수수료를 [address]로 돌려보내고 보낸 금액을 돌려줌
  Future<int> returnExitFee(String address, int feeRateSatPerVb);
}

/// 지금 단계에서 할 수 있는 일을 하고 다음 상태를 돌려줌. 할 일이 없으면 같은 [session]
Future<ArkExitSession> nextArkExitState(ArkExitSteps steps, ArkExitSession session, {required int? tipHeight}) async {
  final expiry = session.firstExpiryHeight;
  final expired = tipHeight != null && expiry != null && tipHeight >= expiry;
  switch (session.phase) {
    case ArkExitPhase.funding:
      if (expired)
        return _settle(
          steps,
          session.copyWith(phase: ArkExitPhase.failed, failure: ArkExitFailure.expired, finishedAt: DateTime.now()),
        );
      if (await steps.exitFeeConfirmedSats() < session.fundingSats) return session;
      await steps.startExit(session.vtxoIds);
      return _progress(steps, session.copyWith(phase: ArkExitPhase.exiting), expired);
    case ArkExitPhase.exiting:
    case ArkExitPhase.waiting:
      return _progress(steps, session, expired);
    case ArkExitPhase.claiming:
      return _claim(steps, session);
    case ArkExitPhase.done:
    case ArkExitPhase.failed:
      return _settle(steps, session);
  }
}

Future<ArkExitSession> _progress(ArkExitSteps steps, ArkExitSession session, bool expired) async {
  final progress = await steps.progressExit(session.vtxoIds, session.feeRateSatPerVb);
  final txTotal = progress.txTotal > 0 ? progress.txTotal : session.txTotal;
  final txDone = progress.txTotal > 0 ? progress.txDone : (progress.onChain ? txTotal : session.txDone);
  final counted = session.copyWith(txDone: txDone, txTotal: txTotal);
  if (progress.spent) {
    return _settle(
      steps,
      counted.copyWith(phase: ArkExitPhase.failed, failure: ArkExitFailure.spent, finishedAt: DateTime.now()),
    );
  }
  // 출금 거래가 확정되기 전에 만료되면 서버가 회수함
  if (!progress.onChain) {
    return expired
        ? _settle(
          steps,
          counted.copyWith(phase: ArkExitPhase.failed, failure: ArkExitFailure.expired, finishedAt: DateTime.now()),
        )
        : counted;
  }
  if (progress.allClaimable) return _claim(steps, counted.copyWith(phase: ArkExitPhase.claiming));
  return counted.copyWith(phase: ArkExitPhase.waiting, claimableHeight: progress.claimableHeight);
}

Future<ArkExitSession> _claim(ArkExitSteps steps, ArkExitSession session) async {
  final claim = await steps.claimExit(session.destination, session.feeRateSatPerVb);
  return _settle(
    steps,
    session.copyWith(
      phase: ArkExitPhase.done,
      claimTxid: claim.txid,
      receivedSats: session.amountSats - claim.feeSats,
      finishedAt: DateTime.now(),
    ),
  );
}

/// 수수료 지갑에 미확정 거래가 있으면 다음에 다시
Future<ArkExitSession> _settle(ArkExitSteps steps, ArkExitSession session) async {
  if (session.feeReturned || await steps.exitFeePendingSats() > 0) return session;
  final returned = await steps.returnExitFee(session.destination, session.feeRateSatPerVb);
  return session.copyWith(feeReturned: true, returnedSats: returned);
}
