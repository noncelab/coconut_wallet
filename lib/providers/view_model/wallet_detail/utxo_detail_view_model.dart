import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:flutter/material.dart';

class UtxoDetailViewModel extends ChangeNotifier {
  static const int kInputMaxCount = 3;
  static const int kOutputMaxCount = 2;

  late final int _walletId;
  late final String _utxoId;
  final UtxoState _utxo;

  final UtxoTagProvider _tagProvider;
  final TransactionProvider _txProvider;

  late final List<String>? _dateString;
  late final TransactionRecord? _transaction;

  int _utxoInputMaxCount = 0;
  int _utxoOutputMaxCount = 0;

  int get utxoInputMaxCount => _utxoInputMaxCount;
  int get utxoOutputMaxCount => _utxoOutputMaxCount;

  List<UtxoTag> get utxoTagsForSelectedUtxo =>
      _tagProvider.setUtxoTagsForSelectedUtxo(_walletId, _utxoId);

  UtxoDetailViewModel(
      this._walletId, this._utxo, this._tagProvider, this._txProvider) {
    _utxoId = _utxo.utxoId;

    _tagProvider.fetchUtxoTagsByWalletId(_walletId);
    // _tagProvider.setUtxoTagsForSelectedUtxo(_walletId, _utxo.utxoId);
    _transaction = _txProvider.getTransaction(_walletId, _utxo.transactionHash,
        utxoTo: _utxo.to);
    // _txProvider.initTransaction(_walletId, _utxo.transactionHash,
    //     utxoTo: _utxo.to);
    final blockHeight = _txProvider.transaction?.blockHeight;
    _dateString = (blockHeight != null && blockHeight > 0)
        ? DateTimeUtil.formatTimeStamp(_utxo.timestamp)
        : null;

    _initUtxoInOutputList();
  }

  UtxoTagProvider? get tagProvider => _tagProvider;
  List<UtxoTag> get selectedTagList => _tagProvider.utxoTagsForSelectedUtxo;
  List<UtxoTag> get tagList => _tagProvider.utxoTags;

  TransactionRecord? get transaction => _txProvider.transaction;

  List<String>? get dateString => _dateString;

  void _initUtxoInOutputList() {
    if (_transaction == null) return;

    _utxoInputMaxCount = _transaction.inputAddressList.length <= kInputMaxCount
        ? _transaction.inputAddressList.length
        : kInputMaxCount;
    _utxoOutputMaxCount =
        _transaction.outputAddressList.length <= kOutputMaxCount
            ? _transaction.outputAddressList.length
            : kOutputMaxCount;
    if (_transaction.inputAddressList.length <= utxoInputMaxCount) {
      _utxoInputMaxCount = _transaction.inputAddressList.length;
    }
    if (_transaction.outputAddressList.length <= utxoOutputMaxCount) {
      _utxoOutputMaxCount = _transaction.outputAddressList.length;
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
