import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'model/request/analytics_request_types.dart';

typedef AnalyticsCollectionStatus = ({bool isUpdating, bool disablePending, bool hasError});

/// Firebase Analytics
class AnalyticsService {
  final FirebaseAnalytics? _analytics;
  final SharedPrefsRepository _sharedPrefs;
  final Future<Map<String, Object>> Function()? _commonParametersLoader;

  final ValueNotifier<bool> _isCollectionEnabled = ValueNotifier(true);
  final _collectionStatus = ValueNotifier<AnalyticsCollectionStatus>((
    isUpdating: false,
    disablePending: false,
    hasError: false,
  ));
  bool _isReadyToCollect = false;
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
  ValueListenable<AnalyticsCollectionStatus> get collectionStatusListenable => _collectionStatus;
  bool get isCollectionEnabled => _isCollectionEnabled.value;
  bool get canCollect => _analytics != null && _isCollectionEnabled.value && _isReadyToCollect;
  bool get _isUpdating => _collectionStatus.value.isUpdating;

  void _updateCollectionStatus({bool? isUpdating, bool? disablePending, bool? hasError}) {
    final previous = _collectionStatus.value;
    _collectionStatus.value = (
      isUpdating: isUpdating ?? previous.isUpdating,
      disablePending: disablePending ?? previous.disablePending,
      hasError: hasError ?? previous.hasError,
    );
  }

  /// 저장된 수집 선택을 SDK에 적용한다. 적용이 끝날 때까지 로깅은 기다렸다가 수집 여부를 다시 확인한다.
  Future<void> initialize() {
    if (_isUpdating) return Future.error(StateError('Analytics update already in progress'));
    return _initialization = _applyStoredChoice();
  }

  Future<void> _applyStoredChoice() async {
    _isReadyToCollect = false;
    _updateCollectionStatus(isUpdating: true);
    try {
      _isCollectionEnabled.value =
          !_sharedPrefs.isContainsKey(SharedPrefKeys.kAnalyticsCollectionEnabled) ||
          _sharedPrefs.getBool(SharedPrefKeys.kAnalyticsCollectionEnabled);
      final analytics = _analytics;
      if (analytics != null) {
        await analytics.setAnalyticsCollectionEnabled(false);
        if (_isCollectionEnabled.value) {
          await _initializeDefaultParameters();
          await analytics.setAnalyticsCollectionEnabled(true);
          _isReadyToCollect = true;
        }
      }
      _updateCollectionStatus(disablePending: false, hasError: false);
    } catch (e) {
      Logger.error('Analytics initialization error: $e');
      final disabled = await _disableCollectionAfterFailure();
      _updateCollectionStatus(
        disablePending: !isCollectionEnabled && !disabled,
        hasError: isCollectionEnabled || !disabled,
      );
    } finally {
      _updateCollectionStatus(isUpdating: false);
    }
  }

  /// 스위치는 저장된 선택을 나타낸다. 수집 거부는 SDK 적용보다 먼저 저장·표시하고 되돌리지 않는다.
  /// 적용 실패 시 Dart 수집을 닫고, 확인되지 않은 끄기는 화면 수명과 무관하게 명시적으로 재시도한다.
  Future<void> setCollectionEnabled(bool enabled) async {
    if (_isUpdating) throw StateError('Analytics update already in progress');
    final analytics = _analytics;
    final status = _collectionStatus.value;
    if (!status.disablePending &&
        !status.hasError &&
        isCollectionEnabled == enabled &&
        (analytics == null || (enabled && _isReadyToCollect))) {
      return;
    }

    _isReadyToCollect = false;
    _updateCollectionStatus(isUpdating: true);
    var choiceSaved = false;
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
        choiceSaved = true;
        _isCollectionEnabled.value = false;
        await analytics?.setAnalyticsCollectionEnabled(false);
      }
      _isCollectionEnabled.value = enabled;
      _updateCollectionStatus(disablePending: false, hasError: false);
    } catch (e) {
      final disabled = await _disableCollectionAfterFailure();
      final disablePending = (!enabled && !choiceSaved) || (!isCollectionEnabled && !disabled);
      _updateCollectionStatus(disablePending: disablePending, hasError: disablePending || !disabled);
      if (!enabled && choiceSaved && disabled) {
        Logger.error('Analytics disable recovered after error: ${e.runtimeType}');
        return;
      }
      rethrow;
    } finally {
      _updateCollectionStatus(isUpdating: false);
    }
  }

  Future<bool> _disableCollectionAfterFailure() async {
    _isReadyToCollect = false;
    try {
      await _analytics?.setAnalyticsCollectionEnabled(false);
      return true;
    } catch (e) {
      Logger.error('Analytics fail-safe disable error: $e');
      return false;
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
