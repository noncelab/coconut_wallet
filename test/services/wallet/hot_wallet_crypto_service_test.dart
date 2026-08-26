import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/services/wallet/hot_wallet_crypto_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HotWalletCryptoService service;
  late Uint8List mnemonic;
  late Uint8List passphrase;

  setUp(() {
    service = HotWalletCryptoService(random: Random(42));
    mnemonic = Uint8List.fromList(
      utf8.encode('abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'),
    );
    passphrase = Uint8List.fromList(utf8.encode('secret'));
  });

  test('랜덤 32바이트 DEK로 니모닉과 패스프레이즈를 암호화한다', () async {
    final result = await service.encryptPayload(mnemonic: mnemonic, passphrase: passphrase);
    final secret = HotWalletSecret(
      version: HotWalletSecret.currentVersion,
      encryptedPayload: result.encryptedPayload,
      deviceWrappedDek: const DeviceWrappedDek(
        protection: DeviceKeyProtection.androidTee,
        alias: 'device-key',
        encryptedDek: EncryptedValue(nonce: '', cipherText: 'native-ciphertext', mac: ''),
      ),
    );
    final plaintext = await service.decryptPayload(secret, result.dek);

    expect(result.dek, hasLength(32));
    expect(plaintext.mnemonic, utf8.decode(mnemonic));
    expect(plaintext.passphrase, 'secret');
    expect(result.encryptedPayload.nonce, isNotEmpty);
    result.dek.fillRange(0, result.dek.length, 0);
  });

  test('암호화할 때마다 nonce와 암호문이 달라진다', () async {
    final first = await service.encryptPayload(mnemonic: mnemonic, passphrase: passphrase);
    final second = await service.encryptPayload(mnemonic: mnemonic, passphrase: passphrase);

    expect(first.encryptedPayload.nonce, isNot(second.encryptedPayload.nonce));
    expect(first.encryptedPayload.cipherText, isNot(second.encryptedPayload.cipherText));
    first.dek.fillRange(0, first.dek.length, 0);
    second.dek.fillRange(0, second.dek.length, 0);
  });

  test('잘못된 DEK로 payload를 복호화할 수 없다', () async {
    final result = await service.encryptPayload(mnemonic: mnemonic, passphrase: passphrase);
    final secret = HotWalletSecret(
      version: HotWalletSecret.currentVersion,
      encryptedPayload: result.encryptedPayload,
      deviceWrappedDek: const DeviceWrappedDek(
        protection: DeviceKeyProtection.iosSecureEnclave,
        alias: 'device-key',
        encryptedDek: EncryptedValue(nonce: '', cipherText: 'native-ciphertext', mac: ''),
      ),
    );

    expect(() => service.decryptPayload(secret, Uint8List(32)), throwsA(isA<SecretBoxAuthenticationError>()));
    result.dek.fillRange(0, result.dek.length, 0);
  });

  test('저장 모델을 직렬화한 뒤에도 같은 DEK로 복호화한다', () async {
    final result = await service.encryptPayload(mnemonic: mnemonic, passphrase: passphrase);
    final encoded =
        HotWalletSecret(
          version: HotWalletSecret.currentVersion,
          encryptedPayload: result.encryptedPayload,
          deviceWrappedDek: const DeviceWrappedDek(
            protection: DeviceKeyProtection.androidStrongBox,
            alias: 'strongbox-key',
            encryptedDek: EncryptedValue(nonce: '', cipherText: 'wrapped-dek', mac: ''),
          ),
        ).encode();
    final decoded = HotWalletSecret.decode(encoded);
    final plaintext = await service.decryptPayload(decoded, result.dek);

    expect(decoded.deviceWrappedDek.protection, DeviceKeyProtection.androidStrongBox);
    expect(decoded.deviceWrappedDek.alias, 'strongbox-key');
    expect(plaintext.mnemonic, utf8.decode(mnemonic));
    result.dek.fillRange(0, result.dek.length, 0);
  });

  test('SecureStorage fallback 키로 DEK를 AES-256-GCM 래핑한다', () async {
    final dek = service.randomBytes(HotWalletCryptoService.keyLength);
    final deviceKek = service.randomBytes(HotWalletCryptoService.keyLength);
    final wrapped = await service.encrypt(dek, deviceKek);
    final unwrapped = await service.decrypt(wrapped, deviceKek);

    expect(unwrapped, dek);
    expect(wrapped.nonce, isNotEmpty);
    expect(wrapped.mac, isNotEmpty);
    dek.fillRange(0, dek.length, 0);
    deviceKek.fillRange(0, deviceKek.length, 0);
    unwrapped.fillRange(0, unwrapped.length, 0);
  });
}
