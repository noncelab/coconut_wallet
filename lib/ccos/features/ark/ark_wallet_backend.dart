import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';

abstract interface class ArkWalletBackend {
  Future<String> fingerprintOf(Uint8List mnemonic);
  Future<void> create(String fingerprint, Uint8List mnemonic, {required bool restore});
  Future<void> open(String fingerprint, Uint8List mnemonic);
  bool isOpen(String fingerprint);
  Future<ArkBalance> balance(String fingerprint);
  Future<bool> isRecoveryPending(String fingerprint);
  Future<List<String>> listFingerprints();
  Future<void> wipeAll();
}
