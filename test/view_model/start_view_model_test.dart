import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/providers/view_model/onboarding/start_view_model.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/app_version_service.dart';
import 'package:coconut_wallet/services/model/response/app_version_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAppVersion extends Fake implements AppVersion {
  FakeAppVersion({required this.delay, this.response, this.shouldThrow = false});

  final Duration delay;
  final AppVersionResponse? response;
  final bool shouldThrow;

  @override
  Future<dynamic> getLatestAppVersion() async {
    await Future.delayed(delay);
    if (shouldThrow) throw Exception('network error');
    return response;
  }
}

class FakeVisibilityProvider extends Fake implements VisibilityProvider {}

class FakeAuthProvider extends Fake implements AuthProvider {}

class CohortVisibilityProvider extends Fake implements VisibilityProvider {
  CohortVisibilityProvider({required this.launched, required this.count, this.version});

  bool launched;
  int count;
  String? version;
  int firstLaunchWrites = 0;
  int versionWrites = 0;

  @override
  bool get hasLaunchedBefore => launched;
  @override
  int get walletCount => count;
  @override
  String? get lastRunAppVersion => version;
  @override
  Future<void> setHasLaunchedBefore() async {
    firstLaunchWrites++;
    launched = true;
  }

  @override
  Future<void> setLastRunAppVersion(String value) async {
    versionWrites++;
    version = value;
  }
}

class CohortAuthProvider extends Fake implements AuthProvider {
  @override
  bool get isAuthEnabled => false;
  @override
  bool get isBiometricsAuthEnabled => false;
}

class CohortRecordingAnalytics extends AnalyticsService {
  CohortRecordingAnalytics() : super(null, true);
  final properties = <String, String>{};
  int writes = 0;

  @override
  Future<void> setUserProperty({required String name, required String value}) async {
    properties[name] = value;
    writes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'coconut_wallet',
      packageName: 'com.coconut.wallet',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    SharedPrefsRepository().setSharedPreferencesForTest(prefs);
  });

  group('StartViewModel.ensureVersionChecked', () {
    test('reflects an update even when the version check resolves slowly', () async {
      final viewModel = StartViewModel(
        FakeVisibilityProvider(),
        FakeAuthProvider(),
        AnalyticsService(null, true),
        appVersionRepository: FakeAppVersion(
          delay: const Duration(milliseconds: 50),
          response: AppVersionResponse(latestVersion: '2.0.0'),
        ),
      );

      await viewModel.ensureVersionChecked();

      expect(viewModel.canUpdate, isTrue);
    });

    test('reflects an update when the version check resolves immediately', () async {
      final viewModel = StartViewModel(
        FakeVisibilityProvider(),
        FakeAuthProvider(),
        AnalyticsService(null, true),
        appVersionRepository: FakeAppVersion(
          delay: Duration.zero,
          response: AppVersionResponse(latestVersion: '2.0.0'),
        ),
      );

      await viewModel.ensureVersionChecked();

      expect(viewModel.canUpdate, isTrue);
    });

    test('does not flag an update when the major version is unchanged', () async {
      final viewModel = StartViewModel(
        FakeVisibilityProvider(),
        FakeAuthProvider(),
        AnalyticsService(null, true),
        appVersionRepository: FakeAppVersion(
          delay: Duration.zero,
          response: AppVersionResponse(latestVersion: '1.2.3'),
        ),
      );

      await viewModel.ensureVersionChecked();

      expect(viewModel.canUpdate, isFalse);
    });

    test('completes without throwing when the version check fails', () async {
      final viewModel = StartViewModel(
        FakeVisibilityProvider(),
        FakeAuthProvider(),
        AnalyticsService(null, true),
        appVersionRepository: FakeAppVersion(delay: Duration.zero, shouldThrow: true),
      );

      await viewModel.ensureVersionChecked();

      expect(viewModel.canUpdate, isFalse);
    });
  });

  group('StartViewModel launch cohort', () {
    for (final entry in [(false, 0, 'new'), (true, 0, 'dormant'), (true, 2, 'existing')]) {
      test('records ${entry.$3} before persisting first launch and keeps it after wallet changes', () async {
        final visibility = CohortVisibilityProvider(launched: entry.$1, count: entry.$2);
        final analytics = CohortRecordingAnalytics();
        final viewModel = StartViewModel(
          visibility,
          CohortAuthProvider(),
          analytics,
          appVersionRepository: FakeAppVersion(delay: Duration.zero),
        );
        await viewModel.ensureVersionChecked();
        await viewModel.determineStartScreen();

        expect(analytics.properties, {AnalyticsUserPropertyNames.userCohort: entry.$3});
        expect(visibility.firstLaunchWrites, entry.$1 ? 0 : 1);
        expect(visibility.version, '1.0.0');
        expect(visibility.versionWrites, 1);

        visibility.count = entry.$2 == 0 ? 3 : 0;
        await viewModel.determineStartScreen();
        expect(analytics.writes, 1);
        expect(visibility.versionWrites, 1);
        expect(analytics.properties[AnalyticsUserPropertyNames.userCohort], entry.$3);
        viewModel.dispose();
      });
    }

    test('a later release updates the version marker without replacing the original cohort', () async {
      final visibility = CohortVisibilityProvider(launched: true, count: 2, version: '0.19.0');
      final analytics = CohortRecordingAnalytics();
      final viewModel = StartViewModel(
        visibility,
        CohortAuthProvider(),
        analytics,
        appVersionRepository: FakeAppVersion(delay: Duration.zero),
      );
      await viewModel.ensureVersionChecked();
      await viewModel.determineStartScreen();

      expect(analytics.writes, 0);
      expect(visibility.versionWrites, 1);
      expect(visibility.firstLaunchWrites, 0);
      expect(visibility.version, '1.0.0');
      viewModel.dispose();
    });
  });
}
