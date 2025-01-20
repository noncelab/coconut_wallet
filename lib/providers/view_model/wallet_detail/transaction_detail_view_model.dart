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

  WalletProvider? _walletProvider;

  AddressBook? _addressBook;
  AddressBook? get addressBook => _addressBook;

  Transfer? _transaction;
  Transfer? get transaction => _transaction;

  int? _currentBlockHeight;
  int? get currentBlockHeight => _currentBlockHeight;

  bool _canSeeMoreInputs = false;
  bool get canSeeMoreInputs => _canSeeMoreInputs;

  bool _canSeeMoreOutputs = false;
  bool get canSeeMoreOutputs => _canSeeMoreOutputs;

  int _itemsToShowInput = 5;
  int get itemsToShowInput => _itemsToShowInput;

  int _itemsToShowOutput = 5;
  int get itemsToShowOutput => _itemsToShowOutput;

  final ValueNotifier<bool> _showDialogNotifier = ValueNotifier(false);
  ValueNotifier<bool> get showDialogNotifier => _showDialogNotifier;

  TransactionDetailViewModel(
      this._walletId, this._txHash, this._walletDataManager);

  void updateWalletProvider(WalletProvider walletProvider) {
    _walletProvider ??= walletProvider;
    _addressBook ??=
        walletProvider.getWalletById(_walletId).walletBase.addressBook;
    _transaction ??= loadTransaction();
    _initSeeMoreButtons();
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
      _itemsToShowInput = _transaction!.inputAddressList.length;
    } else {
      _canSeeMoreInputs = true;
      _itemsToShowInput = initialInputMaxCount;
    }
    if (_transaction!.outputAddressList.length <= initialOutputMaxCount) {
      _canSeeMoreOutputs = false;
      _itemsToShowOutput = _transaction!.outputAddressList.length;
    } else {
      _canSeeMoreOutputs = true;
      _itemsToShowOutput = initialOutputMaxCount;
    }
    notifyListeners();
  }

  Future<void> setCurrentBlockHeight() async {
    _currentBlockHeight = await _walletProvider?.getCurrentBlockHeight();
    notifyListeners();
  }

  TransferDTO? loadTransaction() {
    final result = _walletDataManager.loadTransaction(_walletId, _txHash);
    if (result.isError) {
      Logger.log('-----------------------------------------------------------');
      Logger.log('loadTransaction(id: $_walletId, txHash: $_txHash)');
      Logger.log(result.error);
    }
    return result.data;
  }

  bool updateTransactionMemo(String memo) {
    final result =
        _walletDataManager.updateTransactionMemo(_walletId, _txHash, memo);
    if (result.isSuccess) {
      _transaction = loadTransaction();
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

  // TODO: 로직 확인
  void viewMoreOutput() {
    if (transaction == null) return;

    _itemsToShowOutput = (_itemsToShowOutput + 5)
        .clamp(0, transaction!.outputAddressList.length);
    if (itemsToShowOutput == transaction!.outputAddressList.length) {
      _canSeeMoreOutputs = false;
    }
    notifyListeners();
  }

  void viewMoreInput() {
    if (transaction == null) return;

    _itemsToShowInput =
        (_itemsToShowInput + 5).clamp(0, _transaction!.inputAddressList.length);
    if (_itemsToShowInput == _transaction!.inputAddressList.length) {
      _canSeeMoreInputs = false;
    }
    notifyListeners();
  }
}
