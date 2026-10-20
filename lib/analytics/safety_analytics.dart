import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';

/// Wallet Health 시작·완료 이벤트. 점수·검사 결과·사건 내용·지갑 정보·금액은 보내지 않는다(Epic 3 측정 설계)
extension SafetyAnalytics on AnalyticsService {
  void logSafetyCheckStarted() => logEvent(eventName: AnalyticsEventNames.safetyCheckStarted);

  void logSafetyCheckCompleted() => logEvent(eventName: AnalyticsEventNames.safetyCheckCompleted);

  void logIncidentResponseStarted(IncidentResponseMode mode) {
    logEvent(
      eventName: AnalyticsEventNames.incidentResponseStarted,
      parameters: {AnalyticsParameterNames.responseMode: mode.name},
    );
  }

  void logIncidentResponseCompleted(IncidentResponseMode mode) {
    logEvent(
      eventName: AnalyticsEventNames.incidentResponseCompleted,
      parameters: {AnalyticsParameterNames.responseMode: mode.name},
    );
  }

  void logPremiumPurchaseCompleted(PremiumPeriod period) {
    logEvent(
      eventName: AnalyticsEventNames.premiumPurchaseCompleted,
      parameters: {AnalyticsParameterNames.period: period.name},
    );
  }
}
