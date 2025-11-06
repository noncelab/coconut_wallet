import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockExplorerService {
  static const String _useDefaultExplorerKey = SharedPrefKeys.kUseDefaultExplorer;
  static const String _customExplorerUrlKey = SharedPrefKeys.kCustomExplorerUrl;
  final String _defaultMempoolUrl =
      NetworkType.currentNetworkType == NetworkType.mainnet ? BLOCK_EXPLORER_URL : BLOCK_EXPLORER_URL_REGTEST;

  // 기본 익스플로러 사용 여부 가져오기
  static Future<bool> getUseDefaultExplorer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useDefaultExplorerKey) ?? true;
  }

  // 기본 익스플로러 사용 여부 설정
  static Future<void> setUseDefaultExplorer(bool useDefault) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDefaultExplorerKey, useDefault);
  }

  // 익스플로러 URL 가져오기
  static Future<String> getExplorerUrl() async {
    if (NetworkType.currentNetworkType == NetworkType.regtest) {
      return BLOCK_EXPLORER_URL_REGTEST;
    }

    final prefs = await SharedPreferences.getInstance();
    final useDefault = await getUseDefaultExplorer();
    final service = BlockExplorerService();
    return useDefault
        ? service._defaultMempoolUrl
        : prefs.getString(_customExplorerUrlKey) ?? service._defaultMempoolUrl;
  }

  // 커스텀 익스플로러 URL 설정
  static Future<void> setCustomExplorerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();

    if (!url.startsWith('http') && !url.startsWith('https')) {
      url = 'https://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    await prefs.setString(_customExplorerUrlKey, url.trim());
  }

  // 설정 초기화
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDefaultExplorerKey, true);
    await prefs.setString(_customExplorerUrlKey, '');
  }
}
