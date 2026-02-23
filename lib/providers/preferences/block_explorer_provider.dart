import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/locale_util.dart';
import 'package:coconut_wallet/utils/url_normalize_util.dart';
import 'package:flutter/widgets.dart';

class BlockExplorerProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  static const String _langKr = 'kr';
  static const String _langJp = 'jp';
  static const String _langEn = 'en';

  static const String _mempoolUrlMain = 'https://mempool.space';
  static const String _mempoolUrlKr = 'https://mempool.space/ko';
  static const String _mempoolUrlJp = 'https://mempool.space/ja';

  BlockExplorerProvider();

  bool get useDefaultExplorer {
    if (_sharedPrefs.isContainsKey(SharedPrefKeys.kUseDefaultExplorer)) {
      return _sharedPrefs.getBool(SharedPrefKeys.kUseDefaultExplorer);
    }
    return true;
  }

  String get customExplorerUrl => _sharedPrefs.getString(SharedPrefKeys.kCustomExplorerUrl);

  String get blockExplorerUrl {
    if (NetworkType.currentNetworkType == NetworkType.regtest) {
      return BLOCK_EXPLORER_URL_REGTEST;
    }

    if (useDefaultExplorer) {
      return _getDefaultMempoolUrl();
    } else {
      return customExplorerUrl.isNotEmpty ? customExplorerUrl : _getDefaultMempoolUrl();
    }
  }

  String _getDefaultMempoolUrl() {
    // 언어 설정은 SharedPrefs에서 직접 가져옴
    final language = _sharedPrefs.getString(SharedPrefKeys.kLanguage);
    final effectiveLanguage = language.isNotEmpty ? language : getSystemLanguageCode();

    switch (effectiveLanguage) {
      case _langKr:
        return _mempoolUrlKr;
      case _langJp:
        return _mempoolUrlJp;
      case _langEn:
      default:
        return _mempoolUrlMain;
    }
  }

  Future<void> setUseDefaultExplorer(bool useDefault) async {
    await _sharedPrefs.setBool(SharedPrefKeys.kUseDefaultExplorer, useDefault);
    notifyListeners();
  }

  Future<void> setCustomExplorerUrl(String url) async {
    final formattedUrl = UrlNormalizeUtil.normalize(url);

    await _sharedPrefs.setString(SharedPrefKeys.kCustomExplorerUrl, formattedUrl);
    notifyListeners();
  }

  Future<void> resetBlockExplorerToDefault() async {
    await setUseDefaultExplorer(true);
    await setCustomExplorerUrl('');
  }
}
