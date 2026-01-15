import 'dart:io';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'model/request/analytics_request_types.dart';

/// Firebase Analytics
class AnalyticsService {
  final FirebaseAnalytics? _analytics;
  final bool _isAnalyticsDisabled;

  bool _isInitialized = false;

  AnalyticsService(this._analytics, this._isAnalyticsDisabled) {
    if (_isAnalyticsDisabled) return;
    _initializeDefaultParameters();
  }

  /// 기본 이벤트 파라미터 초기화
  Future<void> _initializeDefaultParameters() async {
    if (_isInitialized) return;

    try {
      final commonParams = await _getCommonParameters();
      await _analytics?.setDefaultEventParameters(commonParams.toMap());
      _isInitialized = true;
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

  /// 커스텀 이벤트 로깅
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async {
    if (_isAnalyticsDisabled) return;

    try {
      final combinedParameters = <String, Object>{...?parameters};

      await _analytics?.logEvent(name: eventName, parameters: combinedParameters);
    } catch (e) {
      // 에러 발생 시 조용히 처리 (Analytics 실패가 앱 동작에 영향을 주지 않도록)
      Logger.error('Analytics error: $e');
    }
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
