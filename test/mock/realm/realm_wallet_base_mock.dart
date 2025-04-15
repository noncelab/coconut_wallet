import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

class RealmWalletBaseMock {
  static RealmWalletBase getMock({
    int id = 1,
    int colorIndex = 0,
    int iconIndex = 0,
    String descriptor = 'descriptor',
    String name = 'Test Wallet',
    String walletType = 'single',
    int usedReceiveIndex = 5,
    int usedChangeIndex = 3,
  }) {
    return RealmWalletBase(id, colorIndex, iconIndex, descriptor, name, walletType,
        usedReceiveIndex: usedReceiveIndex, usedChangeIndex: usedChangeIndex);
  }
}
