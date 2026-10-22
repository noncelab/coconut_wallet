import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

class PickedPhoto {
  final Uint8List bytes;
  final String extension;

  const PickedPhoto(this.bytes, this.extension);
}

typedef PhotoPicker = Future<PickedPhoto?> Function();

class PhotoPickResult {
  final WalletPhotoBackground? photo;
  final bool failed;

  const PhotoPickResult.picked(WalletPhotoBackground this.photo) : failed = false;
  const PhotoPickResult.cancelled() : photo = null, failed = false;
  const PhotoPickResult.failed() : photo = null, failed = true;
}

enum WalletAppearanceTab { wallet, skins, colors, photos }

/// 지갑 카드 꾸미기 화면. 고른 값은 [save] 전까지 화면 안에서만 바뀐다.
class WalletAppearanceViewModel extends ChangeNotifier {
  static const int maxPhotoDimension = 1600;

  final int walletId;
  final WalletProvider _walletProvider;
  final PreferenceProvider _preferenceProvider;
  final WalletAppearanceProvider _appearanceProvider;
  final PhotoPicker _pickPhoto;

  late final WalletBackground? _initialBackground;
  late WalletBackground? _background;
  final List<WalletPhotoBackground> _importedPhotos = [];
  bool _isPickingPhoto = false;
  late final String _initialName;
  late final int _initialIconIndex;
  late final int _initialColorIndex;
  late String _name;
  late int _iconIndex;
  late int _colorIndex;
  bool _isNameDuplicated = false;
  WalletCardSize _previewSize = WalletCardSize.small;
  late WalletAppearanceTab _tab;
  bool _saved = false;

  WalletAppearanceViewModel(
    this.walletId,
    this._walletProvider,
    this._preferenceProvider,
    this._appearanceProvider, {
    PhotoPicker? pickPhoto,
  }) : _pickPhoto = pickPhoto ?? pickPhotoFromGallery {
    _initialBackground = _appearanceProvider.backgroundOf(walletId);
    _background = _initialBackground;
    final current = wallet;
    _initialName = _name = current.name;
    _initialIconIndex = _iconIndex = current.iconIndex;
    _initialColorIndex = _colorIndex = current.colorIndex;
    _tab = canEditWallet ? WalletAppearanceTab.wallet : _backgroundTab(_initialBackground);
  }

  static WalletAppearanceTab _backgroundTab(WalletBackground? background) {
    return switch (background) {
      WalletColorBackground() => WalletAppearanceTab.colors,
      WalletPhotoBackground() => WalletAppearanceTab.photos,
      _ => WalletAppearanceTab.skins,
    };
  }

  WalletItemBase get wallet => _walletProvider.getWalletById(walletId);
  WalletAppearance get appearance =>
      WalletAppearance(colorIndex: _colorIndex, iconIndex: _iconIndex, background: _background);

  bool get _isFromVault => wallet.walletImportSource == WalletImportSource.coconutVault;

  bool get _isCustomAccount {
    final base = wallet.walletBase;
    final path = switch (base) {
      SingleSignatureWallet() => base.derivationPath,
      TaprootWallet() => base.derivationPath,
      _ => null,
    };
    final segments = path?.split('/') ?? const <String>[];
    return segments.length > 3 && (int.tryParse(segments[3].replaceAll("'", '')) ?? 0) != 0;
  }

  /// 볼트에서 가져온 지갑은 볼트의 이름을 따른다. 직접 추가한 지갑, 다른 계정, 핫월렛만 바꿀 수 있다.
  bool get canEditName => !_isFromVault || _isCustomAccount || wallet.hasLocalKey;

  /// 아이콘·색은 코코넛 아이콘을 쓰는 지갑(핫월렛, 다른 계정)만 바꿀 수 있다.
  bool get canEditPalette => (_isCustomAccount || wallet.hasLocalKey) && _isFromVault;

  bool get canEditWallet => canEditName || canEditPalette;

  List<WalletAppearanceTab> get tabs => [
    if (canEditWallet) WalletAppearanceTab.wallet,
    WalletAppearanceTab.skins,
    WalletAppearanceTab.colors,
    WalletAppearanceTab.photos,
  ];

  String get name => _name;
  int get iconIndex => _iconIndex;
  int get colorIndex => _colorIndex;
  bool get isNameEmpty => _name.trim().isEmpty;
  bool get isNameDuplicated => _isNameDuplicated;
  bool get isNameValid => !isNameEmpty && !_isNameDuplicated;
  WalletBackground? get background => _background;
  bool get isPickingPhoto => _isPickingPhoto;
  WalletCardSize get previewSize => _previewSize;
  WalletAppearanceTab get tab => _tab;
  bool get hasChanges =>
      _background != _initialBackground ||
      _name.trim() != _initialName ||
      _iconIndex != _initialIconIndex ||
      _colorIndex != _initialColorIndex;

  bool get canSave => hasChanges && isNameValid && !_isPickingPhoto && !_isSaving;
  bool get isSaving => _isSaving;
  bool _isSaving = false;

  WalletPhotoBackground? get photo => _background.asPhoto;

  /// 마지막으로 고른 사진. 스킨으로 바꿨다가 다시 사진을 고를 때 쓴다.
  WalletPhotoBackground? get lastPhoto =>
      photo ?? (_importedPhotos.isNotEmpty ? _importedPhotos.last : _initialBackground.asPhoto);

  File? photoFileOf(WalletPhotoBackground photo) => _appearanceProvider.photoFileOf(photo);

  String get balanceText => _preferenceProvider.currentUnit.displayBitcoinAmount(
    _walletProvider.getWalletBalance(walletId).total,
    withUnit: true,
  );

  void selectPreviewSize(WalletCardSize size) {
    if (_previewSize == size) return;
    _previewSize = size;
    notifyListeners();
  }

  void selectTab(WalletAppearanceTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    notifyListeners();
  }

  void updateName(String value) {
    _name = value;
    final trimmed = value.trim();
    _isNameDuplicated =
        trimmed.isNotEmpty &&
        trimmed != _initialName &&
        _walletProvider.resolveWalletNameConflict(
              desiredName: trimmed,
              descriptor: wallet.descriptor,
              isSingleSig: wallet is SinglesigWalletItem,
              excludeWalletId: walletId,
            ) !=
            trimmed;
    notifyListeners();
  }

  void selectIcon(int index) {
    if (!canEditPalette || _iconIndex == index) return;
    _iconIndex = index;
    notifyListeners();
  }

  void selectColor(int index) {
    if (!canEditPalette || _colorIndex == index) return;
    _colorIndex = index;
    notifyListeners();
  }

  void selectBackground(WalletBackground? background) {
    if (_background == background) return;
    _background = background;
    notifyListeners();
  }

  /// 사진을 골라 앱 폴더에 복사한다. 아직 배경으로 적용하지 않는다(자르기 단계에서 [applyPhoto] 또는 [dropPhoto]).
  /// 고르지 않고 닫으면 [PhotoPickResult.cancelled], 읽지 못하면 [PhotoPickResult.failed].
  Future<PhotoPickResult> pickPhoto() async {
    if (_isPickingPhoto) return const PhotoPickResult.cancelled();
    _isPickingPhoto = true;
    notifyListeners();
    try {
      final picked = await _pickPhoto();
      if (picked == null) return const PhotoPickResult.cancelled();
      final imported = await _appearanceProvider.importPhoto(walletId, picked.bytes, extension: picked.extension);
      _importedPhotos.add(imported);
      return PhotoPickResult.picked(imported);
    } catch (e) {
      Logger.error('[WalletAppearanceViewModel] pickPhoto failed: $e');
      return const PhotoPickResult.failed();
    } finally {
      _isPickingPhoto = false;
      notifyListeners();
    }
  }

  /// 자르기 단계에서 정한 위치·크기로 사진을 배경에 적용한다.
  void applyPhoto(WalletPhotoBackground framed) => selectBackground(framed);

  /// 자르기 단계에서 취소한 새 사진을 지운다.
  Future<void> dropPhoto(WalletPhotoBackground photo) async {
    if (!_importedPhotos.remove(photo)) return;
    notifyListeners();
    if (_background != photo) await _appearanceProvider.discardPhoto(photo);
  }

  Future<void> save() async {
    if (!canSave) return;
    _isSaving = true;
    notifyListeners();
    try {
      final trimmed = _name.trim();
      if (canEditName && trimmed != _initialName) await _walletProvider.updateWalletName(walletId, trimmed);
      if (canEditPalette && (_iconIndex != _initialIconIndex || _colorIndex != _initialColorIndex)) {
        await _walletProvider.updateWalletPalette(walletId, _iconIndex, _colorIndex);
      }
      await _appearanceProvider.setBackground(walletId, _background);
      _saved = true;
      await _discardUnusedPhotos();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// 저장하지 않고 나갈 때 이번에 가져온 사진을 지운다.
  Future<void> discard() async {
    if (_saved || _isSaving) return;
    await _discardUnusedPhotos();
  }

  Future<void> _discardUnusedPhotos() async {
    final photos = List.of(_importedPhotos);
    _importedPhotos.clear();
    for (final imported in photos) {
      await _appearanceProvider.discardPhoto(imported);
    }
  }

  static Future<PickedPhoto?> pickPhotoFromGallery() async {
    final file = await AppGuard.runWithoutPrivacyScreen(
      () => ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: maxPhotoDimension.toDouble(),
        maxHeight: maxPhotoDimension.toDouble(),
        imageQuality: 85,
        requestFullMetadata: false,
      ),
    );
    if (file == null) return null;
    final extension = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
    return PickedPhoto(await file.readAsBytes(), extension);
  }
}

extension on WalletBackground? {
  WalletPhotoBackground? get asPhoto {
    final self = this;
    return self is WalletPhotoBackground ? self : null;
  }
}
