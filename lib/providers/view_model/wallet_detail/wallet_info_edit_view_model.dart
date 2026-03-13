import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/cupertino.dart';

class WalletInfoEditViewModel extends ChangeNotifier {
  final int _walletId;
  final WalletProvider _walletProvider;

  late String _walletName;
  late int _iconIndex;
  late int _colorIndex;
  late List<WalletListItemBase> _walletList;

  bool _isProcessing = false;
  bool _isNameDuplicated = false;
  bool _isSameAsCurrentName = false;
  bool _isInputEmpty = true;
  bool _isPaletteChanged = false;

  WalletInfoEditViewModel(this._walletId, this._walletProvider) {
    final walletItemBase = _walletProvider.getWalletById(_walletId);
    _walletName = walletItemBase.name;

    try {
      final dynamicWallet = walletItemBase as dynamic;
      _iconIndex = dynamicWallet.iconIndex ?? 0;
      _colorIndex = dynamicWallet.colorIndex ?? 0;
    } catch (_) {
      _iconIndex = 0;
      _colorIndex = 0;
    }

    _walletList = _walletProvider.walletItemList;
  }

  String get walletName => _walletName;
  int get iconIndex => _iconIndex;
  int get colorIndex => _colorIndex;

  bool get canUpdateName =>
      !_isInputEmpty && !_isNameDuplicated && !_isProcessing && (!_isSameAsCurrentName || _isPaletteChanged);

  bool get isProcessing => _isProcessing;
  bool get isNameDuplicated => _isNameDuplicated;
  bool get isSameAsCurrentName => _isSameAsCurrentName;
  bool get isInputEmpty => _isInputEmpty;

  void checkValidity(String inputName, {int? selectedIconIndex, int? selectedColorIndex}) {
    final trimmedName = inputName.trim();
    _isInputEmpty = trimmedName.isEmpty;

    if (selectedIconIndex != null && selectedColorIndex != null) {
      _isPaletteChanged = (_iconIndex != selectedIconIndex) || (_colorIndex != selectedColorIndex);
    }

    _isSameAsCurrentName = (_walletName == trimmedName);

    if (_isSameAsCurrentName) {
      _isNameDuplicated = false;
    } else {
      _isNameDuplicated = _walletList.any((wallet) => wallet.name == trimmedName);
    }

    notifyListeners();
  }

  void checkNameValidity(String input) => checkValidity(input);

  Future<void> changeWalletInfo(String input, int iconIndex, int colorIndex, VoidCallback onProcessFinished) async {
    if (_isProcessing) return;

    _isProcessing = true;
    notifyListeners();

    final newName = input.trim();

    try {
      if (_walletName != newName) {
        await _walletProvider.updateWalletName(_walletId, newName);
      }

      if (_isPaletteChanged) {
        await _walletProvider.updateWalletPalette(_walletId, iconIndex, colorIndex);
      }
    } catch (e) {
      debugPrint('Update Wallet Info Error: $e');
    } finally {
      _isProcessing = false;

      final updatedWallet = _walletProvider.getWalletById(_walletId);
      if (updatedWallet.name == newName) {
        onProcessFinished();
      }

      notifyListeners();
    }
  }
}
