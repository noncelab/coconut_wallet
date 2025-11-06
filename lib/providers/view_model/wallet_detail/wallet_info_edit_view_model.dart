import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/cupertino.dart';

class WalletInfoEditViewModel extends ChangeNotifier {
  final int _walletId;
  final WalletProvider _walletProvider;

  late String _walletName;
  late List<WalletListItemBase> _walletList;
  bool _isProcessing = false;
  bool _isNameDuplicated = false;
  bool _isSameAsCurrentName = false;
  bool _isInputEmpty = true;

  WalletInfoEditViewModel(this._walletId, this._walletProvider) {
    final walletItemBase = _walletProvider.getWalletById(_walletId);
    _walletName = walletItemBase.name;
    _walletList = _walletProvider.walletItemList;
  }

  String get walletName => _walletName;
  bool get canUpdateName =>
      _walletName.isNotEmpty && !_isNameDuplicated && !_isSameAsCurrentName && !_isProcessing && !_isInputEmpty;
  bool get isProcessing => _isProcessing;
  bool get isNameDuplicated => _isNameDuplicated;
  bool get isSameAsCurrentName => _isSameAsCurrentName;
  bool get isInputEmpty => _isInputEmpty;

  void checkNameValidity(String input) {
    _isInputEmpty = input.trim().isEmpty;
    if (_walletName == input.trim()) {
      _isSameAsCurrentName = true;
      notifyListeners();
      return;
    }
    _isSameAsCurrentName = false;

    for (var walletItem in _walletList) {
      if (walletItem.name == input.trim()) {
        _isNameDuplicated = true;
        notifyListeners();
        return;
      }
    }

    _isNameDuplicated = false;
    notifyListeners();
  }

  void changeWalletName(String input, VoidCallback onProcessFinished) async {
    _isProcessing = true;
    notifyListeners();

    try {
      await _walletProvider.updateWalletName(_walletId, input.trim());
    } catch (e) {
      debugPrint(e.toString());
      _isProcessing = false;
    } finally {
      final index = _walletProvider.walletItemList.indexWhere((element) => element.id == _walletId);
      if (_walletProvider.walletItemList[index].name == input.trim()) {
        onProcessFinished();
      }
      notifyListeners();
    }
  }
}
