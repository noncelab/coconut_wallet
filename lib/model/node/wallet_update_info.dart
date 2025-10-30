import 'package:coconut_wallet/enums/network_enums.dart';

/// 갱신된 데이터 정보를 담는 클래스
class WalletUpdateInfo {
  final int walletId;
  WalletSyncState subscription;
  WalletSyncState balance;
  WalletSyncState utxo;
  WalletSyncState transaction;

  WalletUpdateInfo(
    this.walletId, {
    this.subscription = WalletSyncState.waiting,
    this.balance = WalletSyncState.waiting,
    this.transaction = WalletSyncState.waiting,
    this.utxo = WalletSyncState.waiting,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletUpdateInfo &&
          walletId == other.walletId &&
          subscription == other.subscription &&
          balance == other.balance &&
          utxo == other.utxo &&
          transaction == other.transaction;

  @override
  int get hashCode => Object.hash(walletId, subscription, balance, utxo, transaction);

  factory WalletUpdateInfo.fromExisting(
    WalletUpdateInfo existingInfo, {
    WalletSyncState? subscription,
    WalletSyncState? balance,
    WalletSyncState? transaction,
    WalletSyncState? utxo,
  }) {
    return WalletUpdateInfo(
      existingInfo.walletId,
      subscription: subscription ?? existingInfo.subscription,
      balance: balance ?? existingInfo.balance,
      transaction: transaction ?? existingInfo.transaction,
      utxo: utxo ?? existingInfo.utxo,
    );
  }
}
