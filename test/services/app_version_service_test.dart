import 'dart:convert';

import 'package:coconut_wallet/services/app_version_service.dart';
import 'package:coconut_wallet/services/model/response/app_version_response.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PackageInfo package(String id) => PackageInfo(appName: 'test', packageName: id, version: '4.1.0', buildNumber: '108');
  AppUpdateInfo play(UpdateAvailability availability) => AppUpdateInfo(
    updateAvailability: availability,
    immediateUpdateAllowed: false,
    immediateAllowedPreconditions: [],
    flexibleUpdateAllowed: false,
    flexibleAllowedPreconditions: [],
    availableVersionCode: 109,
    installStatus: InstallStatus.unknown,
    packageName: 'onl.coconut.wallet.regtest',
    clientVersionStalenessDays: null,
    updatePriority: 0,
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    test('debug $platform only uses existing API', () async {
      var calls = 0;
      final expected = AppVersionResponse(latestVersion: '4.2.0');
      final service = AppVersion(
        debugMode: true,
        platform: platform,
        apiLookup: () async {
          calls++;
          return expected;
        },
        playLookup: () async => throw StateError('must not query Play'),
        packageInfo: () async => throw StateError('must not query App Store'),
      );
      expect(await service.getLatestAppVersion(), same(expected));
      expect(calls, 1);
    });
  }

  for (final id in ['onl.coconut.wallet', 'onl.coconut.wallet.regtest']) {
    test('iOS resolves $id without country and reads text JSON', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.uri.origin, 'https://itunes.apple.com');
            expect(options.uri.path, '/lookup');
            expect(options.queryParameters, {'bundleId': id});
            handler.resolve(
              Response(
                requestOptions: options,
                data: jsonEncode({
                  'resultCount': 1,
                  'results': [
                    {'bundleId': id, 'version': '4.2.0', 'trackViewUrl': 'https://apps.apple.com/app/id123'},
                  ],
                }),
              ),
            );
          },
        ),
      );
      final response =
          await AppVersion(
                debugMode: false,
                platform: TargetPlatform.iOS,
                storeClient: dio,
                packageInfo: () async => package(id),
                apiLookup: () async => throw StateError('must not use API'),
              ).getLatestAppVersion()
              as AppVersionResponse;
      expect(response.latestVersion, '4.2.0');
      expect(response.storeUrl, 'https://apps.apple.com/app/id123');
      expect(response.updateAvailable, isNull);
    });
  }

  for (final body in [
    {'results': []},
    {
      'results': [
        {'bundleId': 'another.app', 'version': '9.0.0'},
      ],
    },
    {
      'results': [
        {'bundleId': 'onl.coconut.wallet', 'version': ''},
      ],
    },
    {
      'results': [
        {'bundleId': 'onl.coconut.wallet', 'version': 123},
      ],
    },
    {'results': 'invalid'},
    'not json',
  ]) {
    test('iOS invalid or missing listing remains unknown: $body', () async {
      final dio =
          Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  handler.resolve(Response(requestOptions: options, data: body));
                },
              ),
            );
      expect(
        await AppVersion(
          debugMode: false,
          platform: TargetPlatform.iOS,
          storeClient: dio,
          packageInfo: () async => package('onl.coconut.wallet'),
          apiLookup: () async => throw StateError('must not fallback to API'),
        ).getLatestAppVersion(),
        isNull,
      );
    });
  }

  for (final entry
      in {
        UpdateAvailability.updateAvailable: true,
        UpdateAvailability.developerTriggeredUpdateInProgress: true,
        UpdateAvailability.updateNotAvailable: false,
        UpdateAvailability.unknown: null,
      }.entries) {
    test('Android maps ${entry.key} without relying on version name', () async {
      final response =
          await AppVersion(
                debugMode: false,
                platform: TargetPlatform.android,
                playLookup: () async => play(entry.key),
                apiLookup: () async => throw StateError('must not use API'),
                packageInfo: () async => throw StateError('Play resolves installed package itself'),
              ).getLatestAppVersion()
              as AppVersionResponse;
      expect(response.updateAvailable, entry.value);
      expect(response.availableVersionCode, 109);
      expect(response.latestVersion, isEmpty);
    });
  }

  test('Play error for sideloaded app stays unknown without API fallback', () async {
    expect(
      await AppVersion(
        debugMode: false,
        platform: TargetPlatform.android,
        playLookup: () async => throw PlatformException(code: 'ERROR_APP_NOT_OWNED'),
        apiLookup: () async => throw StateError('must not fallback to API'),
      ).getLatestAppVersion(),
      isNull,
    );
  });

  test('iOS network error stays unknown without API fallback', () async {
    final dio =
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                handler.reject(DioException(requestOptions: options, type: DioExceptionType.connectionTimeout));
              },
            ),
          );
    expect(
      await AppVersion(
        debugMode: false,
        platform: TargetPlatform.iOS,
        storeClient: dio,
        packageInfo: () async => package('onl.coconut.wallet'),
        apiLookup: () async => throw StateError('must not fallback to API'),
      ).getLatestAppVersion(),
      isNull,
    );
  });
}
