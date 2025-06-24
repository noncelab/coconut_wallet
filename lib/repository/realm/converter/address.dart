import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';

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
    getWalletAddressId(walletId, walletAddress.index, walletAddress.address),
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
