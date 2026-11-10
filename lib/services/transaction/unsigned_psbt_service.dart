import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:flutter/foundation.dart';

typedef PreparedUnsignedPsbt = ({Psbt psbt, String serialized, int fee});
typedef _PsbtRequest = ({Transaction transaction, String descriptor, String walletKind, String network, bool passport});

/// 공개 descriptor와 거래만 전달하고 Provider·Realm·개인 키는 전달하지 않는다.
Future<PreparedUnsignedPsbt> prepareUnsignedPsbt({
  required Transaction transaction,
  required WalletBase wallet,
  bool passport = false,
}) {
  return compute(_prepareUnsignedPsbt, (
    transaction: transaction,
    descriptor: wallet.descriptor,
    walletKind:
        wallet is TaprootWallet
            ? 'taproot'
            : wallet is MultisignatureWallet
            ? 'multisig'
            : 'single',
    network: NetworkType.currentNetworkType.toString(),
    passport: passport,
  ));
}

PreparedUnsignedPsbt _prepareUnsignedPsbt(_PsbtRequest request) {
  NetworkType.setNetworkType(NetworkType.getNetworkType(request.network));
  final WalletBase wallet = switch (request.walletKind) {
    'taproot' => TaprootWallet.fromDescriptor(request.descriptor),
    'multisig' => MultisignatureWallet.fromDescriptor(request.descriptor),
    _ => SingleSignatureWallet.fromDescriptor(request.descriptor),
  };
  for (final utxo in request.transaction.utxoList) {
    if (utxo is! UtxoState || wallet.getAddressWithDerivationPath(utxo.derivationPath) != utxo.to) {
      throw StateError('UTXO ${utxo.transactionHash}:${utxo.index} is not owned by the wallet descriptor');
    }
  }
  final psbt = Psbt.fromTransaction(request.transaction, wallet);
  // Passport Core rejects coconut's proprietary global field.
  // Vault 3.3.0 hashes the same CLTV DROP wallet under its pre-after_drop spelling.
  if (request.passport || (wallet is TaprootWallet && wallet.policyList.any((p) => p is LegacyInheritancePolicy))) {
    (psbt.psbtMap['global'] as Map).remove('fc07636f636f6e757401');
  }
  return (psbt: psbt, serialized: psbt.serialize(), fee: psbt.fee);
}
