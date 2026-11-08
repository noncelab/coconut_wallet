import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_sender.dart';
import 'package:coconut_wallet/utils/transaction_intent_validator.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const otherMnemonic = 'legal winner thank year wave sausage worth useful legal winner thank yellow';
  late SingleSignatureVault sender;
  late SingleSignatureVault receiver;
  late Transaction original;

  setUp(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    sender = SingleSignatureVault.fromMnemonic(Uint8List.fromList(utf8.encode(mnemonic)));
    receiver = SingleSignatureVault.fromMnemonic(Uint8List.fromList(utf8.encode(otherMnemonic)));
    original = Transaction.forSinglePayment(
      [Utxo(List.filled(32, '11').join(), 0, 100000, '${sender.derivationPath}/0/0')],
      receiver.getAddress(0),
      '${sender.derivationPath}/1/0',
      40000,
      2,
      sender,
    );
  });

  tearDown(() {
    sender.keyStore.wipeSeed();
    receiver.keyStore.wipeSeed();
    NetworkType.setNetworkType(NetworkType.testnet);
  });

  bool isSenderOutput(TransactionOutput output) => output.getAddress() == sender.getAddress(0, isChange: true);

  /// The receiver's proposal: its input appended, its output raised by that
  /// input's value, and [feeContribution] taken from the sender's change.
  Transaction proposalFrom(
    Transaction tx, {
    int receiverInput = 30000,
    int feeContribution = 150,
    bool dropFirstInput = false,
  }) {
    final inputs = [
      for (final input in tx.inputs.skip(dropFirstInput ? 1 : 0))
        TransactionInput.forPayment(input.transactionHash, input.index, sequence: input.sequence),
      TransactionInput.forPayment(List.filled(32, '22').join(), 3, sequence: tx.inputs.first.sequence),
    ];
    final outputs = [
      for (final output in tx.outputs)
        TransactionOutput.forPayment(
          isSenderOutput(output) ? output.amount - feeContribution : output.amount + receiverInput,
          output.getAddress(),
        ),
    ];
    return Transaction.parseUnsignedTransaction(
      _legacyHex(Transaction.withInputsAndOutputs(inputs, outputs, AddressType.p2wpkh)),
    );
  }

  PayjoinCheckedProposal checkedFor(Transaction proposal) =>
      PayjoinCheckedProposal.forTesting(_bareSignablePsbt(proposal));

  TransactionIntentValidationResult validate(Transaction signed, PayjoinCheckedProposal checked) =>
      TransactionIntentValidator.validatePayjoinProposal(original, signed, checked, isOwnOutput: isSenderOutput);

  test('the fixture builds what coconut_lib builds', () {
    final copy = Transaction.parseUnsignedTransaction(_legacyHex(original));
    expect(TransactionIntentValidator.matches(original, copy), isTrue);
  });

  test('accepts a proposal that adds an input and pays the receiver more', () {
    final proposal = proposalFrom(original);
    expect(validate(proposal, checkedFor(proposal)).isValid, isTrue);
    expect(
      TransactionIntentValidator.validate(original, proposal).isValid,
      isFalse,
      reason: 'the plain intent check would reject every payjoin',
    );
  });

  test('rejects a signed transaction that differs from the one payjoin checked', () {
    final checked = checkedFor(proposalFrom(original));
    final other = proposalFrom(original, feeContribution: 5000);
    final result = validate(other, checked);
    expect(result.isValid, isFalse);
    expect(result.mismatch, TransactionIntentMismatch.outputAmount);
  });

  test('rejects a proposal that drops one of our inputs', () {
    final proposal = proposalFrom(original, dropFirstInput: true);
    final result = validate(proposal, checkedFor(proposal));
    expect(result.mismatch, TransactionIntentMismatch.inputTransactionHash);
  });

  test('rejects a proposal that pays the receiver less than the Original', () {
    final proposal = proposalFrom(original, receiverInput: -1000);
    final result = validate(proposal, checkedFor(proposal));
    expect(result.mismatch, TransactionIntentMismatch.outputAmount);
  });

  test('ensurePayjoinProposalMatches throws on a mismatch', () {
    final proposal = proposalFrom(original, dropFirstInput: true);
    expect(
      () => TransactionIntentValidator.ensurePayjoinProposalMatches(
        original,
        proposal,
        checkedFor(proposal),
        isOwnOutput: isSenderOutput,
      ),
      throwsA(isA<TransactionIntentMismatchException>()),
    );
  });
}

String _legacyHex(Transaction tx) {
  final buffer = StringBuffer(tx.version)..write(_varint(tx.inputs.length));
  for (final input in tx.inputs) {
    buffer.write(input.serialize());
  }
  buffer.write(_varint(tx.outputs.length));
  for (final output in tx.outputs) {
    buffer.write(output.serialize());
  }
  buffer.write(tx.lockTime);
  return buffer.toString();
}

/// A PSBT carrying only the unsigned transaction and empty input and output
/// maps: enough for reading back its unsigned transaction.
String _bareSignablePsbt(Transaction tx) {
  final unsigned = _legacyHex(tx);
  final psbt =
      '70736274ff'
      '0100${_varint(unsigned.length ~/ 2)}$unsigned'
      '00'
      '${'00' * tx.inputs.length}'
      '${'00' * tx.outputs.length}';
  return base64Encode(hex.decode(psbt));
}

String _varint(int n) => n < 0xfd ? n.toRadixString(16).padLeft(2, '0') : throw UnimplementedError();
