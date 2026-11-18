import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_wallet_store.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Secrets extends Fake implements HotWalletSecretRepository {
  final Map<String, ({Uint8List mnemonic, Uint8List passphrase})> stored = {};
  var _next = 0;

  @override
  String newSecretStorageKey() => 'hot_wallet_secret_${_next++}';

  @override
  Future<void> create({required String storageKey, required Uint8List mnemonic, required Uint8List passphrase}) async {
    stored[storageKey] = (mnemonic: Uint8List.fromList(mnemonic), passphrase: Uint8List.fromList(passphrase));
  }

  @override
  Future<HotWalletPlaintext> unlockAfterAuthentication(String storageKey) async {
    final secret = stored[storageKey]!;
    return HotWalletPlaintext(
      mnemonic: Uint8List.fromList(secret.mnemonic),
      passphrase: Uint8List.fromList(secret.passphrase),
    );
  }

  @override
  Future<void> delete(String storageKey) async => stored.remove(storageKey);

  @override
  Future<List<String>> getSecretStorageKeys() async => stored.keys.toList();
}

void main() {
  late _Secrets secrets;
  late ArkWalletStore store;
  final words = '${'abandon ' * 11}about';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // ignore: deprecated_member_use_from_same_package
    final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    secrets = _Secrets();
    store = ArkWalletStore(prefs, secrets);
  });

  Future<ArkWalletInfo> save(ArkSeedSource source) =>
      store.save(mnemonic: Uint8List.fromList(utf8.encode(words)), fingerprint: '73c5da0a', source: source);

  test('nothing is stored at first', () {
    expect(store.read(), isNull);
  });

  test('a new seed still needs a backup', () async {
    await save(ArkSeedSource.created);

    final info = store.read()!;
    expect(info.backupVerified, isFalse);
    expect(info.fingerprint, '73c5da0a');
    expect(secrets.stored[info.secretStorageKey]!.passphrase, isEmpty);
  });

  test('a restored seed counts as backed up', () async {
    await save(ArkSeedSource.restored);
    expect(store.read()!.backupVerified, isTrue);
  });

  test('the stored words come back', () async {
    final info = await save(ArkSeedSource.created);

    expect(utf8.decode(await store.readMnemonic(info)), words);
  });

  test('marking the backup verified sticks', () async {
    await save(ArkSeedSource.created);
    await store.markBackupVerified();

    expect(store.read()!.backupVerified, isTrue);
  });

  test('clearing removes the info and the seed', () async {
    await save(ArkSeedSource.created);
    await store.clear();

    expect(store.read(), isNull);
    expect(secrets.stored, isEmpty);
  });
}
