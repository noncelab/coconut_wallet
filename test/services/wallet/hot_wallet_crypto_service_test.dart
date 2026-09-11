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
    expect(utf8.decode(plaintext.mnemonic), utf8.decode(mnemonic));
    expect(utf8.decode(plaintext.passphrase), 'secret');
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
    expect(utf8.decode(plaintext.mnemonic), utf8.decode(mnemonic));
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

  test('빈 패스프레이즈(서명 시 직접 입력하는 경우)도 왕복 복호화된다', () async {
    final emptyPassphrase = Uint8List(0);
    final result = await service.encryptPayload(mnemonic: mnemonic, passphrase: emptyPassphrase);
    final secret = _secretWith(result.encryptedPayload);
    final plaintext = await service.decryptPayload(secret, result.dek);

    expect(plaintext.mnemonic, mnemonic);
    expect(plaintext.passphrase, isEmpty);
    result.dek.fillRange(0, result.dek.length, 0);
  });

  test('평문 payload가 최소 길이보다 짧으면 거부한다', () async {
    final dek = service.randomBytes(HotWalletCryptoService.keyLength);
    final corrupted = await service.encrypt(Uint8List(4), dek);
    final secret = _secretWith(corrupted);

    // decryptPayload가 dek를 실제로 다 사용한 뒤에 wipe하도록 await로 완료를 기다린다.
    // (await 없이 dek.fillRange를 바로 호출하면 진행 중인 복호화가 잘못된 키로
    //  실패해 의도한 FormatException 대신 인증 오류가 발생한다.)
    await expectLater(() => service.decryptPayload(secret, dek), throwsA(isA<FormatException>()));
    dek.fillRange(0, dek.length, 0);
  });

  test('mnemonic 길이 필드가 실제 payload보다 크면 거부한다', () async {
    final dek = service.randomBytes(HotWalletCryptoService.keyLength);
    final malformed = Uint8List(8)..buffer.asByteData().setUint32(0, 999, Endian.big);
    final corrupted = await service.encrypt(malformed, dek);
    final secret = _secretWith(corrupted);

    await expectLater(() => service.decryptPayload(secret, dek), throwsA(isA<FormatException>()));
    dek.fillRange(0, dek.length, 0);
  });

  test('passphrase 길이 필드가 남은 바이트 수와 다르면 거부한다', () async {
    final dek = service.randomBytes(HotWalletCryptoService.keyLength);
    final malformed = Uint8List(9); // mnemonicLength=0, passphraseLength=0 이지만 뒤에 1바이트가 더 있음
    malformed.buffer.asByteData().setUint32(4, 0, Endian.big);
    final corrupted = await service.encrypt(malformed, dek);
    final secret = _secretWith(corrupted);

    await expectLater(() => service.decryptPayload(secret, dek), throwsA(isA<FormatException>()));
    dek.fillRange(0, dek.length, 0);
  });
}

HotWalletSecret _secretWith(EncryptedValue encryptedPayload) => HotWalletSecret(
  version: HotWalletSecret.currentVersion,
  encryptedPayload: encryptedPayload,
  deviceWrappedDek: const DeviceWrappedDek(
    protection: DeviceKeyProtection.androidTee,
    alias: 'device-key',
    encryptedDek: EncryptedValue(nonce: '', cipherText: 'native-ciphertext', mac: ''),
  ),
);
