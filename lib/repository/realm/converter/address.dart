import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

WalletAddress mapRealmToWalletAddress(RealmWalletAddress e) {
  return WalletAddress(e.address, e.derivationPath, e.index, e.isUsed,
      e.confirmed, e.unconfirmed, e.total);
}
