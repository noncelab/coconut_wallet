import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/repository/converter/transaction.dart';
import 'package:coconut_wallet/repository/wallet_data_manager.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/cupertino.dart';

class TransactionProvider extends ChangeNotifier {
  static const int kReceiveInputCount = 3;
  static const int kNotReceiveInputCount = 5;
  static const int kReceiveOutputCount = 4;
  static const int kNotReceiveOutputCount = 2;
  static const int kViewMoreCount = 5;
  static const int kInputMaxCount = 3;
  static const int kOutputMaxCount = 2;
  final WalletDataManager _walletDataManager = WalletDataManager();

  Transfer? _transaction;
  List<TransferDTO> _txList = [];

  bool _canSeeMoreInputs = false;
  bool _canSeeMoreOutputs = false;

  int _inputCountToShow = kViewMoreCount;
  int _outputCountToShow = kViewMoreCount;

  int _utxoInputMaxCount = kInputMaxCount;
  int _utxoOutputMaxCount = kOutputMaxCount;

  Transfer? get transaction => _transaction;
  List<TransferDTO> get txList => _txList;

  bool get canSeeMoreInputs => _canSeeMoreInputs;
  bool get canSeeMoreOutputs => _canSeeMoreOutputs;

  int get inputCountToShow => _inputCountToShow;
  int get outputCountToShow => _outputCountToShow;

  int get utxoInputMaxCount => _utxoInputMaxCount;
  int get utxoOutputMaxCount => _utxoOutputMaxCount;

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

  void initTxList(int walletId) {
    _txList = _walletDataManager.getTxList(walletId) ?? [];
  }

  void initUtxoInOutputList() {
    if (_transaction == null) return;

    _utxoInputMaxCount = _transaction!.inputAddressList.length <= kInputMaxCount
        ? _transaction!.inputAddressList.length
        : kInputMaxCount;
    _utxoOutputMaxCount =
        _transaction!.outputAddressList.length <= kOutputMaxCount
            ? _transaction!.outputAddressList.length
            : kOutputMaxCount;
    if (_transaction!.inputAddressList.length <= utxoInputMaxCount) {
      _utxoInputMaxCount = _transaction!.inputAddressList.length;
    }
    if (_transaction!.outputAddressList.length <= utxoOutputMaxCount) {
      _utxoOutputMaxCount = _transaction!.outputAddressList.length;
    }
  }

  bool initViewMoreButtons() {
    if (_transaction == null) {
      return false;
    }

    final status = TransactionUtil.getStatus(_transaction!);

    final isSending = [
      TransactionStatus.sending,
      TransactionStatus.sent,
      TransactionStatus.self,
      TransactionStatus.selfsending,
    ].contains(status);

    int initialInputMaxCount =
        isSending ? kNotReceiveInputCount : kReceiveInputCount;
    int initialOutputMaxCount =
        isSending ? kNotReceiveOutputCount : kReceiveOutputCount;

    if (_transaction!.inputAddressList.length <= initialInputMaxCount) {
      _canSeeMoreInputs = false;
      _inputCountToShow = _transaction!.inputAddressList.length;
    } else {
      _canSeeMoreInputs = true;
      _inputCountToShow = initialInputMaxCount;
    }
    if (_transaction!.outputAddressList.length <= initialOutputMaxCount) {
      _canSeeMoreOutputs = false;
      _outputCountToShow = _transaction!.outputAddressList.length;
    } else {
      _canSeeMoreOutputs = true;
      _outputCountToShow = initialOutputMaxCount;
    }
    return true;
  }

  void viewMoreInput() {
    if (_transaction == null) return;

    _inputCountToShow = (_inputCountToShow + kViewMoreCount)
        .clamp(0, _transaction!.inputAddressList.length);
    if (_inputCountToShow == _transaction!.inputAddressList.length) {
      _canSeeMoreInputs = false;
    }
    notifyListeners();
  }

  void viewMoreOutput() {
    if (_transaction == null) return;

    _outputCountToShow = (_outputCountToShow + kViewMoreCount)
        .clamp(0, _transaction!.outputAddressList.length);
    if (_outputCountToShow == _transaction!.outputAddressList.length) {
      _canSeeMoreOutputs = false;
    }

    notifyListeners();
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

  TransferDTO? _loadTransaction(int walletId, String txHash) {
    final result = _walletDataManager.loadTransaction(walletId, txHash);
    if (result.isError) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('loadTransaction(id: $walletId, _utxoId: $txHash)');
      Logger.log(result.error);
    }
    return result.data;
  }

  void resetData() {
    _transaction = null;
    _txList.clear();
  }
}
