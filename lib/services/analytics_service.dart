import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'model/request/analytics_request_types.dart';

class AnalyticsService extends ChangeNotifier {
  final FirebaseAnalytics? _analytics;
  final SharedPrefsRepository _sharedPrefs;
  final Future<Map<String, Object>> Function()? _commonParametersLoader;

  bool _isCollectionEnabled = true;
  bool _isReadyToCollect = false;
  bool _isUpdating = false;

  AnalyticsService(
    this._analytics, {
    SharedPrefsRepository? sharedPrefs,
    Future<Map<String, Object>> Function()? commonParametersLoader,
  }) : _sharedPrefs = sharedPrefs ?? SharedPrefsRepository(),
       _commonParametersLoader = commonParametersLoader;

  bool get isCollectionEnabled => _isCollectionEnabled;
  bool get canCollect => _analytics != null && _isCollectionEnabled && _isReadyToCollect;
  bool get isUpdating => _isUpdating;

  Future<void> initialize() async {
    if (_isUpdating) throw StateError('Analytics update already in progress');
    _isUpdating = true;
    _isReadyToCollect = false;
    notifyListeners();
    try {
      _isCollectionEnabled =
          !_sharedPrefs.isContainsKey(SharedPrefKeys.kAnalyticsCollectionEnabled) ||
          _sharedPrefs.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled);
      if (_analytics == null) return;
      await _analytics.setAnalyticsCollectionEnabled(false);
      if (!_isCollectionEnabled) return;
      await _initializeDefaultParameters();
      await _analytics.setAnalyticsCollectionEnabled(true);
      _isReadyToCollect = true;
    } catch (e) {
      Logger.error('Analytics initialization error: $e');
      await _disableCollectionAfterFailure();
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> setCollectionEnabled(bool enabled) async {
    if (_isUpdating) throw StateError('Analytics update already in progress');
    if (_isCollectionEnabled == enabled && (_analytics == null || (enabled && _isReadyToCollect))) return;

    _isUpdating = true;
    _isReadyToCollect = false;
    notifyListeners();
    try {
      if (enabled) {
        if (_analytics != null) {
          await _initializeDefaultParameters();
        }
        await _sharedPrefs.setAnalyticsCollectionEnabled(true);
        _isCollectionEnabled = true;
        if (_analytics != null) {
          await _analytics.setAnalyticsCollectionEnabled(true);
          _isReadyToCollect = true;
        }
      } else {
        await _sharedPrefs.setAnalyticsCollectionEnabled(false);
        _isCollectionEnabled = false;
        await _analytics?.setAnalyticsCollectionEnabled(false);
      }
    } catch (_) {
      await _disableCollectionAfterFailure();
      rethrow;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> _disableCollectionAfterFailure() async {
    _isReadyToCollect = false;
    try {
      await _analytics?.setAnalyticsCollectionEnabled(false);
    } catch (e) {
      Logger.error('Analytics fail-safe disable error: $e');
    }
  }

  Future<void> _initializeDefaultParameters() async {
    final parameters =
        _commonParametersLoader != null ? await _commonParametersLoader() : (await _getCommonParameters()).toMap();
    await _analytics!.setDefaultEventParameters(parameters);
  }

  /// 공통 이벤트 파라미터 생성
  Future<_CommonParameters> _getCommonParameters() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return _CommonParameters(
      platform: Platform.operatingSystem,
      platformVersion: Platform.operatingSystemVersion,
      appVersion: packageInfo.version,
      networkType: NetworkType.currentNetworkType.toString(),
    );
  }

  Future<void> logScreenView({required String screenName}) async {
    if (!canCollect) return;

    try {
      await _analytics!.logScreenView(screenName: screenName);
    } catch (e) {
      Logger.error('Analytics screen_view error: $e');
    }
  }

  /// 커스텀 이벤트 로깅
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async {
    if (!canCollect) return;

    try {
      final combinedParameters = <String, Object>{...?parameters};

      await _analytics!.logEvent(name: eventName, parameters: combinedParameters);
    } catch (e) {
      // 에러 발생 시 조용히 처리 (Analytics 실패가 앱 동작에 영향을 주지 않도록)
      Logger.error('Analytics error: $e');
    }
  }

  /// 사용자 속성 설정
  Future<void> setUserProperty({required String name, required String value}) async {
    if (!canCollect) return;

    try {
      await _analytics!.setUserProperty(name: name, value: value);
    } catch (e) {
      Logger.error('Analytics user property error: $e');
    }
  }
}
