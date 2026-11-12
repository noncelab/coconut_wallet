import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/view_model/onboarding/start_view_model.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/app_version_service.dart';
import 'package:coconut_wallet/services/model/response/app_version_response.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Visibility extends Fake implements VisibilityProvider {}

class _Auth extends Fake implements AuthProvider {}

const _installed = '1.1.0';
const _id = 'onl.coconut.wallet';

/// Play는 버전 이름 없이 업데이트 여부만 준다.
AppVersion _play(UpdateAvailability availability) => AppVersion(
  debugMode: false,
  platform: TargetPlatform.android,
  playLookup:
      () async => AppUpdateInfo(
        updateAvailability: availability,
        immediateUpdateAllowed: false,
        immediateAllowedPreconditions: [],
        flexibleUpdateAllowed: false,
        flexibleAllowedPreconditions: [],
        availableVersionCode: 101,
        installStatus: InstallStatus.unknown,
        packageName: _id,
        clientVersionStalenessDays: null,
        updatePriority: 0,
      ),
  apiLookup: () async => throw StateError('release builds must not use the API'),
);

/// [version]이 null이면 App Store에 이 앱의 목록이 없는 응답이다(조회 실패와 같게 처리된다).
AppVersion _appStore(String? version) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest:
          (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              data: jsonEncode({
                'resultCount': version == null ? 0 : 1,
                'results': [
                  if (version != null)
                    {'bundleId': _id, 'version': version, 'trackViewUrl': 'https://apps.apple.com/app/id1'},
                ],
              }),
            ),
          ),
    ),
  );
  return AppVersion(
    debugMode: false,
    platform: TargetPlatform.iOS,
    storeClient: dio,
    packageInfo:
        () async => PackageInfo(appName: 'coconut_wallet', packageName: _id, version: _installed, buildNumber: '100'),
    apiLookup: () async => throw StateError('release builds must not use the API'),
  );
}

/// debug 빌드는 기존 버전 서버를 읽는다.
AppVersion _server(String version) =>
    AppVersion(debugMode: true, apiLookup: () async => AppVersionResponse(latestVersion: version));

Future<bool> _showsPopup(AppVersion versions, {DateTime? snoozedUntil}) async {
  SharedPreferences.setMockInitialValues({
    if (snoozedUntil != null) SharedPrefKeys.kNextVersionUpdateDialogDate: snoozedUntil.toIso8601String(),
  });
  await SharedPrefsRepository().init();
  final viewModel = StartViewModel(
    _Visibility(),
    _Auth(),
    AnalyticsService(null, true),
    appVersionRepository: versions,
  );
  await viewModel.ensureVersionChecked();
  return viewModel.canUpdate;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'coconut_wallet',
      packageName: _id,
      version: _installed,
      buildNumber: '100',
      buildSignature: '',
    );
  });

  const newer = ['1.1.1', '1.2.0', '2.0.0'];

  group('start update popup on every newer store version', () {
    for (final latest in newer) {
      test('iOS shows it for $_installed -> $latest', () async {
        expect(await _showsPopup(_appStore(latest)), isTrue);
      });
    }

    test('iOS does not show it for the same version', () async {
      expect(await _showsPopup(_appStore(_installed)), isFalse);
    });

    test('iOS does not show it when the store version is older', () async {
      expect(await _showsPopup(_appStore('1.0.9')), isFalse);
    });

    test('iOS does not show it when the store has no listing', () async {
      expect(await _showsPopup(_appStore(null)), isFalse);
    });

    test('iOS does not show it when the store version has an unsupported format', () async {
      expect(await _showsPopup(_appStore('1.2')), isFalse);
    });

    test('Android keeps following Play: an update shows it', () async {
      expect(await _showsPopup(_play(UpdateAvailability.updateAvailable)), isTrue);
    });

    test('Android keeps following Play: no update does not show it', () async {
      expect(await _showsPopup(_play(UpdateAvailability.updateNotAvailable)), isFalse);
    });

    test('Android does not show it when Play cannot tell (unknown)', () async {
      expect(await _showsPopup(_play(UpdateAvailability.unknown)), isFalse);
    });

    test('debug builds read the version server; an older server version does not show it', () async {
      expect(await _showsPopup(_server('1.0.0')), isFalse);
    });

    test('debug builds read the version server; a newer server version shows it', () async {
      expect(await _showsPopup(_server('1.1.1')), isTrue);
    });
  });

  group('7-day snooze still holds', () {
    final later = DateTime.now().add(const Duration(days: 7));
    final earlier = DateTime.now().subtract(const Duration(minutes: 1));

    test('iOS: a newer version is not shown while snoozed', () async {
      expect(await _showsPopup(_appStore('1.1.1'), snoozedUntil: later), isFalse);
    });

    test('Android: an update is not shown while snoozed', () async {
      expect(await _showsPopup(_play(UpdateAvailability.updateAvailable), snoozedUntil: later), isFalse);
    });

    test('iOS: shown again once the snooze has passed', () async {
      expect(await _showsPopup(_appStore('1.1.1'), snoozedUntil: earlier), isTrue);
    });

    test('"later" stores now + 7 days, and the next start does not show it', () async {
      SharedPreferences.setMockInitialValues({});
      await SharedPrefsRepository().init();
      Future<StartViewModel> start() async {
        final viewModel = StartViewModel(
          _Visibility(),
          _Auth(),
          AnalyticsService(null, true),
          appVersionRepository: _appStore('1.1.1'),
        );
        await viewModel.ensureVersionChecked();
        return viewModel;
      }

      final first = await start();
      expect(first.canUpdate, isTrue);

      const week = Duration(days: 7);
      final before = DateTime.now();
      await first.setNextUpdateDialogDate();
      final after = DateTime.now();
      final stored = DateTime.parse(SharedPrefsRepository().getString(SharedPrefKeys.kNextVersionUpdateDialogDate));
      expect(
        stored.microsecondsSinceEpoch,
        inInclusiveRange(before.add(week).microsecondsSinceEpoch, after.add(week).microsecondsSinceEpoch),
      );

      expect((await start()).canUpdate, isFalse);
    });
  });
}
