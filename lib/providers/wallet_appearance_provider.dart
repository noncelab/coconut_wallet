import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/wallet_lifecycle_event.dart';
import 'package:coconut_wallet/repository/shared_preference/wallet_appearance_repository.dart';
import 'package:coconut_wallet/services/wallet/wallet_background_photo_store.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// 지갑 꾸미기 값을 읽고 바꾼다. [WalletCard]를 그리는 쪽은 [appearanceOf]로 외형을 받는다.
///
/// 지갑이 삭제되면([WalletRemoved]) 그 지갑의 꾸미기 값과 사진 파일을 함께 지운다.
class WalletAppearanceProvider extends ChangeNotifier {
  final WalletAppearanceRepository _repository;
  final WalletBackgroundPhotoStore _photoStore;
  StreamSubscription<WalletLifecycleEvent>? _lifecycleSubscription;
  late Map<int, WalletBackground> _backgrounds;
  bool _disposed = false;
  Future<void>? _updates;

  WalletAppearanceProvider({
    required WalletAppearanceRepository repository,
    required WalletBackgroundPhotoStore photoStore,
    Stream<WalletLifecycleEvent>? lifecycleEvents,
  }) : _repository = repository,
       _photoStore = photoStore {
    _backgrounds = _repository.loadBackgrounds();
    _lifecycleSubscription = lifecycleEvents?.listen(_onLifecycleEvent);
  }

  /// 사진 폴더 경로를 구하고, 어느 지갑에도 쓰이지 않는 사진을 지운다.
  Future<void> init() async {
    await _photoStore.init();
    await _photoStore.deleteAllExcept(_referencedPhotoFileNames());
    if (!_disposed && _backgrounds.values.any((background) => background is WalletPhotoBackground)) {
      notifyListeners();
    }
  }

  WalletBackground? backgroundOf(int walletId) => _backgrounds[walletId];

  WalletAppearance appearanceOf(WalletItemBase wallet) =>
      WalletAppearance.of(wallet, background: _backgrounds[wallet.id]);

  File? photoFileOf(WalletPhotoBackground background) => _photoStore.fileOf(background.fileName);

  /// 지갑 배경이 사진이면 그 파일, 아니면 null.
  File? photoFileFor(int walletId) {
    final background = _backgrounds[walletId];
    return background is WalletPhotoBackground ? photoFileOf(background) : null;
  }

  /// 사진을 앱 폴더에 복사해 둔다. [setBackground]로 적용하거나 [discardPhoto]로 버린다.
  Future<WalletPhotoBackground> importPhoto(int walletId, Uint8List bytes, {String extension = 'jpg'}) {
    return _photoStore.save(walletId, bytes, extension: extension);
  }

  /// 적용하지 않은 사진을 지운다. 이미 어떤 지갑의 배경이면 남겨 둔다.
  Future<void> discardPhoto(WalletPhotoBackground background) async {
    if (_referencedPhotoFileNames().contains(background.fileName)) return;
    await _photoStore.delete(background.fileName);
  }

  Future<void> setBackground(int walletId, WalletBackground? background) => _enqueueUpdate(() async {
    final previous = _backgrounds[walletId];
    if (previous == background) return;
    await _repository.setBackground(walletId, background);
    if (background == null) {
      _backgrounds.remove(walletId);
    } else {
      _backgrounds[walletId] = background;
    }
    if (!_disposed) notifyListeners();
    if (previous is WalletPhotoBackground && !_referencedPhotoFileNames().contains(previous.fileName)) {
      await _photoStore.delete(previous.fileName);
    }
  });

  Future<void> _onLifecycleEvent(WalletLifecycleEvent event) async {
    if (event is! WalletRemoved) return;
    await _enqueueUpdate(() async {
      await _repository.remove(event.walletId);
      final removed = _backgrounds.remove(event.walletId);
      if (removed == null) return;
      if (!_disposed) notifyListeners();
      if (removed is WalletPhotoBackground && !_referencedPhotoFileNames().contains(removed.fileName)) {
        await _photoStore.delete(removed.fileName);
      }
    });
  }

  Future<void> _enqueueUpdate(Future<void> Function() update) {
    final operation = _updates == null ? update() : _updates!.then((_) => update());
    // A failed operation still reaches its caller, but must not block later updates.
    late final Future<void> tail;
    tail = operation.catchError((Object _) {}).whenComplete(() {
      if (identical(_updates, tail)) _updates = null;
    });
    _updates = tail;
    return operation;
  }

  Set<String> _referencedPhotoFileNames() =>
      _backgrounds.values.whereType<WalletPhotoBackground>().map((background) => background.fileName).toSet();

  @override
  void dispose() {
    _disposed = true;
    _lifecycleSubscription?.cancel();
    super.dispose();
  }
}

extension WalletAppearanceContext on BuildContext {
  /// 지갑 카드를 그리는 위젯이 외형을 구할 때 쓴다. Provider가 없는 곳(테스트 등)에서는 기본 외형을 쓴다.
  WalletAppearanceProvider? watchWalletAppearance() {
    try {
      return Provider.of<WalletAppearanceProvider>(this);
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// [watchWalletAppearance]와 같지만 다시 그리지 않는다(initState 등에서 쓴다).
  WalletAppearanceProvider? readWalletAppearance() {
    try {
      return Provider.of<WalletAppearanceProvider>(this, listen: false);
    } on ProviderNotFoundException {
      return null;
    }
  }
}
