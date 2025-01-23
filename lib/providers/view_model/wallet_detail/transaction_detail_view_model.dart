import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class TransactionDetailViewModel extends ChangeNotifier {
  final int _walletId;
  final String _txHash;

  AddressBook? _addressBook;
  int? _currentBlockHeight;

  TransactionProvider? _txModel;

  final ValueNotifier<bool> _showDialogNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _loadCompletedNotifier = ValueNotifier(false);

  TransactionDetailViewModel(this._walletId, this._txHash);

  AddressBook? get addressBook => _addressBook;
  int? get currentBlockHeight => _currentBlockHeight;

  TransactionProvider? get txModel => _txModel;
  Transfer? get transaction => _txModel?.transaction;
  bool get canSeeMoreInputs => _txModel?.canSeeMoreInputs ?? false;
  bool get canSeeMoreOutputs => _txModel?.canSeeMoreOutputs ?? false;
  int get inputCountToShow => _txModel?.inputCountToShow ?? 5;
  int get outputCountToShow => _txModel?.outputCountToShow ?? 5;

  ValueNotifier<bool> get showDialogNotifier => _showDialogNotifier;
  ValueNotifier<bool> get loadCompletedNotifier => _loadCompletedNotifier;

  void updateProvider(WalletProvider walletModel, TransactionProvider txModel) {
    // addressBook 설정 이후 txModel 변경 감지
    if (_addressBook != null) notifyListeners();

    if (walletModel.walletItemList.isNotEmpty && _addressBook == null) {
      _addressBook =
          walletModel.getWalletById(_walletId).walletBase.addressBook;
      _setCurrentBlockHeight(walletModel);
      _txModel = txModel;
      txModel.initTransaction(_walletId, _txHash);
      _initSeeMoreButtons();
    }
  }

  bool updateTransactionMemo(String memo) {
    return _txModel?.updateTransactionMemo(_walletId, _txHash, memo) ?? false;
  }

  void _initSeeMoreButtons() {
    if (_txModel?.initViewMoreButtons() == false) {
      _showDialogNotifier.value = true;
      notifyListeners();
    }
  }

  void _setCurrentBlockHeight(WalletProvider walletProvider) async {
    _currentBlockHeight = await walletProvider.getCurrentBlockHeight();
    notifyListeners();
  }
}
