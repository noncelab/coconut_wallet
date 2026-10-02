import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

// 지갑 상세 화면 퍼널
extension WalletDetailAnalytics on AnalyticsService {
  void logWalletDetailAction(WalletDetailAction element) {
    logEvent(
      eventName: AnalyticsEventNames.walletDetailAction,
      parameters: {AnalyticsParameterNames.element: element.name},
    );
  }

  void logTargetAmountSaved() {
    logEvent(eventName: AnalyticsEventNames.targetAmountSaved);
  }

  void logWalletFilterChanged(WalletFilter filter) {
    logEvent(
      eventName: AnalyticsEventNames.walletFilterChanged,
      parameters: {AnalyticsParameterNames.walletTypeFilter: filter.name},
    );
  }
}
