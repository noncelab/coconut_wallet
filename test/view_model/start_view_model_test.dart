import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/view_model/onboarding/start_view_model.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
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
        appVersionRepository: FakeAppVersion(delay: Duration.zero, shouldThrow: true),
      );

      await viewModel.ensureVersionChecked();

      expect(viewModel.canUpdate, isFalse);
    });
  });
}
