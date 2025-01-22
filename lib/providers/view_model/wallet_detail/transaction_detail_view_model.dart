import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/converter/transaction.dart';
import 'package:coconut_wallet/repository/wallet_data_manager.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

class TransactionDetailViewModel extends ChangeNotifier {
  final int _walletId;
  final String _txHash;
  final WalletDataManager _walletDataManager;

  AddressBook? _addressBook;
  Transfer? _transaction;

  int? _currentBlockHeight;
  bool _canSeeMoreInputs = false;

  bool _canSeeMoreOutputs = false;
  int _inputCountToShow = 5;

  int _outputCountToShow = 5;
  final ValueNotifier<bool> _showDialogNotifier = ValueNotifier(false);

  TransactionDetailViewModel(
      this._walletId, this._txHash, this._walletDataManager);
  AddressBook? get addressBook => _addressBook;

  bool get canSeeMoreInputs => _canSeeMoreInputs;
  bool get canSeeMoreOutputs => _canSeeMoreOutputs;

  int? get currentBlockHeight => _currentBlockHeight;
  int get inputCountToShow => _inputCountToShow;

  int get itemsToShowOutput => _outputCountToShow;
  ValueNotifier<bool> get showDialogNotifier => _showDialogNotifier;

  Transfer? get transaction => _transaction;

  bool updateTransactionMemo(String memo) {
    final result =
        _walletDataManager.updateTransactionMemo(_walletId, _txHash, memo);
    if (result.isSuccess) {
      _transaction = _loadTransaction();
      notifyListeners();
      return true;
    } else {
      Logger.log('-----------------------------------------------------------');
      Logger.log(
          'updateTransactionMemo(walletId: $_walletId, txHash: $_txHash, memo: $memo)');
      Logger.log(result.error);
    }
    return false;
  }

  void updateWalletProvider(WalletProvider walletProvider) {
    if (_addressBook == null && walletProvider.walletItemList.isNotEmpty) {
      _addressBook =
          walletProvider.getWalletById(_walletId).walletBase.addressBook;
      _transaction ??= _loadTransaction();
      _setCurrentBlockHeight(walletProvider);
      _initSeeMoreButtons();
    }
  }

  void viewMoreInput() {
    if (transaction == null) return;

    _inputCountToShow =
        (_inputCountToShow + 5).clamp(0, _transaction!.inputAddressList.length);
    if (_inputCountToShow == _transaction!.inputAddressList.length) {
      _canSeeMoreInputs = false;
    }
    notifyListeners();
  }

  void viewMoreOutput() {
    if (transaction == null) return;

    _outputCountToShow = (_outputCountToShow + 5)
        .clamp(0, transaction!.outputAddressList.length);
    if (itemsToShowOutput == transaction!.outputAddressList.length) {
      _canSeeMoreOutputs = false;
    }
    notifyListeners();
  }

  void _initSeeMoreButtons() {
    if (_transaction == null) {
      _showDialogNotifier.value = true;
      notifyListeners();
      _showDialogNotifier.value = false;
      return;
    }

    final status = TransactionUtil.getStatus(_transaction!);

    int initialInputMaxCount = (status == TransactionStatus.sending ||
            status == TransactionStatus.sent ||
            status == TransactionStatus.self ||
            status == TransactionStatus.selfsending)
        ? 5
        : 3;
    int initialOutputMaxCount = (status == TransactionStatus.sending ||
            status == TransactionStatus.sent ||
            status == TransactionStatus.self ||
            status == TransactionStatus.selfsending)
        ? 2
        : 4;

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
    notifyListeners();
  }

  TransferDTO? _loadTransaction() {
    final result = _walletDataManager.loadTransaction(_walletId, _txHash);
    if (result.isError) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('loadTransaction(id: $_walletId, txHash: $_txHash)');
      Logger.log(result.error);
    }
    return result.data;
  }

  Future<void> _setCurrentBlockHeight(WalletProvider walletProvider) async {
    _currentBlockHeight = await walletProvider.getCurrentBlockHeight();
    notifyListeners();
  }
}
