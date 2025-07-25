import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/locale_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
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

  /// 전체 주소 보기 화면 [입금] 툴팁 표시 여부 - 영문 버전에서는 표시 안함
  late bool _isReceivingTooltipDisabled;
  bool get isReceivingTooltipDisabled => language == 'kr' ? _isReceivingTooltipDisabled : true;

  /// 전체 주소 보기 화면 [잔돈] 툴팁 표시 여부 - 영문 버전에서는 표시 안함
  late bool _isChangeTooltipDisabled;
  bool get isChangeTooltipDisabled => language == 'kr' ? _isChangeTooltipDisabled : true;

  /// 언어 설정
  late String _language;
  String get language => _language;

  /// 선택된 통화
  late FiatCode _selectedFiat;
  FiatCode get selectedFiat => _selectedFiat;

  PreferenceProvider() {
    _fakeBalanceTotalAmount = _sharedPrefs.getIntOrNull(SharedPrefKeys.kFakeBalanceTotal);
    _isFakeBalanceActive = _fakeBalanceTotalAmount != null;
    _isBalanceHidden = _sharedPrefs.getBool(SharedPrefKeys.kIsBalanceHidden);
    _isBtcUnit = _sharedPrefs.isContainsKey(SharedPrefKeys.kIsBtcUnit)
        ? _sharedPrefs.getBool(SharedPrefKeys.kIsBtcUnit)
        : true;
    _showOnlyUnusedAddresses = _sharedPrefs.getBool(SharedPrefKeys.kShowOnlyUnusedAddresses);
    _isReceivingTooltipDisabled = _sharedPrefs.getBool(SharedPrefKeys.kIsReceivingTooltipDisabled);
    _isChangeTooltipDisabled = _sharedPrefs.getBool(SharedPrefKeys.kIsChangeTooltipDisabled);

    // 통화 설정 초기화
    _initializeFiat();

    // 언어 설정 초기화 - OS 설정에 따라 자동 선택
    _initializeLanguageFromSystem();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyLanguageSettingSync();
    });
  }

  /// 통화 설정 초기화
  void _initializeFiat() {
    final fiatCode = _sharedPrefs.getString(SharedPrefKeys.kSelectedFiat);
    if (fiatCode.isNotEmpty) {
      _selectedFiat = FiatCode.values.firstWhere(
        (fiat) => fiat.code == fiatCode,
        orElse: () => FiatCode.KRW,
      );
    } else {
      _selectedFiat = FiatCode.KRW;
      _sharedPrefs.setString(SharedPrefKeys.kSelectedFiat, _selectedFiat.code);
    }
  }

  /// OS 설정에 따라 언어 설정 초기화
  void _initializeLanguageFromSystem() {
    bool changed = false;
    if (_sharedPrefs.isContainsKey(SharedPrefKeys.kLanguage)) {
      _language = _sharedPrefs.getString(SharedPrefKeys.kLanguage);
    } else {
      _language = getSystemLanguageCode();
      _sharedPrefs.setString(SharedPrefKeys.kLanguage, _language);
      changed = true;
    }

    _applyLanguageSettingSync();
    if (changed) {
      notifyListeners();
    }
  }

  /// 언어 설정 적용 (동기 버전)
  void _applyLanguageSettingSync() {
    try {
      Logger.log('Applying language setting: $_language');
      if (_language == 'kr') {
        LocaleSettings.setLocaleSync(AppLocale.kr);
        Logger.log('Korean locale applied successfully');
      } else if (_language == 'en') {
        LocaleSettings.setLocaleSync(AppLocale.en);
        Logger.log('English locale applied successfully');
      }

      // 언어 설정 후 상태 업데이트를 위해 notifyListeners 호출
      notifyListeners();
    } catch (e) {
      // 언어 초기화 실패 시 로그 출력 (선택사항)
      Logger.log('Language initialization failed: $e');
    }
  }

  /// 언어 설정 적용
  Future<void> _applyLanguageSetting() async {
    try {
      if (_language == 'kr') {
        await LocaleSettings.setLocale(AppLocale.kr);
      } else if (_language == 'en') {
        await LocaleSettings.setLocale(AppLocale.en);
      } else {
        // 기본값은 영어로 설정
        await LocaleSettings.setLocale(AppLocale.en);
      }
    } catch (e) {
      // 언어 초기화 실패 시 로그 출력 (선택사항)
      Logger.log('Language initialization failed: $e');
    }
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

  /// 주소 리스트 화면 '입금' 툴팁 다시 보지 않기 설정
  Future<void> setReceivingTooltipDisabledPermanently() async {
    _isReceivingTooltipDisabled = true;
    await _sharedPrefs.setBool(SharedPrefKeys.kIsReceivingTooltipDisabled, true);
    notifyListeners();
  }

  /// 주소 리스트 화면 '잔돈' 툴팁 다시 보지 않기 설정
  Future<void> setChangeTooltipDisabledPermanently() async {
    _isChangeTooltipDisabled = true;
    await _sharedPrefs.setBool(SharedPrefKeys.kIsChangeTooltipDisabled, true);
    notifyListeners();
  }

  /// 언어 변경
  Future<void> changeLanguage(String languageCode) async {
    _language = languageCode;
    await _sharedPrefs.setString(SharedPrefKeys.kLanguage, languageCode);

    // 언어 설정 적용
    await _applyLanguageSetting();

    // 언어 설정 후 상태 업데이트
    notifyListeners();
  }

  /// 통화 변경
  Future<void> changeFiat(FiatCode fiatCode) async {
    _selectedFiat = fiatCode;
    await _sharedPrefs.setString(SharedPrefKeys.kSelectedFiat, fiatCode.code);
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
