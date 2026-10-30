import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/wallet_lifecycle_event.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_appearance_view_model.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/wallet_appearance_repository.dart';
import 'package:coconut_wallet/services/wallet/wallet_background_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../mock/wallet_mock.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  bool fail = false;
  bool throws = false;
  Completer<void>? gate;
  int attempts = 0;

  Future<bool> _write(Future<bool> Function() write) async {
    attempts++;
    await gate?.future;
    if (fail) {
      if (throws) throw StateError('injected storage failure');
      return false;
    }
    return write();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      _write(() => super.setValue(valueType, key, value));
  @override
  Future<bool> remove(String key) => _write(() => super.remove(key));
}

class _Wallets extends Fake implements WalletProvider {
  final wallet = WalletMock.createSingleSigWalletItem();
  @override
  WalletItemBase getWalletById(int id) => wallet;
}

class _Preferences extends Fake implements PreferenceProvider {}

class _Photos extends WalletBackgroundPhotoStore {
  _Photos(Directory directory) : super(baseDirectory: () async => directory);
  Completer<void>? gate;
  int imports = 0;
  @override
  Future<WalletPhotoBackground> save(int walletId, Uint8List bytes, {String extension = 'jpg'}) async {
    imports++;
    await gate?.future;
    return super.save(walletId, bytes, extension: extension);
  }
}

void main() {
  late Directory directory;
  late _Store store;
  late _Photos photos;
  late WalletAppearanceRepository repository;
  late WalletAppearanceProvider provider;
  late SharedPreferences preferences;
  late StreamController<WalletLifecycleEvent> events;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    preferences = await SharedPreferences.getInstance();
    final prefs = SharedPrefsRepository();
    await prefs.init();
    repository = WalletAppearanceRepository(prefs);
    directory = await Directory.systemTemp.createTemp('appearance-durability');
    photos = _Photos(directory);
    events = StreamController<WalletLifecycleEvent>.broadcast();
    provider = WalletAppearanceProvider(repository: repository, photoStore: photos, lifecycleEvents: events.stream);
    await provider.init();
  });

  tearDown(() async {
    provider.dispose();
    await events.close();
    await directory.delete(recursive: true);
  });

  for (final throws in [false, true]) {
    for (final replacement in [const WalletSkinBackground('sky'), null]) {
      test(
        'failed ${throws ? 'throw' : 'false'} ${replacement == null ? 'remove' : 'write'} retains photo and retries',
        () async {
          const old = WalletPhotoBackground(fileName: 'old.jpg', aspectRatio: 1);
          final file = photos.fileOf(old.fileName)!;
          await file.writeAsBytes([1]);
          await provider.setBackground(1, old);
          var notifications = 0;
          provider.addListener(() => notifications++);
          store.fail = true;
          store.throws = throws;
          await expectLater(provider.setBackground(1, replacement), throwsA(isA<StateError>()));
          expect(provider.backgroundOf(1), old);
          expect(repository.loadBackgrounds()[1], old);
          expect(file.existsSync(), isTrue);
          expect(notifications, 0);
          store.fail = false;
          await provider.setBackground(1, replacement);
          await preferences.reload();
          expect(repository.loadBackgrounds()[1], replacement);
          expect(provider.backgroundOf(1), replacement);
          expect(store.attempts, 3);
          expect(file.existsSync(), isFalse);
          expect(notifications, 1);
        },
      );
    }
  }

  test('pending persistence keeps memory and photo until durable completion', () async {
    const old = WalletPhotoBackground(fileName: 'old.jpg', aspectRatio: 1);
    final file = photos.fileOf(old.fileName)!;
    await file.writeAsBytes([1]);
    await provider.setBackground(1, old);
    store.gate = Completer<void>();
    final saving = provider.setBackground(1, const WalletSkinBackground('sky'));
    await pumpEventQueue();
    expect(provider.backgroundOf(1), old);
    expect(file.existsSync(), isTrue);
    store.gate!.complete();
    await saving;
    expect(file.existsSync(), isFalse);
  });

  test('failed queued write reports its error without poisoning the next update', () async {
    store.gate = Completer<void>();
    store.fail = true;
    store.throws = true;
    final first = provider.setBackground(1, const WalletSkinBackground('mint'));
    final checked = expectLater(first, throwsA(isA<StateError>()));
    final next = provider.setBackground(2, const WalletSkinBackground('sky'));
    first.catchError((Object _) {
      store.fail = false;
    });
    await pumpEventQueue();
    store.gate!.complete();
    await checked;
    await next;
    await preferences.reload();
    expect(provider.backgroundOf(1), isNull);
    expect(provider.backgroundOf(2), const WalletSkinBackground('sky'));
    expect(repository.loadBackgrounds(), {2: const WalletSkinBackground('sky')});
    expect(store.attempts, 2);
  });

  test('wallet removal during pending save cannot revive its background or photo', () async {
    const draft = WalletPhotoBackground(fileName: 'draft.jpg', aspectRatio: 1);
    final file = photos.fileOf(draft.fileName)!;
    await file.writeAsBytes([1]);
    store.gate = Completer<void>();
    final saving = provider.setBackground(1, draft);
    await pumpEventQueue();
    events.add(const WalletRemoved(1));
    await pumpEventQueue();
    store.gate!.complete();
    await saving;
    await pumpEventQueue();
    await preferences.reload();
    expect(provider.backgroundOf(1), isNull);
    expect(repository.loadBackgrounds()[1], isNull);
    expect(file.existsSync(), isFalse);
  });

  for (final fails in [false, true]) {
    test('discard during ${fails ? 'failed' : 'successful'} save defers photo cleanup', () async {
      final wallets = _Wallets();
      final vm = WalletAppearanceViewModel(
        wallets.wallet.id,
        wallets,
        _Preferences(),
        provider,
        pickPhoto:
            () async => PickedPhoto(
              base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4z8AARAAI/gH/xp559wAAAABJRU5ErkJggg==',
              ),
              'png',
            ),
      );
      final picked = (await vm.pickPhoto()).photo!;
      vm.applyPhoto(picked);
      final file = provider.photoFileOf(picked)!;
      store.gate = Completer<void>();
      store.fail = fails;
      store.throws = true;
      final saving = vm.save();
      final checked = fails ? expectLater(saving, throwsA(isA<StateError>())) : saving;
      await pumpEventQueue();
      await vm.discard();
      vm.dispose();
      expect(file.existsSync(), isTrue);
      store.gate!.complete();
      await checked;
      expect(file.existsSync(), !fails);
      await preferences.reload();
      expect(repository.loadBackgrounds()[wallets.wallet.id], fails ? null : picked);
    });
  }

  for (final dispose in [false, true]) {
    for (final duringImport in [false, true]) {
      test(
        'late photo after ${dispose ? 'dispose' : 'discard'} during ${duringImport ? 'import' : 'picker'} is cleaned',
        () async {
          final picker = Completer<PickedPhoto?>();
          final wallets = _Wallets();
          final vm = WalletAppearanceViewModel(
            wallets.wallet.id,
            wallets,
            _Preferences(),
            provider,
            pickPhoto: () => picker.future,
          );
          var notifications = 0;
          vm.addListener(() => notifications++);
          final picking = vm.pickPhoto();
          if (duringImport) {
            photos.gate = Completer<void>();
            picker.complete(
              PickedPhoto(
                base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4z8AARAAI/gH/xp559wAAAABJRU5ErkJggg==',
                ),
                'png',
              ),
            );
            await pumpEventQueue();
          }
          if (dispose) {
            vm.dispose();
          } else {
            await vm.discard();
          }
          final before = notifications;
          if (duringImport) {
            photos.gate!.complete();
          } else {
            picker.complete(
              PickedPhoto(
                base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4z8AARAAI/gH/xp559wAAAABJRU5ErkJggg==',
                ),
                'png',
              ),
            );
          }
          final result = await picking;
          expect(result.photo, isNull);
          expect(result.failed, isFalse);
          expect(notifications, before);
          expect(photos.imports, duringImport ? 1 : 0);
          expect(directory.listSync(recursive: true).whereType<File>(), isEmpty);
          if (!dispose) vm.dispose();
        },
      );
    }
  }
}
