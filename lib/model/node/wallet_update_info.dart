import 'package:coconut_wallet/enums/network_enums.dart';

/// 갱신된 데이터 정보를 담는 클래스
class WalletUpdateInfo {
  final int walletId;
  UpdateStatus balance;
  UpdateStatus utxo;
  UpdateStatus transaction;

  // 동시성 제어를 위한 카운터 추가
  int balanceCounter;
  int utxoCounter;
  int transactionCounter;

  WalletUpdateInfo(this.walletId,
      {this.balance = UpdateStatus.waiting,
      this.transaction = UpdateStatus.waiting,
      this.utxo = UpdateStatus.waiting,
      this.balanceCounter = 0,
      this.utxoCounter = 0,
      this.transactionCounter = 0});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletUpdateInfo &&
          walletId == other.walletId &&
          balance == other.balance &&
          utxo == other.utxo &&
          transaction == other.transaction;

  @override
  int get hashCode => Object.hash(walletId, balance, utxo, transaction);

  factory WalletUpdateInfo.fromExisting(WalletUpdateInfo existingInfo,
      {UpdateStatus? balance,
      UpdateStatus? transaction,
      UpdateStatus? utxo,
      int? balanceCounter,
      int? utxoCounter,
      int? transactionCounter}) {
    return WalletUpdateInfo(existingInfo.walletId,
        balance: balance ?? existingInfo.balance,
        transaction: transaction ?? existingInfo.transaction,
        utxo: utxo ?? existingInfo.utxo,
        balanceCounter: balanceCounter ?? existingInfo.balanceCounter,
        utxoCounter: utxoCounter ?? existingInfo.utxoCounter,
        transactionCounter: transactionCounter ?? existingInfo.transactionCounter);
  }
}
