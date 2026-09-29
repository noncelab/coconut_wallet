import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/cupertino.dart';

class WalletInfoEditViewModel extends ChangeNotifier {
  final int _walletId;
  final WalletProvider _walletProvider;

  late String _walletName;
  late int _iconIndex;
  late int _colorIndex;
  late String _walletDescriptor;

  bool _isProcessing = false;
  bool _isNameDuplicated = false;
  bool _isSameAsCurrentName = false;
  bool _isInputEmpty = true;
  bool _isPaletteChanged = false;

  WalletInfoEditViewModel(this._walletId, this._walletProvider) {
    final walletItemBase = _walletProvider.getWalletById(_walletId);
    _walletName = walletItemBase.name;
    _walletDescriptor = walletItemBase.descriptor;

    try {
      final dynamicWallet = walletItemBase as dynamic;
      _iconIndex = dynamicWallet.iconIndex ?? 0;
      _colorIndex = dynamicWallet.colorIndex ?? 0;
    } catch (_) {
      _iconIndex = 0;
      _colorIndex = 0;
    }
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
      final resolvedName = _walletProvider.resolveWalletNameConflict(
        desiredName: trimmedName,
        descriptor: _walletDescriptor,
        isSingleSig: true,
        excludeWalletId: _walletId,
      );
      // 동일 주소의 Watch-only/핫월렛은 입력한 이름이 그대로 반환된다.
      // 다른 계정처럼 대체 이름이 필요한 경우에는 이름 변경 화면에서 자동 변경하지 않고 충돌로 안내한다.
      _isNameDuplicated = resolvedName != trimmedName;
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
