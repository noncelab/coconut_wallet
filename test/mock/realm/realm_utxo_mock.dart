import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

class RealmUtxoMock {
  static RealmUtxo getMock({
    String id = 'utxo1',
    int walletId = 1,
    String address = 'address1',
    int amount = 1000,
    DateTime? timestamp,
    String transactionHash = 'hash1',
    int index = 0,
    String derivationPath = 'm/0/0',
    int blockHeight = 700000,
    String status = 'unspent',
  }) {
    return RealmUtxo(
      id,
      walletId,
      address,
      amount,
      timestamp ?? DateTime.now(),
      transactionHash,
      index,
      derivationPath,
      blockHeight,
      status,
    );
  }
}
