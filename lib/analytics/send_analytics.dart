import 'package:coconut_wallet/analytics/analytics_value_formatter.dart';
import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/analytics_wallet_type.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

extension SendInfoAnalyticsEntryPoint on SendInfoProvider {
  SendAnalyticsEntryPoint get resolvedAnalyticsEntryPoint {
    final explicitEntryPoint = analyticsEntryPoint;
    if (explicitEntryPoint != null) return explicitEntryPoint;
    if (feeBumpingType != null) return SendAnalyticsEntryPoint.feeBump;
    return switch (sendEntryPoint) {
      SendEntryPoint.walletDetail => SendAnalyticsEntryPoint.walletDetail,
      SendEntryPoint.transactionDetail => SendAnalyticsEntryPoint.feeBump,
      SendEntryPoint.home || null => SendAnalyticsEntryPoint.home,
    };
  }
}

// 보내기 퍼널
extension SendAnalytics on AnalyticsService {
  void logSendStarted({required AnalyticsWalletType walletType, required SendAnalyticsEntryPoint entryPoint}) {
    logEvent(
      eventName: AnalyticsEventNames.sendStarted,
      parameters: {
        AnalyticsParameterNames.walletType: walletType.name,
        AnalyticsParameterNames.entryPoint: entryPoint.name,
      },
    );
  }

  void logSendCompleted({
    required AnalyticsWalletType walletType,
    required SendAnalyticsEntryPoint entryPoint,
    bool? isFirstSend,
    DateTime? hotWalletCreatedAt,
  }) {
    logEvent(
      eventName: AnalyticsEventNames.sendCompleted,
      parameters: {
        AnalyticsParameterNames.walletType: walletType.name,
        AnalyticsParameterNames.entryPoint: entryPoint.name,
        if (isFirstSend != null) AnalyticsParameterNames.isFirstSend: isFirstSend,
        if (hotWalletCreatedAt != null)
          AnalyticsParameterNames.sinceCreatedBucket: AnalyticsValueFormatter.sinceCreated(hotWalletCreatedAt),
      },
    );
  }
}
