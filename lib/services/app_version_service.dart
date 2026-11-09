import 'dart:convert';

import 'package:coconut_wallet/services/dio_client.dart';
import 'package:coconut_wallet/services/model/response/app_version_response.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  AppVersion({
    Dio? storeClient,
    Future<dynamic> Function()? apiLookup,
    Future<AppUpdateInfo> Function()? playLookup,
    Future<PackageInfo> Function()? packageInfo,
    bool? debugMode,
    TargetPlatform? platform,
  }) : _storeClient =
           storeClient ??
           Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10))),
       _apiLookup = apiLookup,
       _playLookup = playLookup ?? InAppUpdate.checkForUpdate,
       _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
       _debugMode = debugMode ?? kDebugMode,
       _platform = platform ?? defaultTargetPlatform;

  final Dio _storeClient;
  final Future<dynamic> Function()? _apiLookup;
  final Future<AppUpdateInfo> Function() _playLookup;
  final Future<PackageInfo> Function() _packageInfo;
  final bool _debugMode;
  final TargetPlatform _platform;

  Future<dynamic> getLatestAppVersion() async {
    if (_debugMode) {
      final response = await (_apiLookup?.call() ?? DioClient().getLatestAppVersion());
      Logger.log('[App Update] source=api, response=$response');
      return response;
    }
    try {
      if (_platform == TargetPlatform.android) {
        final info = await _playLookup().timeout(const Duration(seconds: 10));
        Logger.log(
          '[App Update] source=Google Play, availability=${info.updateAvailability}, '
          'versionCode=${info.availableVersionCode}',
        );
        final available = switch (info.updateAvailability) {
          UpdateAvailability.updateAvailable || UpdateAvailability.developerTriggeredUpdateInProgress => true,
          UpdateAvailability.updateNotAvailable => false,
          _ => null,
        };
        return AppVersionResponse(
          latestVersion: '',
          updateAvailable: available,
          availableVersionCode: info.availableVersionCode,
        );
      }
      if (_platform == TargetPlatform.iOS) {
        final package = await _packageInfo();
        // Resolve the current flavor by bundle ID. Omitting country uses the default storefront.
        final response = await _storeClient.get<dynamic>(
          'https://itunes.apple.com/lookup',
          queryParameters: {'bundleId': package.packageName},
        );
        final data = response.data is String ? jsonDecode(response.data as String) : response.data;
        if (data is! Map || data['results'] is! List) return null;
        final results = data['results'] as List;
        for (final result in results) {
          if (result is! Map || result['bundleId'] != package.packageName) continue;
          final version = result['version'];
          if (version is! String || version.trim().isEmpty) return null;
          Logger.log(
            '[App Update] source=App Store, bundleId=${package.packageName}, '
            'current=${package.version}, latest=$version',
          );
          return AppVersionResponse(
            latestVersion: version,
            storeUrl: result['trackViewUrl'] is String ? result['trackViewUrl'] as String : null,
          );
        }
      }
    } catch (error) {
      Logger.log('[App Update] store check failed: $error');
    }
    // An unavailable store response must not be interpreted as "up to date".
    return null;
  }
}
