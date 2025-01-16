// VisibilityProvider

// 1. 최초 구동인지 - 홈 / 온보딩
// 2. 용어집 바로가기 요소 보여줄지 - 홈
// 3. 지갑 목록이 비었는지 → 지갑이 몇 개인지?! - 홈

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/services/secure_storage_service.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:flutter/material.dart';

class VisibilityProvider extends ChangeNotifier {
  final SharedPrefs _sharedPrefs = SharedPrefs();
  final SecureStorageService _secureStorageService = SecureStorageService();

  /// iOS에서 앱 지워도 secureStorage가 남아있어서 지우기 위해 사용
  late bool _hasLaunchedBefore;
  bool get hasLaunchedBefore => _hasLaunchedBefore;

  /// 용어집 바로가기 요소
  bool _hideTermsShortcut = false;
  bool get visibleTermsShortcut => _hideTermsShortcut;

  late int _walletCount;
  int get walletCount => _walletCount;

  VisibilityProvider() {
    _hasLaunchedBefore =
        _sharedPrefs.getBool(SharedPrefKeys.kHasLaunchedBefore);
    _hideTermsShortcut =
        _sharedPrefs.getBool(SharedPrefKeys.kHideTermsShortcut);
    _walletCount = _sharedPrefs.getInt(SharedPrefKeys.kWalletCount);
  }

  Future<void> setHasLaunchedBefore() async {
    await _secureStorageService.deleteAll();
    await _sharedPrefs.setBool(SharedPrefKeys.kHasLaunchedBefore, true);
  }

  Future<void> hideTermsShortcut() async {
    _hideTermsShortcut = true;
    await _sharedPrefs.setBool(SharedPrefKeys.kHideTermsShortcut, true);
    notifyListeners();
  }

  Future<void> setWalletCount(int count) async {
    _walletCount = count;
    await _sharedPrefs.setInt(SharedPrefKeys.kWalletCount, count);
    notifyListeners();
  }
}
