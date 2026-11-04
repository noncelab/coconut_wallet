import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/transaction/broadcast_transaction_service.dart';
import 'package:coconut_wallet/utils/transaction_intent_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NetworkType previousNetwork;
  setUp(() => previousNetwork = NetworkType.currentNetworkType);
  tearDown(() => NetworkType.setNetworkType(previousNetwork));

  ({SingleSignatureVault vault, Psbt psbt}) build({int amount = 40000}) {
    final vault = SingleSignatureVault.fromEntropy(Uint8List(16));
    final tx = Transaction.withInputsAndOutputs(
      [TransactionInput.forPayment('a' * 64, 0, sequence: 0xfffffffd)],
      [
        TransactionOutput.forPayment(amount, vault.getAddress(5)),
        TransactionOutput.forPayment(
          99000 - amount,
          vault.getAddress(1, isChange: true),
          derivationPath: '${vault.derivationPath}/1/1',
          isChangeOutput: true,
        ),
      ],
      AddressType.p2wpkh,
    );
    tx.utxoList.add(Utxo('a' * 64, 0, 100000, '${vault.derivationPath}/0/0'));
    tx.changeAddressDerivationPath = '${vault.derivationPath}/1/1';
    return (vault: vault, psbt: Psbt.fromTransaction(tx, vault));
  }

  for (final network in [NetworkType.mainnet, NetworkType.testnet, NetworkType.regtest]) {
    test('worker preserves finalized transaction, ownership and amounts on $network', () async {
      NetworkType.setNetworkType(network);
      final fixture = build();
      final signed = fixture.vault.addSignatureToPsbt(fixture.psbt.serialize());
      final wallet = SingleSignatureWallet.fromDescriptor(fixture.vault.descriptor);
      final expected = Psbt.parse(signed);
      final prepared = await prepareBroadcastTransaction(
        originalPsbt: fixture.psbt.serialize(),
        signedPayload: signed,
        signedIsPsbt: true,
        wallet: wallet,
      );
      expect(prepared.transaction.serialize(), expected.getSignedTransaction(wallet.addressType).serialize());
      expect(prepared.originalOutputOwned, fixture.psbt.outputs.map((o) => o.isOwnedBy(wallet)).toList());
      expect(prepared.outputOwned, expected.outputs.map((o) => o.isOwnedBy(wallet)).toList());
      expect(prepared.outputChange, expected.outputs.map((o) => o.isChange(wallet)).toList());
      expect(prepared.sendingAmount, expected.sendingAmount(wallet));
      expect(prepared.fee, expected.fee);
      expect(NetworkType.currentNetworkType, network);
    });
  }

  test('worker rejects a signed transaction whose payment differs from the original intent', () async {
    NetworkType.setNetworkType(NetworkType.testnet);
    final original = build();
    final different = build(amount: 40001);
    final signed = different.vault.addSignatureToPsbt(different.psbt.serialize());
    await expectLater(
      prepareBroadcastTransaction(
        originalPsbt: original.psbt.serialize(),
        signedPayload: signed,
        signedIsPsbt: true,
        wallet: SingleSignatureWallet.fromDescriptor(original.vault.descriptor),
      ),
      throwsA(isA<TransactionIntentMismatchException>()),
    );
  });

  test('worker still rejects PSBTs without required signatures', () async {
    NetworkType.setNetworkType(NetworkType.testnet);
    final fixture = build();
    await expectLater(
      prepareBroadcastTransaction(
        originalPsbt: fixture.psbt.serialize(),
        signedPayload: fixture.psbt.serialize(),
        signedIsPsbt: true,
        wallet: SingleSignatureWallet.fromDescriptor(fixture.vault.descriptor),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('raw transaction path preserves original input metadata and fee', () async {
    NetworkType.setNetworkType(NetworkType.testnet);
    final fixture = build();
    final signed = fixture.vault.addSignatureToPsbt(fixture.psbt.serialize());
    final raw = Psbt.parse(signed).getSignedTransaction(AddressType.p2wpkh).serialize();
    final prepared = await prepareBroadcastTransaction(
      originalPsbt: fixture.psbt.serialize(),
      signedPayload: raw,
      signedIsPsbt: false,
      wallet: SingleSignatureWallet.fromDescriptor(fixture.vault.descriptor),
    );
    expect(prepared.transaction.serialize(), raw);
    expect(prepared.psbt.serialize(), fixture.psbt.serialize());
    expect(prepared.psbt.inputs.first.witnessUtxo?.amount, 100000);
    expect(prepared.fee, 1000);
  });
}
