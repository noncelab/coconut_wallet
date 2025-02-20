import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:flutter/material.dart';

class TransactionDetailViewModel extends ChangeNotifier {
  final int _walletId;
  final String _txHash;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final TransactionProvider _txProvider;

  BlockTimestamp? _currentBlock;

  final ValueNotifier<bool> _showDialogNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _loadCompletedNotifier = ValueNotifier(false);

  TransactionDetailViewModel(this._walletId, this._txHash, this._walletProvider,
      this._txProvider, this._nodeProvider);

  BlockTimestamp? get currentBlock => _currentBlock;

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

  WalletProvider get walletProvider => _walletProvider;

  void updateProvider() {
    if (_walletProvider.walletItemList.isNotEmpty) {
      _setCurrentBlockHeight();
      _txProvider.initTransaction(_walletId, _txHash);
      if (_txProvider.initViewMoreButtons() == false) {
        _showDialogNotifier.value = true;
      }
    }
    notifyListeners();
  }

  void _setCurrentBlockHeight() async {
    final result = await _nodeProvider.getLatestBlock();

    if (result.isSuccess) {
      _currentBlock = result.value;
      notifyListeners();
    }
  }
}
