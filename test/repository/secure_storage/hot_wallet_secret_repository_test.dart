import 'dart:convert';
import 'dart:math';

import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/services/wallet/hot_wallet_crypto_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySecureStorage extends Fake implements SecureStorageRepository {
  final Map<String, String> values = {};
  final Set<String> failingWriteKeys = {};

  @override
  Future<void> write({required String key, required String value}) async {
    if (failingWriteKeys.contains(key)) throw StateError('write failed: $key');
    values[key] = value;
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<List<String>> getAllKeys() async => values.keys.toList();
}

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
    const storageKey = 'hot_wallet_secret_hardware_wallet';
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
    const storageKey = 'hot_wallet_secret_fallback_wallet';
    await createSecret(storageKey);
    final secret = await readSecret(storageKey);

    expect(secret.deviceWrappedDek.protection, DeviceKeyProtection.secureStorage);
    expect(secret.deviceWrappedDek.encryptedDek.nonce, isNotEmpty);
    expect(await storage.read(key: '${storageKey}_fallback_kek'), isNotNull);

    final plaintext = await repository.unlockAfterAuthentication(storageKey);
    expect(plaintext.mnemonic, startsWith('abandon'));
  });

  test('wrap 실패 시 OS에 생성된 alias를 삭제하고 예외를 전파한다', () async {
    const storageKey = 'hot_wallet_secret_failed_wrap_wallet';
    wrapFailureCode = 'KEYSTORE_FAILED';

    await expectLater(createSecret(storageKey), throwsA(isA<PlatformException>()));

    expect(deletedAliases, hasLength(1));
    expect(osKeys, isEmpty);
    expect(await storage.read(key: storageKey), isNull);
    expect(await storage.read(key: '${storageKey}_fallback_kek'), isNull);
  });

  test('하드웨어 미지원 실패에도 alias 삭제를 시도한 뒤 SecureStorage로 폴백한다', () async {
    hardwareAvailable = false;
    const storageKey = 'hot_wallet_secret_fallback_after_cleanup_wallet';

    await createSecret(storageKey);

    expect(deletedAliases, hasLength(1));
    expect(osKeys, isEmpty);
    final secret = await readSecret(storageKey);
    expect(secret.deviceWrappedDek.protection, DeviceKeyProtection.secureStorage);
  });

  test('하드웨어 지갑 삭제 시 secret과 OS alias를 함께 삭제한다', () async {
    const storageKey = 'hot_wallet_secret_delete_hardware_wallet';
    await createSecret(storageKey);
    final secret = await readSecret(storageKey);
    final alias = secret.deviceWrappedDek.alias!;

    await repository.delete(storageKey);

    expect(await storage.read(key: storageKey), isNull);
    expect(deletedAliases, contains(alias));
  });

  test('OS alias 삭제가 실패하면 secret을 남겨 다음 정리 시 재시도할 수 있게 한다', () async {
    const storageKey = 'hot_wallet_secret_retry_delete_hardware_wallet';
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
    const storageKey = 'hot_wallet_secret_delete_fallback_wallet';
    await createSecret(storageKey);
    deletedAliases.clear();

    await repository.delete(storageKey);

    expect(await storage.read(key: storageKey), isNull);
    expect(await storage.read(key: '${storageKey}_fallback_kek'), isNull);
    expect(deletedAliases, isEmpty);
  });

  test('지원하지 않는 네이티브 채널에서도 SecureStorage로 폴백한다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    const storageKey = 'hot_wallet_secret_missing_plugin_wallet';

    await createSecret(storageKey);

    final secret = await readSecret(storageKey);
    expect(secret.deviceWrappedDek.protection, DeviceKeyProtection.secureStorage);
    expect((await repository.unlockAfterAuthentication(storageKey)).passphrase, 'passphrase');
  });

  test('하드웨어 wrap 성공 후 최종 secret 쓰기가 실패하면 alias를 삭제한다', () async {
    const storageKey = 'hot_wallet_secret_hardware_final_write_failure';
    final memoryStorage = _MemorySecureStorage()..failingWriteKeys.add(storageKey);
    final failingRepository = HotWalletSecretRepository(
      secureStorage: memoryStorage,
      cryptoService: HotWalletCryptoService(random: Random(42)),
      random: Random(43),
    );

    await expectLater(
      failingRepository.create(
        storageKey: storageKey,
        mnemonic: Uint8List.fromList(
          utf8.encode('abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'),
        ),
        passphrase: Uint8List.fromList(utf8.encode('passphrase')),
      ),
      throwsStateError,
    );

    expect(osKeys, isEmpty);
    expect(deletedAliases, hasLength(1));
    expect(memoryStorage.values, isEmpty);
  });

  test('fallback KEK 저장 후 최종 secret 쓰기가 실패하면 fallback KEK를 삭제한다', () async {
    hardwareAvailable = false;
    const storageKey = 'hot_wallet_secret_fallback_final_write_failure';
    final memoryStorage = _MemorySecureStorage()..failingWriteKeys.add(storageKey);
    final failingRepository = HotWalletSecretRepository(
      secureStorage: memoryStorage,
      cryptoService: HotWalletCryptoService(random: Random(42)),
      random: Random(43),
    );

    await expectLater(
      failingRepository.create(
        storageKey: storageKey,
        mnemonic: Uint8List.fromList(
          utf8.encode('abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'),
        ),
        passphrase: Uint8List.fromList(utf8.encode('passphrase')),
      ),
      throwsStateError,
    );

    expect(memoryStorage.values, isEmpty);
    expect(osKeys, isEmpty);
  });

  test('이미 사용 중인 storage key와 fallback key 충돌을 거부한다', () async {
    const storageKey = 'hot_wallet_secret_collision';
    await storage.write(key: storageKey, value: 'occupied');
    await expectLater(createSecret(storageKey), throwsStateError);
    expect(osKeys, isEmpty);

    FlutterSecureStorage.setMockInitialValues(<String, String>{'${storageKey}_fallback_kek': 'occupied'});
    await expectLater(createSecret(storageKey), throwsStateError);
    expect(osKeys, isEmpty);
  });

  test('hot wallet prefix가 아니거나 fallback key 형식인 storage key를 거부한다', () async {
    await expectLater(createSecret('wallet_without_prefix'), throwsArgumentError);
    await expectLater(createSecret('hot_wallet_secret_invalid_fallback_kek'), throwsArgumentError);
    expect(osKeys, isEmpty);
  });

  test('존재하지 않거나 이미 삭제된 secret 삭제는 멱등적으로 성공한다', () async {
    const storageKey = 'hot_wallet_secret_idempotent_delete';
    await repository.delete(storageKey);
    await createSecret(storageKey);
    await repository.delete(storageKey);
    await repository.delete(storageKey);

    expect(await storage.read(key: storageKey), isNull);
    expect(await storage.read(key: '${storageKey}_fallback_kek'), isNull);
    expect(osKeys, isEmpty);
  });

  test('손상된 JSON과 지원하지 않는 version을 거부한다', () async {
    const storageKey = 'hot_wallet_secret_invalid_model';
    await storage.write(key: storageKey, value: '{invalid-json');
    await expectLater(repository.unlockAfterAuthentication(storageKey), throwsA(isA<FormatException>()));

    await storage.write(
      key: storageKey,
      value: jsonEncode({
        'version': HotWalletSecret.currentVersion + 1,
        'encryptedPayload': {'nonce': '', 'cipherText': '', 'mac': ''},
        'deviceWrappedDek': {
          'protection': 'androidStrongBox',
          'alias': 'alias',
          'encryptedDek': {'nonce': '', 'cipherText': '', 'mac': ''},
        },
      }),
    );
    await expectLater(repository.unlockAfterAuthentication(storageKey), throwsFormatException);
  });

  for (final field in ['nonce', 'cipherText', 'mac']) {
    test('손상된 encrypted payload $field Base64를 거부한다', () async {
      final storageKey = 'hot_wallet_secret_invalid_$field';
      await createSecret(storageKey);
      final encoded = await storage.read(key: storageKey);
      final json = jsonDecode(encoded!) as Map<String, dynamic>;
      final payload = json['encryptedPayload'] as Map<String, dynamic>;
      payload[field] = '%%%not-base64%%%';
      await storage.write(key: storageKey, value: jsonEncode(json));

      await expectLater(repository.unlockAfterAuthentication(storageKey), throwsA(isA<FormatException>()));
    });
  }
}
