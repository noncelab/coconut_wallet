import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

extension WalletSyncAnalytics on AnalyticsService {
  void logWalletBulkSyncCompleted() {
    logEvent(eventName: AnalyticsEventNames.walletBulkSyncCompleted);
  }

  void logWalletBulkSyncFailed() {
    logEvent(eventName: AnalyticsEventNames.walletBulkSyncFailed);
  }
}
