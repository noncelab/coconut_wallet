import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:flutter/material.dart';

class PreferenceProvider extends ChangeNotifier {
  final SharedPrefs _sharedPrefs = SharedPrefs();

  /// 홈 화면 잔액 숨기기 on/off 여부
  late bool _isBalanceHidden;
  bool get isBalanceHidden => _isBalanceHidden;

  PreferenceProvider() {
    _isBalanceHidden = _sharedPrefs.getBool(SharedPrefs.kIsBalanceHidden);
  }

  /// 홈 화면 잔액 숨기기
  Future<void> changeIsBalanceHidden(bool isOn) async {
    _isBalanceHidden = isOn;
    await _sharedPrefs.setBool(SharedPrefs.kIsBalanceHidden, isOn);
    notifyListeners();
  }
}
