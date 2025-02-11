import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class TransactionDetailViewModel extends ChangeNotifier {
  final int _walletId;
  final String _txHash;
  final WalletProvider _walletProvider;
  final TransactionProvider _txProvider;

  int? _currentBlockHeight;

  final ValueNotifier<bool> _showDialogNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _loadCompletedNotifier = ValueNotifier(false);

  TransactionDetailViewModel(
      this._walletId, this._txHash, this._walletProvider, this._txProvider);

  int? get currentBlockHeight => _currentBlockHeight;

  TransactionProvider get txModel => _txProvider;
  TransactionRecord? get transaction => _txProvider.transaction;
  bool get canSeeMoreInputs => _txProvider.canSeeMoreInputs;
  bool get canSeeMoreOutputs => _txProvider.canSeeMoreOutputs;
  int get inputCountToShow => _txProvider.inputCountToShow;
  int get outputCountToShow => _txProvider.outputCountToShow;
  DateTime? get timestamp {
    final blockHeight = _txProvider.transaction?.blockHeight;
    return (blockHeight != null && blockHeight > 0)
        ? _txProvider.transaction!.timestamp
        : null;
  }

  ValueNotifier<bool> get showDialogNotifier => _showDialogNotifier;
  ValueNotifier<bool> get loadCompletedNotifier => _loadCompletedNotifier;

  void updateProvider() {
    // TODO: addressBook
    // if (_walletProvider.walletItemList.isNotEmpty && _addressBook == null) {
    if (_walletProvider.walletItemList.isNotEmpty) {
      // _addressBook =
      //     _walletProvider.getWalletById(_walletId).walletBase.addressBook;
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
