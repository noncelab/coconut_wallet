import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_receiver.dart';

/// What to tell the receiver about its payjoin session.
String payjoinReceiveStatusText(PayjoinReceiveProgress? progress, {required bool hasError}) => switch (progress) {
  PayjoinReceiveNeedsSignature() => t.payjoin.receive_needs_signature,
  PayjoinReceiveProposalSent() => t.payjoin.receive_proposal_sent,
  PayjoinReceiveClosed(payjoinTxid: final txid?) when txid.isNotEmpty => t.payjoin.receive_done_payjoin,
  PayjoinReceiveClosed(fallbackBroadcast: true) => t.payjoin.receive_done_fallback,
  PayjoinReceiveClosed() => t.payjoin.receive_closed,
  PayjoinReceiveWaiting() || null => hasError ? t.payjoin.receive_unavailable : t.payjoin.receive_waiting,
};
