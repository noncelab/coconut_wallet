import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

const String _receiveInteractionIdParameter = 'receive_interaction_id';

extension ReceiveAnalytics on AnalyticsService {
  void logWalletAddQrRecognized() {
    logEvent(eventName: AnalyticsEventNames.walletAddQrRecognized);
  }

  void logReceiveAddressCopied(int walletId) {
    _logReceiveEvent(AnalyticsEventNames.receiveAddressCopied, walletId);
  }

  void logReceiveQrShown(int walletId) {
    _logReceiveEvent(AnalyticsEventNames.receiveQrShown, walletId);
  }

  void logReceiveDepositDetected(int walletId) {
    final interactionId = markReceiveDepositDetected(walletId);
    if (interactionId == null) return;
    _logReceiveEventWithId(AnalyticsEventNames.receiveDepositDetected, interactionId);
  }

  void logReceiveWalletSynced(int walletId) {
    final interactionId = finishReceiveInteractionAfterDeposit(walletId);
    if (interactionId == null) return;
    _logReceiveEventWithId(AnalyticsEventNames.receiveWalletSynced, interactionId);
  }

  void _logReceiveEvent(String eventName, int walletId) {
    final interactionId = activeReceiveInteractionId(walletId);
    if (interactionId == null) return;
    _logReceiveEventWithId(eventName, interactionId);
  }

  void _logReceiveEventWithId(String eventName, String interactionId) {
    logEvent(eventName: eventName, parameters: {_receiveInteractionIdParameter: interactionId});
  }
}
