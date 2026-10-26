import 'dart:convert';
import 'dart:io';

import 'package:coconut_wallet/services/wallet/wallet_background_photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4z8AARAAI/gH/xp559wAAAABJRU5ErkJggg==',
  );
  late Directory tempDir;
  late WalletBackgroundPhotoStore store;

  File outsideFile() => File(p.join(tempDir.path, 'keep.txt'));

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wallet_background_photo_store_test');
    store = WalletBackgroundPhotoStore(baseDirectory: () async => tempDir);
    await store.init();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('delete ignores a name that leaves the photo directory', () async {
    final outside = outsideFile()..writeAsStringSync('keep');

    await store.delete('../keep.txt');
    await store.delete(outside.path);
    await store.delete('nested/keep.txt');

    expect(outside.existsSync(), isTrue);
    expect(outside.readAsStringSync(), 'keep');
    expect(store.fileOf('../keep.txt'), isNull);
    expect(store.fileOf(outside.path), isNull);
  });

  test('save keeps a hostile extension inside the photo directory', () async {
    final saved = await store.save(7, png, extension: 'png/../../escaped');
    final directory = p.join(tempDir.path, WalletBackgroundPhotoStore.directoryName);

    expect(saved.fileName.contains('/'), isFalse);
    expect(saved.fileName.contains('..'), isFalse);
    expect(p.isWithin(directory, store.fileOf(saved.fileName)!.path), isTrue);
    expect(File(p.join(tempDir.path, 'escaped')).existsSync(), isFalse);
    expect(store.fileOf(saved.fileName)!.existsSync(), isTrue);
  });
}
