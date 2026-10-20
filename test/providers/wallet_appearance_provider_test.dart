import 'dart:async';
import 'dart:io';

import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/model/wallet/wallet_lifecycle_event.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/wallet_appearance_repository.dart';
import 'package:coconut_wallet/services/wallet/wallet_background_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDir;
  late WalletAppearanceRepository repository;
  late WalletBackgroundPhotoStore photoStore;
  late StreamController<WalletLifecycleEvent> events;

  File photoFile(String name) => File(p.join(tempDir.path, WalletBackgroundPhotoStore.directoryName, name));

  Future<WalletPhotoBackground> writePhoto(String name) async {
    final file = photoFile(name);
    await file.parent.create(recursive: true);
    await file.writeAsBytes([1, 2, 3]);
    return WalletPhotoBackground(fileName: name, aspectRatio: 1);
  }

  Future<WalletAppearanceProvider> createProvider() async {
    final provider = WalletAppearanceProvider(
      repository: repository,
      photoStore: photoStore,
      lifecycleEvents: events.stream,
    );
    await provider.init();
    return provider;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    repository = WalletAppearanceRepository(prefs);
    tempDir = await Directory.systemTemp.createTemp('wallet_appearance_test');
    photoStore = WalletBackgroundPhotoStore(baseDirectory: () async => tempDir);
    events = StreamController<WalletLifecycleEvent>.broadcast();
  });

  tearDown(() async {
    await events.close();
    await tempDir.delete(recursive: true);
  });

  test('setBackground persists and notifies', () async {
    final provider = await createProvider();
    var notified = 0;
    provider.addListener(() => notified++);

    await provider.setBackground(1, const WalletSkinBackground('mint'));

    expect(provider.backgroundOf(1), const WalletSkinBackground('mint'));
    expect(repository.loadBackgrounds()[1], const WalletSkinBackground('mint'));
    expect(notified, 1);
  });

  test('replacing a photo deletes the old file', () async {
    final provider = await createProvider();
    final first = await writePhoto('first.jpg');
    final second = await writePhoto('second.jpg');

    await provider.setBackground(1, first);
    await provider.setBackground(1, second);

    expect(photoFile('first.jpg').existsSync(), isFalse);
    expect(photoFile('second.jpg').existsSync(), isTrue);
  });

  test('moving the same photo keeps the file', () async {
    final provider = await createProvider();
    final photo = await writePhoto('photo.jpg');

    await provider.setBackground(1, photo);
    await provider.setBackground(1, photo.copyWith(focusX: 0.5));

    expect(photoFile('photo.jpg').existsSync(), isTrue);
  });

  test('wallet removal clears its background and photo', () async {
    final provider = await createProvider();
    final photo = await writePhoto('photo.jpg');
    await provider.setBackground(1, photo);
    await provider.setBackground(2, const WalletSkinBackground('sky'));

    events.add(const WalletRemoved(1));
    await pumpEventQueue();

    expect(provider.backgroundOf(1), isNull);
    expect(repository.loadBackgrounds().keys, [2]);
    expect(photoFile('photo.jpg').existsSync(), isFalse);
  });

  test('init deletes photos no wallet uses', () async {
    final kept = await writePhoto('kept.jpg');
    await writePhoto('orphan.jpg');
    await repository.setBackground(1, kept);

    await createProvider();

    expect(photoFile('kept.jpg').existsSync(), isTrue);
    expect(photoFile('orphan.jpg').existsSync(), isFalse);
  });

  test('discardPhoto keeps a photo that a wallet uses', () async {
    final provider = await createProvider();
    final used = await writePhoto('used.jpg');
    final draft = await writePhoto('draft.jpg');
    await provider.setBackground(1, used);

    await provider.discardPhoto(used);
    await provider.discardPhoto(draft);

    expect(photoFile('used.jpg').existsSync(), isTrue);
    expect(photoFile('draft.jpg').existsSync(), isFalse);
  });
}
