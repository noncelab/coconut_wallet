import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';

/// 지갑별 꾸미기 값을 SharedPreferences 한 키(`WALLET_APPEARANCE_MAP`)에 walletId → json 맵으로 둔다.
/// Realm 지갑 스키마는 건드리지 않는다.
class WalletAppearanceRepository {
  final SharedPrefsRepository _prefs;

  WalletAppearanceRepository([SharedPrefsRepository? prefs]) : _prefs = prefs ?? SharedPrefsRepository();

  Map<int, WalletBackground> loadBackgrounds() {
    final result = <int, WalletBackground>{};
    _readMap().forEach((key, value) {
      final walletId = int.tryParse(key);
      final background = value is Map ? WalletBackground.fromJson(value['background']) : null;
      if (walletId != null && background != null) result[walletId] = background;
    });
    return result;
  }

  Future<void> setBackground(int walletId, WalletBackground? background) async {
    final map = _readMap();
    final key = walletId.toString();
    final entry = Map<String, dynamic>.from(map[key] is Map ? map[key] as Map : const {});
    if (background == null) {
      entry.remove('background');
    } else {
      entry['background'] = background.toJson();
    }
    if (entry.isEmpty) {
      map.remove(key);
    } else {
      map[key] = entry;
    }
    await _writeMap(map);
  }

  Future<void> remove(int walletId) async {
    final map = _readMap();
    if (map.remove(walletId.toString()) == null) return;
    await _writeMap(map);
  }

  Map<String, dynamic> _readMap() {
    final encoded = _prefs.getStringOrNull(SharedPrefKeys.kWalletAppearanceMap);
    if (encoded == null || encoded.isEmpty) return {};
    try {
      final decoded = json.decode(encoded);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMap(Map<String, dynamic> map) async {
    if (map.isEmpty) {
      await _prefs.deleteSharedPrefsWithKey(SharedPrefKeys.kWalletAppearanceMap);
    } else {
      await _prefs.setString(SharedPrefKeys.kWalletAppearanceMap, json.encode(map));
    }
  }
}
