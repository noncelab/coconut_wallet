import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/hot_wallet_passphrase_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const passphrase = 'coconut-passphrase';

  test('입력한 패스프레이즈로 기존 descriptor를 재현하면 일치한다', () async {
    final mnemonicBytes = Uint8List.fromList(utf8.encode(mnemonic));
    final passphraseBytes = Uint8List.fromList(utf8.encode(passphrase));
    final seed = Seed.fromMnemonic(Uint8List.fromList(mnemonicBytes), passphrase: passphraseBytes);
    final descriptor = SingleSignatureVault.fromSeed(seed).descriptor;
    seed.wipe();

    // doesPassphraseMatchDescriptorBytes는 mnemonicBytes를 복사해서만 쓰므로
    // 같은 배열로 여러 번 검증해도 문제없이 동작한다.
    expect(
      doesPassphraseMatchDescriptor(mnemonic: mnemonicBytes, passphrase: passphrase, descriptor: descriptor),
      isTrue,
    );
    expect(
      doesPassphraseMatchDescriptor(mnemonic: mnemonicBytes, passphrase: 'wrong-passphrase', descriptor: descriptor),
      isFalse,
    );
    expect(
      await doesPassphraseMatchDescriptorAsync(mnemonic: mnemonicBytes, passphrase: passphrase, descriptor: descriptor),
      isTrue,
    );
  });

  test('doesPassphraseMatchDescriptorBytes 호출 후에도 전달한 mnemonic 원본 바이트는 지워지지 않는다', () async {
    // Seed.fromMnemonic은 전달받은 Uint8List를 복사하지 않고 그대로 들고 있다가
    // seed.wipe()에서 그 배열을 직접 0으로 채운다. doesPassphraseMatchDescriptorBytes가
    // 내부에서 복사본을 만들어 쓰지 않으면, 화면에서 오답 후 재시도할 때 니모닉이
    // 이미 지워져 있는 문제가 생긴다.
    final mnemonicBytes = Uint8List.fromList(utf8.encode(mnemonic));
    final mnemonicSnapshot = Uint8List.fromList(mnemonicBytes);

    doesPassphraseMatchDescriptor(mnemonic: mnemonicBytes, passphrase: 'wrong-passphrase', descriptor: '');
    expect(mnemonicBytes, mnemonicSnapshot);

    // 같은 mnemonic 바이트로 다시 검증해도(재시도) 문제없이 동작해야 한다.
    final mnemonicBytes2 = Uint8List.fromList(utf8.encode(mnemonic));
    final passphraseBytes = Uint8List.fromList(utf8.encode(passphrase));
    final seed = Seed.fromMnemonic(Uint8List.fromList(mnemonicBytes2), passphrase: passphraseBytes);
    final descriptor = SingleSignatureVault.fromSeed(seed).descriptor;
    seed.wipe();

    expect(
      doesPassphraseMatchDescriptor(mnemonic: mnemonicBytes2, passphrase: passphrase, descriptor: descriptor),
      isTrue,
    );
    expect(mnemonicBytes2, isNot(everyElement(0)));
  });
}
