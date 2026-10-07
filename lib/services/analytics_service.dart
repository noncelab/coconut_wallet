import 'dart:io';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'model/request/analytics_request_types.dart';

/// Firebase Analytics
class AnalyticsService {
  final FirebaseAnalytics? _analytics;
  final bool _isAnalyticsDisabled;
  late final Future<void> _initialization;

  AnalyticsService(this._analytics, this._isAnalyticsDisabled) {
    _initialization =
        _isAnalyticsDisabled || _analytics == null ? Future<void>.value() : _initializeDefaultParameters();
  }

  /// 기본 이벤트 파라미터 초기화
  Future<void> _initializeDefaultParameters() async {
    try {
      final commonParams = await _getCommonParameters();
      await _analytics?.setDefaultEventParameters(commonParams.toMap());
    } catch (e) {
      Logger.error('Analytics initialization error: $e');
    }
  }

  /// 공통 이벤트 파라미터 생성
  Future<_CommonParameters> _getCommonParameters() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentNetworkType = NetworkType.currentNetworkType;

    return _CommonParameters(
      platform: Platform.operatingSystem,
      platformVersion: Platform.operatingSystemVersion,
      appVersion: packageInfo.version,
      networkType: currentNetworkType.toString(),
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
    if (_isAnalyticsDisabled) return;

    try {
      await _initialization;
      await _analytics?.logScreenView(screenName: screenName, parameters: normalized.isEmpty ? null : normalized);
    } catch (e) {
      Logger.error('Analytics screen_view error: $e');
    }
  }

  /// 커스텀 이벤트 로깅
  ///
  /// [parameters]의 `bool` 값은 `'true'` / `'false'` 문자열로 바뀌어 전송된다.
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async {
    if (_isAnalyticsDisabled) return;

    try {
      final combinedParameters = normalizeParameters(parameters);

      await _initialization;
      await _analytics?.logEvent(name: eventName, parameters: combinedParameters);
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

  /// 사용자 속성 설정
  Future<void> setUserProperty({required String name, required String value}) async {
    if (_isAnalyticsDisabled) return;

    try {
      await _analytics?.setUserProperty(name: name, value: value);
    } catch (e) {
      Logger.error('Analytics user property error: $e');
    }
  }
}
