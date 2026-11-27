import 'package:coconut_wallet/services/payjoin/ohttp_relay_pool.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_http.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_session_persister.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:payjoin/payjoin.dart' as pj;

/// Where a send session stands after one step.
sealed class PayjoinSendProgress {
  const PayjoinSendProgress();
}

/// The Original is with the directory and the receiver has not answered yet.
class PayjoinSendWaiting extends PayjoinSendProgress {
  const PayjoinSendWaiting();
}

/// The receiver's proposal, already checked by payjoin's sender rules
/// (BIP 78 "Senders' payjoin proposal checklist"). Only [PayjoinSender]
/// creates one, so holding it is proof those checks ran.
class PayjoinCheckedProposal extends PayjoinSendProgress {
  const PayjoinCheckedProposal._(this.psbtBase64);

  @visibleForTesting
  const PayjoinCheckedProposal.forTesting(this.psbtBase64);

  final String psbtBase64;
}

/// The session cannot produce a payjoin; broadcast the Original instead.
class PayjoinSendFallback extends PayjoinSendProgress {
  const PayjoinSendFallback(this.reason);

  final Object reason;
}

/// True when [bip21] asks for a BIP 77 payjoin this wallet can attempt.
bool isPayjoinUri(String bip21) {
  try {
    pj.Uri.parse(uri: bip21).checkPjSupported();
    return true;
  } catch (_) {
    return false;
  }
}

/// Drives the sender side of a BIP 77 session, one network round trip per
/// [step], persisting every transition before acting on it.
///
/// The steps follow payjoin-cli's sender: build with the recommended fee
/// contribution, post the Original, poll for the proposal. Signing the
/// proposal and broadcasting are the wallet's job, as is broadcasting the
/// Original when this returns [PayjoinSendFallback].
class PayjoinSender {
  PayjoinSender({required PayjoinEventStore store, required OhttpRelayPool relays, PayjoinHttpPost? post})
    : _store = store,
      _relays = relays,
      _post = post ?? postPayjoinRequest;

  final PayjoinEventStore _store;
  final OhttpRelayPool _relays;
  final PayjoinHttpPost _post;

  /// Starts a session for [originalPsbt], which must be signed and finalized:
  /// the receiver checks it can be broadcast as is.
  ///
  /// [feeRateSatPerVb] is the Original's fee rate; payjoin lets the receiver
  /// lower the effective rate down to it, never below.
  ///
  /// Throws [NoIndependentRelayException], before saving anything, when the
  /// directory in [bip21] is run by the operator of every relay. The wallet
  /// then sends the Original rather than let one operator see both ends.
  void begin({
    required String sessionId,
    required String bip21,
    required String originalPsbt,
    required double feeRateSatPerVb,
  }) {
    final uri = pj.Uri.parse(uri: bip21).checkPjSupported();
    final directory = uri.pjEndpoint();
    if (!_relays.serves(directory)) throw NoIndependentRelayException(directory);
    // payjoin's sender session does not expose its directory after a replay.
    _store.writeValue(sessionId, _directoryKey, directory);
    pj.SenderBuilder(psbt: originalPsbt, uri: uri)
        .buildRecommended(minFeeRateSatPerKwu: satPerVbToSatPerKwu(feeRateSatPerVb))
        .save(persister: _persister(sessionId));
  }

  /// Advances the session by one round trip with the directory.
  Future<PayjoinSendProgress> step(String sessionId) async {
    final persister = _persister(sessionId);
    final pj.SendSession state;
    try {
      state = pj.replaySenderEventLog(persister: persister).state();
    } on pj.SenderReplayException catch (e) {
      persister.close();
      return PayjoinSendFallback(e);
    }

    final directory = _store.readValue(sessionId, _directoryKey);
    try {
      switch (state) {
        case pj.WithReplyKeySendSession(:final inner) when directory != null:
          return await _postOriginal(inner, directory, persister);
        case pj.PollingForProposalSendSession(:final inner) when directory != null:
          return await _poll(inner, directory, persister);
      }
    } on PayjoinSessionExpired catch (e) {
      cancel(sessionId);
      return PayjoinSendFallback(e);
    } on pj.SenderPersistedException catch (e) {
      // The receiver's answer failed payjoin's checks or could not be read.
      // payjoin has recorded the failure; the Original is still valid.
      return PayjoinSendFallback(e);
    }

    switch (state) {
      case pj.ClosedSendSession(:final inner):
        final psbt = inner.successPsbtBase64();
        if (inner.isSuccess() && psbt != null) return PayjoinCheckedProposal._(psbt);
        return const PayjoinSendFallback('session closed without a proposal');
      case pj.SenderPendingFallbackSendSession():
        return const PayjoinSendFallback('session was cancelled');
      default:
        return PayjoinSendFallback('unexpected sender state $state');
    }
  }

  /// Abandons the session so the caller can broadcast the Original.
  void cancel(String sessionId) {
    final persister = _persister(sessionId);
    final pj.SendSession state;
    try {
      state = pj.replaySenderEventLog(persister: persister).state();
    } on pj.SenderReplayException {
      persister.close();
      return;
    }
    final pj.SenderPendingFallback? pending = switch (state) {
      pj.WithReplyKeySendSession(:final inner) => inner.cancel().save(persister: persister),
      pj.PollingForProposalSendSession(:final inner) => inner.cancel().save(persister: persister),
      pj.SenderPendingFallbackSendSession(:final inner) => inner,
      _ => null,
    };
    pending?.close().save(persister: persister);
  }

  Future<PayjoinSendProgress> _postOriginal(
    pj.WithReplyKey sender,
    String directory,
    StoredSenderSessionPersister persister,
  ) async {
    final (body, ctx) = await postViaRelay<pj.ClientResponse>(_relays, directory, (relay) {
      final request = _buildOrFallback(() => sender.createV2PostRequest(ohttpRelay: relay));
      return RelayRequest(
        url: request.request.url,
        body: request.request.body,
        contentType: request.request.contentType,
        context: request.ohttpCtx,
      );
    }, _post);
    sender.processResponse(response: body, postCtx: ctx).save(persister: persister);
    return const PayjoinSendWaiting();
  }

  Future<PayjoinSendProgress> _poll(
    pj.PollingForProposal sender,
    String directory,
    StoredSenderSessionPersister persister,
  ) async {
    final (body, ctx) = await postViaRelay<pj.ClientResponse>(_relays, directory, (relay) {
      final request = _buildOrFallback(() => sender.createPollRequest(ohttpRelay: relay));
      return RelayRequest(
        url: request.request.url,
        body: request.request.body,
        contentType: request.request.contentType,
        context: request.ohttpCtx,
      );
    }, _post);
    final outcome = sender.processResponse(response: body, ohttpCtx: ctx).save(persister: persister);
    return switch (outcome) {
      pj.ProgressPollingForProposalTransitionOutcome(:final psbtBase64) => PayjoinCheckedProposal._(psbtBase64),
      _ => const PayjoinSendWaiting(),
    };
  }

  pj.RequestOhttpContext _buildOrFallback(pj.RequestOhttpContext Function() build) {
    try {
      return build();
    } on pj.CreateRequestException catch (e) {
      if (e.isExpired()) throw PayjoinSessionExpired(e);
      rethrow;
    }
  }

  StoredSenderSessionPersister _persister(String sessionId) => StoredSenderSessionPersister(_store, sessionId);
}

const _directoryKey = 'directory';

class PayjoinSessionExpired implements Exception {
  const PayjoinSessionExpired(this.cause);

  final Object cause;

  @override
  String toString() => 'Payjoin session expired: $cause';
}

/// payjoin takes fee rates in sat/kwu; one virtual byte is four weight units.
int satPerVbToSatPerKwu(double satPerVb) => (satPerVb * 250).ceil();
