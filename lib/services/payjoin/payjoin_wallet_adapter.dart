import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/payjoin_session_repository.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_psbt.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_receiver.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
import 'package:convert/convert.dart';

/// Session value keys the wallet keeps beside a receive session.
abstract final class PayjoinReceiveValues {
  /// The coin the receiver added to the proposal, locked until the session
  /// settles.
  static const reservedUtxoId = 'reservedUtxoId';
}

/// Answers a receive session's questions from one wallet's own data.
///
/// Only single-signature P2WPKH wallets take part. A hot wallet signs its
/// input at once; a watch-only wallet returns no signature and leaves the
/// session waiting for one from its signing device.
class WalletPayjoinReceiver implements PayjoinReceiverWallet {
  WalletPayjoinReceiver({
    required this.walletId,
    required this.sessionId,
    required WalletProvider wallets,
    required NodeProvider node,
    required PayjoinSessionRepository sessions,
    HotWalletSigningService? signer,
  }) : _wallets = wallets,
       _node = node,
       _sessions = sessions,
       _signer = signer ?? HotWalletSigningService();

  final int walletId;
  final String sessionId;
  final WalletProvider _wallets;
  final NodeProvider _node;
  final PayjoinSessionRepository _sessions;
  final HotWalletSigningService _signer;

  @override
  bool isOwnedOutpoint(String txid, int vout) => _wallets.getUtxoState(walletId, getUtxoId(txid, vout)) != null;

  @override
  bool isOwnedScript(Uint8List scriptPubKey) {
    // ScriptPublicKey.parse reads a length-prefixed script, as in a
    // serialized output; payjoin hands over the bare script.
    final address = ScriptPublicKey.parse(_lengthPrefixed(scriptPubKey)).getAddress();
    return _wallets.containsAddress(walletId, address);
  }

  @override
  bool markInputSeen(String txid, int vout) => _sessions.markInputSeen('$txid:$vout');

  @override
  List<PayjoinCandidateInput> candidateInputs() => [
    for (final utxo in _wallets.getUtxoListByStatus(walletId, UtxoStatus.unspent))
      if (utxo.blockHeight > 0)
        PayjoinCandidateInput(
          txid: utxo.transactionHash,
          vout: utxo.index,
          amountSats: utxo.amount,
          scriptPubKey: Uint8List.fromList(
            hex.decode(TransactionOutput.forPayment(utxo.amount, utxo.to).scriptPubKey.rawSerialize()),
          ),
        ),
  ];

  @override
  Future<void> reserveInput(String txid, int vout) async {
    final utxoId = getUtxoId(txid, vout);
    _sessions.writeValue(sessionId, PayjoinReceiveValues.reservedUtxoId, utxoId);
    await _wallets.lockUtxo(walletId, utxoId);
  }

  @override
  Future<String?> signProposal(String psbt) async {
    final walletItem = _wallets.getWalletById(walletId);
    final metadata = walletItem.hotWalletMetadata;
    final wallet = walletItem.walletBase;
    if (!walletItem.hasLocalKey || metadata == null || wallet is! SingleSignatureWallet) return null;
    if (metadata.enterPassphraseWhenSigning) return null;
    final withDerivations = addOwnDerivations(
      psbt,
      wallet: wallet,
      derivationPathOf: (address) => _wallets.derivationPathOf(walletId, address),
    );
    return _signer.signAndFinalize(
      (
        storageKey: metadata.secureStorageKey,
        passphrase: null,
        addressTypeName: wallet.addressType.name,
        accountIndex: metadata.accountIndex,
        expectedExtendedPublicKey: wallet.keyStore.extendedPublicKey.serialize(),
        unsignedPsbt: withDerivations,
      ),
      allowFinalizedForeignInputs: true,
      keepDerivations: false,
      verifyForeignInputs: false,
    );
  }

  @override
  Future<Uint8List?> fetchTransaction(String txid) async {
    final result = await _node.getTransaction(txid);
    if (result.isFailure || result.value.isEmpty) return null;
    return Uint8List.fromList(hex.decode(result.value));
  }

  @override
  Future<void> broadcast(Uint8List rawTx) async {
    final result = await _node.broadcast(Transaction.parse(hex.encode(rawTx)));
    if (result.isFailure) throw result.error;
  }

  /// Unlocks the coin this session reserved, when the session ended without
  /// spending it.
  Future<void> releaseReservedInput() async {
    final utxoId = _sessions.readValue(sessionId, PayjoinReceiveValues.reservedUtxoId);
    if (utxoId == null) return;
    final utxo = _wallets.getUtxoState(walletId, utxoId);
    if (utxo != null && utxo.status == UtxoStatus.locked) {
      await _wallets.toggleUtxoLockStatus(walletId, utxoId);
    }
  }
}

String _lengthPrefixed(Uint8List script) {
  if (script.length >= 0xfd) throw ArgumentError.value(script.length, 'script', 'too long for an output script');
  return hex.encode([script.length, ...script]);
}
