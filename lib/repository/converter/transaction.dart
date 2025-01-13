import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_data.dart';

// Transfer -> _RealmTransaction 변환 함수
RealmTransaction mapTransferToRealmTransaction(Transfer transfer,
    RealmWalletBase realmWalletBase, int id, DateTime? createdAt) {
  return RealmTransaction(id, transfer.transactionHash,
      walletBase: realmWalletBase,
      timestamp: transfer.timestamp,
      blockHeight: transfer.blockHeight,
      transferType: transfer.transferType,
      memo: transfer.memo,
      amount: transfer.amount,
      fee: transfer.fee,
      inputAddressList: transfer.inputAddressList
          .map((address) => jsonEncode(addressToJson(address)))
          .toList(),
      outputAddressList: transfer.outputAddressList
          .map((address) => jsonEncode(addressToJson(address)))
          .toList(),
      createdAt: createdAt);
}

// note(트랜잭션 메모) 정보가 추가로 필요하여 TransferDTO를 반환
TransferDTO mapRealmTransactionToTransfer(RealmTransaction realmTransaction) {
  return TransferDTO(
      realmTransaction.transactionHash,
      realmTransaction.timestamp,
      realmTransaction.blockHeight,
      realmTransaction.transferType,
      realmTransaction.memo,
      realmTransaction.amount,
      realmTransaction.fee,
      realmTransaction.inputAddressList
          .map((element) => jsonToAddress(jsonDecode(element)))
          .toList(),
      realmTransaction.outputAddressList
          .map((element) => jsonToAddress(jsonDecode(element)))
          .toList(),
      realmTransaction.note,
      realmTransaction.createdAt);
}

Map<String, dynamic> addressToJson(Address address) {
  return {
    'address': address.address,
    'derivationPath': address.derivationPath,
    'amount': address.amount
  };
}

Address jsonToAddress(Map<String, dynamic> json) {
  /// index와 isUsed는 사용하지 않습니다.
  return Address(
      json['address'], json['derivationPath'], 0, false, json['amount']);
}

class TransferDTO extends Transfer {
  String? note;
  DateTime? createdAt;

  TransferDTO(
      super.transactionHash,
      super.timestamp,
      super.blockHeight,
      super.transferType,
      super.memo,
      super.amount,
      super.fee,
      super.inputAddressList,
      super.outputAddressList,
      this.note,
      this.createdAt);

  DateTime? getDateTimeToDisplay() {
    if (blockHeight != null && blockHeight == 0 && createdAt != null) {
      return createdAt;
    }

    return timestamp;
  }
}
