import 'dart:async';

import 'package:coconut_wallet/repository/realm/payjoin_session_repository.dart';
import 'package:coconut_wallet/services/payjoin/ohttp_relay_pool.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_config.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_sender.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

enum PayjoinSendStage { contactingReceiver, waitingForReceiver, receiverAddedInput }

sealed class PayjoinSendOutcome {
  const PayjoinSendOutcome(this.sessionId);

  final String? sessionId;
}

/// The receiver's proposal, checked by payjoin, ready for the wallet to sign.
class PayjoinSendProposal extends PayjoinSendOutcome {
  const PayjoinSendProposal(String super.sessionId, this.proposal);

  final PayjoinCheckedProposal proposal;
}

/// No payjoin this time; the wallet broadcasts the Original.
class PayjoinSendFallsBack extends PayjoinSendOutcome {
  const PayjoinSendFallsBack(super.sessionId, this.reason);

  final Object reason;
}

/// Session value keys the wallet keeps beside a send session.
abstract final class PayjoinSendValues {
  /// The signed Original, hex, so a session found open after a restart can
  /// still be settled by broadcasting it.
  static const originalTx = 'originalTx';

  /// The txid the wallet broadcast to settle the session.
  static const broadcastTxid = 'broadcastTxid';
}

/// One foreground payjoin attempt by a sender that is watching the screen.
///
/// The app cannot poll in the background, so the attempt gives up after
/// [patience] and the wallet sends the Original, which the receiver expects
/// as the fallback anyway.
class PayjoinSendAttempt {
  PayjoinSendAttempt({
    required PayjoinSessionRepository repository,
    PayjoinSender? sender,
    this.patience = const Duration(minutes: 2),
    this.pollInterval = PayjoinConfig.pollInterval,
  }) : _repository = repository,
       _sender =
           sender ?? PayjoinSender(store: repository, relays: OhttpRelayPool(PayjoinConfig.current.ohttpRelayUrls));

  final PayjoinSessionRepository _repository;
  final PayjoinSender _sender;
  final Duration patience;
  final Duration pollInterval;

  final ValueNotifier<PayjoinSendStage> stage = ValueNotifier(PayjoinSendStage.contactingReceiver);
  final Completer<void> _abandoned = Completer<void>();

  /// Stops waiting for the receiver; [run] then returns a fallback.
  void abandon() {
    if (!_abandoned.isCompleted) _abandoned.complete();
  }

  Future<PayjoinSendOutcome> run({
    required int walletId,
    required String bip21,
    required String signedOriginalPsbt,
    required String originalTxHex,
    required double feeRateSatPerVb,
  }) async {
    final sessionId = const Uuid().v4();
    _repository.create(id: sessionId, walletId: walletId, role: PayjoinRole.send);
    _repository.writeValue(sessionId, PayjoinSendValues.originalTx, originalTxHex);
    try {
      _sender.begin(
        sessionId: sessionId,
        bip21: bip21,
        originalPsbt: signedOriginalPsbt,
        feeRateSatPerVb: feeRateSatPerVb,
      );
    } catch (e) {
      _repository.markClosed(sessionId);
      return PayjoinSendFallsBack(sessionId, e);
    }

    final deadline = DateTime.now().add(patience);
    Object lastError = 'the receiver did not answer in time';
    while (!_abandoned.isCompleted && DateTime.now().isBefore(deadline)) {
      try {
        switch (await _sender.step(sessionId)) {
          case PayjoinCheckedProposal proposal:
            stage.value = PayjoinSendStage.receiverAddedInput;
            return PayjoinSendProposal(sessionId, proposal);
          case PayjoinSendFallback(:final reason):
            return PayjoinSendFallsBack(sessionId, reason);
          case PayjoinSendWaiting():
            stage.value = PayjoinSendStage.waitingForReceiver;
        }
      } on NoOhttpRelayAvailableException catch (e) {
        // Relays can be down for a moment; keep trying until patience runs out.
        lastError = e;
      }
      await Future.any([Future<void>.delayed(pollInterval), _abandoned.future]);
    }
    _sender.cancel(sessionId);
    return PayjoinSendFallsBack(
      sessionId,
      _abandoned.isCompleted ? 'sent without waiting for the receiver' : lastError,
    );
  }

  void dispose() => stage.dispose();
}
