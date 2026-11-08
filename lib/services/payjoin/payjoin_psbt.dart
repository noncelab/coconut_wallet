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

/// Marks the sender's inputs of a receiver's payjoin PSBT as finalized, using
/// their final scripts from the sender's Original ([originalTx], raw bytes).
///
/// payjoin hands the receiver its proposal with the sender's signatures
/// removed, since they do not cover the new transaction. coconut_lib signs a
/// PSBT only if every input is either ours or already finalized, so that a
/// PSBT cannot pass off another input as ours. Restoring the sender's own
/// final scripts lets the signer recognise those inputs as the sender's and
/// skip them. They are not valid for the proposal and must be removed again
/// with [withoutCounterpartyFinals] before the proposal goes back to payjoin.
String withCounterpartyInputsFinal(String psbtBase64, Uint8List originalTx) {
  final psbt = Psbt.parse(psbtBase64);
  final inputMaps = psbt.toKeyMap()['inputs'] as List<dynamic>;
  final originalInputs = {for (final input in _parseTx(originalTx).inputs) _outpoint(input): input};
  final proposalInputs = psbt.unsignedTransaction!.inputs;
  for (var i = 0; i < proposalInputs.length; i++) {
    final original = originalInputs[_outpoint(proposalInputs[i])];
    if (original == null) continue;
    final map = inputMaps[i] as Map<String, dynamic>;
    map['08'] = _serializeWitness(original.witnessList);
    final scriptSig = original.scriptSig.rawSerialize();
    if (scriptSig.isNotEmpty) map['07'] = scriptSig;
  }
  return Psbt.parse(psbt.serialize()).serialize();
}

/// Removes the final scripts [withCounterpartyInputsFinal] restored, so the
/// sender's inputs go back to payjoin unsigned as it requires.
String withoutCounterpartyFinals(String psbtBase64, Uint8List originalTx) {
  final psbt = Psbt.parse(psbtBase64);
  final inputMaps = psbt.toKeyMap()['inputs'] as List<dynamic>;
  final senderOutpoints = {for (final input in _parseTx(originalTx).inputs) _outpoint(input)};
  final proposalInputs = psbt.unsignedTransaction!.inputs;
  for (var i = 0; i < proposalInputs.length; i++) {
    if (!senderOutpoints.contains(_outpoint(proposalInputs[i]))) continue;
    (inputMaps[i] as Map<String, dynamic>).removeWhere((key, _) => key == '07' || key == '08');
  }
  return Psbt.parse(psbt.serialize()).serialize();
}

Transaction _parseTx(Uint8List raw) => Transaction.parse(_hex(raw));

String _outpoint(TransactionInput input) => '${input.transactionHash}:${input.index}';

/// BIP 141 witness serialization: item count, then each item with its length.
/// coconut_lib parses an empty witness item as "00".
String _serializeWitness(List<String> items) {
  final buffer = StringBuffer(_varint(items.length));
  for (final item in items) {
    if (item.isEmpty || item == '00') {
      buffer.write('00');
    } else {
      buffer
        ..write(_varint(item.length ~/ 2))
        ..write(item);
    }
  }
  return buffer.toString();
}

String _varint(int n) {
  if (n < 0xfd) return _hex([n]);
  if (n <= 0xffff) return _hex([0xfd, n & 0xff, n >> 8]);
  return _hex([0xfe, n & 0xff, (n >> 8) & 0xff, (n >> 16) & 0xff, (n >> 24) & 0xff]);
}
