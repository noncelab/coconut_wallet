import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/transaction_intent_validator.dart';
import 'package:flutter/foundation.dart';

typedef PreparedBroadcastTransaction =
    ({
      Transaction transaction,
      Psbt psbt,
      List<bool> originalOutputOwned,
      List<bool> outputOwned,
      List<bool> outputChange,
      int sendingAmount,
      int fee,
    });

typedef _BroadcastPreparationRequest =
    ({
      String originalPsbt,
      String signedPayload,
      bool signedIsPsbt,
      String descriptor,
      String walletKind,
      String network,
    });

/// Transfer public transaction data and a watch-only descriptor, never Provider,
/// Realm objects, mnemonic, or private keys. Keep signature and intent validation.
Future<PreparedBroadcastTransaction> prepareBroadcastTransaction({
  required String originalPsbt,
  required String signedPayload,
  required bool signedIsPsbt,
  required WalletBase wallet,
}) => compute(_prepareBroadcastTransaction, (
  originalPsbt: originalPsbt,
  signedPayload: signedPayload,
  signedIsPsbt: signedIsPsbt,
  descriptor: wallet.descriptor,
  walletKind:
      wallet is TaprootWallet
          ? 'taproot'
          : wallet is MultisignatureWallet
          ? 'multisig'
          : 'single',
  network: NetworkType.currentNetworkType.toString(),
));

PreparedBroadcastTransaction _prepareBroadcastTransaction(_BroadcastPreparationRequest request) {
  NetworkType.setNetworkType(NetworkType.getNetworkType(request.network));
  final WalletBase wallet = switch (request.walletKind) {
    'taproot' => TaprootWallet.fromDescriptor(request.descriptor),
    'multisig' => MultisignatureWallet.fromDescriptor(request.descriptor),
    _ => SingleSignatureWallet.fromDescriptor(request.descriptor),
  };
  final original = Psbt.parse(request.originalPsbt);
  final signed = request.signedIsPsbt ? Psbt.parse(request.signedPayload) : original;
  final expected = original.unsignedTransaction;
  final Transaction transaction;
  if (request.signedIsPsbt) {
    TransactionIntentValidator.ensureMatches(expected, signed.unsignedTransaction);
    transaction = signed.getSignedTransaction(wallet.addressType);
  } else {
    transaction = Transaction.parse(request.signedPayload);
  }
  TransactionIntentValidator.ensureMatches(expected, transaction);
  // Preserve the original fallback for signers that omit input derivation data.
  final psbt = signed.inputs.every((input) => input.bip32Derivation != null) ? signed : original;
  final originalOwned = original.outputs.map((output) => output.isOwnedBy(wallet)).toList();
  final owned =
      identical(psbt, original) ? originalOwned : psbt.outputs.map((output) => output.isOwnedBy(wallet)).toList();
  final change = [for (var i = 0; i < psbt.outputs.length; i++) owned[i] && psbt.outputs[i].isChange(wallet)];
  final sendingAmount = psbt.outputs.indexed.fold<int>(
    0,
    (sum, entry) => change[entry.$1] ? sum : sum + entry.$2.outAmount!,
  );
  return (
    transaction: transaction,
    psbt: psbt,
    originalOutputOwned: originalOwned,
    outputOwned: owned,
    outputChange: change,
    sendingAmount: sendingAmount,
    fee: psbt.fee,
  );
}
