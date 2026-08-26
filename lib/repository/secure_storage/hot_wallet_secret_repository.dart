import 'dart:convert';
import 'dart:math';

import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/services/security/device_dek_keystore.dart';
import 'package:coconut_wallet/services/wallet/hot_wallet_crypto_service.dart';
import 'package:flutter/services.dart';

class HotWalletSecretRepository {
  HotWalletSecretRepository({
    SecureStorageRepository? secureStorage,
    HotWalletCryptoService? cryptoService,
    DeviceDekKeystore? deviceKeystore,
    Random? random,
  }) : _secureStorage = secureStorage ?? SecureStorageRepository(),
       _cryptoService = cryptoService ?? HotWalletCryptoService(),
       _deviceKeystore = deviceKeystore ?? DeviceDekKeystore(),
       _random = random ?? Random.secure();

  static const String _secretPrefix = 'hot_wallet_secret_';
  static const String _hardwareKeyPrefix = 'hot_wallet_device_key_';
  static const String _fallbackKeySuffix = '_fallback_kek';

  final SecureStorageRepository _secureStorage;
  final HotWalletCryptoService _cryptoService;
  final DeviceDekKeystore _deviceKeystore;
  final Random _random;

  String newSecretStorageKey() => '$_secretPrefix${_randomId()}';

  Future<void> create({required String storageKey, required Uint8List mnemonic, required Uint8List passphrase}) async {
    final result = await _cryptoService.encryptPayload(mnemonic: mnemonic, passphrase: passphrase);
    String? hardwareAlias;
    String? fallbackKey;

    try {
      final wrappedDek = await _wrapDekWithBestAvailableProtection(
        storageKey,
        result.dek,
        onHardwareAliasCreated: (alias) => hardwareAlias = alias,
        onFallbackKeyStored: (key) => fallbackKey = key,
      );
      final secret = HotWalletSecret(
        version: HotWalletSecret.currentVersion,
        encryptedPayload: result.encryptedPayload,
        deviceWrappedDek: wrappedDek,
      );
      await _secureStorage.write(key: storageKey, value: secret.encode());
    } catch (_) {
      if (hardwareAlias != null) {
        await _deleteHardwareKeyIgnoringFailure(hardwareAlias!);
      }
      if (fallbackKey != null) {
        await _secureStorage.delete(key: fallbackKey!);
      }
      rethrow;
    } finally {
      result.dek.fillRange(0, result.dek.length, 0);
    }
  }

  /// 앱 PIN/생체인증은 호출 전에 완료되어야 한다.
  ///
  /// 이 메서드는 인증 상태를 판단하지 않고, 저장된 기기 키 경로로 DEK와
  /// payload를 복호화한다.
  /// 사용자 인증 정책은 HotWalletUnlockService에서 처리한다.
  /// 프로덕션 UI에서는 이 메서드를 직접 호출하지 않는다.
  Future<HotWalletPlaintext> unlockAfterAuthentication(String storageKey) async {
    final secret = await _readSecret(storageKey);
    final dek = await _unwrapDek(secret.deviceWrappedDek);
    try {
      return await _cryptoService.decryptPayload(secret, dek);
    } finally {
      dek.fillRange(0, dek.length, 0);
    }
  }

  Future<void> delete(String storageKey) async {
    HotWalletSecret? secret;
    try {
      secret = await _readSecret(storageKey);
    } on StateError {
      // 생성 도중 실패해 secret 레코드가 아직 없는 경우도 정리한다.
    }

    await _secureStorage.delete(key: storageKey);
    await _secureStorage.delete(key: _fallbackStorageKey(storageKey));

    final wrapped = secret?.deviceWrappedDek;
    if (wrapped != null && wrapped.protection != DeviceKeyProtection.secureStorage && wrapped.alias != null) {
      await _deleteHardwareKeyIgnoringFailure(wrapped.alias!);
    }
  }

  Future<List<String>> getSecretStorageKeys() async {
    final keys = await _secureStorage.getAllKeys();
    return keys.where((key) => key.startsWith(_secretPrefix) && !key.endsWith(_fallbackKeySuffix)).toList();
  }

  Future<DeviceWrappedDek> _wrapDekWithBestAvailableProtection(
    String storageKey,
    Uint8List dek, {
    required void Function(String alias) onHardwareAliasCreated,
    required void Function(String storageKey) onFallbackKeyStored,
  }) async {
    final hardwareAlias = '$_hardwareKeyPrefix${_randomId()}';
    try {
      final wrapped = await _deviceKeystore.wrap(alias: hardwareAlias, dek: dek);
      onHardwareAliasCreated(hardwareAlias);
      return DeviceWrappedDek(
        protection: wrapped.protection,
        alias: wrapped.alias,
        encryptedDek: EncryptedValue(nonce: '', cipherText: base64Encode(wrapped.ciphertext), mac: ''),
      );
    } on MissingPluginException {
      // 시뮬레이터 또는 지원하지 않는 플랫폼은 SecureStorage로 폴백한다.
    } on PlatformException catch (error) {
      if (error.code != 'HARDWARE_UNAVAILABLE') rethrow;
    }

    final fallbackKeyStorageKey = _fallbackStorageKey(storageKey);
    final fallbackKey = _cryptoService.randomBytes(HotWalletCryptoService.keyLength);
    try {
      await _secureStorage.write(key: fallbackKeyStorageKey, value: base64Encode(fallbackKey));
      onFallbackKeyStored(fallbackKeyStorageKey);
      return DeviceWrappedDek(
        protection: DeviceKeyProtection.secureStorage,
        alias: fallbackKeyStorageKey,
        encryptedDek: await _cryptoService.encrypt(dek, fallbackKey),
      );
    } finally {
      fallbackKey.fillRange(0, fallbackKey.length, 0);
    }
  }

  Future<Uint8List> _unwrapDek(DeviceWrappedDek wrapped) async {
    if (wrapped.protection != DeviceKeyProtection.secureStorage) {
      final alias = wrapped.alias;
      if (alias == null || alias.isEmpty) {
        throw const FormatException('Hardware key alias is missing');
      }
      final dek = await _deviceKeystore.unwrap(
        alias: alias,
        ciphertext: Uint8List.fromList(base64Decode(wrapped.encryptedDek.cipherText)),
      );
      // MethodChannel이 반환하는 TypedData는 플랫폼에 따라 수정 불가능한
      // view일 수 있다. 사용 후 메모리를 0으로 덮어쓸 수 있도록 앱이 소유한
      // mutable buffer로 즉시 복사한다.
      return Uint8List.fromList(dek);
    }

    final fallbackStorageKey = wrapped.alias;
    if (fallbackStorageKey == null || fallbackStorageKey.isEmpty) {
      throw const FormatException('Fallback key storage key is missing');
    }
    final encodedKey = await _secureStorage.read(key: fallbackStorageKey);
    if (encodedKey == null) {
      throw StateError('Hot wallet fallback key not found');
    }
    final fallbackKey = Uint8List.fromList(base64Decode(encodedKey));
    try {
      return await _cryptoService.decrypt(wrapped.encryptedDek, fallbackKey);
    } finally {
      fallbackKey.fillRange(0, fallbackKey.length, 0);
    }
  }

  Future<HotWalletSecret> _readSecret(String storageKey) async {
    final encoded = await _secureStorage.read(key: storageKey);
    if (encoded == null) throw StateError('Hot wallet secret not found');
    return HotWalletSecret.decode(encoded);
  }

  Future<void> _deleteHardwareKeyIgnoringFailure(String alias) async {
    try {
      await _deviceKeystore.delete(alias);
    } on PlatformException {
      // Secret 삭제가 OS 키 정리 실패로 취소되지 않도록 한다.
    } on MissingPluginException {
      // 지원하지 않는 플랫폼에서는 정리할 네이티브 키가 없다.
    }
  }

  String _fallbackStorageKey(String storageKey) => '$storageKey$_fallbackKeySuffix';

  String _randomId() =>
      List<int>.generate(
        16,
        (_) => _random.nextInt(256),
      ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}
