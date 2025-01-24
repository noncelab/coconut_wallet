import 'dart:math';

import 'package:coconut_wallet/constants/secure_keys.dart';
import 'package:coconut_wallet/repository/realm/wallet_data_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/hash_util.dart';

import '../utils/logger.dart';

class AppSubStateModel with ChangeNotifier {
  final SecureStorageRepository _secureStorageService =
      SecureStorageRepository();
  final LocalAuthentication _auth = LocalAuthentication();
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

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
    _isSetBiometrics =
        _sharedPrefs.getBool(SharedPrefsRepository.kIsSetBiometrics);
    _canCheckBiometrics =
        _sharedPrefs.getBool(SharedPrefsRepository.kCanCheckBiometrics);
    _isNotEmptyWalletList =
        _sharedPrefs.getBool(SharedPrefsRepository.kIsNotEmptyWalletList);
    _isSetPin = _sharedPrefs.getBool(SharedPrefsRepository.kIsSetPin);
    if (_sharedPrefs.isContainsKey(hasLaunchedBeforeKey)) {
      _hasLaunchedBefore = _sharedPrefs.getBool(hasLaunchedBeforeKey);
    }
    _isBalanceHidden =
        _sharedPrefs.getBool(SharedPrefsRepository.kIsBalanceHidden);
    _isOpenTermsScreen =
        _sharedPrefs.getBool(SharedPrefsRepository.kIsOpenTermsScreen);
    _lastUpdateTime =
        _sharedPrefs.getInt(SharedPrefsRepository.kLastUpdateTime);
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
    await _sharedPrefs.setInt(
        SharedPrefsRepository.kLastUpdateTime, _lastUpdateTime);
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
    await _sharedPrefs.setBool(SharedPrefsRepository.kIsBalanceHidden, isOn);
    notifyListeners();
  }

  /// /// 용어집 바로가기 진입 여부 저장
  Future<void> setIsOpenTermsScreen() async {
    _isOpenTermsScreen = true;
    await _sharedPrefs.setBool(SharedPrefsRepository.kIsOpenTermsScreen, true);
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
          SharedPrefsRepository.kCanCheckBiometrics, _canCheckBiometrics);

      if (!_canCheckBiometrics) {
        _isSetBiometrics = false;
        _sharedPrefs.setBool(SharedPrefsRepository.kIsSetBiometrics, false);
      }

      notifyListeners();
    } on PlatformException catch (e) {
      // 생체 인식 기능 비활성화, 사용자가 권한 거부, 기기 하드웨어에 문제가 있는 경우, 기기 호환성 문제, 플랫폼 제한
      Logger.log(e);
      _canCheckBiometrics = false;
      _sharedPrefs.setBool(SharedPrefsRepository.kCanCheckBiometrics, false);
      _isSetBiometrics = false;
      _sharedPrefs.setBool(SharedPrefsRepository.kIsSetBiometrics, false);
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
    await _sharedPrefs.setBool(
        SharedPrefsRepository.kIsNotEmptyWalletList, isNotEmpty);
    if (!isNotEmpty) {
      await _sharedPrefs.setInt(SharedPrefsRepository.kLastUpdateTime, 0);
    }
    notifyListeners();
  }

  /// 사용자 생체인증 활성화 여부 저장
  Future<void> saveIsSetBiometrics(bool value) async {
    _isSetBiometrics = value;
    await _sharedPrefs.setBool(SharedPrefsRepository.kIsSetBiometrics, value);
    notifyListeners();
  }

  /// 비밀번호 저장
  Future<void> savePinSet(String hashedPin) async {
    await _secureStorageService.write(
        key: kSecureStoragePinKey, value: hashedPin);
    _isSetPin = true;
    _sharedPrefs.setBool(SharedPrefsRepository.kIsSetPin, _isSetPin);
    notifyListeners();
  }

  /// 비밀번호 삭제
  Future<void> deletePin() async {
    await _secureStorageService.delete(key: kSecureStoragePinKey);
    _isSetPin = false;
    _isSetBiometrics = false;
    _sharedPrefs.setBool(SharedPrefsRepository.kIsSetPin, _isSetPin);
    _sharedPrefs.setBool(
        SharedPrefsRepository.kIsSetBiometrics, _isSetBiometrics);
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

    WalletDataManager().reset();

    await SecureStorageRepository().deleteAll();
    await SharedPrefsRepository().clearSharedPref();
    await checkDeviceBiometrics();
  }
}
