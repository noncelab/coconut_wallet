import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

int getWalletAddressId({required int walletId, required int index, required String address}) {
  return Object.hash(walletId, index, address);
}

WalletAddress mapRealmToWalletAddress(RealmWalletAddress realmAddress) {
  return WalletAddress(
      realmAddress.address,
      realmAddress.derivationPath,
      realmAddress.index,
      realmAddress.isChange,
      realmAddress.isUsed,
      realmAddress.confirmed,
      realmAddress.unconfirmed,
      realmAddress.total);
}

RealmWalletAddress mapWalletAddressToRealm(int walletId, WalletAddress walletAddress) {
  return RealmWalletAddress(
    getWalletAddressId(
        walletId: walletId, index: walletAddress.index, address: walletAddress.address),
    walletId,
    walletAddress.address,
    walletAddress.index,
    walletAddress.isChange,
    walletAddress.derivationPath,
    walletAddress.isUsed,
    walletAddress.confirmed,
    walletAddress.unconfirmed,
    walletAddress.total,
  );
}
