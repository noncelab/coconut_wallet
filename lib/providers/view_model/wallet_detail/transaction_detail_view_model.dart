import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

class TransactionDetailViewModel extends ChangeNotifier {
  final int _walletId;
  final String _txHash;

  TransactionProvider? _txModel;

  AddressBook? _addressBook;

  int? _currentBlockHeight;
  bool _canSeeMoreInputs = false;

  bool _canSeeMoreOutputs = false;
  int _inputCountToShow = 5;

  int _outputCountToShow = 5;
  final ValueNotifier<bool> _showDialogNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _loadCompletedNotifier = ValueNotifier(false);

  TransactionDetailViewModel(this._walletId, this._txHash);

  TransactionProvider? get txModel => _txModel;

  AddressBook? get addressBook => _addressBook;

  bool get canSeeMoreInputs => _canSeeMoreInputs;
  bool get canSeeMoreOutputs => _canSeeMoreOutputs;

  int? get currentBlockHeight => _currentBlockHeight;
  int get inputCountToShow => _inputCountToShow;

  int get itemsToShowOutput => _outputCountToShow;
  ValueNotifier<bool> get showDialogNotifier => _showDialogNotifier;
  ValueNotifier<bool> get loadCompletedNotifier => _loadCompletedNotifier;

  Transfer? get transaction => _txModel?.transaction;

  bool updateTransactionMemo(String memo) {
    return _txModel?.updateTransactionMemo(_walletId, _txHash, memo) ?? false;
  }

  void updateProvider(
      WalletProvider walletModel, TransactionProvider txModel) async {
    if (walletModel.walletItemList.isNotEmpty && _addressBook == null) {
      _addressBook =
          walletModel.getWalletById(_walletId).walletBase.addressBook;
      await _setCurrentBlockHeight(walletModel);
      _txModel = txModel;
      txModel.initTransaction(_walletId, _txHash);
      _initSeeMoreButtons();
      _loadCompletedNotifier.value = true;
    }
  }

  void viewMoreInput() {
    if (txModel?.transaction == null) return;

    _inputCountToShow = (_inputCountToShow + 5)
        .clamp(0, txModel!.transaction!.inputAddressList.length);
    if (_inputCountToShow == txModel!.transaction!.inputAddressList.length) {
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
    if (txModel?.transaction == null) {
      _showDialogNotifier.value = true;
      notifyListeners();
      _showDialogNotifier.value = false;
      return;
    }

    final status = TransactionUtil.getStatus(txModel!.transaction!);

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

    if (txModel!.transaction!.inputAddressList.length <= initialInputMaxCount) {
      _canSeeMoreInputs = false;
      _inputCountToShow = txModel!.transaction!.inputAddressList.length;
    } else {
      _canSeeMoreInputs = true;
      _inputCountToShow = initialInputMaxCount;
    }
    if (txModel!.transaction!.outputAddressList.length <=
        initialOutputMaxCount) {
      _canSeeMoreOutputs = false;
      _outputCountToShow = txModel!.transaction!.outputAddressList.length;
    } else {
      _canSeeMoreOutputs = true;
      _outputCountToShow = initialOutputMaxCount;
    }
    notifyListeners();
  }

  Future<void> _setCurrentBlockHeight(WalletProvider walletProvider) async {
    _currentBlockHeight = await walletProvider.getCurrentBlockHeight();
    notifyListeners();
  }
}
