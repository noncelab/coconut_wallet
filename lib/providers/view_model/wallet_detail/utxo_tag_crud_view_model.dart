import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:flutter/material.dart';

class UtxoTagCrudViewModel extends ChangeNotifier {
  late final UtxoTagProvider _tagProvider;
  late final int _walletId;

  List<UtxoTag> _utxoTagList = [];
  List<UtxoTag> get utxoTagList => _utxoTagList;

  UtxoTag? _selectedUtxoTag;
  UtxoTag? get selectedUtxoTag => _selectedUtxoTag;

  String? _updatedTagName;
  String? get updatedTagName => _updatedTagName;

  // todo 컬러 인덱스

  UtxoTagCrudViewModel(this._tagProvider, this._walletId) {
    _init();
    _setUtxoTagList();
  }

  void _init() {
    _selectedUtxoTag = null;
    _updatedTagName = null;
  }

  void _setUtxoTagList() {
    _utxoTagList = List.from(_tagProvider.getUtxoTagList(_walletId));
  }

  bool addUtxoTag(UtxoTag utxoTag) {
    final result = _tagProvider.addUtxoTag(_walletId, utxoTag);
    _setUtxoTagList();
    notifyListeners();
    return result;
  }

  bool updateUtxoTag(UtxoTag updatedUtxoTag) {
    if (_selectedUtxoTag == null) return false;
    final result = _tagProvider.updateUtxoTag(_walletId, updatedUtxoTag);
    _selectedUtxoTag = null;
    _setUtxoTagList();
    notifyListeners();
    return result;
  }

  bool deleteUtxoTag() {
    if (_selectedUtxoTag == null) return false;
    final result = _tagProvider.deleteUtxoTag(_walletId, _selectedUtxoTag!);
    _selectedUtxoTag = null;
    _setUtxoTagList();
    notifyListeners();
    return result;
  }

  void toggleUtxoTag(UtxoTag? utxoTag) {
    debugPrint('selectUtxoTag: $utxoTag');
    if (_selectedUtxoTag == utxoTag) {
      _selectedUtxoTag = null;
    } else {
      _selectedUtxoTag = utxoTag;
    }
    notifyListeners();
  }

  void deselectUtxoTag() {
    _selectedUtxoTag = null;
    notifyListeners();
  }
}
