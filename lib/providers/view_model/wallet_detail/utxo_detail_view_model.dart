import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app/utxo/utxo.dart' as model;
import 'package:coconut_wallet/model/app/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:flutter/material.dart';

class UtxoDetailViewModel extends ChangeNotifier {
  final int _walletId;
  final model.UTXO _utxo;

  UtxoTagProvider? _tagModel;
  TransactionProvider? _txModel;

  List<String> _dateString = [];

  int _initialInputMaxCount = 3;
  int _initialOutputMaxCount = 2;

  UtxoDetailViewModel(this._walletId, this._utxo) {
    _dateString = DateTimeUtil.formatDatetime(_utxo.timestamp).split('|');
  }

  UtxoTagProvider? get tagModel => _tagModel;

  List<String> get dateString => _dateString;
  int get initialInputMaxCount => _initialInputMaxCount;

  int get initialOutputMaxCount => _initialOutputMaxCount;

  Transfer? get transaction => _txModel?.transaction;

  List<UtxoTag> get selectedTagList => _tagModel?.selectedTagList ?? [];
  List<UtxoTag> get tagList => _tagModel?.tagList ?? [];

  void updateProvider(TransactionProvider txModel, UtxoTagProvider tagModel) {
    _txModel ??= txModel;
    txModel.initTransaction(_walletId, _utxo.txHash, utxoTo: _utxo.to);
    final tx = txModel.transaction;
    if (tx != null) {
      _initialInputMaxCount =
          tx.inputAddressList.length <= 3 ? tx.inputAddressList.length : 3;
      _initialOutputMaxCount =
          tx.outputAddressList.length <= 2 ? tx.outputAddressList.length : 2;
      if (tx.inputAddressList.length <= initialInputMaxCount) {
        _initialInputMaxCount = tx.inputAddressList.length;
      }
      if (tx.outputAddressList.length <= initialOutputMaxCount) {
        _initialOutputMaxCount = tx.outputAddressList.length;
      }
      notifyListeners();
    }

    _tagModel ??= tagModel;
    tagModel.initTagList(_walletId, utxoId: _utxo.utxoId);
  }
}
