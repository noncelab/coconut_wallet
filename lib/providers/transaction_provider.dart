import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/repository/converter/transaction.dart';
import 'package:coconut_wallet/repository/wallet_data_manager.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/cupertino.dart';

class TransactionProvider extends ChangeNotifier {
  final WalletDataManager _walletDataManager = WalletDataManager();
  Transfer? _transaction;
  // List<TransferDTO>? _txList = [];

  Transfer? get transaction => _transaction;
  // List<TransferDTO>? get txList => _txList;

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
    notifyListeners();
  }

  // void initTxList(int walletId) {
  //   _txList = _walletDataManager.getTxList(walletId);
  //   notifyListeners();
  // }

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

  TransferDTO? _loadTransaction(int walletId, String txHash) {
    final result = _walletDataManager.loadTransaction(walletId, txHash);
    if (result.isError) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('loadTransaction(id: $walletId, _utxoId: $txHash)');
      Logger.log(result.error);
    }
    return result.data;
  }
}
