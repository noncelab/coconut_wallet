import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

/// 지갑 재동기화(wipe & re-fetch) 퍼널
/// TODO: fix/stale-balance 머지 후 호출부에서 연결한다.
extension WalletResyncAnalytics on AnalyticsService {
  void logWalletResyncStarted() {
    logEvent(eventName: AnalyticsEventNames.walletResyncStarted);
  }

  void logWalletResyncCompleted() {
    logEvent(eventName: AnalyticsEventNames.walletResyncCompleted);
  }

  void logWalletResyncFailed() {
    logEvent(eventName: AnalyticsEventNames.walletResyncFailed);
  }
}
