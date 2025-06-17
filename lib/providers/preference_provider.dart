import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/material.dart';

class PreferenceProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  /// 홈 화면 잔액 숨기기 on/off 여부
  late bool _isBalanceHidden;
  bool get isBalanceHidden => _isBalanceHidden;

  late bool _isBtcUnit;
  bool get isBtcUnit => _isBtcUnit;
  BitcoinUnit get currentUnit => _isBtcUnit ? BitcoinUnit.btc : BitcoinUnit.sats;

  PreferenceProvider() {
    _isBalanceHidden = _sharedPrefs.getBool(SharedPrefKeys.kIsBalanceHidden);
    _isBtcUnit = _sharedPrefs.isContainsKey(SharedPrefKeys.kIsBtcUnit)
        ? _sharedPrefs.getBool(SharedPrefKeys.kIsBtcUnit)
        : true;
  }

  /// 홈 화면 잔액 숨기기
  Future<void> changeIsBalanceHidden(bool isOn) async {
    _isBalanceHidden = isOn;
    await _sharedPrefs.setBool(SharedPrefKeys.kIsBalanceHidden, isOn);
    notifyListeners();
  }

  /// 비트코인 기본 단위
  Future<void> changeIsBtcUnit(bool isBtcUnit) async {
    _isBtcUnit = isBtcUnit;
    await _sharedPrefs.setBool(SharedPrefKeys.kIsBtcUnit, isBtcUnit);
    notifyListeners();
  }
}
