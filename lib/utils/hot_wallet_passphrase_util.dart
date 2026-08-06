import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';

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
