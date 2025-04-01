import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/material.dart';

class PreferenceProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  /// 홈 화면 잔액 숨기기 on/off 여부
  late bool _isBalanceHidden;
  bool get isBalanceHidden => _isBalanceHidden;

  PreferenceProvider() {
    _isBalanceHidden = _sharedPrefs.getBool(SharedPrefKeys.kIsBalanceHidden);
  }

  /// 홈 화면 잔액 숨기기
  Future<void> changeIsBalanceHidden(bool isOn) async {
    _isBalanceHidden = isOn;
    await _sharedPrefs.setBool(SharedPrefKeys.kIsBalanceHidden, isOn);
    notifyListeners();
  }
}
