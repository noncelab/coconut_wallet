import 'dart:math';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart' show Psbt, Transaction;
import 'package:coconut_wallet/services/payjoin/ohttp_relay_pool.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_http.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_psbt.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_sender.dart' show PayjoinSessionExpired;
import 'package:coconut_wallet/services/payjoin/payjoin_session_persister.dart';
import 'package:payjoin/http.dart' show fetchOhttpKeys;
import 'package:payjoin/payjoin.dart' as pj;

/// A spendable output the receiver may add to the sender's transaction.
class PayjoinCandidateInput {
  const PayjoinCandidateInput({
    required this.txid,
    required this.vout,
    required this.amountSats,
    required this.scriptPubKey,
  });

  final String txid;
  final int vout;
  final int amountSats;
  final Uint8List scriptPubKey;
}

/// What the receiver needs from the wallet that owns the session.
abstract class PayjoinReceiverWallet {
  bool isOwnedOutpoint(String txid, int vout);

  bool isOwnedScript(Uint8List scriptPubKey);

  /// Records the outpoint and returns whether it had been recorded before.
  bool markInputSeen(String txid, int vout);

  List<PayjoinCandidateInput> candidateInputs();

  /// Keeps the contributed input out of other spends while the session runs.
  Future<void> reserveInput(String txid, int vout);

  /// Signs and finalizes the receiver's inputs of [psbt], where the sender's
  /// inputs appear finalized with their scripts from the Original and must be
  /// left alone. Returns null when the signature has to come from elsewhere
  /// (an air-gapped signer); the session then waits in its current state
  /// until [PayjoinReceiver.step] is called with the signed PSBT.
  Future<String?> signProposal(String psbt);

  /// The raw transaction with [txid] if the network has it.
  Future<Uint8List?> fetchTransaction(String txid);

  Future<void> broadcast(Uint8List rawTx);
}

sealed class PayjoinReceiveProgress {
  const PayjoinReceiveProgress();
}

/// No Original from a sender yet.
class PayjoinReceiveWaiting extends PayjoinReceiveProgress {
  const PayjoinReceiveWaiting();
}

/// The proposal is ready and waits for the receiver's signature.
class PayjoinReceiveNeedsSignature extends PayjoinReceiveProgress {
  const PayjoinReceiveNeedsSignature(this.psbtToSign);

  final String psbtToSign;
}

/// The proposal is with the sender; the session watches the network for the
/// payjoin or the Original.
class PayjoinReceiveProposalSent extends PayjoinReceiveProgress {
  const PayjoinReceiveProposalSent(this.proposalTxid);

  final String? proposalTxid;
}

/// The session is over. [txid] is the transaction that settled it, if any.
class PayjoinReceiveClosed extends PayjoinReceiveProgress {
  const PayjoinReceiveClosed({this.payjoinTxid, this.fallbackBroadcast = false});

  final String? payjoinTxid;
  final bool fallbackBroadcast;
}

/// A new receive session's URI and identity.
class PayjoinReceiveStart {
  const PayjoinReceiveStart({required this.pjUri});

  final String pjUri;
}

typedef OhttpKeysFetcher =
    Future<pj.OhttpKeys> Function({
      required String ohttpRelayUrl,
      required String directoryUrl,
      Uint8List? certificate,
    });

/// Drives the receiver side of a BIP 77 session.
///
/// The checks run in the order of payjoin-cli's receiver. Where a mobile
/// Electrum wallet cannot do what payjoin-cli does with bitcoind, it deviates:
/// it cannot `testmempoolaccept` the Original, so it assumes an interactive
/// receiver (the sender is waiting and will broadcast); ownership comes from
/// the wallet's own address and UTXO sets; seen inputs live in the app's DB.
class PayjoinReceiver {
  PayjoinReceiver({
    required PayjoinEventStore store,
    required OhttpRelayPool relays,
    required List<String> directoryUrls,
    Uint8List? directoryCertificate,
    PayjoinHttpPost? post,
    OhttpKeysFetcher? fetchKeys,
    Random? random,
  }) : _store = store,
       _relays = relays,
       _directoryUrls = List.unmodifiable(directoryUrls),
       _directoryCertificate = directoryCertificate,
       _post = post ?? postPayjoinRequest,
       _fetchKeys = fetchKeys ?? fetchOhttpKeys,
       _random = random ?? Random.secure() {
    if (_directoryUrls.isEmpty) {
      throw ArgumentError.value(directoryUrls, 'directoryUrls', 'at least one directory is required');
    }
  }

  final PayjoinEventStore _store;
  final OhttpRelayPool _relays;
  final List<String> _directoryUrls;
  final Uint8List? _directoryCertificate;
  final PayjoinHttpPost _post;
  final OhttpKeysFetcher _fetchKeys;
  final Random _random;

  /// Told about each transition payjoin refused, such as a failed check on
  /// the sender's Original, before the session replies with the error.
  void Function(String sessionId, Object error)? onTransitionError;

  /// Opens a session that receives to [address] on a directory picked at
  /// random, fetching the directory's OHTTP keys through a relay so the
  /// directory never sees this device's IP.
  Future<PayjoinReceiveStart> begin({
    required String sessionId,
    required String address,
    int? amountSats,
    required Duration expiry,
  }) async {
    final directory = _directoryUrls[_random.nextInt(_directoryUrls.length)];
    final keys = await _fetchOhttpKeys(directory);
    var builder = pj.ReceiverBuilder(
      address: address,
      directory: directory,
      ohttpKeys: keys,
    ).withExpiration(expirationSecs: expiry.inSeconds);
    if (amountSats != null) builder = builder.withAmount(amountSats: amountSats);
    final initialized = builder.build().save(persister: _persister(sessionId));
    return PayjoinReceiveStart(pjUri: initialized.pjUri().asString());
  }

  /// The session's URI, replayed from its event log.
  String pjUri(String sessionId) =>
      pj.replayReceiverEventLog(persister: _persister(sessionId)).sessionHistory().pjUri().asString();

  /// The sender's Original, once the session has one: the transaction to
  /// broadcast if the payjoin does not happen.
  Uint8List? fallbackTx(String sessionId) {
    try {
      return pj.replayReceiverEventLog(persister: _persister(sessionId)).sessionHistory().fallbackTx();
    } on pj.ReceiverReplayException {
      return null;
    }
  }

  /// Runs the session as far as it can go without waiting on anyone.
  ///
  /// [signedProposal] is the receiver-signed PSBT for a session that stopped
  /// at [PayjoinReceiveNeedsSignature].
  Future<PayjoinReceiveProgress> step(String sessionId, PayjoinReceiverWallet wallet, {String? signedProposal}) async {
    final persister = _persister(sessionId);
    // Each transition is saved before the next one runs, so a failure part
    // way leaves a session that resumes from the last saved state. A
    // replyable error is itself a state, handled on the next pass.
    for (var guard = 0; guard < 32; guard++) {
      final pj.ReceiveSession state;
      final String directory;
      try {
        final replay = pj.replayReceiverEventLog(persister: persister);
        state = replay.state();
        // The directory is part of the session's URI, so a session resumed
        // after a restart stays on it even if the configured list changed.
        directory = replay.sessionHistory().pjUri().pjEndpoint();
      } on pj.ReceiverReplayException catch (e) {
        persister.close();
        if (e.isExpired()) return const PayjoinReceiveClosed();
        rethrow;
      }
      try {
        final next = await _advance(state, directory, persister, wallet, signedProposal);
        if (next != null) return next;
      } on PayjoinSessionExpired {
        _cancel(state, persister);
        return const PayjoinReceiveClosed();
      } on pj.ReceiverPersistedException catch (e) {
        // The transition recorded its failure; replaying picks up the
        // resulting state (an error to reply with, or a closed session).
        onTransitionError?.call(sessionId, e);
        continue;
      }
    }
    throw StateError('payjoin receive session $sessionId did not settle');
  }

  /// Ends the session; returns the sender's Original if it should be
  /// broadcast instead of the payjoin.
  Uint8List? cancel(String sessionId) {
    final persister = _persister(sessionId);
    try {
      final state = pj.replayReceiverEventLog(persister: persister).state();
      return _cancel(state, persister);
    } on pj.ReceiverReplayException {
      persister.close();
      return null;
    }
  }

  /// Returns the next progress to report, or null to keep advancing.
  Future<PayjoinReceiveProgress?> _advance(
    pj.ReceiveSession state,
    String directory,
    StoredReceiverSessionPersister persister,
    PayjoinReceiverWallet wallet,
    String? signedProposal,
  ) async {
    switch (state) {
      case pj.InitializedReceiveSession(:final inner):
        final (body, ctx) = await postViaRelay<pj.ClientResponse>(
          _relays,
          directory,
          (relay) => _relayRequest(() => inner.createPollRequest(ohttpRelay: relay)),
          _post,
        );
        final outcome = inner.processResponse(body: body, ctx: ctx).save(persister: persister);
        return outcome is pj.StasisInitializedTransitionOutcome ? const PayjoinReceiveWaiting() : null;

      case pj.UncheckedOriginalPayloadReceiveSession(:final inner):
        inner.assumeInteractiveReceiver().save(persister: persister);
        return null;

      case pj.MaybeInputsOwnedReceiveSession(:final inner):
        final marked = [
          for (final item in inner.inputsOwnedChecklist())
            item.mark(result: wallet.isOwnedOutpoint(item.value().txid, item.value().vout)),
        ];
        inner.applyInputsOwnedChecklist(markedChecklist: marked).save(persister: persister);
        return null;

      case pj.MaybeInputsSeenReceiveSession(:final inner):
        final marked = [
          for (final item in inner.inputsSeenChecklist())
            item.mark(result: wallet.markInputSeen(item.value().txid, item.value().vout)),
        ];
        inner.applyInputsSeenChecklist(markedChecklist: marked).save(persister: persister);
        return null;

      case pj.OutputsUnknownReceiveSession(:final inner):
        final marked = [
          for (final item in inner.outputsOwnedChecklist()) item.mark(result: wallet.isOwnedScript(item.value())),
        ];
        inner.applyOutputsOwnedChecklist(markedChecklist: marked).save(persister: persister);
        return null;

      case pj.WantsOutputsReceiveSession(:final inner):
        inner.commitOutputs().save(persister: persister);
        return null;

      case pj.WantsInputsReceiveSession(:final inner):
        final candidates = wallet.candidateInputs();
        if (candidates.isEmpty) throw const PayjoinNoInputToContribute();
        final selected = inner.tryPreservingPrivacy(candidateInputs: candidates.map(_inputPair).toList());
        final outpoint = selected.outpoint();
        inner.contributeInputs(replacementInputs: [selected]).commitInputs().save(persister: persister);
        await wallet.reserveInput(outpoint.txid, outpoint.vout);
        return null;

      case pj.WantsFeeRangeReceiveSession(:final inner):
        inner.applyFeeRange(minFeeRateSatPerVb: null, maxEffectiveFeeRateSatPerVb: null).save(persister: persister);
        return null;

      case pj.ProvisionalProposalReceiveSession(:final inner):
        final original = fallbackTx(persister.sessionId)!;
        final toSign = withCounterpartyInputsFinal(inner.psbtToSign(), original);
        final signed = signedProposal ?? await wallet.signProposal(toSign);
        if (signed == null) return PayjoinReceiveNeedsSignature(toSign);
        inner
            .finalizeSignedProposal(signedPsbt: withoutCounterpartyFinals(signed, original))
            .save(persister: persister);
        return null;

      case pj.PayjoinProposalReceiveSession(:final inner):
        _store.writeValue(
          persister.sessionId,
          _proposalTxidKey,
          Psbt.parse(inner.psbt()).unsignedTransaction!.transactionHash,
        );
        final (body, ctx) = await postViaRelay<pj.ClientResponse>(
          _relays,
          directory,
          (relay) => _relayRequest(() => inner.createPostRequest(ohttpRelay: relay)),
          _post,
        );
        inner.processResponse(body: body, ohttpContext: ctx).save(persister: persister);
        return null;

      case pj.HasReplyableExceptionReceiveSession(:final inner):
        final (body, ctx) = await postViaRelay<pj.ClientResponse>(
          _relays,
          directory,
          (relay) => _relayRequest(() => inner.createErrorRequest(ohttpRelay: relay)),
          _post,
        );
        inner.processErrorResponse(body: body, ohttpContext: ctx).save(persister: persister);
        return null;

      case pj.MonitorReceiveSession(:final inner):
        return _monitor(inner, persister, wallet);

      case pj.ReceiverPendingFallbackReceiveSession(:final inner):
        // The sender's Original is a valid transaction to us. Broadcasting it
        // settles the transfer the sender already committed to.
        await wallet.broadcast(inner.fallbackTx());
        inner.close().save(persister: persister);
        return const PayjoinReceiveClosed(fallbackBroadcast: true);

      case pj.ClosedReceiveSession():
        persister.close();
        return const PayjoinReceiveClosed();

      default:
        throw StateError('unexpected receive state $state');
    }
  }

  Future<PayjoinReceiveProgress?> _monitor(
    pj.Monitor monitor,
    StoredReceiverSessionPersister persister,
    PayjoinReceiverWallet wallet,
  ) async {
    // payjoin's finder callback is synchronous, so fetch what it will ask for
    // first: the payjoin's txid, then the Original's.
    final proposalTxid = _proposalTxid(persister);
    final fallback = fallbackTx(persister.sessionId);
    final found = <String, Uint8List>{};
    for (final txid in [proposalTxid, if (fallback != null) _txid(fallback)]) {
      if (txid == null) continue;
      final tx = await wallet.fetchTransaction(txid);
      if (tx != null) found[txid] = tx;
    }
    monitor.checkForTransaction(findTransaction: _Finder(found)).save(persister: persister);
    final state = pj.replayReceiverEventLog(persister: persister).state();
    if (state is pj.ClosedReceiveSession) {
      persister.close();
      final payjoinFound = proposalTxid != null && found.containsKey(proposalTxid);
      return PayjoinReceiveClosed(payjoinTxid: payjoinFound ? proposalTxid : null);
    }
    return PayjoinReceiveProposalSent(proposalTxid);
  }

  String? _proposalTxid(StoredReceiverSessionPersister persister) =>
      _store.readValue(persister.sessionId, _proposalTxidKey);

  /// The txid of the payjoin this session proposed, once it has posted one.
  String? proposalTxid(String sessionId) => _store.readValue(sessionId, _proposalTxidKey);

  Uint8List? _cancel(pj.ReceiveSession state, StoredReceiverSessionPersister persister) {
    final pj.CancelTransition? transition = switch (state) {
      pj.InitializedReceiveSession(:final inner) => inner.cancel(),
      pj.UncheckedOriginalPayloadReceiveSession(:final inner) => inner.cancel(),
      pj.MaybeInputsOwnedReceiveSession(:final inner) => inner.cancel(),
      pj.MaybeInputsSeenReceiveSession(:final inner) => inner.cancel(),
      pj.OutputsUnknownReceiveSession(:final inner) => inner.cancel(),
      pj.WantsOutputsReceiveSession(:final inner) => inner.cancel(),
      pj.WantsInputsReceiveSession(:final inner) => inner.cancel(),
      pj.WantsFeeRangeReceiveSession(:final inner) => inner.cancel(),
      pj.ProvisionalProposalReceiveSession(:final inner) => inner.cancel(),
      pj.PayjoinProposalReceiveSession(:final inner) => inner.cancel(),
      pj.MonitorReceiveSession(:final inner) => inner.cancel(),
      pj.HasReplyableExceptionReceiveSession(:final inner) => inner.cancel(),
      _ => null,
    };
    final pending = switch (state) {
      pj.ReceiverPendingFallbackReceiveSession(:final inner) => inner,
      _ => transition?.save(persister: persister),
    };
    if (pending == null) {
      persister.close();
      return null;
    }
    final tx = pending.fallbackTx();
    pending.close().save(persister: persister);
    return tx;
  }

  Future<pj.OhttpKeys> _fetchOhttpKeys(String directory) async {
    Object? lastError;
    for (var relay = _relays.choose(directory); relay != null; relay = _relays.choose(directory)) {
      try {
        return await _fetchKeys(ohttpRelayUrl: relay, directoryUrl: directory, certificate: _directoryCertificate);
      } catch (e) {
        lastError = e;
        _relays.markFailed(relay);
      }
    }
    _relays.clearFailed();
    throw NoOhttpRelayAvailableException(lastError);
  }

  StoredReceiverSessionPersister _persister(String sessionId) => StoredReceiverSessionPersister(_store, sessionId);
}

/// [pjUri] with [amountSats] set, for a receiver who enters an amount after
/// the session started.
String payjoinUriWithAmount(String pjUri, int? amountSats) {
  if (amountSats == null) return pjUri;
  return pj.Uri.parse(uri: pjUri).checkPjSupported().setAmountSats(amountSats: amountSats).asString();
}

const _proposalTxidKey = 'proposalTxid';

String _txid(Uint8List rawTx) => Transaction.parse(_hex(rawTx)).transactionHash;

String _hex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

class PayjoinNoInputToContribute implements Exception {
  const PayjoinNoInputToContribute();

  @override
  String toString() => 'No confirmed P2WPKH coin to add to the payjoin';
}

RelayRequest<pj.ClientResponse> _relayRequest(pj.RequestResponse Function() build) {
  final pj.RequestResponse request;
  try {
    request = build();
  } on pj.ReceiverCreateRequestException catch (e) {
    if (e.isExpired()) throw PayjoinSessionExpired(e);
    rethrow;
  }
  return RelayRequest(
    url: request.request.url,
    body: request.request.body,
    contentType: request.request.contentType,
    context: request.clientResponse,
  );
}

pj.InputPair _inputPair(PayjoinCandidateInput input) => pj.InputPair(
  txin: pj.TxIn(
    previousOutput: pj.OutPoint(txid: input.txid, vout: input.vout),
    scriptSig: Uint8List(0),
    sequence: 0xfffffffd,
    witness: const [],
  ),
  psbtin: pj.PsbtInput(witnessUtxo: pj.TxOut(valueSat: input.amountSats, scriptPubkey: input.scriptPubKey)),
  expectedWeight: null,
);

class _Finder implements pj.TransactionFinder {
  _Finder(this._found);

  final Map<String, Uint8List> _found;

  @override
  Uint8List? callback(String txid) => _found[txid];
}
