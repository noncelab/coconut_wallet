import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/nfkd_util.dart';
import 'package:flutter/foundation.dart';

typedef _PassphraseMatchBytesArguments =
    ({Uint8List mnemonic, Uint8List passphrase, String descriptor, String networkType});

bool _doesPassphraseMatchDescriptorInBackground(_PassphraseMatchBytesArguments arguments) {
  try {
    NetworkType.setNetworkType(NetworkType.getNetworkType(arguments.networkType));
    return _matchesDescriptor(arguments.mnemonic, arguments.passphrase, arguments.descriptor);
  } finally {
    arguments.mnemonic.fillRange(0, arguments.mnemonic.length, 0);
    arguments.passphrase.fillRange(0, arguments.passphrase.length, 0);
  }
}

bool _matchesDescriptor(Uint8List mnemonic, Uint8List passphrase, String descriptor) {
  Seed? seed;
  try {
    seed = Seed.fromMnemonic(mnemonic, passphrase: passphrase);
    return SingleSignatureVault.fromSeed(seed).descriptor == descriptor;
  } finally {
    seed?.wipe();
  }
}

/// 호출자 소유 니모닉은 복사해서 사용하며 변경하지 않는다.
/// 정규화한 패스프레이즈와 니모닉 사본은 실패 시에도 지운다.
bool doesPassphraseMatchDescriptor({
  required Uint8List mnemonic,
  required String passphrase,
  required String descriptor,
}) {
  final mnemonicBytes = Uint8List.fromList(mnemonic);
  Uint8List? passphraseBytes;
  try {
    passphraseBytes = NfkdUtil.encodeNfkd(passphrase);
    return _matchesDescriptor(mnemonicBytes, passphraseBytes, descriptor);
  } finally {
    mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
    passphraseBytes?.fillRange(0, passphraseBytes.length, 0);
  }
}

Future<bool> doesPassphraseMatchDescriptorAsync({
  required Uint8List mnemonic,
  required String passphrase,
  required String descriptor,
}) async {
  final mnemonicBytes = Uint8List.fromList(mnemonic);
  Uint8List? passphraseBytes;
  try {
    // String을 isolate로 전달하지 않고 정규화한 바이트만 전달한다.
    passphraseBytes = NfkdUtil.encodeNfkd(passphrase);
    return await compute(_doesPassphraseMatchDescriptorInBackground, (
      mnemonic: mnemonicBytes,
      passphrase: passphraseBytes,
      descriptor: descriptor,
      networkType: NetworkType.currentNetworkType.toString(),
    ));
  } finally {
    // isolate 내부 사본과 별개로 메인 isolate의 전달용 사본도 정리한다.
    mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
    passphraseBytes?.fillRange(0, passphraseBytes.length, 0);
  }
}
