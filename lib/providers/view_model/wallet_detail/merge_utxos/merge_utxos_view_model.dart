import 'package:coconut_wallet/enums/utxo_merge_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:flutter/material.dart';

class MergeUtxosViewModel extends ChangeNotifier {
  final int walletId;
  final UtxoRepository _utxoRepository;
  final UtxoTagProvider _utxoTagProvider;

  MergeUtxosViewModel(this.walletId, this._utxoRepository, this._utxoTagProvider);

  List<UtxoState> _utxoList = [];
  List<UtxoState> get utxoList => _utxoList;
  late UtxoMergeStep _currentStep;
  UtxoMergeStep get currentStep => _currentStep;

  int get utxoCount => _utxoList.length;

  void initialize() {
    final allUtxos = _utxoRepository.getUtxoStateList(walletId);
    _utxoList = allUtxos.where((utxo) => utxo.status == UtxoStatus.unspent).toList();
    _currentStep =
        utxoList.length >= 2 && utxoList.length < 11 ? UtxoMergeStep.entry : UtxoMergeStep.selectMergeCriteria;

    for (var utxo in _utxoList) {
      utxo.tags = _utxoTagProvider.getUtxoTagsByUtxoId(walletId, utxo.utxoId);
    }

    notifyListeners();
  }

  void setCurrentStep(UtxoMergeStep step) {
    _currentStep = step;
    notifyListeners();
  }

  bool get hasMergeableTaggedUtxos {
    final tagCounts = <String, int>{};
    for (final utxo in _utxoList) {
      final tags = utxo.tags;
      if (tags == null || tags.isEmpty) continue;

      final uniqueTagNames = tags.map((tag) => tag.name).toSet();
      for (final tagName in uniqueTagNames) {
        final count = (tagCounts[tagName] ?? 0) + 1;
        if (count >= 2) return true;
        tagCounts[tagName] = count;
      }
    }
    return false;
  }

  bool get hasSameAddressUtxos {
    final addressSet = <String>{};
    for (final utxo in _utxoList) {
      if (!addressSet.add(utxo.to)) return true;
    }
    return false;
  }
}
