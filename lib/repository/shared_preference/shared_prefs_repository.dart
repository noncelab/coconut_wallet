import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/model/faucet/faucet_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsRepository {
  // TODO: lib/contants/shared_pref_keys.dart로 옮긴 것을 사용하기
  static const String kSharedIsBalanceHidden = "SHARED_IS_BALANCE_HIDDEN";
  static const String lastUpdateTime = "LAST_UPDATE_TIME";
  static const String kLastUpdateTime = "LAST_UPDATE_TIME";
  static const String kFaucetHistories = "FAUCET_HISTORIES";
  static const String kIsBalanceHidden = "IS_BALANCE_HIDDEN";
  static const String kIsNotEmptyWalletList = "IS_NOT_EMPTY_WALLET_LIST";
  static const String kCanCheckBiometrics = "CAN_CHECK_BIOMETRICS";
  static const String kIsSetBiometrics = "IS_SET_BIOMETRICS";
  static const String kIsSetPin = "IS_SET_PIN";
  static const String kWalletTxListId = "WALLET_TX_LIST_ID";
  static const String kNextVersionUpdateDialogDate =
      "NEXT_VERSION_UPDATE_DIALOG_DATE";
  static const String kIsOpenTermsScreen = "IS_OPEN_TERMS_SCREEN";

  /// 리뷰 요청 관련
  static const String kHaveSent = 'HAVE_SENT';
  static const String kHaveReviewed = 'HAVE_REVIEWED';
  static const String kAppRunCountAfterRejectReview =
      'APP_RUN_COUNT_AFTER_REJECT_REVIEW';

  late SharedPreferences _sharedPrefs;
  SharedPreferences get sharedPrefs => _sharedPrefs;

  @Deprecated('Test code에서만 사용합니다')
  void setSharedPreferencesForTest(SharedPreferences sp) {
    _sharedPrefs = sp;
  }

  static final SharedPrefsRepository _instance = SharedPrefsRepository._internal();

  factory SharedPrefsRepository() => _instance;

  SharedPrefsRepository._internal();

  Future<void> init() async {
    // init in main.dart
    _sharedPrefs = await SharedPreferences.getInstance();
  }

  /// Common--------------------------------------------------------------------
  Future clearSharedPref() async {
    await _sharedPrefs.clear();
  }

  bool isContainsKey(String key) {
    return _sharedPrefs.containsKey(key);
  }

  Future deleteSharedPrefsWithKey(String key) async {
    await _sharedPrefs.remove(key);
  }

  bool getBool(String key) {
    return _sharedPrefs.getBool(key) ?? false;
  }

  Future setBool(String key, bool value) async {
    await _sharedPrefs.setBool(key, value);
  }

  int getInt(String key) {
    return _sharedPrefs.getInt(key) ?? 0;
  }

  Future setInt(String key, int value) async {
    await _sharedPrefs.setInt(key, value);
  }

  String getString(String key) {
    return _sharedPrefs.getString(key) ?? '';
  }

  Future setString(String key, String value) async {
    await _sharedPrefs.setString(key, value);
  }

  /// FaucetHistory-------------------------------------------------------------
  Future<void> saveFaucetHistory(FaucetRecord faucetHistory) async {
    final Map<int, FaucetRecord> faucetHistories = _getFaucetHistories();
    faucetHistories[faucetHistory.id] = faucetHistory;
    await _saveFaucetHistories(faucetHistories);
  }

  FaucetRecord getFaucetHistoryWithId(int id) {
    final Map<int, FaucetRecord> faucetHistories = _getFaucetHistories();
    if (faucetHistories.containsKey(id)) {
      return faucetHistories[id]!;
    } else {
      return FaucetRecord(
        id: id,
        dateTime: DateTime.now().millisecondsSinceEpoch,
        count: 0,
      );
    }
  }

  Future<void> removeFaucetHistory(int id) async {
    Map<int, FaucetRecord> faucetHistories = _getFaucetHistories();
    faucetHistories.remove(id);
    await _saveFaucetHistories(faucetHistories);
  }

  Future<void> _saveFaucetHistories(Map<int, FaucetRecord> histories) async {
    final String encodedData = json.encode(histories
        .map((key, value) => MapEntry(key.toString(), value.toJson())));
    await _sharedPrefs.setString(kFaucetHistories, encodedData);
  }

  Map<int, FaucetRecord> _getFaucetHistories() {
    final String? encodedData = _sharedPrefs.getString(kFaucetHistories);
    if (encodedData == null) {
      return {};
    }
    final Map<String, dynamic> decodedData = json.decode(encodedData);
    return decodedData.map(
        (key, value) => MapEntry(int.parse(key), FaucetRecord.fromJson(value)));
  }

  /// TxList--------------------------------------------------------------
  Future setTxList(int walletId, String value) async {
    await _sharedPrefs.setString(
        '$kWalletTxListId${walletId.toString()}', value);
  }

  String? getTxList(int walletId) {
    return _sharedPrefs.getString('$kWalletTxListId${walletId.toString()}');
  }

  Future removeTxList(int walletId) async {
    await _sharedPrefs.remove('$kWalletTxListId${walletId.toString()}');
  }
}
