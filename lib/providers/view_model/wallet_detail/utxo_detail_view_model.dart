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

  final UtxoTagProvider _tagModel;
  final TransactionProvider _txModel;

  List<String> _dateString = [];

  UtxoDetailViewModel(
      this._walletId, this._utxo, this._tagModel, this._txModel) {
    _dateString = DateTimeUtil.formatDatetime(_utxo.timestamp).split('|');
    _tagModel.initTagList(_walletId, utxoId: _utxo.utxoId);
    _txModel.initTransaction(_walletId, _utxo.txHash, utxoTo: _utxo.to);
    _txModel.initUtxoInOutputList();
  }

  UtxoTagProvider? get tagModel => _tagModel;
  List<UtxoTag> get selectedTagList => _tagModel.selectedTagList;
  List<UtxoTag> get tagList => _tagModel.tagList;

  Transfer? get transaction => _txModel.transaction;
  int get utxoInputMaxCount => _txModel.utxoInputMaxCount;
  int get utxoOutputMaxCount => _txModel.utxoOutputMaxCount;

  List<String> get dateString => _dateString;
}
