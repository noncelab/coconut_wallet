import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class TransactionDetailViewModel extends ChangeNotifier {
  final int _walletId;
  final String _txHash;
  final TransactionProvider _txModel;

  AddressBook? _addressBook;
  int? _currentBlockHeight;

  final ValueNotifier<bool> _showDialogNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _loadCompletedNotifier = ValueNotifier(false);

  TransactionDetailViewModel(this._walletId, this._txHash, this._txModel);

  AddressBook? get addressBook => _addressBook;
  int? get currentBlockHeight => _currentBlockHeight;

  TransactionProvider get txModel => _txModel;
  Transfer? get transaction => _txModel.transaction;
  bool get canSeeMoreInputs => _txModel.canSeeMoreInputs;
  bool get canSeeMoreOutputs => _txModel.canSeeMoreOutputs;
  int get inputCountToShow => _txModel.inputCountToShow;
  int get outputCountToShow => _txModel.outputCountToShow;

  ValueNotifier<bool> get showDialogNotifier => _showDialogNotifier;
  ValueNotifier<bool> get loadCompletedNotifier => _loadCompletedNotifier;

  void updateProvider(WalletProvider walletModel) {
    if (walletModel.walletItemList.isNotEmpty && _addressBook == null) {
      _addressBook =
          walletModel.getWalletById(_walletId).walletBase.addressBook;
      _setCurrentBlockHeight(walletModel);
      _txModel.initTransaction(_walletId, _txHash);
      if (_txModel.initViewMoreButtons() == false) {
        _showDialogNotifier.value = true;
      }
    }
    notifyListeners();
  }

  void _setCurrentBlockHeight(WalletProvider walletProvider) async {
    _currentBlockHeight = await walletProvider.getCurrentBlockHeight();
    notifyListeners();
  }
}
