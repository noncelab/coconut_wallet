import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

// 새 홈 편집
extension HomeEditAnalytics on AnalyticsService {
  void logHomeEditCompleted({required bool changed, required bool presetApplied}) {
    logEvent(
      eventName: AnalyticsEventNames.homeEditCompleted,
      parameters: {AnalyticsParameterNames.changed: changed, AnalyticsParameterNames.presetApplied: presetApplied},
    );
  }
}
