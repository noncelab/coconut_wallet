import 'dart:convert';
import 'dart:math';

import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/services/wallet/hot_wallet_crypto_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('onl.coconut.wallet/device-dek');
  const storage = FlutterSecureStorage();
  late HotWalletSecretRepository repository;
  late Map<String, Uint8List> osKeys;
  late List<String> deletedAliases;
  var hardwareAvailable = true;

  Uint8List copyBytes(Object? value) => Uint8List.fromList((value! as Uint8List).toList());

  Future<HotWalletSecret> readSecret(String storageKey) async {
    final encoded = await storage.read(key: storageKey);
    expect(encoded, isNotNull);
    return HotWalletSecret.decode(encoded!);
  }

  Future<void> createSecret(String storageKey) => repository.create(
    storageKey: storageKey,
    mnemonic: Uint8List.fromList(
      utf8.encode('abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'),
    ),
    passphrase: Uint8List.fromList(utf8.encode('passphrase')),
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    osKeys = <String, Uint8List>{};
    deletedAliases = <String>[];
    hardwareAvailable = true;
    repository = HotWalletSecretRepository(
      cryptoService: HotWalletCryptoService(random: Random(42)),
      random: Random(43),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      final arguments = call.arguments! as Map<Object?, Object?>;
      final alias = arguments['alias']! as String;
      switch (call.method) {
        case 'wrap':
          if (!hardwareAvailable) {
            throw PlatformException(code: 'HARDWARE_UNAVAILABLE');
          }
          osKeys[alias] = copyBytes(arguments['plaintext']);
          return <String, dynamic>{
            'ciphertext': Uint8List.fromList(utf8.encode(alias)),
            'protection': 'androidStrongBox',
          };
        case 'unwrap':
          return copyBytes(osKeys[alias]);
        case 'delete':
          deletedAliases.add(alias);
          osKeys.remove(alias);
          return null;
      }
      throw MissingPluginException();
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('PIN·생체인증 설정과 무관한 단일 하드웨어 wrapper를 저장한다', () async {
    const storageKey = 'hardware-wallet';
    await createSecret(storageKey);
    final secret = await readSecret(storageKey);

    expect(secret.deviceWrappedDek.protection, DeviceKeyProtection.androidStrongBox);
    expect(secret.deviceWrappedDek.alias, isNotEmpty);
    expect(secret.encryptedPayload.cipherText, isNotEmpty);

    final plaintext = await repository.unlockAfterAuthentication(storageKey);
    expect(plaintext.passphrase, 'passphrase');
  });

  test('하드웨어 보안 키가 없으면 SecureStorage Device KEK로 폴백한다', () async {
    hardwareAvailable = false;
    const storageKey = 'fallback-wallet';
    await createSecret(storageKey);
    final secret = await readSecret(storageKey);

    expect(secret.deviceWrappedDek.protection, DeviceKeyProtection.secureStorage);
    expect(secret.deviceWrappedDek.encryptedDek.nonce, isNotEmpty);
    expect(await storage.read(key: '${storageKey}_fallback_kek'), isNotNull);

    final plaintext = await repository.unlockAfterAuthentication(storageKey);
    expect(plaintext.mnemonic, startsWith('abandon'));
  });

  test('하드웨어 지갑 삭제 시 secret과 OS alias를 함께 삭제한다', () async {
    const storageKey = 'delete-hardware-wallet';
    await createSecret(storageKey);
    final secret = await readSecret(storageKey);
    final alias = secret.deviceWrappedDek.alias!;

    await repository.delete(storageKey);

    expect(await storage.read(key: storageKey), isNull);
    expect(deletedAliases, contains(alias));
  });

  test('fallback 지갑 삭제 시 Device KEK도 함께 삭제한다', () async {
    hardwareAvailable = false;
    const storageKey = 'delete-fallback-wallet';
    await createSecret(storageKey);

    await repository.delete(storageKey);

    expect(await storage.read(key: storageKey), isNull);
    expect(await storage.read(key: '${storageKey}_fallback_kek'), isNull);
    expect(deletedAliases, isEmpty);
  });

  test('지원하지 않는 네이티브 채널에서도 SecureStorage로 폴백한다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    const storageKey = 'missing-plugin-wallet';

    await createSecret(storageKey);

    final secret = await readSecret(storageKey);
    expect(secret.deviceWrappedDek.protection, DeviceKeyProtection.secureStorage);
    expect((await repository.unlockAfterAuthentication(storageKey)).passphrase, 'passphrase');
  });
}
