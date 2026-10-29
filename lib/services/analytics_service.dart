import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'model/request/analytics_request_types.dart';

/// Firebase Analytics
class AnalyticsService {
  final FirebaseAnalytics? _analytics;
  final SharedPrefsRepository _sharedPrefs;
  final Future<Map<String, Object>> Function()? _commonParametersLoader;

  final ValueNotifier<bool> _isCollectionEnabled = ValueNotifier(true);
  bool _isReadyToCollect = false;
  bool _isUpdating = false;
  Future<void> _initialization = Future<void>.value();

  /// [isAnalyticsDisabled]이면 SDK를 호출하지 않고 수집 선택만 저장한다.
  AnalyticsService(
    FirebaseAnalytics? analytics,
    bool isAnalyticsDisabled, {
    SharedPrefsRepository? sharedPrefs,
    Future<Map<String, Object>> Function()? commonParametersLoader,
  }) : _analytics = isAnalyticsDisabled ? null : analytics,
       _sharedPrefs = sharedPrefs ?? SharedPrefsRepository(),
       _commonParametersLoader = commonParametersLoader;

  ValueListenable<bool> get collectionEnabledListenable => _isCollectionEnabled;
  bool get isCollectionEnabled => _isCollectionEnabled.value;
  bool get canCollect => _analytics != null && _isCollectionEnabled.value && _isReadyToCollect;

  /// 저장된 수집 선택을 SDK에 적용한다. 적용이 끝날 때까지 로깅은 기다렸다가 수집 여부를 다시 확인한다.
  Future<void> initialize() {
    if (_isUpdating) return Future.error(StateError('Analytics update already in progress'));
    return _initialization = _applyStoredChoice();
  }

  Future<void> _applyStoredChoice() async {
    _isUpdating = true;
    _isReadyToCollect = false;
    try {
      _isCollectionEnabled.value =
          !_sharedPrefs.isContainsKey(SharedPrefKeys.kAnalyticsCollectionEnabled) ||
          _sharedPrefs.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled);
      final analytics = _analytics;
      if (analytics == null) return;
      await analytics.setAnalyticsCollectionEnabled(false);
      if (!_isCollectionEnabled.value) return;
      await _initializeDefaultParameters();
      await analytics.setAnalyticsCollectionEnabled(true);
      _isReadyToCollect = true;
    } catch (e) {
      Logger.error('Analytics initialization error: $e');
      await _disableCollectionAfterFailure();
    } finally {
      _isUpdating = false;
    }
  }

  /// 저장과 SDK 적용이 모두 끝나야 선택을 바꾼다. 실패하면 선택은 그대로 두고 이번 실행의 수집을 닫으므로
  /// 같은 동작으로 다시 시도할 수 있다. 수집 거부는 SDK 적용보다 먼저 저장하고 되돌리지 않는다.
  Future<void> setCollectionEnabled(bool enabled) async {
    if (_isUpdating) throw StateError('Analytics update already in progress');
    final analytics = _analytics;
    if (isCollectionEnabled == enabled && (analytics == null || (enabled && _isReadyToCollect))) return;

    _isUpdating = true;
    _isReadyToCollect = false;
    try {
      if (enabled) {
        if (analytics != null) {
          await _initializeDefaultParameters();
          await analytics.setAnalyticsCollectionEnabled(true);
        }
        await _sharedPrefs.setAnalyticsCollectionEnabled(true);
        _isReadyToCollect = analytics != null;
      } else {
        await _sharedPrefs.setAnalyticsCollectionEnabled(false);
        await analytics?.setAnalyticsCollectionEnabled(false);
      }
      _isCollectionEnabled.value = enabled;
    } catch (_) {
      await _disableCollectionAfterFailure();
      rethrow;
    } finally {
      _isUpdating = false;
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

  /// 기본 이벤트 파라미터는 선택 사항이라 실패해도 수집 선택 적용과 이벤트 전송을 막지 않는다.
  Future<void> _initializeDefaultParameters() async {
    try {
      final parameters =
          _commonParametersLoader != null ? await _commonParametersLoader() : (await _getCommonParameters()).toMap();
      await _analytics!.setDefaultEventParameters(parameters);
    } catch (e) {
      Logger.error('Analytics default parameters error: $e');
    }
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

  String? _lastScreenName;
  Map<String, Object> _lastScreenParameters = const {};

  /// Whether the last screen_view sent, also by pages that log their own (SelfLoggedScreenView), had this name and
  /// these parameters: the same name with another segment counts as a new screen_view.
  bool isLastScreenView(String screenName, [Map<String, Object>? parameters]) =>
      screenName == _lastScreenName && mapEquals(normalizeParameters(parameters), _lastScreenParameters);

  /// [parameters] are normalized like [logEvent]'s.
  Future<void> logScreenView({required String screenName, Map<String, Object>? parameters}) async {
    final normalized = normalizeParameters(parameters);
    _lastScreenName = screenName;
    _lastScreenParameters = normalized;

    try {
      await _initialization;
      if (!canCollect) return;
      await _analytics!.logScreenView(screenName: screenName, parameters: normalized.isEmpty ? null : normalized);
    } catch (e) {
      Logger.error('Analytics screen_view error: $e');
    }
  }

  /// 커스텀 이벤트 로깅
  ///
  /// [parameters]의 `bool` 값은 `'true'` / `'false'` 문자열로 바뀌어 전송된다.
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async {
    try {
      final combinedParameters = normalizeParameters(parameters);

      await _initialization;
      if (!canCollect) return;
      await _analytics!.logEvent(name: eventName, parameters: combinedParameters);
    } catch (e) {
      // 에러 발생 시 조용히 처리 (Analytics 실패가 앱 동작에 영향을 주지 않도록)
      Logger.error('Analytics error: $e');
    }
  }

  /// 파이어베이스 애널리틱스는 파라미터 값으로 문자열과 숫자만 받으므로 `bool` 값을 문자열로 바꾼다.
  @visibleForTesting
  static Map<String, Object> normalizeParameters(Map<String, Object>? parameters) {
    return {
      for (final entry in (parameters ?? const <String, Object>{}).entries)
        entry.key: entry.value is bool ? ((entry.value as bool) ? 'true' : 'false') : entry.value,
    };
  }

  /// 수집이 허용되고 SDK 호출이 오류 없이 끝나면 true를 반환한다. 서버 수신을 보장하지는 않는다.
  Future<bool> setUserProperty({required String name, required String value}) async {
    try {
      await _initialization;
      if (!canCollect) return false;
      await _analytics!.setUserProperty(name: name, value: value);
      return true;
    } catch (e) {
      Logger.error('Analytics user property error: $e');
      return false;
    }
  }
}
