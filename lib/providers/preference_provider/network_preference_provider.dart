import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/widgets.dart';

class NetworkPreferenceProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  NetworkPreferenceProvider();

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
    await _sharedPrefs.setString(SharedPrefKeys.kElectrumServerName, 'CUSTOM');
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
        setDefaultElectrumServer(DefaultElectrumServer.coconut);
        return DefaultElectrumServer.coconut.server;
      } else {
        setDefaultElectrumServer(DefaultElectrumServer.regtest);
        return DefaultElectrumServer.regtest.server;
      }
    }

    if (serverName == 'CUSTOM') {
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
}
