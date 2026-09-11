import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/foundation.dart';

typedef _PassphraseMatchBytesArguments = ({Uint8List mnemonic, String passphrase, String descriptor});

bool _doesPassphraseMatchDescriptorInBackground(_PassphraseMatchBytesArguments arguments) {
  return doesPassphraseMatchDescriptor(
    mnemonic: arguments.mnemonic,
    passphrase: arguments.passphrase,
    descriptor: arguments.descriptor,
  );
}

/// [mnemonic]은 화면에 표시할 필요가 없는 경우(예: 서명용 패스프레이즈 재확인) 쓰는
/// 니모닉을 String으로 변환하지 않기 위한 버전이다. 전달받은 [mnemonic]은 내부에서
/// 복사해서만 사용하므로 호출자가 들고 있는 원본 바이트는 변경/삭제되지 않는다.
bool doesPassphraseMatchDescriptor({
  required Uint8List mnemonic,
  required String passphrase,
  required String descriptor,
}) {
  final mnemonicBytes = Uint8List.fromList(mnemonic);
  final passphraseBytes = Uint8List.fromList(utf8.encode(passphrase));
  final seed = Seed.fromMnemonic(mnemonicBytes, passphrase: passphraseBytes);
  try {
    return SingleSignatureVault.fromSeed(seed).descriptor == descriptor;
  } finally {
    seed.wipe();
    mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
    passphraseBytes.fillRange(0, passphraseBytes.length, 0);
  }
}

Future<bool> doesPassphraseMatchDescriptorAsync({
  required Uint8List mnemonic,
  required String passphrase,
  required String descriptor,
}) {
  return compute(_doesPassphraseMatchDescriptorInBackground, (
    mnemonic: mnemonic,
    passphrase: passphrase,
    descriptor: descriptor,
  ));
}
