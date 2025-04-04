import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class WalletDataManagerCryptography {
  static final AesCbc _aesCbc = AesCbc.with256bits(macAlgorithm: Hmac.sha256());

  late List<int> _nonce;
  String get nonce => base64Encode(_nonce);

  SecretKey? _secretKey;

  WalletDataManagerCryptography({List<int>? nonce}) {
    if (nonce != null) {
      _nonce = nonce;
    } else {
      _nonce = _aesCbc.newNonce();
    }
  }

  Future<void> initialize({required int iterations, required String hashedPin}) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations, // 적절한 반복 횟수 설정
      bits: 256,
    );

    _secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(hashedPin)),
      nonce: _nonce,
    );
  }

  Future<String> encrypt(String plainText) async {
    assert(_secretKey != null);

    SecretBox secretBox = await _aesCbc.encrypt(utf8.encode(plainText), secretKey: _secretKey!);

    return '${base64Encode(secretBox.nonce)}:${base64Encode(secretBox.cipherText)}:${base64Encode(secretBox.mac.bytes)}';
  }

  Future<String> decrypt(String encrypted) async {
    assert(_secretKey != null);

    List<String> splited = encrypted.split(':');
    var decrypted = await _aesCbc.decrypt(
        SecretBox(base64Decode(splited[1]),
            nonce: base64Decode(splited[0]), mac: Mac(base64Decode(splited[2]))),
        secretKey: _secretKey!);

    return utf8.decode(decrypted);
  }
}
