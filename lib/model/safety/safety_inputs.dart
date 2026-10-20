import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';

/// 엔진이 보는 거래 한 건. blockHeight 0 = 미확정, timestamp = 블록 시각(미확정이면 처음 본 시각),
/// [ownReceiveOutputs] = 이 거래가 지급한 내 받기 주소
typedef SafetyTx =
    ({
      String txid,
      TransactionType type,
      int blockHeight,
      int amount,
      DateTime timestamp,
      DateTime createdAt,
      Set<String> ownReceiveOutputs,
    });

enum AppUpdateStatus { unknown, upToDate, available }

enum MultisigConfigStatus { complete, incomplete, mismatch }

class ServerCertObservation {
  const ServerCertObservation({
    required this.applicable,
    this.pinned,
    this.actual,
    this.endValidity,
    required this.caValid,
  });

  /// 사용자 서버 + 고정 지문일 때만 true
  final bool applicable;
  final String? pinned, actual;
  final DateTime? endValidity;
  final bool caValid;
}

/// 지갑 하나의 점검 재료. Realm·Flutter 타입 없이 수집기가 채운다.
class SafetyWalletSnapshot {
  const SafetyWalletSnapshot({
    required this.id,
    required this.kind,
    required this.balanceSats,
    required this.isSettled,
    this.lastResyncAt,
    required this.txs,
    required this.pendingSpentByTxids,
    required this.trackedTxStates,
    required this.backupVerified,
    required this.passphraseOnSigning,
    required this.hasMfp,
    required this.descriptorHash,
    this.multisigConfig,
    required this.reusedAddressesWithUtxo,
    required this.unlockedDustUtxoIds,
    required this.hasReceiveHistory,
    required this.hasUtxoHistory,
  });

  final int id;
  final SafetyWalletKind kind;

  /// 확정 + 대기
  final int balanceSats;

  /// 구독 완료 + 동기화 중 아님
  final bool isSettled;
  final DateTime? lastResyncAt;

  /// 대체된 거래는 빠진 목록. 단 대체 표시가 남은 채 확정된 원거래는 포함(확정으로)
  final List<SafetyTx> txs;

  /// 나가는 중(outgoing) UTXO의 spentByTransactionHash
  final Set<String> pendingSpentByTxids;

  /// [txs]에 없는 사건 거래의 상태(replaced | dropped, 남은 기록이 확정이면 confirmed)
  final Map<String, IncidentTxState> trackedTxStates;
  final bool backupVerified, passphraseOnSigning, hasMfp;
  final String descriptorHash;

  /// 다중서명만
  final MultisigConfigStatus? multisigConfig;

  /// 서로 다른 거래로 2번 이상 받았고 지금 UTXO가 남은 받기 주소
  final List<String> reusedAddressesWithUtxo;

  /// 잠기지 않은 더스트 의심 UTXO id
  final List<String> unlockedDustUtxoIds;
  final bool hasReceiveHistory, hasUtxoHistory;
}

/// `SafetyEngine.evaluate`·`IncidentDetector.detect`의 입력 전부. Premium 여부는 없다(SPEC §7.2).
class SafetyInputs {
  const SafetyInputs({
    required this.now,
    required this.wallets,
    required this.state,
    required this.appLockEnabled,
    required this.appUpdate,
    this.serverCert,
    required this.isConnected,
    required this.currentBlockHeight,
    required this.labelTagCount,
    required this.labelMemoCount,
  });

  final DateTime now;
  final List<SafetyWalletSnapshot> wallets;
  final SafetyState state;
  final bool appLockEnabled;
  final AppUpdateStatus appUpdate;
  final ServerCertObservation? serverCert;
  final bool isConnected;

  /// 첫 블록 조회 전엔 0
  final int currentBlockHeight;
  final int labelTagCount, labelMemoCount;

  /// 감지 결과를 적용한 상태로 다시 평가할 때
  SafetyInputs withState(SafetyState state) => SafetyInputs(
    now: now,
    wallets: wallets,
    state: state,
    appLockEnabled: appLockEnabled,
    appUpdate: appUpdate,
    serverCert: serverCert,
    isConnected: isConnected,
    currentBlockHeight: currentBlockHeight,
    labelTagCount: labelTagCount,
    labelMemoCount: labelMemoCount,
  );
}
