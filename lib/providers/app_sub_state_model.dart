import 'dart:math';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:coconut_wallet/constants/app_info.dart';
import 'package:coconut_wallet/services/secure_storage_service.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/utils/hash_util.dart';

import '../utils/logger.dart';

class AppSubStateModel with ChangeNotifier {
  final SecureStorageService _secureStorageService = SecureStorageService();
  final LocalAuthentication _auth = LocalAuthentication();
  final SharedPrefs _sharedPrefs = SharedPrefs();

  /// 사용자 생체인증 on/off 여부
  bool _isSetBiometrics = false;
  bool get isSetBiometrics => _isSetBiometrics;

  /// 디바이스 생체인증 활성화 여부
  bool _canCheckBiometrics = false;
  bool get canCheckBiometrics => _canCheckBiometrics;

  /// 비밀번호 설정 여부
  bool _isSetPin = false;
  bool get isSetPin => _isSetPin;

  /// 핀 입력 키
  List<String> _pinShuffleNumbers = [];
  List<String> get pinShuffleNumbers => _pinShuffleNumbers;

  /// 지갑 리스트 생성 여부
  bool _isNotEmptyWalletList = false;
  bool get isNotEmptyWalletList => _isNotEmptyWalletList;

  /// iOS에서 앱 지워도 secureStorage가 남아있어서 지우기 위해 사용
  bool _hasLaunchedBefore = false;
  bool get hasLaunchedBefore => _hasLaunchedBefore;
  final hasLaunchedBeforeKey = 'hasLaunchedBefore';

  /// 홈 화면 잔액 숨기기 on/off 여부
  bool _isBalanceHidden = false;
  bool get isBalanceHidden => _isBalanceHidden;

  /// 마지막 업데이트 시간
  int _lastUpdateTime = 0;
  int get lastUpdateTime => _lastUpdateTime;

  /// 용어집 바로가기 진입 여부
  bool _isOpenTermsScreen = false;
  bool get isOpenTermsScreen => _isOpenTermsScreen;

  setInitData() async {
    await checkDeviceBiometrics();
    _isSetBiometrics = _sharedPrefs.getBool(SharedPrefs.kIsSetBiometrics);
    _canCheckBiometrics = _sharedPrefs.getBool(SharedPrefs.kCanCheckBiometrics);
    _isNotEmptyWalletList =
        _sharedPrefs.getBool(SharedPrefs.kIsNotEmptyWalletList);
    _isSetPin = _sharedPrefs.getBool(SharedPrefs.kIsSetPin);
    if (_sharedPrefs.isContainsKey(hasLaunchedBeforeKey)) {
      _hasLaunchedBefore = _sharedPrefs.getBool(hasLaunchedBeforeKey);
    }
    _isBalanceHidden = _sharedPrefs.getBool(SharedPrefs.kIsBalanceHidden);
    _isOpenTermsScreen = _sharedPrefs.getBool(SharedPrefs.kIsOpenTermsScreen);
    _lastUpdateTime = _sharedPrefs.getInt(SharedPrefs.kLastUpdateTime);
    shuffleNumbers();
  }

  Future<void> setHasLaunchedBefore() async {
    await _secureStorageService.deleteAll();
    await _sharedPrefs.setBool(hasLaunchedBeforeKey, true);
  }

  Future<void> removeFaucetHistory(int id) async {
    await _sharedPrefs.removeFaucetHistory(id);
  }

  Future<void> setLastUpdateTime() async {
    _lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
    await _sharedPrefs.setInt(SharedPrefs.kLastUpdateTime, _lastUpdateTime);
    notifyListeners();
  }

  void shuffleNumbers({isSettings = false}) {
    final random = Random();
    _pinShuffleNumbers = List<String>.generate(10, (index) => index.toString());
    _pinShuffleNumbers.shuffle(random);
    _pinShuffleNumbers.insert(_pinShuffleNumbers.length - 1,
        !isSettings && _isSetBiometrics ? 'bio' : '');
    _pinShuffleNumbers.add('<');
    notifyListeners();
  }

  /// 홈 화면 잔액 숨기기
  Future<void> changeIsBalanceHidden(bool isOn) async {
    _isBalanceHidden = isOn;
    await _sharedPrefs.setBool(SharedPrefs.kIsBalanceHidden, isOn);
    notifyListeners();
  }

  /// /// 용어집 바로가기 진입 여부 저장
  Future<void> setIsOpenTermsScreen() async {
    _isOpenTermsScreen = true;
    await _sharedPrefs.setBool(SharedPrefs.kIsOpenTermsScreen, true);
    notifyListeners();
  }

  /// 기기의 생체인증 가능 여부 업데이트
  Future<void> checkDeviceBiometrics() async {
    List<BiometricType> availableBiometrics = [];

    try {
      final isEnabledBiometrics = await _auth.canCheckBiometrics;
      availableBiometrics = await _auth.getAvailableBiometrics();
      _canCheckBiometrics =
          isEnabledBiometrics && availableBiometrics.isNotEmpty;
      _sharedPrefs.setBool(
          SharedPrefs.kCanCheckBiometrics, _canCheckBiometrics);

      if (!_canCheckBiometrics) {
        _isSetBiometrics = false;
        _sharedPrefs.setBool(SharedPrefs.kIsSetBiometrics, false);
      }

      notifyListeners();
    } on PlatformException catch (e) {
      // 생체 인식 기능 비활성화, 사용자가 권한 거부, 기기 하드웨어에 문제가 있는 경우, 기기 호환성 문제, 플랫폼 제한
      Logger.log(e);
      _canCheckBiometrics = false;
      _sharedPrefs.setBool(SharedPrefs.kCanCheckBiometrics, false);
      _isSetBiometrics = false;
      _sharedPrefs.setBool(SharedPrefs.kIsSetBiometrics, false);
      notifyListeners();
    }
  }

  /// 생체인증 진행 후 성공 여부 반환
  Future<bool> authenticateWithBiometrics({bool isSave = false}) async {
    bool authenticated = false;
    try {
      authenticated = await _auth.authenticate(
        localizedReason: '생체 인증을 진행해 주세요',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (isSave) {
        saveIsSetBiometrics(authenticated);
      }

      return authenticated;
    } on PlatformException catch (e) {
      Logger.log(e);
    }
    return false;
  }

  /// WalletList isNotEmpty 상태 저장
  Future<void> saveNotEmptyWalletList(bool isNotEmpty) async {
    _isNotEmptyWalletList = isNotEmpty;
    await _sharedPrefs.setBool(SharedPrefs.kIsNotEmptyWalletList, isNotEmpty);
    if (!isNotEmpty) await _sharedPrefs.setInt(SharedPrefs.kLastUpdateTime, 0);
    notifyListeners();
  }

  /// 사용자 생체인증 활성화 여부 저장
  Future<void> saveIsSetBiometrics(bool value) async {
    _isSetBiometrics = value;
    await _sharedPrefs.setBool(SharedPrefs.kIsSetBiometrics, value);
    notifyListeners();
  }

  /// 비밀번호 저장
  Future<void> savePinSet(String pin) async {
    if (_canCheckBiometrics) {
      _isSetBiometrics = true;
      _sharedPrefs.setBool(SharedPrefs.kIsSetBiometrics, _isSetBiometrics);
    }

    String hashed = hashString(pin);
    await _secureStorageService.write(key: kSecureStoragePinKey, value: hashed);
    _isSetPin = true;
    _sharedPrefs.setBool(SharedPrefs.kIsSetPin, _isSetPin);
    notifyListeners();
  }

  /// 비밀번호 삭제
  Future<void> deletePin() async {
    await _secureStorageService.delete(key: kSecureStoragePinKey);
    _isSetPin = false;
    _isSetBiometrics = false;
    _sharedPrefs.setBool(SharedPrefs.kIsSetPin, _isSetPin);
    _sharedPrefs.setBool(SharedPrefs.kIsSetBiometrics, _isSetBiometrics);
    notifyListeners();
  }

  /// 비밀번호 검증
  Future<bool> verifyPin(String inputPin) async {
    String hashedInput = hashString(inputPin);
    final savedPin =
        await _secureStorageService.read(key: kSecureStoragePinKey);
    return savedPin == hashedInput;
  }

  /// 비밀번호 초기화
  Future<void> resetPassword() async {
    _isSetBiometrics = false;
    _canCheckBiometrics = false;
    _isNotEmptyWalletList = false;
    _isSetPin = false;
    _isBalanceHidden = false;
    _lastUpdateTime = 0;
    Repository().resetObjectBox();
    await SecureStorageService().deleteAll();
    await SharedPrefs().clearSharedPref();
    await checkDeviceBiometrics();
  }
}
