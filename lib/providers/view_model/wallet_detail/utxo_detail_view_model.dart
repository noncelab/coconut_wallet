import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:flutter/material.dart';

class UtxoDetailViewModel extends ChangeNotifier {
  static const int kInputMaxCount = 3;
  static const int kOutputMaxCount = 2;

  late final int _walletId;
  late final String _utxoId;
  late UtxoState _utxo;
  late final UtxoTagProvider _tagProvider;
  late final TransactionProvider _txProvider;
  late final WalletProvider _walletProvider;

  List<UtxoTag> _utxoTagList = [];
  List<UtxoTag> _selectedUtxoTagList = [];
  late final List<String> _dateString;
  late final TransactionRecord? _transaction;

  int _utxoInputMaxCount = 0;
  int _utxoOutputMaxCount = 0;

  UtxoDetailViewModel(
    this._walletId,
    this._utxo,
    this._tagProvider,
    this._txProvider,
    this._walletProvider,
  ) {
    _utxoId = _utxo.utxoId;
    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);
    _selectedUtxoTagList = _tagProvider.getUtxoTagsByUtxoId(_walletId, _utxoId);

    _transaction = _txProvider.getTransaction(_walletId, _utxo.transactionHash);
    _dateString = DateTimeUtil.formatTimestamp(_transaction!.timestamp);

    _initUtxoInOutputList();
    _walletProvider.addWalletUpdateListener(_walletId, _onWalletUpdate);
  }

  void _onWalletUpdate(WalletUpdateInfo info) {
    final updatedUtxo = _walletProvider.getUtxoState(_walletId, _utxoId);
    if (updatedUtxo != null) {
      _utxo = updatedUtxo;
      notifyListeners();
    }
  }

  UtxoStatus _setUtxoStateToggled() {
    if (_utxo.status == UtxoStatus.locked) {
      return UtxoStatus.unspent;
    } else if (_utxo.status == UtxoStatus.unspent) {
      return UtxoStatus.locked;
    }
    return _utxo.status;
  }

  Future<bool> toggleUtxoLockStatus() async {
    try {
      await _walletProvider.toggleUtxoLockStatus(_walletId, _utxo.utxoId);
    } catch (e) {
      Logger.error('❌ toggleUtxoLockStatus error: $e');
      return false;
    }

    _utxo.status = _setUtxoStateToggled();
    notifyListeners();
    return true;
  }

  List<String> get dateString => _dateString;
  List<UtxoTag> get selectedUtxoTagList => _selectedUtxoTagList;
  UtxoTagProvider? get tagProvider => _tagProvider;

  TransactionRecord? get transaction => _transaction;
  int get utxoInputMaxCount => _utxoInputMaxCount;
  int get utxoOutputMaxCount => _utxoOutputMaxCount;
  List<UtxoTag> get utxoTagList => _utxoTagList;
  UtxoStatus get utxoStatus => _utxo.status;

  String getInputAddress(int index) => TransactionUtil.getInputAddress(_transaction, index);
  int getInputAmount(int index) => TransactionUtil.getInputAmount(_transaction, index);
  String getOutputAddress(int index) => TransactionUtil.getOutputAddress(_transaction, index);
  int getOutputAmount(int index) => TransactionUtil.getOutputAmount(_transaction, index);

  void updateUtxoTags(String utxoId, List<String> selectedTagNames, List<UtxoTag> newTags) {
    _tagProvider.updateUtxoTagList(
        walletId: _walletId, utxoId: utxoId, newTags: newTags, selectedTagNames: selectedTagNames);

    _utxoTagList = _tagProvider.getUtxoTagList(_walletId);
    _selectedUtxoTagList = _tagProvider.getUtxoTagsByUtxoId(_walletId, utxoId);
    notifyListeners();
  }

  void _initUtxoInOutputList() {
    if (_transaction == null) return;

    _utxoInputMaxCount = _transaction.inputAddressList.length <= kInputMaxCount
        ? _transaction.inputAddressList.length
        : kInputMaxCount;
    _utxoOutputMaxCount = _transaction.outputAddressList.length <= kOutputMaxCount
        ? _transaction.outputAddressList.length
        : kOutputMaxCount;
    if (_transaction.inputAddressList.length <= utxoInputMaxCount) {
      _utxoInputMaxCount = _transaction.inputAddressList.length;
    }
    if (_transaction.outputAddressList.length <= utxoOutputMaxCount) {
      _utxoOutputMaxCount = _transaction.outputAddressList.length;
    }
  }

  @override
  void dispose() {
    _walletProvider.removeWalletUpdateListener(_walletId, _onWalletUpdate);
    super.dispose();
  }
}
