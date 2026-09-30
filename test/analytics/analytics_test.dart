import 'package:coconut_wallet/analytics/analytics_value_formatter.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/user_cohort_analytics.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserCohortAnalytics.resolve', () {
    test('classifies a fresh install as new', () {
      final cohort = UserCohortAnalytics.resolve(lastRunAppVersion: null, hasLaunchedBefore: false, walletCount: 0);
      expect(cohort, AnalyticsUserCohort.newUser);
    });

    test('classifies an upgraded install with wallets as existing', () {
      final cohort = UserCohortAnalytics.resolve(lastRunAppVersion: null, hasLaunchedBefore: true, walletCount: 2);
      expect(cohort, AnalyticsUserCohort.existing);
    });

    test('classifies an upgraded install without wallets as dormant', () {
      final cohort = UserCohortAnalytics.resolve(lastRunAppVersion: null, hasLaunchedBefore: true, walletCount: 0);
      expect(cohort, AnalyticsUserCohort.dormant);
    });

    test('does not classify once a run has been recorded', () {
      final cohort = UserCohortAnalytics.resolve(lastRunAppVersion: '1.0.0', hasLaunchedBefore: true, walletCount: 1);
      expect(cohort, isNull);
    });
  });

  group('AnalyticsValueFormatter', () {
    final createdAt = DateTime(2026, 1, 1);

    test('buckets elapsed time since creation', () {
      expect(AnalyticsValueFormatter.sinceCreated(createdAt, now: createdAt.add(const Duration(minutes: 59))), 'lt1h');
      expect(AnalyticsValueFormatter.sinceCreated(createdAt, now: createdAt.add(const Duration(hours: 1))), '1to24h');
      expect(AnalyticsValueFormatter.sinceCreated(createdAt, now: createdAt.add(const Duration(hours: 24))), '1to7d');
      expect(AnalyticsValueFormatter.sinceCreated(createdAt, now: createdAt.add(const Duration(days: 7))), 'gt7d');
    });
  });

  group('AnalyticsService.normalizeParameters', () {
    test('converts bool values to strings and keeps other values', () {
      final parameters = AnalyticsService.normalizeParameters({
        'flag_on': true,
        'flag_off': false,
        'name': 'a',
        'count': 3,
      });
      expect(parameters, {'flag_on': 'true', 'flag_off': 'false', 'name': 'a', 'count': 3});
    });

    test('returns an empty map when parameters are null', () {
      expect(AnalyticsService.normalizeParameters(null), isEmpty);
    });
  });
}
