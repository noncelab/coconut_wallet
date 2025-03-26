import 'dart:convert';

import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';

// TransactionRecord -> _RealmTransaction 변환 함수
RealmTransaction mapTransactionToRealmTransaction(
    TransactionRecord transaction, int walletId, int id) {
  return RealmTransaction(
    id,
    transaction.transactionHash,
    walletId,
    transaction.timestamp,
    transaction.blockHeight,
    transaction.transactionType,
    transaction.amount,
    transaction.fee,
    transaction.vSize,
    transaction.createdAt,
    memo: transaction.memo,
    inputAddressList: transaction.inputAddressList
        .map((address) => jsonEncode(addressToJson(address)))
        .toList(),
    outputAddressList: transaction.outputAddressList
        .map((address) => jsonEncode(addressToJson(address)))
        .toList(),
  );
}

// note(트랜잭션 메모) 정보가 추가로 필요하여 TransactionDto를 반환
TransactionRecord mapRealmTransactionToTransaction(
    RealmTransaction realmTransaction,
    {List<RealmRbfHistory>? realmRbfHistoryList,
    RealmCpfpHistory? realmCpfpHistory}) {
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
      realmTransaction.createdAt,
      rbfHistoryList: realmRbfHistoryList
          ?.map((element) => RbfHistory(
                feeRate: element.feeRate,
                timestamp: element.timestamp,
                transactionHash: element.transactionHash,
              ))
          .toList(),
      cpfpHistory: realmCpfpHistory != null
          ? CpfpHistory(
              originalFee: realmCpfpHistory.originalFee,
              newFee: realmCpfpHistory.newFee,
              timestamp: realmCpfpHistory.timestamp,
              parentTransactionHash: realmCpfpHistory.parentTransactionHash,
              childTransactionHash: realmCpfpHistory.childTransactionHash,
            )
          : null);
}

Map<String, dynamic> addressToJson(TransactionAddress address) {
  return {'address': address.address, 'amount': address.amount};
}

TransactionAddress jsonToAddress(Map<String, dynamic> json) {
  return TransactionAddress(json['address'], json['amount']);
}

RealmCpfpHistory mapCpfpHistoryToRealmCpfpHistory(CpfpHistoryDto cpfpHistory) {
  return RealmCpfpHistory(
    cpfpHistory.id,
    cpfpHistory.walletId,
    cpfpHistory.parentTransactionHash,
    cpfpHistory.childTransactionHash,
    cpfpHistory.originalFee,
    cpfpHistory.newFee,
    cpfpHistory.timestamp,
  );
}

RealmRbfHistory mapRbfHistoryToRealmRbfHistory(
    RbfHistoryDto rbfHistory, int order) {
  return RealmRbfHistory(
    rbfHistory.id,
    rbfHistory.walletId,
    rbfHistory.originalTransactionHash,
    rbfHistory.transactionHash,
    order,
    rbfHistory.feeRate,
    rbfHistory.timestamp,
  );
}
