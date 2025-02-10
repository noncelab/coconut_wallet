import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/utxo/utxo.dart' as model;
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:flutter/material.dart';

class UtxoDetailViewModel extends ChangeNotifier {
  final int _walletId;
  final model.UTXO _utxo;

  final UtxoTagProvider _tagProvider;
  final TransactionProvider _txProvider;

  late final List<String>? _dateString;

  UtxoDetailViewModel(
      this._walletId, this._utxo, this._tagProvider, this._txProvider) {
    _tagProvider.initTagList(_walletId, utxoId: _utxo.utxoId);
    _txProvider.initTransaction(_walletId, _utxo.txHash, utxoTo: _utxo.to);
    _txProvider.initUtxoInOutputList();
    final blockHeight = _txProvider.transaction?.blockHeight;
    _dateString = (blockHeight != null && blockHeight > 0)
        ? DateTimeUtil.formatDatetime(_utxo.timestamp).split('|')
        : null;
  }

  UtxoTagProvider? get tagProvider => _tagProvider;
  List<UtxoTag> get selectedTagList => _tagProvider.selectedTagList;
  List<UtxoTag> get tagList => _tagProvider.tagList;

  Transfer? get transaction => _txProvider.transaction;
  int get utxoInputMaxCount => _txProvider.utxoInputMaxCount;
  int get utxoOutputMaxCount => _txProvider.utxoOutputMaxCount;

  List<String>? get dateString => _dateString;
}
