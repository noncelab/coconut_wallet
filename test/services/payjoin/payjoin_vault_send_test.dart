import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_psbt.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_sender.dart';
import 'package:coconut_wallet/utils/transaction_intent_validator.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

/// A sender whose wallet is watch-only and signs with Coconut Vault makes
/// two trips to the vault: the Original, then the receiver's proposal. Both
/// vault answers come back signed but not finalized.
void main() {
  const senderWords = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  const receiverWords = 'legal winner thank year wave sausage worth useful legal winner thank yellow';
  late SingleSignatureVault senderVault;
  late SingleSignatureWallet senderWallet;
  late SingleSignatureVault receiver;
  late SingleSignatureWallet receiverWallet;

  setUp(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    senderVault = SingleSignatureVault.fromMnemonic(Uint8List.fromList(utf8.encode(senderWords)));
    senderWallet = SingleSignatureWallet.fromDescriptor(senderVault.descriptor);
    receiver = SingleSignatureVault.fromMnemonic(Uint8List.fromList(utf8.encode(receiverWords)));
    receiverWallet = SingleSignatureWallet.fromDescriptor(receiver.descriptor);
  });

  tearDown(() {
    senderVault.keyStore.wipeSeed();
    receiver.keyStore.wipeSeed();
    NetworkType.setNetworkType(NetworkType.testnet);
  });

  String? Function(String) pathsOf(SingleSignatureWallet wallet, String accountPath) => (address) {
    for (final isChange in [false, true]) {
      for (var i = 0; i < 10; i++) {
        if (wallet.getAddress(i, isChange: isChange) == address) return '$accountPath/${isChange ? 1 : 0}/$i';
      }
    }
    return null;
  };

  test('the Original and then the proposal, each signed by the vault and finalized by the wallet', () {
    final senderPaths = pathsOf(senderWallet, senderVault.derivationPath);
    final original = Transaction.forSinglePayment(
      [Utxo(List.filled(32, '11').join(), 0, 100000, '${senderVault.derivationPath}/0/0')],
      receiver.getAddress(0),
      '${senderVault.derivationPath}/1/0',
      40000,
      2,
      senderVault,
    );
    final unsigned = Psbt.fromTransaction(original, senderWallet).serialize();

    // Trip 1: the vault signs the Original as it signs any send.
    final firstAnswer = senderVault.addSignatureToPsbt(unsigned);
    expect(Psbt.parse(firstAnswer).inputs.single.isFinalized, isFalse);
    final originalPsbt = finalizeOriginalForPayjoin(firstAnswer);
    final originalInput = Psbt.parse(originalPsbt).inputs.single;
    expect(originalInput.isFinalized, isTrue, reason: 'the receiver must be able to broadcast it');
    expect(originalInput.bip32Derivation, hasLength(1), reason: 'payjoin restores these on the proposal');
    expect(finalizeOriginalForPayjoin(originalPsbt), originalPsbt);
    final signedOriginal = Psbt.parse(originalPsbt).getSignedTransaction(AddressType.p2wpkh);
    expect(signedOriginal.transactionHash, original.transactionHash);

    // The receiver adds an input and signs it; payjoin hands the sender the
    // proposal with no key origins on inputs or outputs.
    final proposalPsbt = _receiverProposal(
      original,
      Uint8List.fromList(hex.decode(signedOriginal.serialize())),
      receiver: receiver,
      receiverWallet: receiverWallet,
      senderSpends: TransactionOutput.forPayment(100000, senderVault.getAddress(0)),
    );
    final checked = PayjoinCheckedProposal.forTesting(proposalPsbt);

    // Trip 2: the proposal goes to the vault with our key origins restored.
    final forVault = addOwnDerivations(proposalPsbt, wallet: senderWallet, derivationPathOf: senderPaths);
    final shown = Psbt.parse(forVault);
    expect(shown.inputs.map((i) => i.isFinalized), [false, true]);
    expect(shown.matchesVault(senderVault, allowFinalizedForeignInputs: true), isTrue);
    final change = shown.unsignedTransaction!.outputs.firstWhere(
      (o) => o.getAddress() == senderVault.getAddress(0, isChange: true),
    );
    expect(shown.netAmount(senderVault), change.amount - 100000, reason: 'the vault shows what we spend');

    final secondAnswer = senderVault.addSignatureToPsbt(forVault, allowFinalizedForeignInputs: true);
    final signedProposal = finalizeDeviceSignedPsbt(secondAnswer, shownPsbtBase64: forVault);
    final payjoin = Psbt.parse(signedProposal).getSignedTransaction(AddressType.p2wpkh);
    expect(payjoin.inputs, hasLength(2));
    expect(
      () => TransactionIntentValidator.ensurePayjoinProposalMatches(
        Psbt.parse(unsigned).unsignedTransaction,
        payjoin,
        checked,
        isOwnOutput: (o) => o.getAddress() == senderVault.getAddress(0, isChange: true),
      ),
      returnsNormally,
    );

    // The first answer is not accepted as the second.
    expect(
      () => finalizeDeviceSignedPsbt(firstAnswer, shownPsbtBase64: forVault),
      throwsA(isA<PayjoinSignedPsbtMismatch>()),
    );
  });
}

/// The proposal a payjoin receiver posts for [original]: its coin added as a
/// second input and paid into its output, 150 sat of fee taken from the
/// sender's change, its input signed and final, the sender's input bare.
String _receiverProposal(
  Transaction original,
  Uint8List signedOriginal, {
  required SingleSignatureVault receiver,
  required SingleSignatureWallet receiverWallet,
  required TransactionOutput senderSpends,
}) {
  const coin = 30000;
  final receiverAddress = receiver.getAddress(0);
  final proposal = Transaction.withInputsAndOutputs(
    [
      TransactionInput.forPayment(original.inputs.single.transactionHash, 0, sequence: original.inputs.single.sequence),
      TransactionInput.forPayment(List.filled(32, '22').join(), 3, sequence: original.inputs.single.sequence),
    ],
    [
      for (final output in original.outputs)
        TransactionOutput.forPayment(
          output.getAddress() == receiverAddress ? output.amount + coin : output.amount - 150,
          output.getAddress(),
        ),
    ],
    AddressType.p2wpkh,
  );
  final bare = _psbtWithSpentOutputs(proposal, [
    senderSpends,
    TransactionOutput.forPayment(coin, receiver.getAddress(5)),
  ]);
  final shown = addOwnDerivations(
    withCounterpartyInputsFinal(bare, signedOriginal),
    wallet: receiverWallet,
    derivationPathOf: (address) => address == receiver.getAddress(5) ? '${receiver.derivationPath}/0/5' : null,
  );
  final signed = finalizeDeviceSignedPsbt(
    receiver.addSignatureToPsbt(shown, allowFinalizedForeignInputs: true),
    shownPsbtBase64: shown,
  );
  final posted = Psbt.parse(withoutCounterpartyFinals(signed, signedOriginal));
  for (final output in posted.toKeyMap()['outputs'] as List<dynamic>) {
    (output as Map<String, dynamic>).removeWhere((key, _) => key.startsWith('02'));
  }
  return Psbt.parse(posted.serialize()).serialize();
}

String _psbtWithSpentOutputs(Transaction tx, List<TransactionOutput> spent) {
  final unsigned = StringBuffer(tx.version)..write(_varint(tx.inputs.length));
  for (final input in tx.inputs) {
    unsigned.write(input.serialize());
  }
  unsigned.write(_varint(tx.outputs.length));
  for (final output in tx.outputs) {
    unsigned.write(output.serialize());
  }
  unsigned.write(tx.lockTime);
  final psbt =
      StringBuffer('70736274ff0100')
        ..write(_varint(unsigned.length ~/ 2))
        ..write(unsigned)
        ..write('00');
  for (final output in spent) {
    final value = output.serialize();
    psbt.write('0101${_varint(value.length ~/ 2)}${value}00');
  }
  psbt.write('00' * tx.outputs.length);
  return base64Encode(hex.decode(psbt.toString()));
}

String _varint(int n) => n.toRadixString(16).padLeft(2, '0');
