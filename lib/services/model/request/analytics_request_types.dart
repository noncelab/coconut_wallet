part of '../../analytics_service.dart';

class _CommonParameters {
  /// ios, android
  final String platform;

  final String platformVersion;
  final String appVersion;
  final String networkType;

  _CommonParameters({
    required this.platform,
    required this.platformVersion,
    required this.appVersion,
    required this.networkType,
  });

  Map<String, Object> toMap() {
    return {
      'platform': platform,
      'platform_version': platformVersion,
      'app_version': appVersion,
      'network_type': networkType,
    };
  }
}
