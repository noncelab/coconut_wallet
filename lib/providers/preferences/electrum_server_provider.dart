import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/widgets.dart';

class ElectrumServerProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  static const String _customServerLabel = 'CUSTOM';

  /// 기본 서버의 실제 인증서 도메인이 바뀌어 접속 주소가 달라진 경우의 이전 주소 매핑
  /// migrateLegacyCustomServerStorage에서 기본 서버 매칭을 시도하기 전에 먼저 적용한다.
  static const Map<String, String> _legacyDefaultServerHostAliases = {
    'mainnet.foundationdevices.com': 'mainnet-0.foundation.xyz',
    'electrum1.bluewallet.io': 'electrum2.bluewallet.io',
  };

  ElectrumServerProvider();

  /// 기본 서버를 선택했을 때 host/port/ssl을 리터럴로 저장하지 않고 serverName 참조로 저장한다.
  /// 이후 해당 기본 서버의 host나 지문이 바뀌어도 getElectrumServer()가 항상 최신 enum 값을 반환한다.
  Future<void> setSelectedDefaultServer(String serverName) async {
    await _sharedPrefs.setString(SharedPrefKeys.kElectrumServerName, serverName);
    await _sharedPrefs.deleteMultipleKeys([
      SharedPrefKeys.kCustomElectrumHost,
      SharedPrefKeys.kCustomElectrumPort,
      SharedPrefKeys.kCustomElectrumIsSsl,
      SharedPrefKeys.kCustomElectrumCertFingerprint,
    ]);
    notifyListeners();
  }

  /// 앱 부팅 시(NetworkType 결정 이후) 1회 호출
  /// 예전 구조에서는 기본 서버를 선택해도 무조건 'CUSTOM' + 리터럴 host/port/ssl로 저장하는 구조 개선
  /// - 저장된 값이 실제로는 기본 서버와 일치하면 serverName 참조로 옮긴다.
  /// - 사용자가 직접 등록한 커스텀 서버 목록(kUserServers)은 건드리지 않는다.
  Future<void> migrateLegacyCustomServerStorage() async {
    if (_sharedPrefs.getString(SharedPrefKeys.kElectrumServerName) != _customServerLabel) return;

    final storedHost = _sharedPrefs.getString(SharedPrefKeys.kCustomElectrumHost);
    final host = _legacyDefaultServerHostAliases[storedHost] ?? storedHost;
    final port = _sharedPrefs.getInt(SharedPrefKeys.kCustomElectrumPort);
    final ssl = _sharedPrefs.getBool(SharedPrefKeys.kCustomElectrumIsSsl);

    final matched = DefaultElectrumServer.findMatching(host, port, ssl);
    if (matched != null) {
      await setSelectedDefaultServer(matched.serverName);
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

  Future<void> setCustomElectrumServer(String host, int port, bool ssl, {String? pinnedCertFingerprint}) async {
    _validateCustomElectrumServerParams(host, port, ssl);
    await _sharedPrefs.setString(SharedPrefKeys.kElectrumServerName, _customServerLabel);
    await _sharedPrefs.setString(SharedPrefKeys.kCustomElectrumHost, host);
    await _sharedPrefs.setInt(SharedPrefKeys.kCustomElectrumPort, port);
    await _sharedPrefs.setBool(SharedPrefKeys.kCustomElectrumIsSsl, ssl);
    if (pinnedCertFingerprint != null) {
      await _sharedPrefs.setString(SharedPrefKeys.kCustomElectrumCertFingerprint, pinnedCertFingerprint);
    } else {
      await _sharedPrefs.deleteSharedPrefsWithKey(SharedPrefKeys.kCustomElectrumCertFingerprint);
    }
    notifyListeners();
  }

  ElectrumServer getElectrumServer() {
    final serverName = _sharedPrefs.getString(SharedPrefKeys.kElectrumServerName);
    debugPrint('ELECTRUM_SERVER_PROVIDER:: getElectrumServer() serverName: $serverName');

    if (serverName.isEmpty) {
      if (NetworkType.currentNetworkType == NetworkType.mainnet) {
        return DefaultElectrumServer.coconut.server;
      } else if (NetworkType.currentNetworkType == NetworkType.regtest) {
        return DefaultElectrumServer.regtest.server;
      } else {
        return DefaultElectrumServer.blockstreamTestnet.server;
      }
    }

    if (serverName == _customServerLabel) {
      return ElectrumServer.custom(
        _sharedPrefs.getString(SharedPrefKeys.kCustomElectrumHost),
        _sharedPrefs.getInt(SharedPrefKeys.kCustomElectrumPort),
        _sharedPrefs.getBool(SharedPrefKeys.kCustomElectrumIsSsl),
        pinnedCertFingerprint: _sharedPrefs.getStringOrNull(SharedPrefKeys.kCustomElectrumCertFingerprint),
      );
    }

    return DefaultElectrumServer.fromServerType(serverName).server;
  }

  Future<List<ElectrumServer>> getUserServers() async {
    return (await _sharedPrefs.getUserServers()) ?? [];
  }

  Future<void> addUserServer(String host, int port, bool ssl, {String? pinnedCertFingerprint}) async {
    await _sharedPrefs.addUserServer(
      ElectrumServer.custom(host, port, ssl, pinnedCertFingerprint: pinnedCertFingerprint),
    );
    notifyListeners();
  }

  Future<void> removeUserServer(ElectrumServer server) async {
    await _sharedPrefs.removeUserServer(server);
    notifyListeners();
  }
}
