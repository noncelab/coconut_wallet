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
    final payload = _encodePayload(mnemonic, passphrase);

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
      return _decodePayload(bytes);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  /// mnemonic/passphrase는 평문 상태에서 절대 String으로 변환하지 않는다.
  /// (Dart String은 immutable이라 사용 후 메모리에서 지울 수 없다.)
  ///
  /// Layout: [mnemonicLength(4B, big-endian)][mnemonic][passphraseLength(4B, big-endian)][passphrase]
  Uint8List _encodePayload(Uint8List mnemonic, Uint8List passphrase) {
    final payload = Uint8List(8 + mnemonic.length + passphrase.length);
    final view = ByteData.sublistView(payload);
    var offset = 0;
    view.setUint32(offset, mnemonic.length, Endian.big);
    offset += 4;
    payload.setRange(offset, offset + mnemonic.length, mnemonic);
    offset += mnemonic.length;
    view.setUint32(offset, passphrase.length, Endian.big);
    offset += 4;
    payload.setRange(offset, offset + passphrase.length, passphrase);
    return payload;
  }

  HotWalletPlaintext _decodePayload(Uint8List bytes) {
    if (bytes.length < 8) {
      throw const FormatException('Hot wallet payload is too short');
    }
    final view = ByteData.sublistView(bytes);
    var offset = 0;
    final mnemonicLength = view.getUint32(offset, Endian.big);
    offset += 4;
    if (offset + mnemonicLength + 4 > bytes.length) {
      throw const FormatException('Hot wallet payload mnemonic length is invalid');
    }
    final mnemonic = bytes.sublist(offset, offset + mnemonicLength);
    offset += mnemonicLength;
    final passphraseLength = view.getUint32(offset, Endian.big);
    offset += 4;
    if (offset + passphraseLength != bytes.length) {
      throw const FormatException('Hot wallet payload passphrase length is invalid');
    }
    final passphrase = bytes.sublist(offset, offset + passphraseLength);
    return HotWalletPlaintext(mnemonic: mnemonic, passphrase: passphrase);
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
