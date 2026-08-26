import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:cryptography/cryptography.dart';

class HotWalletCryptoService {
  HotWalletCryptoService({Random? random}) : _random = random ?? Random.secure();

  static const int keyLength = 32;
  static const int _nonceLength = 12;

  final Random _random;
  final AesGcm _aes = AesGcm.with256bits();

  Future<({EncryptedValue encryptedPayload, Uint8List dek})> encryptPayload({
    required Uint8List mnemonic,
    required Uint8List passphrase,
  }) async {
    final dek = randomBytes(keyLength);
    final payload = Uint8List.fromList(
      utf8.encode(jsonEncode({'mnemonic': utf8.decode(mnemonic), 'passphrase': utf8.decode(passphrase)})),
    );

    try {
      return (encryptedPayload: await encrypt(payload, dek), dek: dek);
    } finally {
      payload.fillRange(0, payload.length, 0);
    }
  }

  Future<HotWalletPlaintext> decryptPayload(HotWalletSecret secret, Uint8List dek) async {
    if (secret.version != HotWalletSecret.currentVersion) {
      throw const FormatException('Unsupported hot wallet secret version');
    }
    final bytes = await decrypt(secret.encryptedPayload, dek);
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return HotWalletPlaintext(mnemonic: json['mnemonic'] as String, passphrase: json['passphrase'] as String);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<EncryptedValue> encrypt(List<int> clearText, List<int> key) async {
    if (key.length != keyLength) {
      throw const FormatException('AES-256-GCM key must be 32 bytes');
    }
    final nonce = randomBytes(_nonceLength);
    final box = await _aes.encrypt(clearText, secretKey: SecretKey(key), nonce: nonce);
    return EncryptedValue(
      nonce: base64Encode(box.nonce),
      cipherText: base64Encode(box.cipherText),
      mac: base64Encode(box.mac.bytes),
    );
  }

  Future<Uint8List> decrypt(EncryptedValue value, List<int> key) async {
    if (key.length != keyLength) {
      throw const FormatException('AES-256-GCM key must be 32 bytes');
    }
    final clearText = await _aes.decrypt(
      SecretBox(base64Decode(value.cipherText), nonce: base64Decode(value.nonce), mac: Mac(base64Decode(value.mac))),
      secretKey: SecretKey(key),
    );
    return Uint8List.fromList(clearText);
  }

  Uint8List randomBytes(int length) => Uint8List.fromList(List<int>.generate(length, (_) => _random.nextInt(256)));
}
