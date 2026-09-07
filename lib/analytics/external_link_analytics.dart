import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

extension ExternalLinkAnalytics on AnalyticsService {
  void logExternalLinkOpened(String url) {
    logEvent(
      eventName: AnalyticsEventNames.externalLinkOpened,
      parameters: {AnalyticsParameterNames.externalLinkUrl: url},
    );
  }
}
