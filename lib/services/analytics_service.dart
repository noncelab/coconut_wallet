import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';

part 'model/request/analytics_request_types.dart';

/// Firebase Analytics
class AnalyticsService {
  static const Duration receiveInteractionTtl = Duration(minutes: 30);

  final FirebaseAnalytics? _analytics;
  final bool _isAnalyticsDisabled;
  final DateTime Function() _now;
  final Random _secureRandom;
  final Map<int, _ReceiveInteraction> _receiveInteractions = {};

  bool _isInitialized = false;

  AnalyticsService(this._analytics, this._isAnalyticsDisabled, {DateTime Function()? now, Random? secureRandom})
    : _now = now ?? DateTime.now,
      _secureRandom = secureRandom ?? Random.secure() {
    if (_isAnalyticsDisabled) return;
    _initializeDefaultParameters();
  }

  /// 받기 화면과 같은 지갑에서 이어지는 로컬 동기화를 연결하기 위한 임시 식별자입니다.
  /// 지갑 ID는 메모리 맵의 키로만 쓰고 Analytics로 전송하지 않습니다.
  String startReceiveInteraction(int walletId) {
    _removeExpiredReceiveInteractions();
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
    final interactionId = base64UrlEncode(bytes).replaceAll('=', '');
    _receiveInteractions[walletId] = _ReceiveInteraction(interactionId, _now().add(receiveInteractionTtl));
    return interactionId;
  }

  String? activeReceiveInteractionId(int walletId) {
    _removeExpiredReceiveInteractions();
    return _receiveInteractions[walletId]?.id;
  }

  String? markReceiveDepositDetected(int walletId) {
    _removeExpiredReceiveInteractions();
    final interaction = _receiveInteractions[walletId];
    if (interaction == null) return null;
    interaction.depositDetected = true;
    return interaction.id;
  }

  String? finishReceiveInteractionAfterDeposit(int walletId) {
    _removeExpiredReceiveInteractions();
    final interaction = _receiveInteractions[walletId];
    if (interaction == null || !interaction.depositDetected) return null;
    _receiveInteractions.remove(walletId);
    return interaction.id;
  }

  void _removeExpiredReceiveInteractions() {
    final now = _now();
    _receiveInteractions.removeWhere((_, interaction) => !interaction.expiresAt.isAfter(now));
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

  Future<void> logScreenView({required String screenName}) async {
    if (_isAnalyticsDisabled) return;

    try {
      await _analytics?.logScreenView(screenName: screenName);
    } catch (e) {
      Logger.error('Analytics screen_view error: $e');
    }
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

class _ReceiveInteraction {
  final String id;
  final DateTime expiresAt;
  bool depositDetected = false;

  _ReceiveInteraction(this.id, this.expiresAt);
}
