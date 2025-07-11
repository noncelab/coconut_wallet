import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/cupertino.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _transactionRepository;

  TransactionRecord? _transaction;
  List<TransactionRecord> _txList = [];

  TransactionRecord? get transaction => _transaction;
  List<TransactionRecord> get txList => _txList;

  TransactionProvider(this._transactionRepository);

  void initTransaction(int walletId, String txHash, {String? utxoTo}) {
    final tx = _transactionRepository.getTransactionRecord(walletId, txHash);

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

  TransactionRecord? getTransaction(int walletId, String txHash, {String? utxoTo}) {
    final tx = _transactionRepository.getTransactionRecord(walletId, txHash);

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
    _txList = _transactionRepository.getTransactionRecordList(walletId);
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  bool updateTransactionMemo(int walletId, String txHash, String memo) {
    final result = _transactionRepository.updateTransactionMemo(walletId, txHash, memo);
    if (result.isSuccess) {
      _transaction = _transactionRepository.getTransactionRecord(walletId, txHash);
      if (_transaction != null) {
        List<TransactionRecord> newTxList = _txList.map((tx) {
          if (tx.transactionHash == _transaction!.transactionHash) {
            return _transaction!;
          }
          return tx;
        }).toList();
        _txList = newTxList;
      }
      notifyListeners();
      return true;
    } else {
      Logger.log('-----------------------------------------------------------');
      Logger.log('updateTransactionMemo(walletId: $walletId, txHash: $txHash, memo: $memo)');
      Logger.log(result.error);
    }
    return false;
  }

  TransactionRecord? getTransactionRecord(int walletId, String txHash) {
    return _transactionRepository.getTransactionRecord(walletId, txHash);
  }

  bool hasTransactionConfirmed(int walletId, String txHash) {
    return _transactionRepository.hasTransactionConfirmed(walletId, txHash);
  }

  void resetData() {
    _transaction = null;
    _txList.clear();
  }

  Future<void> updateTransaction(int walletId, String txHash, TransactionRecord updatedTx) async {
    _transaction = updatedTx;

    await _transactionRepository.updateTransactionRecord(walletId, txHash, updatedTx);

    initTxList(walletId);
  }
}
