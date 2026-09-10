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
  var hardwareDeleteFails = false;
  String? wrapFailureCode;

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
    hardwareDeleteFails = false;
    wrapFailureCode = null;
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
          if (wrapFailureCode != null) {
            throw PlatformException(code: wrapFailureCode!);
          }
          return <String, dynamic>{
            'ciphertext': Uint8List.fromList(utf8.encode(alias)),
            'protection': 'androidStrongBox',
          };
        case 'unwrap':
          return copyBytes(osKeys[alias]);
        case 'delete':
          if (hardwareDeleteFails) {
            throw PlatformException(code: 'DELETE_FAILED');
          }
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

  test('wrap 실패 시 OS에 생성된 alias를 삭제하고 예외를 전파한다', () async {
    const storageKey = 'failed-wrap-wallet';
    wrapFailureCode = 'KEYSTORE_FAILED';

    await expectLater(createSecret(storageKey), throwsA(isA<PlatformException>()));

    expect(deletedAliases, hasLength(1));
    expect(osKeys, isEmpty);
    expect(await storage.read(key: storageKey), isNull);
    expect(await storage.read(key: '${storageKey}_fallback_kek'), isNull);
  });

  test('하드웨어 미지원 실패에도 alias 삭제를 시도한 뒤 SecureStorage로 폴백한다', () async {
    hardwareAvailable = false;
    const storageKey = 'fallback-after-cleanup-wallet';

    await createSecret(storageKey);

    expect(deletedAliases, hasLength(1));
    expect(osKeys, isEmpty);
    final secret = await readSecret(storageKey);
    expect(secret.deviceWrappedDek.protection, DeviceKeyProtection.secureStorage);
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

  test('OS alias 삭제가 실패하면 secret을 남겨 다음 정리 시 재시도할 수 있게 한다', () async {
    const storageKey = 'retry-delete-hardware-wallet';
    await createSecret(storageKey);
    final alias = (await readSecret(storageKey)).deviceWrappedDek.alias!;
    hardwareDeleteFails = true;

    await expectLater(repository.delete(storageKey), throwsA(isA<PlatformException>()));

    expect(await storage.read(key: storageKey), isNotNull);
    expect(osKeys, contains(alias));

    hardwareDeleteFails = false;
    await repository.delete(storageKey);

    expect(await storage.read(key: storageKey), isNull);
    expect(osKeys, isNot(contains(alias)));
  });

  test('fallback 지갑 삭제 시 Device KEK도 함께 삭제한다', () async {
    hardwareAvailable = false;
    const storageKey = 'delete-fallback-wallet';
    await createSecret(storageKey);
    deletedAliases.clear();

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
