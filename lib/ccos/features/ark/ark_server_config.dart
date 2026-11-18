import 'package:flutter/foundation.dart';

/// 빌드할 때 넘긴 아크 서버 주소. 둘 다 있어야 아크를 쓸 수 있다
abstract final class ArkServerConfig {
  static const String serverUrl = String.fromEnvironment('ARK_SERVER_URL');
  static const String esploraUrl = String.fromEnvironment('ARK_ESPLORA_URL');

  @visibleForTesting
  static bool? isConfiguredOverride;

  static bool get isConfigured => isConfiguredOverride ?? (serverUrl.isNotEmpty && esploraUrl.isNotEmpty);
}
