import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_home_view_model.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/locale_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:tuple/tuple.dart';

class PreferenceProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();
  final WalletPreferencesRepository _walletPreferencesRepository;

  /// 홈 화면 잔액 숨기기 on/off 여부
  late bool _isBalanceHidden;
  bool get isBalanceHidden => _isBalanceHidden;

  late bool _isFakeBalanceActive;
  bool get isFakeBalanceActive => _isFakeBalanceActive;

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

  // 분석 위젯의 기준이 되는 기간
  late int _analysisPeriod;
  int get analysisPeriod => _analysisPeriod;

  late Tuple2<DateTime?, DateTime?> _analysisPeriodRange;
  Tuple2<DateTime?, DateTime?> get analysisPeriodRange => _analysisPeriodRange;

  late AnalysisTransactionType _selectedAnalysisTransactionType;
  AnalysisTransactionType get selectedAnalysisTransactionType => _selectedAnalysisTransactionType;

  late UtxoOrder _utxoSortOrder;
  UtxoOrder get utxoSortOrder => _utxoSortOrder;

  PreferenceProvider(this._walletPreferencesRepository) {
    _fakeBalanceTotalBtc = _sharedPrefs.getIntOrNull(SharedPrefKeys.kFakeBalanceTotal);
    _isFakeBalanceActive = _fakeBalanceTotalBtc != null;
    _isBalanceHidden = _sharedPrefs.getBool(SharedPrefKeys.kIsBalanceHidden);
    _isBtcUnit =
        _sharedPrefs.isContainsKey(SharedPrefKeys.kIsBtcUnit) ? _sharedPrefs.getBool(SharedPrefKeys.kIsBtcUnit) : true;
    _showOnlyUnusedAddresses = _sharedPrefs.getBool(SharedPrefKeys.kShowOnlyUnusedAddresses);
    _walletOrder = getWalletOrder();
    _favoriteWalletIds = getFavoriteWalletIds();
    _excludedFromTotalBalanceWalletIds = getExcludedFromTotalBalanceWalletIds();
    _homeFeatures = getHomeFeatures();
    _analysisPeriod = getAnalysisPeriod();
    _analysisPeriodRange = getAnalysisPeriodRange();
    _selectedAnalysisTransactionType = getAnalysisTransactionType();
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
    initializeFiat();
    initializeLanguageFromSystem();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyLanguageSettingSync();
    });
  }

  /// 통화 설정 초기화
  void initializeFiat() {
    final fiatCode = _sharedPrefs.getString(SharedPrefKeys.kSelectedFiat);
    if (fiatCode.isNotEmpty) {
      _selectedFiat = FiatCode.values.firstWhere((fiat) => fiat.code == fiatCode, orElse: () => FiatCode.KRW);
    } else {
      _selectedFiat = FiatCode.KRW;
      _sharedPrefs.setString(SharedPrefKeys.kSelectedFiat, _selectedFiat.code);
    }
  }

  /// OS 설정에 따라 언어 설정 초기화
  void initializeLanguageFromSystem() {
    bool changed = false;
    if (_sharedPrefs.isContainsKey(SharedPrefKeys.kLanguage)) {
      _language = _sharedPrefs.getString(SharedPrefKeys.kLanguage);
    } else {
      _language = getSystemLanguageCode();
      _sharedPrefs.setString(SharedPrefKeys.kLanguage, _language);
      changed = true;
    }

    applyLanguageSettingSync();
    if (changed) {
      notifyListeners();
    }
  }

  /// 언어 설정 적용 (동기 버전)
  void applyLanguageSettingSync() {
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
      }

      // 언어 설정 후 상태 업데이트를 위해 notifyListeners 호출
      notifyListeners();
    } catch (e) {
      // 언어 초기화 실패 시 로그 출력 (선택사항)
      Logger.log('Language initialization failed: $e');
    }
  }

  /// 언어 설정 적용
  Future<void> applyLanguageSetting() async {
    try {
      if (isKorean) {
        await LocaleSettings.setLocale(AppLocale.kr);
      } else if (isJapanese) {
        await LocaleSettings.setLocale(AppLocale.jp);
      } else if (isEnglish) {
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
    await applyLanguageSetting();

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

  /// 지갑 순서 불러오기
  List<int> getWalletOrder() {
    final encoded = _walletPreferencesRepository.getWalletOrder().toList();
    if (encoded.isEmpty) return [];
    return encoded;
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
  List<int> getFavoriteWalletIds() {
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
  List<int> getExcludedFromTotalBalanceWalletIds() {
    final encoded = _sharedPrefs.getString(SharedPrefKeys.kExcludedFromTotalBalanceWalletIds);
    if (encoded.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(encoded);
    return decoded.cast<int>();
  }

  /// 총 잔액에서 제외할 지갑 설정
  Future<void> setExcludedFromTotalBalanceWalletIds(List<int> ids) async {
    _excludedFromTotalBalanceWalletIds = ids;
    await _sharedPrefs.setString(SharedPrefKeys.kExcludedFromTotalBalanceWalletIds, jsonEncode(ids));
    notifyListeners();
  }

  /// 총 잔액에서 제외할 지갑 단일 제거
  Future<void> removeExcludedFromTotalBalanceWalletId(int walletId) async {
    _excludedFromTotalBalanceWalletIds.remove(walletId);
    await setExcludedFromTotalBalanceWalletIds(_excludedFromTotalBalanceWalletIds);
    notifyListeners();
  }

  /// 홈 화면에 표시할 기능
  List<HomeFeature> getHomeFeatures() {
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
    await _sharedPrefs.setString(SharedPrefKeys.kHomeFeatures, jsonEncode(features.map((e) => e.toJson()).toList()));
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
      homeFeatures.removeWhere(
        (e) => !initialHomeFeatures.any((k) => k.homeFeatureTypeString == e.homeFeatureTypeString),
      );
      homeFeatures.addAll(
        updatedHomeFeatures.where((e) => !homeFeatures.any((h) => h.homeFeatureTypeString == e.homeFeatureTypeString)),
      );
      await setHomeFeautres(homeFeatures);
    }

    notifyListeners();
  }

  Tuple2<DateTime?, DateTime?> getAnalysisPeriodRange() {
    final start = _sharedPrefs.getString(SharedPrefKeys.kAnalysisPeriodStart);
    final end = _sharedPrefs.getString(SharedPrefKeys.kAnalysisPeriodEnd);
    debugPrint('Analysis period range: $start ~ $end');
    return Tuple2(start.isEmpty ? null : DateTime.parse(start), end.isEmpty ? null : DateTime.parse(end));
  }

  Future<void> setAnalysisPeriodRange(DateTime start, DateTime end) async {
    _analysisPeriodRange = Tuple2(start, end);
    await _sharedPrefs.setString(SharedPrefKeys.kAnalysisPeriodStart, start.toIso8601String());
    await _sharedPrefs.setString(SharedPrefKeys.kAnalysisPeriodEnd, end.toIso8601String());
    notifyListeners();
  }

  int getAnalysisPeriod() {
    final period = _sharedPrefs.getIntOrNull(SharedPrefKeys.kAnalysisPeriod);
    debugPrint('Analysis period: $period');
    return period ?? 30; // 기본 기간 30일
  }

  Future<void> setAnalysisPeriod(int days) async {
    _analysisPeriod = days;
    await _sharedPrefs.setInt(SharedPrefKeys.kAnalysisPeriod, days);
    notifyListeners();
  }

  AnalysisTransactionType getAnalysisTransactionType() {
    final encoded = _sharedPrefs.getString(SharedPrefKeys.kSelectedTransactionTypeIndices);
    if (encoded.isEmpty) return AnalysisTransactionType.all; // [전체 = all]이 기본
    return AnalysisTransactionType.values.firstWhere(
      (type) => type.name == encoded,
      orElse: () => AnalysisTransactionType.all,
    );
  }

  Future<void> setAnalysisTransactionType(AnalysisTransactionType transactionType) async {
    _selectedAnalysisTransactionType = transactionType;
    await _sharedPrefs.setString(SharedPrefKeys.kSelectedTransactionTypeIndices, _selectedAnalysisTransactionType.name);
    notifyListeners();
  }

  /// 보내기 화면 [수신자 추가 카드] 확인 여부 활성화 - 보내기 화면 진입시 Bounce 애니메이션을 처리하지 않음
  Future<void> setHasSeenAddRecipientCard() async {
    _hasSeenAddRecipientCard = true;
    await _sharedPrefs.setBool(SharedPrefKeys.kHasSeenAddRecipientCard, _hasSeenAddRecipientCard);
    notifyListeners();
  }

  /// 커스텀 일렉트럼 서버 파라미터 검증
  void validateCustomElectrumServerParams(String host, int port, bool ssl) {
    if (host.trim().isEmpty) {
      throw ArgumentError('Host cannot be empty');
    }

    if (port <= 0 || port > 65535) {
      throw ArgumentError('Port must be between 1 and 65535');
    }
  }

  /// 일렉트럼 서버 설정
  Future<void> setDefaultElectrumServer(DefaultElectrumServer defaultElectrumServer) async {
    await _sharedPrefs.setString(SharedPrefKeys.kElectrumServerName, defaultElectrumServer.serverName);
  }

  /// 커스텀 일렉트럼 서버 설정
  Future<void> setCustomElectrumServer(String host, int port, bool ssl) async {
    validateCustomElectrumServerParams(host, port, ssl);
    await _sharedPrefs.setString(SharedPrefKeys.kElectrumServerName, 'CUSTOM');
    await _sharedPrefs.setString(SharedPrefKeys.kCustomElectrumHost, host);
    await _sharedPrefs.setInt(SharedPrefKeys.kCustomElectrumPort, port);
    await _sharedPrefs.setBool(SharedPrefKeys.kCustomElectrumIsSsl, ssl);
  }

  /// 일렉트럼 서버 설정 불러오기
  ElectrumServer getElectrumServer() {
    final serverName = _sharedPrefs.getString(SharedPrefKeys.kElectrumServerName);
    debugPrint('PREFERNECE_PROVIDER:: getElectrumServer() serverName: $serverName');

    if (serverName.isEmpty) {
      if (NetworkType.currentNetworkType == NetworkType.mainnet) {
        setDefaultElectrumServer(DefaultElectrumServer.coconut);
        return DefaultElectrumServer.coconut.server;
      } else {
        setDefaultElectrumServer(DefaultElectrumServer.regtest);
        return DefaultElectrumServer.regtest.server;
      }
    }

    if (serverName == 'CUSTOM') {
      return ElectrumServer.custom(
        _sharedPrefs.getString(SharedPrefKeys.kCustomElectrumHost),
        _sharedPrefs.getInt(SharedPrefKeys.kCustomElectrumPort),
        _sharedPrefs.getBool(SharedPrefKeys.kCustomElectrumIsSsl),
      );
    }

    return DefaultElectrumServer.fromServerType(serverName).server;
  }

  /// 사용자 서버 정보 불러오기
  Future<List<ElectrumServer>> getUserServers() async {
    return (await _sharedPrefs.getUserServers()) ?? [];
  }

  /// 사용자 서버 추가
  Future<void> addUserServer(String host, int port, bool ssl) async {
    await _sharedPrefs.addUserServer(ElectrumServer.custom(host, port, ssl));
    notifyListeners();
  }

  /// 사용자 서버 삭제
  Future<void> removeUserServer(ElectrumServer server) async {
    await _sharedPrefs.removeUserServer(server);
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
