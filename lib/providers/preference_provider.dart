import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/locale_util.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

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

  /// 언어 설정
  late String _language;
  String get language => _language;

  /// 선택된 통화
  late FiatCode _selectedFiat;
  FiatCode get selectedFiat => _selectedFiat;

  /// 지갑 순서
  late List<int> _walletOrder;
  List<int> get walletOrder => _walletOrder;

  /// 지갑 즐겨찾기 목록
  late List<int> _favoriteWalletIds;
  List<int> get favoriteWalletIds => _favoriteWalletIds;

  /// 총 잔액에서 제외할 지갑 목록
  late List<int> _excludedFromTotalBalanceWalletIds;
  List<int> get excludedFromTotalBalanceWalletIds => _excludedFromTotalBalanceWalletIds;

  /// 홈 화면에 표시할 기능(최근 거래, 분석 ...)
  late List<HomeFeature> _homeFeatures;
  List<HomeFeature> get homeFeatures => _homeFeatures;

  PreferenceProvider() {
    _fakeBalanceTotalAmount = _sharedPrefs.getIntOrNull(SharedPrefKeys.kFakeBalanceTotal);
    _isFakeBalanceActive = _fakeBalanceTotalAmount != null;
    _isBalanceHidden = _sharedPrefs.getBool(SharedPrefKeys.kIsBalanceHidden);
    _isBtcUnit = _sharedPrefs.isContainsKey(SharedPrefKeys.kIsBtcUnit)
        ? _sharedPrefs.getBool(SharedPrefKeys.kIsBtcUnit)
        : true;
    _showOnlyUnusedAddresses = _sharedPrefs.getBool(SharedPrefKeys.kShowOnlyUnusedAddresses);
    _walletOrder = _getWalletOrder();
    _favoriteWalletIds = _getFavoriteWalletIds();
    _excludedFromTotalBalanceWalletIds = _getExcludedFromTotalBalanceWalletIds();
    _homeFeatures = _getHomeFeatures();
    _initializeFiat();
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
      print('Applying language setting: $_language');
      if (_language == 'kr') {
        LocaleSettings.setLocaleSync(AppLocale.kr);
        print('Korean locale applied successfully');
      } else if (_language == 'en') {
        LocaleSettings.setLocaleSync(AppLocale.en);
        print('English locale applied successfully');
      }

      // 언어 설정 후 상태 업데이트를 위해 notifyListeners 호출
      notifyListeners();
    } catch (e) {
      // 언어 초기화 실패 시 로그 출력 (선택사항)
      print('Language initialization failed: $e');
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
      print('Language initialization failed: $e');
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

  /// 지갑 순서 불러오기
  List<int> _getWalletOrder() {
    final encoded = _sharedPrefs.getString(SharedPrefKeys.kWalletOrder);
    if (encoded.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(encoded);
    return decoded.cast<int>();
  }

  /// 지갑 순서 설정
  Future<void> setWalletOrder(List<int> walletOrder) async {
    _walletOrder = walletOrder;
    await _sharedPrefs.setString(SharedPrefKeys.kWalletOrder, jsonEncode(walletOrder));
    notifyListeners();
  }

  /// 지갑 순서 단일 제거
  Future<void> removeWalletOrder(int walletId) async {
    _walletOrder.remove(walletId);
    await setWalletOrder(_walletOrder);
    notifyListeners();
  }

  /// 지갑 즐겨찾기 목록 불러오기
  List<int> _getFavoriteWalletIds() {
    final encoded = _sharedPrefs.getString(SharedPrefKeys.kFavoriteWalletIds);
    if (encoded.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(encoded);
    return decoded.cast<int>();
  }

  /// 지갑 즐겨찾기 목록 설정
  Future<void> setFavoriteWalletIds(List<int> favoriteWalletIds) async {
    _favoriteWalletIds = favoriteWalletIds;
    await _sharedPrefs.setString(SharedPrefKeys.kFavoriteWalletIds, jsonEncode(favoriteWalletIds));
    notifyListeners();
  }

  /// 지갑 즐겨찾기 단일 제거
  Future<void> removeFavoriteWalletId(int walletId) async {
    _favoriteWalletIds.remove(walletId);
    await setFavoriteWalletIds(_favoriteWalletIds);
    notifyListeners();
  }

  /// 총 잔액에서 제외할 지갑 목록 불러오기
  List<int> _getExcludedFromTotalBalanceWalletIds() {
    final encoded = _sharedPrefs.getString(SharedPrefKeys.kExcludedFromTotalBalanceWalletIds);
    if (encoded.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(encoded);
    return decoded.cast<int>();
  }

  /// 총 잔액에서 제외할 지갑 설정
  Future<void> setExcludedFromTotalBalanceWalletIds(List<int> ids) async {
    _excludedFromTotalBalanceWalletIds = ids;
    await _sharedPrefs.setString(
        SharedPrefKeys.kExcludedFromTotalBalanceWalletIds, jsonEncode(ids));
    notifyListeners();
  }

  /// 총 잔액에서 제외할 지갑 단일 제거
  Future<void> removeExcludedFromTotalBalanceWalletId(int walletId) async {
    _excludedFromTotalBalanceWalletIds.remove(walletId);
    await setExcludedFromTotalBalanceWalletIds(_excludedFromTotalBalanceWalletIds);
    notifyListeners();
  }

  /// 홈 화면에 표시할 기능
  List<HomeFeature> _getHomeFeatures() {
    final encoded = _sharedPrefs.getString(SharedPrefKeys.kHomeFeatures);
    if (encoded.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(encoded);
    return decoded.map((e) => HomeFeature.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> setHomeFeautres(List<HomeFeature> features) async {
    // 잔액 합계, 지갑 목록은 고정이기 때문에 리스트에 포함되지 않습니다.
    // 토글 가능한 항목('최근 거래', '분석'...)만 리스트에 포함됩니다.
    // 추후 홈 화면 기능이 추가됨에 따라 kHomeFeatures를 수정할 필요가 있습니다.
    _homeFeatures = List.from(features);
    await _sharedPrefs.setString(
      SharedPrefKeys.kHomeFeatures,
      jsonEncode(features.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> setWalletPreferences(List<WalletListItemBase> walletItemList) async {
    final initialHomeFeatures = [
      // ** 추가시 homeFeatureTypeString 을 [HomeFeatureType]과 동일시해야함 **
      HomeFeature(homeFeatureTypeString: HomeFeatureType.recentTransaction.name, isEnabled: true),
      HomeFeature(homeFeatureTypeString: HomeFeatureType.analysis.name, isEnabled: true),
    ];

    var walletOrder = _walletOrder;
    var favoriteWalletIds = _favoriteWalletIds;
    var homeFeatures = _homeFeatures;

    if (walletOrder.isEmpty) {
      walletOrder = List.from(walletItemList.map((w) => w.id));
      await setWalletOrder(walletOrder);
    }
    if (favoriteWalletIds.isEmpty) {
      favoriteWalletIds = List.from(walletItemList.take(5).map((w) => w.id));
      await setFavoriteWalletIds(favoriteWalletIds);
    }
    if (homeFeatures.isEmpty) {
      homeFeatures.addAll(List.from(initialHomeFeatures));
      await setHomeFeautres(homeFeatures);
    } else {
      final isSame = const DeepCollectionEquality.unordered().equals(
        homeFeatures.map((e) => e.homeFeatureTypeString).toList(),
        initialHomeFeatures.map((e) => e.homeFeatureTypeString).toList(),
      );
      if (isSame) return;

      // 홈 기능은 추후 추가/제거 등 달라질 여지가 있기 때문에 내용을 비교해서 추가/제거 합니다.(kHomeFeatures 기준)
      final updatedHomeFeatures = <HomeFeature>[];
      for (final defaultFeature in initialHomeFeatures) {
        final existing = homeFeatures.firstWhereOrNull(
          (e) => e.homeFeatureTypeString == defaultFeature.homeFeatureTypeString,
        );
        updatedHomeFeatures.add(existing ?? defaultFeature);
      }
      homeFeatures.removeWhere((e) =>
          !initialHomeFeatures.any((k) => k.homeFeatureTypeString == e.homeFeatureTypeString));
      homeFeatures.addAll(updatedHomeFeatures.where(
          (e) => !homeFeatures.any((h) => h.homeFeatureTypeString == e.homeFeatureTypeString)));
      await setHomeFeautres(homeFeatures);
    }

    notifyListeners();
  }
}
