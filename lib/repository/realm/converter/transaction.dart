import 'dart:convert';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/cpfp_history.dart';
import 'package:coconut_wallet/model/node/rbf_history.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';

// TransactionRecord -> _RealmTransaction 변환 함수
RealmTransaction mapTransactionToRealmTransaction(
    TransactionRecord transaction, int walletId, int id) {
  return RealmTransaction(
    id,
    transaction.transactionHash,
    walletId,
    transaction.timestamp,
    transaction.blockHeight,
    transaction.transactionType.name,
    transaction.amount,
    transaction.fee,
    transaction.vSize,
    transaction.createdAt,
    inputAddressList:
        transaction.inputAddressList.map((address) => jsonEncode(addressToJson(address))).toList(),
    outputAddressList:
        transaction.outputAddressList.map((address) => jsonEncode(addressToJson(address))).toList(),
  );
}

// note(트랜잭션 메모) 정보가 추가로 필요하여 TransactionDto를 반환
TransactionRecord mapRealmTransactionToTransaction(RealmTransaction realmTransaction,
    {List<RealmRbfHistory>? realmRbfHistoryList,
    RealmCpfpHistory? realmCpfpHistory,
    String? memo}) {
  return TransactionRecord(
      realmTransaction.transactionHash,
      realmTransaction.timestamp,
      realmTransaction.blockHeight,
      TransactionTypeExtension.fromString(realmTransaction.transactionType),
      memo,
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
          ?.map((realmRbfHistory) => RbfHistory(
                feeRate: realmRbfHistory.feeRate,
                timestamp: realmRbfHistory.timestamp,
                transactionHash: realmRbfHistory.transactionHash,
                walletId: realmRbfHistory.walletId,
                originalTransactionHash: realmRbfHistory.originalTransactionHash,
              ))
          .toList(),
      cpfpHistory: realmCpfpHistory != null
          ? CpfpHistory(
              originalFee: realmCpfpHistory.originalFee,
              newFee: realmCpfpHistory.newFee,
              timestamp: realmCpfpHistory.timestamp,
              parentTransactionHash: realmCpfpHistory.parentTransactionHash,
              childTransactionHash: realmCpfpHistory.childTransactionHash,
              walletId: realmCpfpHistory.walletId,
            )
          : null);
}

Map<String, dynamic> addressToJson(TransactionAddress address) {
  return {'address': address.address, 'amount': address.amount};
}

TransactionAddress jsonToAddress(Map<String, dynamic> json) {
  return TransactionAddress(json['address'], json['amount']);
}

RealmCpfpHistory mapCpfpHistoryToRealmCpfpHistory(CpfpHistory cpfpHistory) {
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

RealmRbfHistory mapRbfHistoryToRealmRbfHistory(RbfHistory rbfHistory) {
  return RealmRbfHistory(
    rbfHistory.id,
    rbfHistory.walletId,
    rbfHistory.originalTransactionHash,
    rbfHistory.transactionHash,
    rbfHistory.feeRate,
    rbfHistory.timestamp,
  );
}

RealmTransactionMemo generateRealmTransactionMemo(
    String transactionHash, int walletId, String memo) {
  return RealmTransactionMemo(
    getTransactionMemoId(transactionHash, walletId),
    transactionHash,
    walletId,
    memo,
    DateTime.now(),
  );
}
