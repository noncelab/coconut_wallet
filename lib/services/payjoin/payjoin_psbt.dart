import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';

/// Adds this wallet's BIP 32 derivation to each unfinalized input that spends
/// one of its own addresses, and to each output that pays one, where it is
/// missing, and returns the PSBT.
///
/// coconut_lib signs only inputs whose derivation names our key. Payjoin
/// PSBTs often lack it: the receiver adds its input with only the spent
/// output (the BIP 77 bindings have no field for derivations), and the
/// sender gets its inputs back without derivations when the Original was
/// finalized. A signing device that has no address index, such as Coconut
/// Vault, also tells our outputs from the counterparty's only by their
/// derivations, so a receiver's output that came from the sender's Original
/// would read as money leaving the wallet. The derivation is added only when
/// the address derived from it is the one the input spends or the output
/// pays, so nothing in the PSBT can steer which key signs.
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
  final keyMap = psbt.toKeyMap();
  final inputMaps = keyMap['inputs'] as List<dynamic>;
  final outputMaps = keyMap['outputs'] as List<dynamic>;
  bool isOurs(DerivationPath d) => d.masterFingerprint.toLowerCase() == fingerprint;

  /// The BIP 32 key-value pair for [address], or null when its path does
  /// not derive it.
  MapEntry<String, String>? derivationFor(String address) {
    final path = derivationPathOf(address);
    if (path == null) return null;
    final (isChange, index) = _changeAndIndex(path);
    if (wallet.getAddress(index, isChange: isChange) != address) return null;
    final publicKey = wallet.keyStore.getPublicKey(index, isChange: isChange);
    return MapEntry(publicKey, fingerprint + _hex(_serializePath(path)));
  }

  var changed = false;
  for (var i = 0; i < psbt.inputs.length; i++) {
    final input = psbt.inputs[i];
    final witnessUtxo = input.witnessUtxo;
    if (input.isFinalized || witnessUtxo == null) continue;
    if (input.bip32Derivation?.any(isOurs) ?? false) continue;
    final entry = derivationFor(witnessUtxo.scriptPubKey.getAddress());
    if (entry == null) continue;
    (inputMaps[i] as Map<String, dynamic>)['06${entry.key}'] = entry.value;
    changed = true;
  }
  for (var i = 0; i < psbt.outputs.length; i++) {
    final output = psbt.outputs[i];
    if (output.bip32Derivations.any(isOurs)) continue;
    final String address;
    try {
      address = output.outAddress;
    } catch (_) {
      continue; // OP_RETURN and other scripts without an address
    }
    final entry = derivationFor(address);
    if (entry == null) continue;
    (outputMaps[i] as Map<String, dynamic>)['02${entry.key}'] = entry.value;
    changed = true;
  }
  return changed ? Psbt.parse(psbt.serialize()).serialize() : psbtBase64;
}

/// Finalizes the inputs a signing device signed in [signedPsbtBase64], the
/// device's answer to [shownPsbtBase64], and returns the PSBT.
///
/// Coconut Vault and other air-gapped signers return single-signature
/// inputs signed but not finalized; payjoin wants them final. Each input
/// the device was asked to sign must carry a valid signature for this
/// transaction, unless the device finalized it itself, in which case the
/// signature is left to the counterparty's checks. Throws
/// [PayjoinSignedPsbtMismatch] when the device answered for another
/// transaction or left one of those inputs unsigned.
String finalizeDeviceSignedPsbt(String signedPsbtBase64, {required String shownPsbtBase64}) {
  final shown = Psbt.parse(shownPsbtBase64);
  final signed = Psbt.parse(signedPsbtBase64);
  final shownTx = shown.unsignedTransaction!;
  if (signed.unsignedTransaction?.transactionHash != shownTx.transactionHash) {
    throw const PayjoinSignedPsbtMismatch('the signed PSBT is for another transaction');
  }
  // A signature over one input commits to the whole unsigned transaction
  // but not to the other inputs' witnesses (BIP 143), so each one checks out
  // even while a counterparty's input still shows a final script that does
  // not fit this transaction.
  final check = Transaction.parseUnsignedTransaction(shownTx.serialize());
  for (var i = 0; i < shown.inputs.length; i++) {
    if (shown.inputs[i].isFinalized) continue;
    final spent = shown.inputs[i].witnessUtxo;
    if (signed.inputs[i].isFinalized) continue;
    final signatures = signed.inputs[i].partialSig;
    if (spent == null || signatures == null || signatures.isEmpty) {
      throw PayjoinSignedPsbtMismatch('input $i was not signed');
    }
    check.inputs[i].setSignature(AddressType.p2wpkh, signatures);
    if (!check.validateEcdsa(i, spent)) throw PayjoinSignedPsbtMismatch('input $i has no valid signature');
  }
  final Psbt finalized;
  try {
    finalized = signed.finalizeInputs();
  } on PsbtException catch (e) {
    throw PayjoinSignedPsbtMismatch('an input could not be finalized: $e');
  }
  return finalized.serialize();
}

/// The Original a payjoin sender posts, from [signedPsbtBase64]: every
/// input finalized, so the receiver can broadcast it as the fallback, and
/// the key origins kept, so payjoin can restore them on our inputs of the
/// receiver's proposal for the second signature.
String finalizeOriginalForPayjoin(String signedPsbtBase64) {
  final psbt = Psbt.parse(signedPsbtBase64);
  if (psbt.inputs.every((input) => input.isFinalized)) return signedPsbtBase64;
  return psbt.finalizeInputs(keepDerivations: true).serialize();
}

class PayjoinSignedPsbtMismatch implements Exception {
  const PayjoinSignedPsbtMismatch(this.message);

  final String message;

  @override
  String toString() => 'Signed PSBT does not match: $message';
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
