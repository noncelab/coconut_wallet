import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_psbt.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecretRepository extends Fake implements HotWalletSecretRepository {
  _FakeSecretRepository(this.mnemonic);

  final String mnemonic;

  @override
  Future<HotWalletPlaintext> unlockAfterAuthentication(String storageKey) async =>
      HotWalletPlaintext(mnemonic: Uint8List.fromList(utf8.encode(mnemonic)), passphrase: Uint8List(0));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  late SingleSignatureVault vault;
  late SingleSignatureWallet wallet;

  setUp(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    vault = SingleSignatureVault.fromMnemonic(Uint8List.fromList(utf8.encode(mnemonic)));
    wallet = SingleSignatureWallet.fromDescriptor(vault.descriptor);
  });

  tearDown(() {
    vault.keyStore.wipeSeed();
    NetworkType.setNetworkType(NetworkType.testnet);
  });

  Transaction twoInputSpend() => Transaction.forSinglePayment(
    [
      Utxo(List.filled(32, '11').join(), 0, 60000, '${vault.derivationPath}/0/3'),
      Utxo(List.filled(32, '22').join(), 1, 50000, '${vault.derivationPath}/1/7'),
    ],
    vault.getAddress(9),
    '${vault.derivationPath}/1/0',
    80000,
    1,
    vault,
  );

  String stripDerivations(String psbtBase64) {
    final psbt = Psbt.parse(psbtBase64);
    for (final input in psbt.toKeyMap()['inputs'] as List<dynamic>) {
      (input as Map<String, dynamic>).removeWhere((key, _) => key.startsWith('06'));
    }
    return Psbt.parse(psbt.serialize()).serialize();
  }

  String? pathOf(String address) {
    for (final isChange in [false, true]) {
      for (var i = 0; i < 20; i++) {
        if (wallet.getAddress(i, isChange: isChange) == address) {
          return '${vault.derivationPath}/${isChange ? 1 : 0}/$i';
        }
      }
    }
    return null;
  }

  group('addOwnDerivations', () {
    test('restores the derivations a signer needs', () {
      final unsigned = Psbt.fromTransaction(twoInputSpend(), wallet).serialize();
      final stripped = stripDerivations(unsigned);
      expect(Psbt.parse(stripped).inputs.every((i) => i.bip32Derivation?.isEmpty ?? true), isTrue);

      final restored = addOwnDerivations(stripped, wallet: wallet, derivationPathOf: pathOf);

      final want = Psbt.parse(unsigned).inputs;
      final got = Psbt.parse(restored).inputs;
      for (var i = 0; i < want.length; i++) {
        expect(got[i].bip32Derivation!.single.publicKey, want[i].bip32Derivation!.single.publicKey);
        expect(got[i].bip32Derivation!.single.path, want[i].bip32Derivation!.single.path);
        expect(got[i].bip32Derivation!.single.masterFingerprint, want[i].bip32Derivation!.single.masterFingerprint);
      }
      // The signer accepts the restored PSBT and signs every input.
      final signed = vault.addSignatureToPsbt(restored);
      expect(Psbt.parse(signed).getSignedTransaction(AddressType.p2wpkh).inputs, hasLength(2));
    });

    test('leaves inputs alone when the address is not ours or the path does not derive it', () {
      final stripped = stripDerivations(Psbt.fromTransaction(twoInputSpend(), wallet).serialize());
      expect(addOwnDerivations(stripped, wallet: wallet, derivationPathOf: (_) => null), stripped);
      expect(
        addOwnDerivations(stripped, wallet: wallet, derivationPathOf: (_) => '${vault.derivationPath}/0/15'),
        stripped,
        reason: 'a path that derives a different address is ignored',
      );
    });

    test('adds what is missing on our outputs too, once', () {
      final unsigned = Psbt.fromTransaction(twoInputSpend(), wallet).serialize();
      // The spend pays our own address 9, which coconut_lib leaves without a
      // derivation, and returns change with one.
      final added = addOwnDerivations(unsigned, wallet: wallet, derivationPathOf: pathOf);
      final outputs = Psbt.parse(added).outputs;
      expect(outputs.map((o) => o.bip32Derivations.single.path).toSet(), {
        '${vault.derivationPath}/0/9',
        '${vault.derivationPath}/1/0',
      });
      expect(addOwnDerivations(added, wallet: wallet, derivationPathOf: pathOf), added);
    });
  });

  group('HotWalletSigningService.signAndFinalize', () {
    test('finalizes an Original and keeps derivations when asked', () async {
      final service = HotWalletSigningService(secretRepository: _FakeSecretRepository(mnemonic));
      final transaction = twoInputSpend();
      final finalized = await service.signAndFinalize(
        (
          storageKey: 'k',
          passphrase: null,
          addressTypeName: vault.addressType.name,
          accountIndex: 0,
          expectedExtendedPublicKey: vault.keyStore.extendedPublicKey.serialize(),
          unsignedPsbt: Psbt.fromTransaction(transaction, wallet).serialize(),
        ),
        allowFinalizedForeignInputs: false,
        keepDerivations: true,
      );
      final psbt = Psbt.parse(finalized);
      expect(psbt.inputs.every((input) => input.isFinalized), isTrue);
      expect(psbt.inputs.every((input) => input.bip32Derivation?.length == 1), isTrue);
      expect(psbt.getSignedTransaction(AddressType.p2wpkh).transactionHash, transaction.transactionHash);
    });
  });

  group('receiver signing with the sender inputs shown final', () {
    const senderWords = 'legal winner thank year wave sausage worth useful legal winner thank yellow';

    test('signs only our input and hands the sender inputs back unsigned', () {
      final sender = SingleSignatureVault.fromMnemonic(Uint8List.fromList(utf8.encode(senderWords)));
      try {
        final senderWallet = SingleSignatureWallet.fromDescriptor(sender.descriptor);
        // The sender's signed, finalized Original pays our address 1.
        final originalTx = Transaction.forSinglePayment(
          [Utxo(List.filled(32, '44').join(), 0, 90000, '${sender.derivationPath}/0/0')],
          vault.getAddress(1),
          '${sender.derivationPath}/1/0',
          30000,
          2,
          sender,
        );
        final signedOriginal = Psbt.parse(
          sender.addSignatureToPsbt(Psbt.fromTransaction(originalTx, senderWallet).serialize()),
        ).finalizeInputs().getSignedTransaction(AddressType.p2wpkh);
        final originalBytes = Uint8List.fromList(hex.decode(signedOriginal.serialize()));

        // The proposal payjoin gives the receiver: the sender's input unsigned,
        // ours added with only its spent output, our output raised by it.
        const ourCoin = 20000;
        final ourUtxoAddress = vault.getAddress(4);
        final proposal = Transaction.withInputsAndOutputs(
          [
            TransactionInput.forPayment(
              originalTx.inputs.single.transactionHash,
              0,
              sequence: originalTx.inputs.single.sequence,
            ),
            TransactionInput.forPayment(List.filled(32, '55').join(), 1, sequence: originalTx.inputs.single.sequence),
          ],
          [
            for (final output in originalTx.outputs)
              TransactionOutput.forPayment(
                output.getAddress() == vault.getAddress(1) ? output.amount + ourCoin : output.amount,
                output.getAddress(),
              ),
          ],
          AddressType.p2wpkh,
        );
        final psbtToSign = _psbtWithSpentOutputs(proposal, [
          TransactionOutput.forPayment(90000, sender.getAddress(0)),
          TransactionOutput.forPayment(ourCoin, ourUtxoAddress),
        ]);

        final shown = withCounterpartyInputsFinal(psbtToSign, originalBytes);
        expect(Psbt.parse(shown).inputs.map((i) => i.isFinalized), [true, false]);

        final withDerivation = addOwnDerivations(shown, wallet: wallet, derivationPathOf: pathOf);
        final signed =
            Psbt.parse(
              vault.addSignatureToPsbt(withDerivation, allowFinalizedForeignInputs: true),
            ).finalizeInputs().serialize();

        final back = Psbt.parse(withoutCounterpartyFinals(signed, originalBytes));
        expect(back.inputs[0].isFinalized, isFalse, reason: 'the sender input goes back unsigned');
        expect(back.inputs[0].partialSig ?? const [], isEmpty);
        expect(back.inputs[1].isFinalized, isTrue, reason: 'our input is signed and final');
        expect(back.unsignedTransaction!.transactionHash, proposal.transactionHash);
      } finally {
        sender.keyStore.wipeSeed();
      }
    });

    test('a vault sees our input and output, signs, and the wallet finalizes', () {
      final sender = SingleSignatureVault.fromMnemonic(Uint8List.fromList(utf8.encode(senderWords)));
      try {
        final senderWallet = SingleSignatureWallet.fromDescriptor(sender.descriptor);
        final originalTx = Transaction.forSinglePayment(
          [Utxo(List.filled(32, '44').join(), 0, 90000, '${sender.derivationPath}/0/0')],
          vault.getAddress(1),
          '${sender.derivationPath}/1/0',
          30000,
          2,
          sender,
        );
        final originalBytes = Uint8List.fromList(
          hex.decode(
            Psbt.parse(
              sender.addSignatureToPsbt(Psbt.fromTransaction(originalTx, senderWallet).serialize()),
            ).finalizeInputs().getSignedTransaction(AddressType.p2wpkh).serialize(),
          ),
        );
        const ourCoin = 20000;
        final proposal = Transaction.withInputsAndOutputs(
          [
            TransactionInput.forPayment(originalTx.inputs.single.transactionHash, 0),
            TransactionInput.forPayment(List.filled(32, '55').join(), 1),
          ],
          [
            for (final output in originalTx.outputs)
              TransactionOutput.forPayment(
                output.getAddress() == vault.getAddress(1) ? output.amount + ourCoin : output.amount,
                output.getAddress(),
              ),
          ],
          AddressType.p2wpkh,
        );
        final shownFinal = withCounterpartyInputsFinal(
          _psbtWithSpentOutputs(proposal, [
            TransactionOutput.forPayment(90000, sender.getAddress(0)),
            TransactionOutput.forPayment(ourCoin, vault.getAddress(4)),
          ]),
          originalBytes,
        );
        final forVault = addOwnDerivations(shownFinal, wallet: wallet, derivationPathOf: pathOf);

        // The vault knows our input and our output only by their derivations.
        final ourOutput = proposal.outputs.indexWhere((o) => o.getAddress() == vault.getAddress(1));
        final parsed = Psbt.parse(forVault);
        expect(parsed.inputs[1].bip32Derivation!.single.path, '${vault.derivationPath}/0/4');
        expect(parsed.outputs[ourOutput].bip32Derivations.single.path, '${vault.derivationPath}/0/1');
        expect(parsed.outputs.where((o) => o.bip32Derivations.isNotEmpty), hasLength(1));
        expect(parsed.inputs[0].isFinalized, isTrue, reason: 'the sender input reads as final');
        final inputOnly = addOwnDerivations(
          shownFinal,
          wallet: wallet,
          derivationPathOf: (address) => address == vault.getAddress(4) ? pathOf(address) : null,
        );
        expect(
          Psbt.parse(inputOnly).netAmount(vault),
          -ourCoin,
          reason: 'with our input alone, the vault reads a spend',
        );
        expect(parsed.netAmount(vault), 30000, reason: 'with it, the vault reads what we receive');
        expect(parsed.matchesVault(vault, allowFinalizedForeignInputs: true), isTrue);

        // The vault signs without finalizing, as Coconut Vault returns it.
        final fromVault = vault.addSignatureToPsbt(forVault, allowFinalizedForeignInputs: true);
        expect(Psbt.parse(fromVault).inputs[1].isFinalized, isFalse);

        final finalized = finalizeDeviceSignedPsbt(fromVault, shownPsbtBase64: forVault);
        final back = Psbt.parse(withoutCounterpartyFinals(finalized, originalBytes));
        expect(back.inputs[0].isFinalized, isFalse, reason: 'the sender input goes back unsigned');
        expect(back.inputs[1].isFinalized, isTrue, reason: 'our input is final');
        expect(back.unsignedTransaction!.transactionHash, proposal.transactionHash);

        expect(
          () => finalizeDeviceSignedPsbt(forVault, shownPsbtBase64: forVault),
          throwsA(isA<PayjoinSignedPsbtMismatch>()),
          reason: 'an unsigned answer is refused',
        );
        final otherTx = Psbt.fromTransaction(twoInputSpend(), wallet).serialize();
        expect(
          () => finalizeDeviceSignedPsbt(vault.addSignatureToPsbt(otherTx), shownPsbtBase64: forVault),
          throwsA(isA<PayjoinSignedPsbtMismatch>()),
          reason: 'an answer for another transaction is refused',
        );
      } finally {
        sender.keyStore.wipeSeed();
      }
    });

    test('without the sender inputs shown final the signer refuses the proposal', () {
      final sender = SingleSignatureVault.fromMnemonic(Uint8List.fromList(utf8.encode(senderWords)));
      try {
        final proposal = Transaction.withInputsAndOutputs(
          [
            TransactionInput.forPayment(List.filled(32, '44').join(), 0),
            TransactionInput.forPayment(List.filled(32, '55').join(), 1),
          ],
          [TransactionOutput.forPayment(100000, vault.getAddress(1))],
          AddressType.p2wpkh,
        );
        final psbt = addOwnDerivations(
          _psbtWithSpentOutputs(proposal, [
            TransactionOutput.forPayment(90000, sender.getAddress(0)),
            TransactionOutput.forPayment(20000, vault.getAddress(4)),
          ]),
          wallet: wallet,
          derivationPathOf: pathOf,
        );
        expect(() => vault.addSignatureToPsbt(psbt, allowFinalizedForeignInputs: true), throwsA(anything));
      } finally {
        sender.keyStore.wipeSeed();
      }
    });
  });
}

/// A PSBT for [tx] whose inputs carry only their spent outputs, as payjoin
/// hands a receiver its proposal.
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
