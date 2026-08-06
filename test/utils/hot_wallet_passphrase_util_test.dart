import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/hot_wallet_passphrase_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const passphrase = 'coconut-passphrase';

  test('입력한 패스프레이즈로 기존 descriptor를 재현하면 일치한다', () {
    final mnemonicBytes = Uint8List.fromList(utf8.encode(mnemonic));
    final passphraseBytes = Uint8List.fromList(utf8.encode(passphrase));
    final seed = Seed.fromMnemonic(mnemonicBytes, passphrase: passphraseBytes);
    final descriptor = SingleSignatureVault.fromSeed(seed).descriptor;
    seed.wipe();
    mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
    passphraseBytes.fillRange(0, passphraseBytes.length, 0);

    expect(doesPassphraseMatchDescriptor(mnemonic: mnemonic, passphrase: passphrase, descriptor: descriptor), isTrue);
    expect(
      doesPassphraseMatchDescriptor(mnemonic: mnemonic, passphrase: 'wrong-passphrase', descriptor: descriptor),
      isFalse,
    );
  });
}
