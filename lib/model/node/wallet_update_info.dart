import 'package:coconut_wallet/enums/network_enums.dart';

/// 지갑 하나가 업데이트 중인지 판단 (지갑 상세·보내기 화면 공통 기준)
bool calculateWalletSyncing(WalletUpdateInfo? walletUpdateInfo, NodeSyncState nodeSyncState) {
  if (walletUpdateInfo?.balanceSnapshot != null && nodeSyncState != NodeSyncState.failed) {
    return walletUpdateInfo!.isSyncQueued;
  }
  if (nodeSyncState == NodeSyncState.completed || nodeSyncState == NodeSyncState.failed) {
    return false;
  }
  if (walletUpdateInfo == null) {
    return nodeSyncState == NodeSyncState.init || nodeSyncState == NodeSyncState.syncing;
  }
  return walletUpdateInfo.balance != WalletSyncState.completed ||
      walletUpdateInfo.transaction != WalletSyncState.completed;
}

/// 지갑 하나의 마지막 동기화가 성공으로 끝났는지: 노드에 연결돼 있고([isConnected]는 실패 상태가 아님도 본다),
/// 대기열이 없고 구독·잔액·거래·UTXO가 모두 완료. 실패하면 잔액 단계가 완료가 아니고 옛 잔액 스냅샷만 남으므로
/// 스냅샷이 있다고 성공으로 보지 않는다. 목표 합계가 같은 계정 지갑의 잔액을 믿을지 정할 때 쓴다(B1-a).
bool isWalletSyncSucceeded(WalletUpdateInfo? info, {required bool isConnected}) =>
    isConnected &&
    info != null &&
    !info.isSyncQueued &&
    info.subscription == WalletSyncState.completed &&
    info.balance == WalletSyncState.completed &&
    info.transaction == WalletSyncState.completed &&
    info.utxo == WalletSyncState.completed;

/// 갱신된 데이터 정보를 담는 클래스
class WalletUpdateInfo {
  final int walletId;
  WalletSyncState subscription;
  WalletSyncState balance;
  WalletSyncState utxo;
  WalletSyncState transaction;
  final bool isSyncQueued;

  /// 마지막으로 지갑의 동기화 대기열 전체를 처리한 잔액 (satoshi).
  final int? balanceSnapshot;

  WalletUpdateInfo(
    this.walletId, {
    this.subscription = WalletSyncState.waiting,
    this.balance = WalletSyncState.waiting,
    this.transaction = WalletSyncState.waiting,
    this.utxo = WalletSyncState.waiting,
    this.isSyncQueued = false,
    this.balanceSnapshot,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletUpdateInfo &&
          walletId == other.walletId &&
          subscription == other.subscription &&
          balance == other.balance &&
          utxo == other.utxo &&
          transaction == other.transaction &&
          isSyncQueued == other.isSyncQueued &&
          balanceSnapshot == other.balanceSnapshot;

  @override
  int get hashCode => Object.hash(walletId, subscription, balance, utxo, transaction, isSyncQueued, balanceSnapshot);

  factory WalletUpdateInfo.fromExisting(
    WalletUpdateInfo existingInfo, {
    WalletSyncState? subscription,
    WalletSyncState? balance,
    WalletSyncState? transaction,
    WalletSyncState? utxo,
    bool? isSyncQueued,
    int? balanceSnapshot,
  }) {
    return WalletUpdateInfo(
      existingInfo.walletId,
      subscription: subscription ?? existingInfo.subscription,
      balance: balance ?? existingInfo.balance,
      transaction: transaction ?? existingInfo.transaction,
      utxo: utxo ?? existingInfo.utxo,
      isSyncQueued: isSyncQueued ?? existingInfo.isSyncQueued,
      balanceSnapshot: balanceSnapshot ?? existingInfo.balanceSnapshot,
    );
  }
}
