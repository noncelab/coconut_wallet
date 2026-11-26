import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/foundation.dart';

/// 빌드할 때 넘긴 아크 서버 주소. 둘 다 있어야 아크를 쓸 수 있다
abstract final class ArkServerConfig {
  static const String serverUrl = String.fromEnvironment('ARK_SERVER_URL');
  static const String esploraUrl = String.fromEnvironment('ARK_ESPLORA_URL');

  @visibleForTesting
  static bool? isConfiguredOverride;

  @visibleForTesting
  static bool? isRegtestOverride;

  static bool get isConfigured => isConfiguredOverride ?? (serverUrl.isNotEmpty && esploraUrl.isNotEmpty);

  static bool get _isRegtest => isRegtestOverride ?? NetworkType.currentNetworkType == NetworkType.regtest;

  /// 서버 주소 없는 regtest 빌드. 스토어에 보이되 추가는 막음
  static bool get isMainnetOnlyPreview => !isConfigured && _isRegtest;
}
