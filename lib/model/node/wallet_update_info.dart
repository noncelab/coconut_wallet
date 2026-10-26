import 'package:coconut_wallet/enums/network_enums.dart';

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
