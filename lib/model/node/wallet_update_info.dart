import 'package:coconut_wallet/enums/network_enums.dart';

/// 갱신된 데이터 정보를 담는 클래스
class WalletUpdateInfo {
  final int walletId;
  UpdateTypeState balance;
  UpdateTypeState utxo;
  UpdateTypeState transaction;

  WalletUpdateInfo(this.walletId,
      {this.balance = UpdateTypeState.completed,
      this.transaction = UpdateTypeState.completed,
      this.utxo = UpdateTypeState.completed});

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
      {UpdateTypeState? balance,
      UpdateTypeState? transaction,
      UpdateTypeState? utxo}) {
    return WalletUpdateInfo(existingInfo.walletId,
        balance: balance ?? existingInfo.balance,
        transaction: transaction ?? existingInfo.transaction,
        utxo: utxo ?? existingInfo.utxo);
  }
}
