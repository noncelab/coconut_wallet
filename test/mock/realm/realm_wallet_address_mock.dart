import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

class RealmWalletAddressMock {
  static RealmWalletAddress getUsedMock({
    int id = 1,
    int walletId = 1,
    String address = 'address1',
    int index = 0,
    bool isChange = false,
    String derivationPath = 'm/0/0',
    bool isUsed = true,
    int confirmed = 1000,
    int unconfirmed = 500,
    int total = 1500,
  }) {
    return RealmWalletAddress(
      id,
      walletId,
      address,
      index,
      isChange,
      derivationPath,
      isUsed,
      confirmed,
      unconfirmed,
      total,
    );
  }

  static RealmWalletAddress getUnusedMock({
    int id = 1,
    int walletId = 1,
    String address = 'address1',
    int index = 0,
    bool isChange = false,
    String derivationPath = 'm/0/0',
    bool isUsed = false,
    int confirmed = 0,
    int unconfirmed = 0,
    int total = 0,
  }) {
    return RealmWalletAddress(
      id,
      walletId,
      address,
      index,
      isChange,
      derivationPath,
      isUsed,
      confirmed,
      unconfirmed,
      total,
    );
  }
}
