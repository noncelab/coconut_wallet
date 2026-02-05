import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/preferences/electrum_server_provider.dart';
import 'package:coconut_wallet/providers/preferences/feature_settings_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_home_view_model.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/locale_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';
import 'package:tuple/tuple.dart';

class PreferenceProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();
  final WalletPreferencesRepository _walletPreferencesRepository;

  // FeatureSettingsProvider는 선택적으로 주입받을 수 있음 (Facade 패턴)
  // 주입되지 않으면 내부에서 직접 관리 (하위 호환성)
  FeatureSettingsProvider? _featureSettingsProvider;

  final ElectrumServerProvider _electrumServerProvider;
  final BlockExplorerProvider _blockExplorerProvider;

  /// 홈 화면 잔액 숨기기 on/off 여부
  late bool _isBalanceHidden;
  bool get isBalanceHidden => _isBalanceHidden;

  late bool _isFakeBalanceActive;
  bool get isFakeBalanceActive => _isFakeBalanceActive;

  late bool _isFiatBalanceHidden;
  bool get isFiatBalanceHidden => _isFiatBalanceHidden;

  /// 가짜 잔액 총량
  late int? _fakeBalanceTotalBtc;
  int? get fakeBalanceTotalAmount => _fakeBalanceTotalBtc;

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

  /// 보내기 화면 [수신자 추가하기 카드] 확인 여부
  late bool _hasSeenAddRecipientCard;
  bool get hasSeenAddRecipientCard => _hasSeenAddRecipientCard;

  /// 언어 설정
  late String _language;
  String get language => _language;

  bool get isKorean => _language == "kr";
  bool get isEnglish => _language == "en";
  bool get isJapanese => _language == "jp";
  bool get isSpanish => _language == "es";

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
  // FeatureSettingsProvider로 위임
  List<HomeFeature> get homeFeatures => _featureSettingsProvider?.features ?? [];

  /// 특정 기능이 활성화되어 있는지 확인
  bool isHomeFeatureEnabled(HomeFeatureType type) {
    return _featureSettingsProvider?.isEnabled(type) ?? false;
  }

  // 분석 위젯 설정 (FeatureSettingsProvider로 위임)
  int get analysisPeriod => _featureSettingsProvider?.analysisPeriod ?? 30;
  Tuple2<DateTime?, DateTime?> get analysisPeriodRange =>
      _featureSettingsProvider?.analysisPeriodRange ?? const Tuple2(null, null);
  AnalysisTransactionType get selectedAnalysisTransactionType =>
      _featureSettingsProvider?.selectedAnalysisTransactionType ?? AnalysisTransactionType.all;

  late UtxoOrder _utxoSortOrder;
  UtxoOrder get utxoSortOrder => _utxoSortOrder;

  PreferenceProvider(
    this._walletPreferencesRepository,
    this._electrumServerProvider,
    this._blockExplorerProvider, {
    FeatureSettingsProvider? featureSettingsProvider,
  }) : _featureSettingsProvider = featureSettingsProvider {
    _electrumServerProvider.addListener(notifyListeners);
    _blockExplorerProvider.addListener(notifyListeners);
    _fakeBalanceTotalBtc = _sharedPrefs.getIntOrNull(SharedPrefKeys.kFakeBalanceTotal);
    _isFiatBalanceHidden = _sharedPrefs.getBool(SharedPrefKeys.kIsFiatBalanceHidden);
    _isFakeBalanceActive = _fakeBalanceTotalBtc != null;
    _isBalanceHidden = _sharedPrefs.getBool(SharedPrefKeys.kIsBalanceHidden);
    _isBtcUnit =
        _sharedPrefs.isContainsKey(SharedPrefKeys.kIsBtcUnit) ? _sharedPrefs.getBool(SharedPrefKeys.kIsBtcUnit) : true;
    _showOnlyUnusedAddresses = _sharedPrefs.getBool(SharedPrefKeys.kShowOnlyUnusedAddresses);
    _walletOrder = _walletPreferencesRepository.getWalletOrder().toList();
    _favoriteWalletIds = _walletPreferencesRepository.getFavoriteWalletIds().toList();
    _excludedFromTotalBalanceWalletIds = _walletPreferencesRepository.getExcludedWalletIds().toList();
    // FeatureSettingsProvider가 없으면 내부에서 생성 (하위 호환성)
    // 주입된 경우에는 이미 초기화되어 있음
    _featureSettingsProvider ??= FeatureSettingsProvider();
    _isReceivingTooltipDisabled = _sharedPrefs.getBool(SharedPrefKeys.kIsReceivingTooltipDisabled);
    _isChangeTooltipDisabled = _sharedPrefs.getBool(SharedPrefKeys.kIsChangeTooltipDisabled);
    _hasSeenAddRecipientCard = _sharedPrefs.getBool(SharedPrefKeys.kHasSeenAddRecipientCard);
    _utxoSortOrder =
        _sharedPrefs.getString(SharedPrefKeys.kUtxoSortOrder).isNotEmpty
            ? UtxoOrder.values.firstWhere(
              (e) => e.name == _sharedPrefs.getString(SharedPrefKeys.kUtxoSortOrder),
              orElse: () => UtxoOrder.byAmountDesc,
            )
            : UtxoOrder.byAmountDesc;

    // 통화 설정 초기화
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
      _selectedFiat = FiatCode.values.firstWhere((fiat) => fiat.code == fiatCode, orElse: () => FiatCode.KRW);
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
      if (isKorean) {
        LocaleSettings.setLocaleSync(AppLocale.kr);
        Logger.log('Korean locale applied successfully');
      } else if (isJapanese) {
        LocaleSettings.setLocaleSync(AppLocale.jp);
        Logger.log('Japanese locale applied successfully');
      } else if (isEnglish) {
        LocaleSettings.setLocaleSync(AppLocale.en);
        Logger.log('English locale applied successfully');
      } else if (isSpanish) {
        LocaleSettings.setLocaleSync(AppLocale.es);
        Logger.log('Spanish locale applied successfully');
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
      if (isKorean) {
        await LocaleSettings.setLocale(AppLocale.kr);
      } else if (isJapanese) {
        await LocaleSettings.setLocale(AppLocale.jp);
      } else if (isEnglish) {
        await LocaleSettings.setLocale(AppLocale.en);
      } else if (isSpanish) {
        await LocaleSettings.setLocale(AppLocale.es);
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

    notifyListeners();
  }

  /// 홈 화면 법정화폐 잔액 숨기기
  Future<void> changeIsFiatBalanceHidden(bool isOn) async {
    _isFiatBalanceHidden = isOn;
    await _sharedPrefs.setBool(SharedPrefKeys.kIsFiatBalanceHidden, isOn);

    notifyListeners();
  }

  /// 가짜 잔액 활성화 상태 변경
  Future<void> toggleFakeBalanceActivation(bool isActive) async {
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

  /// 가짜 잔액 분배
  Future<void> distributeFakeBalance(
    List<WalletListItemBase> wallets, {
    required bool isFakeBalanceActive,
    double? fakeBalanceTotalSats,
  }) async {
    assert(
      isFakeBalanceActive == true && fakeBalanceTotalSats != null,
      'isFakeBalanceActive일 때, fakeBalanceTotalSats는 필수 값입니다.',
    );

    var fakeBalanceTotalBtc = fakeBalanceTotalSats ?? _fakeBalanceTotalBtc!.toDouble();
    fakeBalanceTotalBtc = fakeBalanceTotalBtc / 100000000;

    if (isFakeBalanceActive != _isFakeBalanceActive) {
      await toggleFakeBalanceActivation(_isFakeBalanceActive);
    }

    if (!isFakeBalanceActive) return;

    final fixedString = fakeBalanceTotalBtc.toStringAsFixed(8).replaceAll('.', '');
    fakeBalanceTotalBtc = double.parse(fixedString);

    final Map<int, dynamic> fakeBalanceMap = {};

    final splits = FakeBalanceUtil.distributeFakeBalance(fakeBalanceTotalBtc, wallets.length, BitcoinUnit.sats);

    for (int i = 0; i < splits.length; i++) {
      final walletId = wallets[i].id;
      final fakeBalance = splits[i];
      fakeBalanceMap[walletId] = fakeBalance;
    }

    await setFakeBalanceTotalAmount(fakeBalanceTotalBtc.toInt());
    await setFakeBalanceMap(fakeBalanceMap);
    await changeIsBalanceHidden(false); // 가짜 잔액 설정 시 잔액 숨기기는 해제
  }

  /// 가짜 잔액 총량 수정
  Future<void> setFakeBalanceTotalAmount(int balance) async {
    _fakeBalanceTotalBtc = balance;
    await _sharedPrefs.setInt(SharedPrefKeys.kFakeBalanceTotal, balance);
    notifyListeners();
  }

  /// 가짜 잔액 총량 초기화
  Future<void> clearFakeBalanceTotalAmount() async {
    _fakeBalanceTotalBtc = null;
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
    final Map<String, dynamic> stringKeyMap = map.map((key, value) => MapEntry(key.toString(), value));
    final String encoded = json.encode(stringKeyMap);
    await _sharedPrefs.setString(SharedPrefKeys.kFakeBalanceMap, encoded);
  }

  /// 지갑 순서 설정
  Future<void> setWalletOrder(List<int> walletOrder) async {
    _walletOrder = walletOrder;
    await _walletPreferencesRepository.setWalletOrder(walletOrder);
    notifyListeners();
  }

  /// 지갑 순서 단일 제거
  Future<void> removeWalletOrder(int walletId) async {
    _walletOrder.remove(walletId);
    await _walletPreferencesRepository.setWalletOrder(_walletOrder);
    notifyListeners();
  }

  /// 지갑 즐겨찾기 목록 설정
  Future<void> setFavoriteWalletIds(List<int> ids) async {
    _favoriteWalletIds = ids;
    await _walletPreferencesRepository.setFavoriteWalletIds(ids);
    notifyListeners();
  }

  /// 지갑 즐겨찾기 단일 제거
  Future<void> removeFavoriteWalletId(int walletId) async {
    _favoriteWalletIds.remove(walletId);
    await _walletPreferencesRepository.setFavoriteWalletIds(_favoriteWalletIds);
    notifyListeners();
  }

  /// 총 잔액에서 제외할 지갑 설정
  Future<void> setExcludedFromTotalBalanceWalletIds(List<int> ids) async {
    _excludedFromTotalBalanceWalletIds = ids;
    await _walletPreferencesRepository.setExcludedWalletIds(ids);
    notifyListeners();
  }

  /// 총 잔액에서 제외할 지갑 단일 제거
  Future<void> removeExcludedFromTotalBalanceWalletId(int walletId) async {
    _excludedFromTotalBalanceWalletIds.remove(walletId);
    await _walletPreferencesRepository.setExcludedWalletIds(_excludedFromTotalBalanceWalletIds);
    notifyListeners();
  }

  /// 홈 화면에 표시할 기능 (FeatureSettingsProvider로 위임)
  List<HomeFeature> getHomeFeatures() {
    return _featureSettingsProvider?.features ?? [];
  }

  Future<void> setHomeFeautres(List<HomeFeature> features) async {
    // FeatureSettingsProvider로 위임
    await _featureSettingsProvider?.setFeatures(features);
    notifyListeners();
  }

  Future<void> setWalletPreferences(List<WalletListItemBase> walletItemList) async {
    var walletOrder = _walletOrder;
    var favoriteWalletIds = _favoriteWalletIds;

    if (walletOrder.isEmpty) {
      walletOrder = List.from(walletItemList.map((w) => w.id));
      await setWalletOrder(walletOrder);
    }
    if (favoriteWalletIds.isEmpty) {
      favoriteWalletIds = List.from(walletItemList.take(5).map((w) => w.id));
      await setFavoriteWalletIds(favoriteWalletIds);
    }

    // FeatureSettingsProvider의 동기화 메서드 사용
    await _featureSettingsProvider?.synchronizeWithDefaults(walletList: walletItemList);

    notifyListeners();
  }

  /// 분석 설정 (FeatureSettingsProvider로 위임)
  Tuple2<DateTime?, DateTime?> getAnalysisPeriodRange() {
    return _featureSettingsProvider?.getAnalysisPeriodRange() ?? const Tuple2(null, null);
  }

  Future<void> setAnalysisPeriodRange(DateTime start, DateTime end) async {
    await _featureSettingsProvider?.setAnalysisPeriodRange(start, end);
    notifyListeners();
  }

  int getAnalysisPeriod() {
    return _featureSettingsProvider?.getAnalysisPeriod() ?? 30;
  }

  Future<void> setAnalysisPeriod(int days) async {
    await _featureSettingsProvider?.setAnalysisPeriod(days);
    notifyListeners();
  }

  AnalysisTransactionType getAnalysisTransactionType() {
    return _featureSettingsProvider?.getAnalysisTransactionType() ?? AnalysisTransactionType.all;
  }

  Future<void> setAnalysisTransactionType(AnalysisTransactionType transactionType) async {
    await _featureSettingsProvider?.setAnalysisTransactionType(transactionType);
    notifyListeners();
  }

  /// 보내기 화면 [수신자 추가 카드] 확인 여부 활성화 - 보내기 화면 진입시 Bounce 애니메이션을 처리하지 않음
  Future<void> setHasSeenAddRecipientCard() async {
    _hasSeenAddRecipientCard = true;
    await _sharedPrefs.setBool(SharedPrefKeys.kHasSeenAddRecipientCard, _hasSeenAddRecipientCard);
    notifyListeners();
  }

  // 마지막으로 선택한 UTXO 정렬 방식 저장
  Future<void> setLastUtxoOrder(UtxoOrder utxoOrder) async {
    _utxoSortOrder = utxoOrder;
    await _sharedPrefs.setString(SharedPrefKeys.kUtxoSortOrder, utxoOrder.name);
    vibrateExtraLight();
    notifyListeners();
  }
}
