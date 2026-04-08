import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:flutter/material.dart';

enum SplitCriteria {
  byAmount,
  evenly,
  manually;

  String getLabel(Translations t) {
    switch (this) {
      case SplitCriteria.byAmount:
        return t.split_utxo_screen.criteria_bottom_sheet.split_by_amount;
      case SplitCriteria.evenly:
        return t.split_utxo_screen.criteria_bottom_sheet.split_evenly;
      case SplitCriteria.manually:
        return t.split_utxo_screen.criteria_bottom_sheet.split_manually;
    }
  }
}

class SplitUtxoViewModel extends ChangeNotifier {
  final int walletId;
  final PreferenceProvider _preferenceProvider;

  List<UtxoState> _selectedUtxoList = [];
  SplitCriteria? _selectedCriteria;
  final TextEditingController amountController = TextEditingController();
  final FocusNode amountFocusNode = FocusNode();

  SplitUtxoViewModel(this.walletId, this._preferenceProvider) {
    amountController.addListener(() {
      notifyListeners();
    });
    amountFocusNode.addListener(() {
      notifyListeners();
    });
  }

  BitcoinUnit get currentUnit => _preferenceProvider.currentUnit;

  List<UtxoState> get selectedUtxoList => _selectedUtxoList;
  SplitCriteria? get selectedCriteria => _selectedCriteria;

  bool get hasAmountError {
    if (_selectedUtxoList.isEmpty) return false;
    final amount = _selectedUtxoList.first.amount;
    return amount >= 1000 && amount < 20000;
  }

  bool get hasAmountWarning {
    if (_selectedUtxoList.isEmpty) return false;
    final amount = _selectedUtxoList.first.amount;
    return amount >= 20000 && amount < 50000;
  }


  void setSelectedUtxoList(List<UtxoState> utxoList) {
    _selectedUtxoList = utxoList;

    if (_selectedUtxoList.isEmpty) {
      _selectedCriteria = null;
    }

    notifyListeners();
  }

  void setSelectedCriteria(SplitCriteria criteria) {
    _selectedCriteria = criteria;
    notifyListeners();
  }

  String getHeaderTitle(Translations t) {
    if (_selectedUtxoList.isEmpty) {
      return t.split_utxo_screen.question_select_utxo;
    }
    if (_selectedCriteria == null) {
      return t.split_utxo_screen.question_select_criteria;
    }

    switch (_selectedCriteria!) {
      case SplitCriteria.byAmount:
        return t.split_utxo_screen.question_split_by_amount;
      case SplitCriteria.evenly:
        return t.split_utxo_screen.question_split_evenly;
      case SplitCriteria.manually:
        return t.split_utxo_screen.question_select_criteria;
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    amountFocusNode.dispose();
    super.dispose();
  }
}
