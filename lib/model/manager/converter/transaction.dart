import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/manager/realm/model/coconut_wallet_data.dart';

// Transfer -> _RealmTransaction 변환 함수
RealmTransaction mapTransferToRealmTransaction(
    Transfer transfer, RealmWalletBase realmWalletBase, int id) {
  return RealmTransaction(id, transfer.transactionHash,
      walletBase: realmWalletBase,
      timestamp: transfer.timestamp,
      blockHeight: transfer.blockHeight,
      transferType: transfer.transferType,
      memo: transfer.memo,
      amount: transfer.amount,
      fee: transfer.fee,
      inputAddressList: transfer.inputAddressList,
      outputAddressList: transfer.outputAddressList);
}

Transfer mapRealmTransactionToTransfer(RealmTransaction realmTransaction) {
  return Transfer(
      realmTransaction.transactionHash,
      realmTransaction.timestamp,
      realmTransaction.blockHeight,
      realmTransaction.transferType,
      realmTransaction.memo,
      realmTransaction.amount,
      realmTransaction.fee,
      realmTransaction.inputAddressList.toList(),
      realmTransaction.outputAddressList.toList());
}
