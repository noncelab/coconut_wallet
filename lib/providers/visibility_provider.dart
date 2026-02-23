// VisibilityProvider

// 1. 최초 구동인지 - 홈 / 온보딩
// 2. 지갑 목록이 비었는지 → 지갑이 몇 개인지?! - 홈

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/material.dart';

class VisibilityProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();
  final SecureStorageRepository _secureStorageService = SecureStorageRepository();
  bool _isDisposed = false;

  /// iOS에서 앱 지워도 secureStorage가 남아있어서 지우기 위해 사용
  /// onBoading 노출 여부
  late bool _hasLaunchedBefore;
  bool get hasLaunchedBefore => _hasLaunchedBefore;

  late int _walletCount;
  int get walletCount => _walletCount;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  VisibilityProvider() {
    _hasLaunchedBefore = _sharedPrefs.getBool(SharedPrefKeys.kHasLaunchedBefore);
    _walletCount = _sharedPrefs.getInt(SharedPrefKeys.kWalletCount);
  }

  Future<void> setHasLaunchedBefore() async {
    await _secureStorageService.deleteAll();
    await _sharedPrefs.setBool(SharedPrefKeys.kHasLaunchedBefore, true);
  }

  Future<void> setWalletCount(int count) async {
    _walletCount = count;
    await _sharedPrefs.setInt(SharedPrefKeys.kWalletCount, count);
    if (!_isDisposed) notifyListeners();
  }
}
