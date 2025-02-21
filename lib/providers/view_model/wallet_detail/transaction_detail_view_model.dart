import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

class TransactionDetailViewModel extends ChangeNotifier {
  static const int kReceiveInputCount = 3;
  static const int kNotReceiveInputCount = 5;
  static const int kReceiveOutputCount = 4;
  static const int kNotReceiveOutputCount = 2;
  static const int kViewMoreCount = 5;
  static const int kInputMaxCount = 3;
  static const int kOutputMaxCount = 2;

  final int _walletId;
  final String _txHash;
  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final TransactionProvider _txProvider;

  BlockTimestamp? _currentBlock;

  final ValueNotifier<bool> _showDialogNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _loadCompletedNotifier = ValueNotifier(false);

  bool _canSeeMoreInputs = false;
  bool _canSeeMoreOutputs = false;

  int _inputCountToShow = 0;
  int _outputCountToShow = 0;

  TransactionRecord? _transaction;
  TransactionRecord? get transaction => _transaction;

  TransactionDetailViewModel(this._walletId, this._txHash, this._walletProvider,
      this._txProvider, this._nodeProvider) {
    _transaction = _txProvider.getTransaction(_walletId, _txHash);
    _initViewMoreButtons();
  }

  bool get canSeeMoreInputs => _canSeeMoreInputs;
  bool get canSeeMoreOutputs => _canSeeMoreOutputs;
  int get inputCountToShow => _inputCountToShow;
  int get outputCountToShow => _outputCountToShow;
  BlockTimestamp? get currentBlock => _currentBlock;

  ValueNotifier<bool> get loadCompletedNotifier => _loadCompletedNotifier;
  ValueNotifier<bool> get showDialogNotifier => _showDialogNotifier;

  DateTime? get timestamp {
    final blockHeight = _txProvider.transaction?.blockHeight;
    return (blockHeight != null && blockHeight > 0)
        ? _txProvider.transaction!.timestamp
        : null;
  }

  void init() {
    _canSeeMoreInputs = false;
    _canSeeMoreOutputs = false;
    _inputCountToShow = 0;
    _outputCountToShow = 0;
  }

  bool isSameAddress(String address) {
    return _walletProvider.containsAddress(_walletId, address);
  }

  void onTapViewMoreInputs() {
    // ignore: no_leading_underscores_for_local_identifiers
    if (_transaction == null) return;

    _inputCountToShow = (_inputCountToShow + kViewMoreCount)
        .clamp(0, _transaction!.inputAddressList.length);
    if (_inputCountToShow == _transaction!.inputAddressList.length) {
      _canSeeMoreInputs = false;
    }
    notifyListeners();
  }

  void onTapViewMoreOutputs() {
    if (_transaction == null) return;

    _outputCountToShow = (_outputCountToShow + kViewMoreCount)
        .clamp(0, _transaction!.outputAddressList.length);
    if (_outputCountToShow == _transaction!.outputAddressList.length) {
      _canSeeMoreOutputs = false;
    }
    notifyListeners();
  }

  void updateProvider() {
    // TODO: addressBook
    // if (_walletProvider.walletItemList.isNotEmpty && _addressBook == null) {
    if (_walletProvider.walletItemList.isNotEmpty) {
      // _addressBook =
      //     _walletProvider.getWalletById(_walletId).walletBase.addressBook;
      _setCurrentBlockHeight();
      _txProvider.initTransaction(_walletId, _txHash);

      if (_initViewMoreButtons() == false) {
        _showDialogNotifier.value = true;
      }
    }
    notifyListeners();
  }

  bool updateTransactionMemo(String memo) {
    return _txProvider.updateTransactionMemo(_walletId, _txHash, memo);
  }

  bool _initViewMoreButtons() {
    if (_transaction == null) {
      _canSeeMoreInputs = false;
      _canSeeMoreOutputs = false;
      _inputCountToShow = 0;
      _outputCountToShow = 0;
      notifyListeners();
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

    notifyListeners();
    return true;
  }

  void _setCurrentBlockHeight() async {
    final result = await _nodeProvider.getLatestBlock();

    if (result.isSuccess) {
      _currentBlock = result.value;
      notifyListeners();
    }
  }

  String getInputAddress(int index) =>
      TransactionUtil.getInputAddress(_transaction, index);

  String getOutputAddress(int index) =>
      TransactionUtil.getOutputAddress(_transaction, index);

  int getInputAmount(int index) =>
      TransactionUtil.getInputAmount(_transaction, index);

  int getOutputAmount(int index) =>
      TransactionUtil.getOutputAmount(_transaction, index);
}
