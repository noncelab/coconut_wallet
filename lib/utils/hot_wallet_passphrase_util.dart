import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/foundation.dart';

typedef _PassphraseMatchArguments = ({String mnemonic, String passphrase, String descriptor});

bool _doesPassphraseMatchDescriptorInBackground(_PassphraseMatchArguments arguments) {
  return doesPassphraseMatchDescriptor(
    mnemonic: arguments.mnemonic,
    passphrase: arguments.passphrase,
    descriptor: arguments.descriptor,
  );
}

bool doesPassphraseMatchDescriptor({required String mnemonic, required String passphrase, required String descriptor}) {
  final mnemonicBytes = Uint8List.fromList(utf8.encode(mnemonic));
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
  required String mnemonic,
  required String passphrase,
  required String descriptor,
}) {
  return compute(_doesPassphraseMatchDescriptorInBackground, (
    mnemonic: mnemonic,
    passphrase: passphrase,
    descriptor: descriptor,
  ));
}
