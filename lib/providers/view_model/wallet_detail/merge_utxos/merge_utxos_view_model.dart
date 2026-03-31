import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:flutter/material.dart';

class MergeUtxosViewModel extends ChangeNotifier {
  final int walletId;
  final UtxoRepository _utxoRepository;

  MergeUtxosViewModel(this.walletId, this._utxoRepository);

  int _utxoCount = 0;
  int get utxoCount => _utxoCount;

  void initialize() {
    final utxoList = _utxoRepository.getUtxoStateList(walletId);
    _utxoCount = utxoList.where((utxo) => utxo.status == UtxoStatus.unspent).length;
    notifyListeners();
  }
}
