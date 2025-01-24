import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class TransactionDetailViewModel extends ChangeNotifier {
  final int _walletId;
  final String _txHash;
  final WalletProvider _walletProvider;
  final TransactionProvider _txProvider;

  AddressBook? _addressBook;
  int? _currentBlockHeight;

  final ValueNotifier<bool> _showDialogNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _loadCompletedNotifier = ValueNotifier(false);

  TransactionDetailViewModel(
      this._walletId, this._txHash, this._walletProvider, this._txProvider);

  AddressBook? get addressBook => _addressBook;
  int? get currentBlockHeight => _currentBlockHeight;

  TransactionProvider get txModel => _txProvider;
  Transfer? get transaction => _txProvider.transaction;
  bool get canSeeMoreInputs => _txProvider.canSeeMoreInputs;
  bool get canSeeMoreOutputs => _txProvider.canSeeMoreOutputs;
  int get inputCountToShow => _txProvider.inputCountToShow;
  int get outputCountToShow => _txProvider.outputCountToShow;

  ValueNotifier<bool> get showDialogNotifier => _showDialogNotifier;
  ValueNotifier<bool> get loadCompletedNotifier => _loadCompletedNotifier;

  void updateProvider() {
    if (_walletProvider.walletItemList.isNotEmpty && _addressBook == null) {
      _addressBook =
          _walletProvider.getWalletById(_walletId).walletBase.addressBook;
      _setCurrentBlockHeight(_walletProvider);
      _txProvider.initTransaction(_walletId, _txHash);
      if (_txProvider.initViewMoreButtons() == false) {
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
