import 'dart:convert';

import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';

class HomeConfigurationRepository {
  static const key = 'HOME_CONFIGURATION';

  final SharedPrefsRepository _prefs;

  HomeConfigurationRepository(this._prefs);

  HomeConfiguration? load() {
    final raw = _prefs.getStringOrNull(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return HomeConfiguration.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  Future<void> save(HomeConfiguration configuration) async {
    await _prefs.setString(key, jsonEncode(configuration.toJson()));
  }
}
