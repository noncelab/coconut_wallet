import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/analytics/analytics_wallet_type.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

/// 지갑 재동기화(wipe & re-fetch) 퍼널
extension WalletResyncAnalytics on AnalyticsService {
  void logWalletResyncStarted(AnalyticsWalletType walletType) {
    logEvent(
      eventName: AnalyticsEventNames.walletResyncStarted,
      parameters: {AnalyticsParameterNames.walletType: walletType.name},
    );
  }

  void logWalletResyncCompleted(AnalyticsWalletType walletType) {
    logEvent(
      eventName: AnalyticsEventNames.walletResyncCompleted,
      parameters: {AnalyticsParameterNames.walletType: walletType.name},
    );
  }

  void logWalletResyncFailed(AnalyticsWalletType walletType) {
    logEvent(
      eventName: AnalyticsEventNames.walletResyncFailed,
      parameters: {AnalyticsParameterNames.walletType: walletType.name},
    );
  }
}
