import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/model/faucet/faucet_history.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsRepository {
  late SharedPreferences _sharedPrefs;
  SharedPreferences get sharedPrefs => _sharedPrefs;

  @Deprecated('Test code에서만 사용합니다')
  void setSharedPreferencesForTest(SharedPreferences sp) {
    _sharedPrefs = sp;
  }

  static final SharedPrefsRepository _instance = SharedPrefsRepository._internal();

  factory SharedPrefsRepository() => _instance;

  SharedPrefsRepository._internal();

  Future<void> init() async {
    // init in main.dart
    _sharedPrefs = await SharedPreferences.getInstance();
  }

  /// Common--------------------------------------------------------------------
  Future clearSharedPref() async {
    await _sharedPrefs.clear();
  }

  bool isContainsKey(String key) {
    return _sharedPrefs.containsKey(key);
  }

  Future deleteSharedPrefsWithKey(String key) async {
    await _sharedPrefs.remove(key);
  }

  bool getBool(String key) {
    return _sharedPrefs.getBool(key) ?? false;
  }

  Future setBool(String key, bool value) async {
    await _sharedPrefs.setBool(key, value);
  }

  int getInt(String key) {
    return _sharedPrefs.getInt(key) ?? 0;
  }

  int? getIntOrNull(String key) {
    return _sharedPrefs.getInt(key);
  }

  Future setInt(String key, int value) async {
    await _sharedPrefs.setInt(key, value);
  }

  String getString(String key) {
    return _sharedPrefs.getString(key) ?? '';
  }

  Future setString(String key, String value) async {
    await _sharedPrefs.setString(key, value);
  }

  double? getDouble(String key) {
    return _sharedPrefs.getDouble(key);
  }

  Future setDouble(String key, double value) async {
    await _sharedPrefs.setDouble(key, value);
  }

  /// Delete multiple keys at once
  Future<void> deleteMultipleKeys(List<String> keys) async {
    for (final key in keys) {
      await _sharedPrefs.remove(key);
    }
  }

  /// FaucetHistory-------------------------------------------------------------
  Future<void> saveFaucetHistory(FaucetRecord faucetHistory) async {
    final Map<int, FaucetRecord> faucetHistories = _getFaucetHistories();
    faucetHistories[faucetHistory.id] = faucetHistory;
    await _saveFaucetHistories(faucetHistories);
  }

  FaucetRecord getFaucetHistoryWithId(int id) {
    final Map<int, FaucetRecord> faucetHistories = _getFaucetHistories();
    if (faucetHistories.containsKey(id)) {
      return faucetHistories[id]!;
    } else {
      return FaucetRecord(
        id: id,
        dateTime: DateTime.now().millisecondsSinceEpoch,
        count: 0,
      );
    }
  }

  Future<void> removeFaucetHistory(int id) async {
    Map<int, FaucetRecord> faucetHistories = _getFaucetHistories();
    faucetHistories.remove(id);
    await _saveFaucetHistories(faucetHistories);
  }

  Future<void> _saveFaucetHistories(Map<int, FaucetRecord> histories) async {
    final String encodedData =
        json.encode(histories.map((key, value) => MapEntry(key.toString(), value.toJson())));
    await _sharedPrefs.setString(SharedPrefKeys.kFaucetHistories, encodedData);
  }

  Map<int, FaucetRecord> _getFaucetHistories() {
    final String? encodedData = _sharedPrefs.getString(SharedPrefKeys.kFaucetHistories);
    if (encodedData == null) {
      return {};
    }
    final Map<String, dynamic> decodedData = json.decode(encodedData);
    return decodedData.map((key, value) => MapEntry(int.parse(key), FaucetRecord.fromJson(value)));
  }

  /// 사용자 서버 정보-------------------------------------------------------------
  Future<List<ElectrumServer>?> getUserServers() async {
    final prefs = await SharedPreferences.getInstance();
    final serverJson = prefs.getString(SharedPrefKeys.kUserServers);

    Logger.log('💽 getUserServers: $serverJson');

    if (serverJson != null) {
      try {
        final serverData = jsonDecode(serverJson) as Map<String, dynamic>;
        final servers = <ElectrumServer>[];
        for (final server in serverData.entries) {
          servers.add(ElectrumServer.custom(
            server.value['host'] as String,
            server.value['port'] as int,
            server.value['ssl'] as bool,
          ));
        }
        return servers;
      } catch (e) {
        Logger.error('Failed to parse user server: $e');
        return null;
      }
    }
    return null;
  }

  /// 사용자 서버 추가 (키 기반으로 중복 확인)
  Future<void> addUserServer(ElectrumServer server) async {
    final existingServers = await getUserServers();
    final serverKey = '${server.host}:${server.port}';

    // 중복 확인
    final isDuplicate =
        existingServers?.any((existing) => '${existing.host}:${existing.port}' == serverKey);

    if (isDuplicate ?? false) {
      Logger.log('User server already exists: $serverKey');
      return;
    }

    existingServers?.add(server);
    await saveUserServers(existingServers ?? []);
    Logger.log('User server added: $serverKey');
  }

  /// 사용자 서버 목록 저장 (host:port를 키로 사용)
  Future<void> saveUserServers(List<ElectrumServer> servers) async {
    final prefs = await SharedPreferences.getInstance();
    final serversMap = <String, Map<String, dynamic>>{};

    for (final server in servers) {
      final key = '${server.host}:${server.port}';
      serversMap[key] = {
        'host': server.host,
        'port': server.port,
        'ssl': server.ssl,
      };
    }

    await prefs.setString(SharedPrefKeys.kUserServers, jsonEncode(serversMap));
  }

  /// 사용자 서버 정보 삭제
  Future<void> removeUserServer(ElectrumServer server) async {
    final existingServers = await getUserServers();
    final serverKey = '${server.host}:${server.port}';
    existingServers?.removeWhere((existing) => '${existing.host}:${existing.port}' == serverKey);
    await saveUserServers(existingServers ?? []);
  }

  /// 사용자 서버 정보 삭제
  Future<void> clearUserServer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(SharedPrefKeys.kUserServers);
  }
}
