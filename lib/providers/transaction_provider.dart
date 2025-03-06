import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/repository/realm/wallet_data_manager.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/cupertino.dart';

class TransactionProvider extends ChangeNotifier {
  final WalletDataManager _walletDataManager = WalletDataManager();

  TransactionRecord? _transaction;
  List<TransactionRecord> _txList = [];

  TransactionRecord? get transaction => _transaction;
  List<TransactionRecord> get txList => _txList;

  void initTransaction(int walletId, String txHash, {String? utxoTo}) {
    final tx = _loadTransaction(walletId, txHash);

    if (utxoTo != null && tx != null) {
      if (tx.outputAddressList.isNotEmpty) {
        tx.outputAddressList.sort((a, b) {
          if (a.address == utxoTo) return -1;
          if (b.address == utxoTo) return 1;
          return 0;
        });
      }
    }

    _transaction = tx;
  }

  TransactionRecord? getTransaction(int walletId, String txHash,
      {String? utxoTo}) {
    final tx = _loadTransaction(walletId, txHash);
    if (utxoTo != null && tx != null) {
      if (tx.outputAddressList.isNotEmpty) {
        tx.outputAddressList.sort((a, b) {
          if (a.address == utxoTo) return -1;
          if (b.address == utxoTo) return 1;
          return 0;
        });
      }
    }

    return tx;
  }

  void initTxList(int walletId) {
    _txList = _walletDataManager.getTransactionRecordList(walletId);
  }

  bool updateTransactionMemo(int walletId, String txHash, String memo) {
    final result =
        _walletDataManager.updateTransactionMemo(walletId, txHash, memo);
    if (result.isSuccess) {
      _transaction = _loadTransaction(walletId, txHash);
      notifyListeners();
      return true;
    } else {
      Logger.log('-----------------------------------------------------------');
      Logger.log(
          'updateTransactionMemo(walletId: $walletId, txHash: $txHash, memo: $memo)');
      Logger.log(result.error);
    }
    return false;
  }

  TransactionRecord? _loadTransaction(int walletId, String txHash) {
    final result = _walletDataManager.loadTransaction(walletId, txHash);
    if (result.isFailure) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('loadTransaction(id: $walletId, _utxoId: $txHash)');
      Logger.log(result.error);
    }
    return result.value;
  }

  void resetData() {
    _transaction = null;
    _txList.clear();
  }
}
