import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

class RealmTransactionMock {
  static RealmTransaction getMock({
    int id = 1,
    String transactionHash = 'hash1',
    int walletId = 1,
    DateTime? timestamp,
    int blockHeight = 700000,
    String transactionType = 'send',
    int amount = 1000,
    int fee = 100,
    double feeRate = 1.0,
    double vSize = 200.0,
    DateTime? createdAt,
    List<String> inputAddressList = const ['input1'],
    List<String> outputAddressList = const ['output1'],
  }) {
    return RealmTransaction(
      id,
      transactionHash,
      walletId,
      timestamp ?? DateTime.now(),
      blockHeight,
      transactionType,
      amount,
      fee,
      vSize,
      createdAt ?? DateTime.now(),
      inputAddressList: inputAddressList,
      outputAddressList: outputAddressList,
    );
  }
}
