import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/locale_util.dart';
import 'package:flutter/widgets.dart';
import 'package:coconut_wallet/utils/url_normalize_util.dart';

class NetworkPreferenceProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  static const String _serverNameCustom = 'CUSTOM';

  static const String _langKr = 'kr';
  static const String _langJp = 'jp';
  static const String _langEn = 'en';

  static const String _mempoolUrlMain = 'https://mempool.space';
  static const String _mempoolUrlKr = 'https://mempool.space/ko';
  static const String _mempoolUrlJp = 'https://mempool.space/ja';

  NetworkPreferenceProvider();

  Future<void> ensureInitialized() async {
    final serverName = _sharedPrefs.getString(SharedPrefKeys.kElectrumServerName);

    if (serverName.isEmpty) {
      if (NetworkType.currentNetworkType == NetworkType.mainnet) {
        await setDefaultElectrumServer(DefaultElectrumServer.coconut);
      } else {
        await setDefaultElectrumServer(DefaultElectrumServer.regtest);
      }
    }
  }

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
      final customUrl = customExplorerUrl;
      return customUrl.isNotEmpty ? customUrl : _getDefaultMempoolUrl();
    }
  }

  String _getDefaultMempoolUrl() {
    // 언어 설정은 SharedPrefs에서 직접 가져옴 (PreferenceProvider 의존성 방지)
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

  void _validateCustomElectrumServerParams(String host, int port, bool ssl) {
    if (host.trim().isEmpty) {
      throw ArgumentError('Host cannot be empty');
    }

    if (port <= 0 || port > 65535) {
      throw ArgumentError('Port must be between 1 and 65535');
    }
  }

  Future<void> setDefaultElectrumServer(DefaultElectrumServer defaultElectrumServer) async {
    await _sharedPrefs.setString(SharedPrefKeys.kElectrumServerName, defaultElectrumServer.serverName);
    notifyListeners();
  }

  Future<void> setCustomElectrumServer(String host, int port, bool ssl) async {
    _validateCustomElectrumServerParams(host, port, ssl);
    await _sharedPrefs.setString(SharedPrefKeys.kElectrumServerName, _serverNameCustom);
    await _sharedPrefs.setString(SharedPrefKeys.kCustomElectrumHost, host);
    await _sharedPrefs.setInt(SharedPrefKeys.kCustomElectrumPort, port);
    await _sharedPrefs.setBool(SharedPrefKeys.kCustomElectrumIsSsl, ssl);
    notifyListeners();
  }

  ElectrumServer getElectrumServer() {
    final serverName = _sharedPrefs.getString(SharedPrefKeys.kElectrumServerName);
    debugPrint('NETWORK_PREFERENCE:: getElectrumServer() serverName: $serverName');

    if (serverName.isEmpty) {
      if (NetworkType.currentNetworkType == NetworkType.mainnet) {
        return DefaultElectrumServer.coconut.server;
      } else {
        return DefaultElectrumServer.regtest.server;
      }
    }

    if (serverName == _serverNameCustom) {
      return ElectrumServer.custom(
        _sharedPrefs.getString(SharedPrefKeys.kCustomElectrumHost),
        _sharedPrefs.getInt(SharedPrefKeys.kCustomElectrumPort),
        _sharedPrefs.getBool(SharedPrefKeys.kCustomElectrumIsSsl),
      );
    }

    return DefaultElectrumServer.fromServerType(serverName).server;
  }

  Future<List<ElectrumServer>> getUserServers() async {
    return (await _sharedPrefs.getUserServers()) ?? [];
  }

  Future<void> addUserServer(String host, int port, bool ssl) async {
    await _sharedPrefs.addUserServer(ElectrumServer.custom(host, port, ssl));
    notifyListeners();
  }

  Future<void> removeUserServer(ElectrumServer server) async {
    await _sharedPrefs.removeUserServer(server);
    notifyListeners();
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
