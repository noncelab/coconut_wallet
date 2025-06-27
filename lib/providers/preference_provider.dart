import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/material.dart';

class PreferenceProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  /// 홈 화면 잔액 숨기기 on/off 여부
  late bool _isBalanceHidden;
  bool get isBalanceHidden => _isBalanceHidden;

  late bool _isFakeBalanceActive;
  bool get isFakeBalanceActive => _isFakeBalanceActive;

  /// 가짜 진엑 총량
  late int? _fakeBalanceTotalAmount;
  int? get fakeBalanceTotalAmount => _fakeBalanceTotalAmount;

  late bool _isBtcUnit;
  bool get isBtcUnit => _isBtcUnit;
  BitcoinUnit get currentUnit => _isBtcUnit ? BitcoinUnit.btc : BitcoinUnit.sats;

  /// 전체 주소 보기 화면 '사용 전 주소만 보기' 여부
  late bool _showOnlyUnusedAddresses;
  bool get showOnlyUnusedAddresses => _showOnlyUnusedAddresses;

  PreferenceProvider() {
    _fakeBalanceTotalAmount = _sharedPrefs.getIntOrNull(SharedPrefKeys.kFakeBalanceTotal);
    _isFakeBalanceActive = _fakeBalanceTotalAmount != null;
    _isBalanceHidden = _sharedPrefs.getBool(SharedPrefKeys.kIsBalanceHidden);
    _isBtcUnit = _sharedPrefs.isContainsKey(SharedPrefKeys.kIsBtcUnit)
        ? _sharedPrefs.getBool(SharedPrefKeys.kIsBtcUnit)
        : true;
    _showOnlyUnusedAddresses = _sharedPrefs.getBool(SharedPrefKeys.kShowOnlyUnusedAddresses);
  }

  /// 홈 화면 잔액 숨기기
  Future<void> changeIsBalanceHidden(bool isOn) async {
    _isBalanceHidden = isOn;
    await _sharedPrefs.setBool(SharedPrefKeys.kIsBalanceHidden, isOn);

    if (!isOn) {
      _isFakeBalanceActive = false;
      await clearFakeBalanceTotalAmount();
    }

    notifyListeners();
  }

  /// 홈 화면 잔액 숨기기
  Future<void> changeIsFakeBalanceActive(bool isActive) async {
    _isFakeBalanceActive = isActive;
    if (!isActive) {
      await clearFakeBalanceTotalAmount();
    }
    notifyListeners();
  }

  /// 비트코인 기본 단위
  Future<void> changeIsBtcUnit(bool isBtcUnit) async {
    _isBtcUnit = isBtcUnit;
    await _sharedPrefs.setBool(SharedPrefKeys.kIsBtcUnit, isBtcUnit);
    notifyListeners();
  }

  /// 주소 리스트 화면 '사용 전 주소만 보기' 옵션
  Future<void> changeShowOnlyUnusedAddresses(bool show) async {
    _showOnlyUnusedAddresses = show;
    await _sharedPrefs.setBool(SharedPrefKeys.kShowOnlyUnusedAddresses, show);
    notifyListeners();
  }

  /// 가짜 잔액 총량 수정
  Future<void> setFakeBalanceTotalAmount(int balance) async {
    _fakeBalanceTotalAmount = balance;
    await _sharedPrefs.setInt(SharedPrefKeys.kFakeBalanceTotal, balance);
    notifyListeners();
  }

  /// 가짜 잔액 총량 초기화
  Future<void> clearFakeBalanceTotalAmount() async {
    _fakeBalanceTotalAmount = null;
    await _sharedPrefs.deleteSharedPrefsWithKey(SharedPrefKeys.kFakeBalanceTotal);
    await _sharedPrefs.deleteSharedPrefsWithKey(SharedPrefKeys.kFakeBalanceMap);
    notifyListeners();
  }

  /// 가짜 잔액 설정
  Future<void> setFakeBalance(int walletId, int fakeBalance) async {
    final Map<int, dynamic> map = getFakeBalanceMap();
    map[walletId] = fakeBalance;
    await setFakeBalanceMap(map);
  }

  /// 가짜 잔액 불러오기
  double getFakeBalance(int walletId) {
    final Map<int, dynamic> map = getFakeBalanceMap();
    return (map[walletId] as num?)?.toDouble() ?? 0.0;
  }

  /// 가짜 잔액 삭제
  Future<void> removeFakeBalance(int walletId) async {
    final Map<int, dynamic> map = getFakeBalanceMap();
    map.remove(walletId);
    await setFakeBalanceMap(map);
  }

  /// 가짜 잔액 Map 불러오기
  Map<int, dynamic> getFakeBalanceMap() {
    final String encoded = _sharedPrefs.getString(SharedPrefKeys.kFakeBalanceMap);
    if (encoded.isEmpty) return {};
    final Map<String, dynamic> decoded = Map<String, dynamic>.from(json.decode(encoded));
    return decoded.map((key, value) => MapEntry(int.parse(key), value));
  }

  /// 가짜 잔액 Map 설정
  Future<void> setFakeBalanceMap(Map<int, dynamic> map) async {
    final Map<String, dynamic> stringKeyMap =
        map.map((key, value) => MapEntry(key.toString(), value));
    final String encoded = json.encode(stringKeyMap);
    await _sharedPrefs.setString(SharedPrefKeys.kFakeBalanceMap, encoded);
  }
}
