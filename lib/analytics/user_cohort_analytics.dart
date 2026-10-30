import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

extension UserCohortAnalytics on AnalyticsService {
  static AnalyticsUserCohort? resolve({
    required String? lastRunAppVersion,
    required bool hasLaunchedBefore,
    required int walletCount,
  }) {
    if (lastRunAppVersion != null) return null;
    if (!hasLaunchedBefore) return AnalyticsUserCohort.newUser;
    return walletCount > 0 ? AnalyticsUserCohort.existing : AnalyticsUserCohort.dormant;
  }

  Future<void> setUserCohort(AnalyticsUserCohort cohort) {
    return setUserProperty(name: AnalyticsUserPropertyNames.userCohort, value: cohort.value);
  }
}
