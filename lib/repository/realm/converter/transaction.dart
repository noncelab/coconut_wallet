import 'dart:convert';

import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

// TransactionRecord -> _RealmTransaction 변환 함수
RealmTransaction mapTransactionToRealmTransaction(
    TransactionRecord transaction, int walletId, int id, DateTime? createdAt) {
  return RealmTransaction(
      id, transaction.transactionHash, walletId, transaction.vSize,
      timestamp: transaction.timestamp,
      blockHeight: transaction.blockHeight,
      transactionType: transaction.transactionType,
      memo: transaction.memo,
      amount: transaction.amount,
      fee: transaction.fee,
      inputAddressList: transaction.inputAddressList
          .map((address) => jsonEncode(addressToJson(address)))
          .toList(),
      outputAddressList: transaction.outputAddressList
          .map((address) => jsonEncode(addressToJson(address)))
          .toList(),
      createdAt: createdAt);
}

// note(트랜잭션 메모) 정보가 추가로 필요하여 TransactionDto를 반환
TransactionRecord mapRealmTransactionToTransaction(
    RealmTransaction realmTransaction) {
  return TransactionRecord(
      realmTransaction.transactionHash,
      realmTransaction.timestamp,
      realmTransaction.blockHeight,
      realmTransaction.transactionType,
      realmTransaction.memo,
      realmTransaction.amount,
      realmTransaction.fee,
      realmTransaction.inputAddressList
          .map((element) => jsonToAddress(jsonDecode(element)))
          .toList(),
      realmTransaction.outputAddressList
          .map((element) => jsonToAddress(jsonDecode(element)))
          .toList(),
      realmTransaction.vSize,
      realmTransaction.createdAt);
}

Map<String, dynamic> addressToJson(TransactionAddress address) {
  return {'address': address.address, 'amount': address.amount};
}

TransactionAddress jsonToAddress(Map<String, dynamic> json) {
  return TransactionAddress(json['address'], json['amount']);
}
