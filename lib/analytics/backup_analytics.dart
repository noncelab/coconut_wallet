import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/analytics_value_formatter.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

// 핫월렛 백업 퍼널
extension BackupAnalytics on AnalyticsService {
  void logBackupPromptTapped(BackupPromptLocation location) {
    logEvent(
      eventName: AnalyticsEventNames.backupPromptTapped,
      parameters: {AnalyticsParameterNames.source: location.name},
    );
  }

  void logBackupCompleted(DateTime? hotWalletCreatedAt) {
    logEvent(
      eventName: AnalyticsEventNames.backupCompleted,
      parameters: {
        if (hotWalletCreatedAt != null)
          AnalyticsParameterNames.sinceCreatedBucket: AnalyticsValueFormatter.sinceCreated(hotWalletCreatedAt),
      },
    );
  }
}
