import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:flutter/material.dart';

class UtxoDetailViewModel extends ChangeNotifier {
  final int _walletId;
  final UtxoState _utxo;

  final UtxoTagProvider _tagProvider;
  final TransactionProvider _txProvider;

  List<String> _dateString = [];

  UtxoDetailViewModel(
      this._walletId, this._utxo, this._tagProvider, this._txProvider) {
    _dateString = DateTimeUtil.formatTimeStamp(_utxo.timestamp);
    _tagProvider.initTagList(_walletId, utxoId: _utxo.utxoId);
    _txProvider.initTransaction(_walletId, _utxo.transactionHash,
        utxoTo: _utxo.to);
    _txProvider.initUtxoInOutputList();
  }

  UtxoTagProvider? get tagProvider => _tagProvider;
  List<UtxoTag> get selectedTagList => _tagProvider.selectedTagList;
  List<UtxoTag> get tagList => _tagProvider.tagList;

  TransactionRecord? get transaction => _txProvider.transaction;
  int get utxoInputMaxCount => _txProvider.utxoInputMaxCount;
  int get utxoOutputMaxCount => _txProvider.utxoOutputMaxCount;

  List<String> get dateString => _dateString;
}
