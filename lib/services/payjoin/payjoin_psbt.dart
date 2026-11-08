import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';

/// Adds this wallet's BIP 32 derivation to each unfinalized input that spends
/// one of its own addresses but lacks one, and returns the PSBT.
///
/// coconut_lib signs only inputs whose derivation names our key. Payjoin
/// PSBTs often lack it: the receiver adds its input with only the spent
/// output (the BIP 77 bindings have no field for derivations), and the
/// sender gets its inputs back without derivations when the Original was
/// finalized. The derivation is added only when the address derived from it
/// is the one the input spends, so nothing in the PSBT can steer which key
/// signs.
///
/// [derivationPathOf] maps an address to its wallet derivation path such as
/// `m/84'/1'/0'/0/5`, or null if the address is not ours.
String addOwnDerivations(
  String psbtBase64, {
  required SingleSignatureWallet wallet,
  required String? Function(String address) derivationPathOf,
}) {
  final psbt = Psbt.parse(psbtBase64);
  final fingerprint = wallet.keyStore.masterFingerprint.toLowerCase();
  final inputMaps = psbt.toKeyMap()['inputs'] as List<dynamic>;
  var changed = false;

  for (var i = 0; i < psbt.inputs.length; i++) {
    final input = psbt.inputs[i];
    final witnessUtxo = input.witnessUtxo;
    if (input.isFinalized || witnessUtxo == null) continue;
    if (input.bip32Derivation?.any((d) => d.masterFingerprint.toLowerCase() == fingerprint) ?? false) continue;

    final address = witnessUtxo.scriptPubKey.getAddress();
    final path = derivationPathOf(address);
    if (path == null) continue;
    final (isChange, index) = _changeAndIndex(path);
    if (wallet.getAddress(index, isChange: isChange) != address) continue;

    final publicKey = wallet.keyStore.getPublicKey(index, isChange: isChange);
    (inputMaps[i] as Map<String, dynamic>)['06$publicKey'] = fingerprint + _hex(_serializePath(path));
    changed = true;
  }
  return changed ? Psbt.parse(psbt.serialize()).serialize() : psbtBase64;
}

(bool, int) _changeAndIndex(String path) {
  final parts = path.split('/');
  return (parts[parts.length - 2] == '1', int.parse(parts.last));
}

/// BIP 174 key origin path: each index as a little-endian uint32, hardened
/// indices with the top bit set.
Uint8List _serializePath(String path) {
  final bytes = BytesBuilder();
  for (final part in path.split('/').skip(1)) {
    final hardened = part.endsWith("'") || part.endsWith('h');
    var index = int.parse(hardened ? part.substring(0, part.length - 1) : part);
    if (hardened) index += 0x80000000;
    bytes.add([index & 0xff, (index >> 8) & 0xff, (index >> 16) & 0xff, (index >> 24) & 0xff]);
  }
  return bytes.toBytes();
}

String _hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
