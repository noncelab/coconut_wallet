import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:equatable/equatable.dart';

/// 받은 거래 감시 한 건(txConflict 두 번 판정)
typedef IncomingWatchEntry = ({DateTime seenAt, int strikes, DateTime? lastStrikeAt, Set<String> paidAddresses});

/// 지갑의 거래 하나에 생긴 일(마지막 전송, 받은 거래 충돌)
typedef WalletTxEvent = ({int walletId, String txid, DateTime at});

/// 지갑의 감지 기준점. 기준점 때 있던 거래는 정확한 txid([knownTxids])로만 옛 거래로 본다.
/// 높이·시각으로 자르지 않는다(서버가 적어 준 높이·리오그로 새 출금이 숨지 않게, 레드팀 §8·리뷰 R2).
class WalletBaseline extends Equatable {
  const WalletBaseline({
    required this.height,
    required this.at,
    this.knownTxids = const {},
    this.knownBelowHeight,
    this.pendingSentAtBaseline = const {},
    this.unexpectedSelfTxids = const {},
  });

  /// 기준점을 잡은 블록 높이(표시·기록용. 판정에는 [knownBelowHeight]만 쓴다)
  final int height;
  final DateTime at;

  /// 기준점 때 있던 모든 거래(종류·확정 무관)와 대기 지출의 txid 앞부분([SafetyState.txidPrefix]). 기준점 뒤엔 넓히지 않는다
  final Set<String> knownTxids;

  /// 거래가 2만 개를 넘어 [knownTxids]를 줄였을 때만: 이 높이 이하 확정 거래도 옛 거래로 본다
  final int? knownBelowHeight;

  /// 검토 항목(pendingOutgoingAtBaseline): 기준점 때 대기 중이었거나 7일 안에 확정된 출금의 txid.
  /// 확정돼도 사라지지 않고 "내 거래예요"나 사건이 될 때까지 남는다(레드팀 §2)
  final Set<String> pendingSentAtBaseline;

  /// 검토 항목(unexpectedSelfTransfer): 기준점 뒤에 생긴, 앱이 만들지 않은 자기 앞 전송의 txid(레드팀 §7)
  final Set<String> unexpectedSelfTxids;

  /// 기준점 때 있던 거래인지
  bool knows(String txid, int blockHeight) =>
      knownTxids.contains(SafetyState.txidPrefix(txid)) ||
      (knownBelowHeight != null && blockHeight > 0 && blockHeight <= knownBelowHeight!);

  WalletBaseline copyWith({Set<String>? knownTxids, int? knownBelowHeight, Set<String>? unexpectedSelfTxids}) =>
      WalletBaseline(
        height: height,
        at: at,
        knownTxids: knownTxids ?? this.knownTxids,
        knownBelowHeight: knownBelowHeight ?? this.knownBelowHeight,
        pendingSentAtBaseline: pendingSentAtBaseline,
        unexpectedSelfTxids: unexpectedSelfTxids ?? this.unexpectedSelfTxids,
      );

  Map<String, Object?> toJson() => {
    'height': height,
    'at': at.toIso8601String(),
    'knownTxids': knownTxids.toList(),
    'knownBelowHeight': knownBelowHeight,
    'pendingSentAtBaseline': pendingSentAtBaseline.toList(),
    'unexpectedSelfTxids': unexpectedSelfTxids.toList(),
  };

  factory WalletBaseline.fromJson(Map<String, Object?> j) => WalletBaseline(
    height: j['height'] as int,
    at: _date(j['at']),
    knownTxids: _strings(j['knownTxids']),
    knownBelowHeight: j['knownBelowHeight'] as int?,
    pendingSentAtBaseline: _strings(j['pendingSentAtBaseline']),
    unexpectedSelfTxids: _strings(j['unexpectedSelfTxids']),
  );

  @override
  List<Object?> get props => [height, at, knownTxids, knownBelowHeight, pendingSentAtBaseline, unexpectedSelfTxids];
}

enum VerificationMethod { qr, user }

enum VerificationResult { match, mismatch, confirmedMismatch }

class WatchOnlyVerification extends Equatable {
  const WatchOnlyVerification({
    required this.method,
    required this.result,
    this.matchedIndex,
    required this.descriptorHash,
    required this.at,
  });

  final VerificationMethod method;
  final VerificationResult result;

  /// 일치한 받기 주소 번호(#0–19)
  final int? matchedIndex;

  /// 검증할 때의 디스크립터 해시. 지금 해시와 다르면 검증은 무효
  final String descriptorHash;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'method': method.name,
    'result': result.name,
    'matchedIndex': matchedIndex,
    'descriptorHash': descriptorHash,
    'at': at.toIso8601String(),
  };

  factory WatchOnlyVerification.fromJson(Map<String, Object?> j) => WatchOnlyVerification(
    method: VerificationMethod.values.byName(j['method'] as String),
    result: VerificationResult.values.byName(j['result'] as String),
    matchedIndex: j['matchedIndex'] as int?,
    descriptorHash: j['descriptorHash'] as String,
    at: _date(j['at']),
  );

  @override
  List<Object?> get props => [method, result, matchedIndex, descriptorHash, at];
}

class BsmsVerification extends Equatable {
  const BsmsVerification({required this.matched, required this.configHash, required this.at});

  final bool matched;
  final String configHash;
  final DateTime at;

  Map<String, Object?> toJson() => {'matched': matched, 'configHash': configHash, 'at': at.toIso8601String()};

  factory BsmsVerification.fromJson(Map<String, Object?> j) =>
      BsmsVerification(matched: j['matched'] as bool, configHash: j['configHash'] as String, at: _date(j['at']));

  @override
  List<Object?> get props => [matched, configHash, at];
}

/// BSMS를 보여 주거나 공유한 기록: 그때 구성 해시와 시각. 검증이 아니다(REQ A.1 2)
typedef BsmsExport = ({String configHash, DateTime at});

/// 비상 이동 목적지. [walletId]면 구성할 때 그 지갑의 받기 주소를 쓴다.
class RescueDestination extends Equatable {
  const RescueDestination({this.walletId, this.address, required this.setAt});

  final int? walletId;
  final String? address;
  final DateTime setAt;

  Map<String, Object?> toJson() => {'walletId': walletId, 'address': address, 'setAt': setAt.toIso8601String()};

  factory RescueDestination.fromJson(Map<String, Object?> j) =>
      RescueDestination(walletId: j['walletId'] as int?, address: j['address'] as String?, setAt: _date(j['setAt']));

  @override
  List<Object?> get props => [walletId, address, setAt];
}

/// 비상 이동 초안 요약(서명 안 한 계획만 저장)
class RescueDraftSummary extends Equatable {
  const RescueDraftSummary({
    required this.destinationAddress,
    required this.amount,
    required this.fee,
    required this.inputCount,
    required this.feeRate,
    required this.preparedAt,
    this.blocker,
  });

  final String destinationAddress;
  final int amount, fee, inputCount;
  final double feeRate;
  final DateTime preparedAt;
  final String? blocker;

  Map<String, Object?> toJson() => {
    'destinationAddress': destinationAddress,
    'amount': amount,
    'fee': fee,
    'inputCount': inputCount,
    'feeRate': feeRate,
    'preparedAt': preparedAt.toIso8601String(),
    'blocker': blocker,
  };

  factory RescueDraftSummary.fromJson(Map<String, Object?> j) => RescueDraftSummary(
    destinationAddress: j['destinationAddress'] as String,
    amount: j['amount'] as int,
    fee: j['fee'] as int,
    inputCount: j['inputCount'] as int,
    feeRate: (j['feeRate'] as num).toDouble(),
    preparedAt: _date(j['preparedAt']),
    blocker: j['blocker'] as String?,
  );

  @override
  List<Object?> get props => [destinationAddress, amount, fee, inputCount, feeRate, preparedAt, blocker];
}

/// 마지막으로 본 사용자 서버 인증서(TOFU 비교용)
class ServerCertRecord extends Equatable {
  const ServerCertRecord({
    required this.host,
    required this.port,
    required this.fingerprint,
    this.endValidity,
    required this.caValid,
    required this.observedAt,
  });

  final String host;
  final int port;
  final String fingerprint;
  final DateTime? endValidity;
  final bool caValid;
  final DateTime observedAt;

  Map<String, Object?> toJson() => {
    'host': host,
    'port': port,
    'fingerprint': fingerprint,
    'endValidity': endValidity?.toIso8601String(),
    'caValid': caValid,
    'observedAt': observedAt.toIso8601String(),
  };

  factory ServerCertRecord.fromJson(Map<String, Object?> j) => ServerCertRecord(
    host: j['host'] as String,
    port: j['port'] as int,
    fingerprint: j['fingerprint'] as String,
    endValidity: _dateOrNull(j['endValidity']),
    caValid: j['caValid'] as bool,
    observedAt: _date(j['observedAt']),
  );

  @override
  List<Object?> get props => [host, port, fingerprint, endValidity, caValid, observedAt];
}

/// Wallet Health 영속 상태. SharedPreferences JSON 하나(`SharedPrefKeys.kSafetyState`).
/// 컬렉션은 불변으로 다룬다(바꿀 땐 [copyWith]로 새 값).
class SafetyState extends Equatable {
  static const version = 1;

  /// txid 앞 20자리(80비트). 도난 거래 txid를 맞춰 만들 수 없는 길이면서 저장은 1/3
  static const txidPrefixLength = 20;

  static String txidPrefix(String txid) =>
      (txid.length > txidPrefixLength ? txid.substring(0, txidPrefixLength) : txid).toLowerCase();

  const SafetyState({
    this.baselines = const {},
    this.appTxidPrefixes = const {},
    this.lastBroadcast,
    this.recognizedTxids = const {},
    this.incidents = const [],
    this.cautionWalletIds = const {},
    this.watchOnlyVerifications = const {},
    this.passphraseVerifiedAt = const {},
    this.bsms = const {},
    this.bsmsExports = const {},
    this.recommendedDoneAt = const {},
    this.metadataExport,
    this.incomingWatch = const {},
    this.conflicts = const [],
    this.rescue = const {},
    this.lastSuccessfulSyncAt,
    this.serverCert,
    this.hintDismissed = false,
    this.readItemIds = const {},
  });

  factory SafetyState.initial() => const SafetyState();

  final Map<int, WalletBaseline> baselines;

  /// 앱이 만든 거래의 txid 앞부분([txidPrefix]). 모든 지갑 공용, 기록 순서(최신이 뒤).
  /// 지갑을 지워도 남긴다(같은 디스크립터의 다른 지갑 보호, ARCH F9). PIN 초기화 때만 지워진다. 분석 이벤트에 넣지 않는다.
  // ponytail: 상한·정리 없음. 앱이 만든 거래 하나에 저장 JSON 약 23바이트라 1만 건 ≈ 230 KB(실제 사용자는 한참 아래).
  // 나중에 정리를 넣더라도 기준점(knownTxids)을 넓히거나 검토 목록(pendingSentAtBaseline·unexpectedSelfTxids)을 건드리면 안 된다:
  // 방향이 나중에 고쳐지는 거래가 영구히 묻히고(리뷰 R1-M1), 내 결제가 모르는 출금 검토로 돌아온다(R1-M2)
  final Set<String> appTxidPrefixes;

  /// 성공한 전송만(가이드 이어하기)
  final WalletTxEvent? lastBroadcast;
  final Set<String> recognizedTxids;
  final List<SafetyIncident> incidents;
  final Set<int> cautionWalletIds;
  final Map<int, WatchOnlyVerification> watchOnlyVerifications;
  final Map<int, DateTime> passphraseVerifiedAt;
  final Map<int, BsmsVerification> bsms;

  /// 지갑마다 마지막 BSMS 내보내기(검증 기록 [bsms]와 따로 둔다)
  final Map<int, BsmsExport> bsmsExports;

  /// key = [RecommendedCheckId.key]('rec.<name>')
  final Map<String, DateTime> recommendedDoneAt;
  final ({DateTime at, int tagCount, int memoCount})? metadataExport;

  /// 지갑 → 받은 txid → 감시
  final Map<int, Map<String, IncomingWatchEntry>> incomingWatch;
  final List<WalletTxEvent> conflicts;
  final Map<int, ({RescueDestination destination, RescueDraftSummary? draft})> rescue;
  final DateTime? lastSuccessfulSyncAt;
  final ServerCertRecord? serverCert;
  final bool hintDismissed;
  final Set<String> readItemIds;

  /// 앱이 만든 거래인지(지갑 무관)
  bool isAppCreated(String txid) => appTxidPrefixes.contains(txidPrefix(txid));

  SafetyState copyWith({
    Map<int, WalletBaseline>? baselines,
    Set<String>? appTxidPrefixes,
    WalletTxEvent? lastBroadcast,
    Set<String>? recognizedTxids,
    List<SafetyIncident>? incidents,
    Set<int>? cautionWalletIds,
    Map<int, WatchOnlyVerification>? watchOnlyVerifications,
    Map<int, DateTime>? passphraseVerifiedAt,
    Map<int, BsmsVerification>? bsms,
    Map<int, BsmsExport>? bsmsExports,
    Map<String, DateTime>? recommendedDoneAt,
    ({DateTime at, int tagCount, int memoCount})? metadataExport,
    Map<int, Map<String, IncomingWatchEntry>>? incomingWatch,
    List<WalletTxEvent>? conflicts,
    Map<int, ({RescueDestination destination, RescueDraftSummary? draft})>? rescue,
    DateTime? lastSuccessfulSyncAt,
    ServerCertRecord? serverCert,
    bool? hintDismissed,
    Set<String>? readItemIds,
  }) => SafetyState(
    baselines: baselines ?? this.baselines,
    appTxidPrefixes: appTxidPrefixes ?? this.appTxidPrefixes,
    lastBroadcast: lastBroadcast ?? this.lastBroadcast,
    recognizedTxids: recognizedTxids ?? this.recognizedTxids,
    incidents: incidents ?? this.incidents,
    cautionWalletIds: cautionWalletIds ?? this.cautionWalletIds,
    watchOnlyVerifications: watchOnlyVerifications ?? this.watchOnlyVerifications,
    passphraseVerifiedAt: passphraseVerifiedAt ?? this.passphraseVerifiedAt,
    bsms: bsms ?? this.bsms,
    bsmsExports: bsmsExports ?? this.bsmsExports,
    recommendedDoneAt: recommendedDoneAt ?? this.recommendedDoneAt,
    metadataExport: metadataExport ?? this.metadataExport,
    incomingWatch: incomingWatch ?? this.incomingWatch,
    conflicts: conflicts ?? this.conflicts,
    rescue: rescue ?? this.rescue,
    lastSuccessfulSyncAt: lastSuccessfulSyncAt ?? this.lastSuccessfulSyncAt,
    serverCert: serverCert ?? this.serverCert,
    hintDismissed: hintDismissed ?? this.hintDismissed,
    readItemIds: readItemIds ?? this.readItemIds,
  );

  /// 지운 지갑의 데이터를 모두 뺀다. 그 지갑을 목적지로 쓰던 구출 설정과 그 지갑의 읽음 표시도 지운다.
  /// 앱 생성 txid([appTxidPrefixes])는 지갑에 묶이지 않아 그대로 둔다(ARCH F9).
  SafetyState withoutWallet(int walletId) {
    Map<int, V> drop<V>(Map<int, V> map) => {...map}..remove(walletId);
    // 읽음 키 형식: 'incident:<walletId>:<txid>'(SafetyProvider), 'check:<점검>:<walletId|app>'(SafetyCheckResult.key)
    bool ofWallet(String key) => switch (key.split(':')) {
      ['incident', final id, _] || ['check', _, final id] => id == '$walletId',
      _ => false,
    };
    return SafetyState(
      baselines: drop(baselines),
      appTxidPrefixes: appTxidPrefixes,
      lastBroadcast: lastBroadcast?.walletId == walletId ? null : lastBroadcast,
      recognizedTxids: recognizedTxids,
      incidents: [...incidents.where((i) => i.walletId != walletId)],
      cautionWalletIds: {...cautionWalletIds}..remove(walletId),
      watchOnlyVerifications: drop(watchOnlyVerifications),
      passphraseVerifiedAt: drop(passphraseVerifiedAt),
      bsms: drop(bsms),
      bsmsExports: drop(bsmsExports),
      recommendedDoneAt: recommendedDoneAt,
      metadataExport: metadataExport,
      incomingWatch: drop(incomingWatch),
      conflicts: [...conflicts.where((c) => c.walletId != walletId)],
      rescue: {
        for (final e in rescue.entries)
          if (e.key != walletId && e.value.destination.walletId != walletId) e.key: e.value,
      },
      lastSuccessfulSyncAt: lastSuccessfulSyncAt,
      serverCert: serverCert,
      hintDismissed: hintDismissed,
      readItemIds: {
        for (final key in readItemIds)
          if (!ofWallet(key)) key,
      },
    );
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'baselines': _byWallet(baselines, (b) => b.toJson()),
    'appTxidPrefixes': appTxidPrefixes.toList(),
    'lastBroadcast': lastBroadcast == null ? null : _eventToJson(lastBroadcast!),
    'recognizedTxids': recognizedTxids.toList(),
    'incidents': [for (final i in incidents) i.toJson()],
    'cautionWalletIds': cautionWalletIds.toList(),
    'watchOnlyVerifications': _byWallet(watchOnlyVerifications, (v) => v.toJson()),
    'passphraseVerifiedAt': _byWallet(passphraseVerifiedAt, (at) => at.toIso8601String()),
    'bsms': _byWallet(bsms, (v) => v.toJson()),
    'bsmsExports': _byWallet(bsmsExports, (e) => {'configHash': e.configHash, 'at': e.at.toIso8601String()}),
    'recommendedDoneAt': recommendedDoneAt.map((k, at) => MapEntry(k, at.toIso8601String())),
    'metadataExport':
        metadataExport == null
            ? null
            : {
              'at': metadataExport!.at.toIso8601String(),
              'tagCount': metadataExport!.tagCount,
              'memoCount': metadataExport!.memoCount,
            },
    'incomingWatch': _byWallet(
      incomingWatch,
      (watch) => watch.map(
        (txid, w) => MapEntry(txid, {
          'seenAt': w.seenAt.toIso8601String(),
          'strikes': w.strikes,
          'lastStrikeAt': w.lastStrikeAt?.toIso8601String(),
          'paidAddresses': w.paidAddresses.toList(),
        }),
      ),
    ),
    'conflicts': [for (final c in conflicts) _eventToJson(c)],
    'rescue': _byWallet(rescue, (r) => {'destination': r.destination.toJson(), 'draft': r.draft?.toJson()}),
    'lastSuccessfulSyncAt': lastSuccessfulSyncAt?.toIso8601String(),
    'serverCert': serverCert?.toJson(),
    'hintDismissed': hintDismissed,
    'readItemIds': readItemIds.toList(),
  };

  /// 깨졌거나 버전이 다르면 [SafetyState.initial]. 없는 키는 빈 값으로 읽는다.
  factory SafetyState.fromJson(Map<String, Object?> j) {
    if (j['version'] != version) return SafetyState.initial();
    try {
      return SafetyState(
        baselines: _walletMap(j['baselines'], (v) => WalletBaseline.fromJson(_obj(v))),
        appTxidPrefixes: _strings(j['appTxidPrefixes']),
        lastBroadcast: j['lastBroadcast'] == null ? null : _eventFromJson(j['lastBroadcast']),
        recognizedTxids: _strings(j['recognizedTxids']),
        incidents: [for (final i in _list(j['incidents'])) SafetyIncident.fromJson(_obj(i))],
        cautionWalletIds: Set<int>.from(_list(j['cautionWalletIds'])),
        watchOnlyVerifications: _walletMap(j['watchOnlyVerifications'], (v) => WatchOnlyVerification.fromJson(_obj(v))),
        passphraseVerifiedAt: _walletMap(j['passphraseVerifiedAt'], _date),
        bsms: _walletMap(j['bsms'], (v) => BsmsVerification.fromJson(_obj(v))),
        bsmsExports: _walletMap(
          j['bsmsExports'],
          (v) => (configHash: _obj(v)['configHash'] as String, at: _date(_obj(v)['at'])),
        ),
        recommendedDoneAt: {for (final e in _obj(j['recommendedDoneAt'] ?? const {}).entries) e.key: _date(e.value)},
        metadataExport: j['metadataExport'] == null ? null : _exportFromJson(_obj(j['metadataExport'])),
        incomingWatch: _walletMap(
          j['incomingWatch'],
          (v) => {
            for (final e in _obj(v).entries)
              e.key: (
                seenAt: _date(_obj(e.value)['seenAt']),
                strikes: _obj(e.value)['strikes'] as int,
                lastStrikeAt: _dateOrNull(_obj(e.value)['lastStrikeAt']),
                paidAddresses: _strings(_obj(e.value)['paidAddresses']),
              ),
          },
        ),
        conflicts: [for (final c in _list(j['conflicts'])) _eventFromJson(c)],
        rescue: _walletMap(
          j['rescue'],
          (v) => (
            destination: RescueDestination.fromJson(_obj(_obj(v)['destination'])),
            draft: _obj(v)['draft'] == null ? null : RescueDraftSummary.fromJson(_obj(_obj(v)['draft'])),
          ),
        ),
        lastSuccessfulSyncAt: _dateOrNull(j['lastSuccessfulSyncAt']),
        serverCert: j['serverCert'] == null ? null : ServerCertRecord.fromJson(_obj(j['serverCert'])),
        hintDismissed: j['hintDismissed'] as bool? ?? false,
        readItemIds: _strings(j['readItemIds']),
      );
    } catch (_) {
      return SafetyState.initial();
    }
  }

  @override
  List<Object?> get props => [
    baselines,
    appTxidPrefixes,
    lastBroadcast,
    recognizedTxids,
    incidents,
    cautionWalletIds,
    watchOnlyVerifications,
    passphraseVerifiedAt,
    bsms,
    bsmsExports,
    recommendedDoneAt,
    metadataExport,
    // 레코드의 ==는 Set을 내용으로 비교하지 않아 목록으로 바꿔 비교한다
    incomingWatch.map(
      (walletId, watch) => MapEntry(
        walletId,
        watch.map((txid, w) => MapEntry(txid, [w.seenAt, w.strikes, w.lastStrikeAt, w.paidAddresses])),
      ),
    ),
    conflicts,
    rescue,
    lastSuccessfulSyncAt,
    serverCert,
    hintDismissed,
    readItemIds,
  ];
}

Map<String, Object?> _byWallet<V>(Map<int, V> map, Object? Function(V) toJson) =>
    map.map((walletId, v) => MapEntry('$walletId', toJson(v)));

Map<int, V> _walletMap<V>(Object? json, V Function(Object?) fromJson) => {
  for (final e in _obj(json ?? const {}).entries) int.parse(e.key): fromJson(e.value),
};

Map<String, Object?> _eventToJson(WalletTxEvent e) => {
  'walletId': e.walletId,
  'txid': e.txid,
  'at': e.at.toIso8601String(),
};

WalletTxEvent _eventFromJson(Object? json) {
  final j = _obj(json);
  return (walletId: j['walletId'] as int, txid: j['txid'] as String, at: _date(j['at']));
}

({DateTime at, int tagCount, int memoCount}) _exportFromJson(Map<String, Object?> j) => (
  at: _date(j['at']),
  tagCount: j['tagCount'] as int,
  memoCount: j['memoCount'] as int,
);

Map<String, Object?> _obj(Object? json) => Map<String, Object?>.from(json as Map);

List<Object?> _list(Object? json) => (json ?? const []) as List<Object?>;

Set<String> _strings(Object? json) => Set<String>.from(_list(json));

DateTime _date(Object? json) => DateTime.parse(json as String);

DateTime? _dateOrNull(Object? json) => json == null ? null : _date(json);
