import 'dart:math';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/services/secure_storage_service.dart';
import 'package:coconut_wallet/services/shared_prefs_service.dart';
import 'package:coconut_wallet/utils/hash_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../constants/secure_keys.dart';

class AuthProvider extends ChangeNotifier {
  final SharedPrefs _sharedPrefs = SharedPrefs();
  final SecureStorageService _secureStorageService = SecureStorageService();
  final LocalAuthentication _auth = LocalAuthentication();

  /// 사용자 생체인증 on/off 여부
  late bool _isSetBiometrics;
  bool get isSetBiometrics => _isSetBiometrics;

  /// 디바이스 생체인증 활성화 여부
  late bool _canCheckBiometrics;
  bool get canCheckBiometrics => _canCheckBiometrics;

  /// 비밀번호 설정 여부
  late bool _isSetPin;
  bool get isSetPin => _isSetPin;

  AuthProvider() {
    _isSetBiometrics = _sharedPrefs.getBool(SharedPrefKeys.kIsSetBiometrics);
    _canCheckBiometrics =
        _sharedPrefs.getBool(SharedPrefKeys.kCanCheckBiometrics);
    _isSetPin = _sharedPrefs.getBool(SharedPrefKeys.kIsSetPin);
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
          SharedPrefKeys.kCanCheckBiometrics, _canCheckBiometrics);

      if (!_canCheckBiometrics) {
        _isSetBiometrics = false;
        _sharedPrefs.setBool(SharedPrefKeys.kIsSetBiometrics, false);
      }
    } on PlatformException catch (e) {
      // 생체 인식 기능 비활성화, 사용자가 권한 거부, 기기 하드웨어에 문제가 있는 경우, 기기 호환성 문제, 플랫폼 제한
      Logger.log(e);
      _canCheckBiometrics = false;
      _sharedPrefs.setBool(SharedPrefKeys.kCanCheckBiometrics, false);
      _isSetBiometrics = false;
      _sharedPrefs.setBool(SharedPrefKeys.kIsSetBiometrics, false);
    } finally {
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

  /// 사용자 생체인증 활성화 여부 저장
  Future<void> saveIsSetBiometrics(bool value) async {
    _isSetBiometrics = value;
    await _sharedPrefs.setBool(SharedPrefKeys.kIsSetBiometrics, value);
    notifyListeners();
  }

  /// 비밀번호 저장
  Future<void> savePinSet(String hashedPin) async {
    await _secureStorageService.write(
        key: kSecureStoragePinKey, value: hashedPin);
    _isSetPin = true;
    _sharedPrefs.setBool(SharedPrefKeys.kIsSetPin, _isSetPin);
    notifyListeners();
  }

  /// 비밀번호 삭제
  Future<void> deletePin() async {
    await _secureStorageService.delete(key: kSecureStoragePinKey);
    _isSetPin = false;
    _isSetBiometrics = false;
    _sharedPrefs.setBool(SharedPrefKeys.kIsSetPin, _isSetPin);
    _sharedPrefs.setBool(SharedPrefKeys.kIsSetBiometrics, _isSetBiometrics);
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
  /// TODO: 비밀번호 초기화 시 호출했던 함수. pin_check_screen의 _showDialog() 함수에서 나머지 초기화 처리 필요
  Future<void> resetPassword() async {
    _isSetBiometrics = false;
    _canCheckBiometrics = false;
    // _isNotEmptyWalletList = false;
    _isSetPin = false;
    // _isBalanceHidden = false;
    // _lastUpdateTime = 0;

    // WalletDataManager().reset();

    await SecureStorageService().deleteAll();
    await SharedPrefs().clearSharedPref();
    await checkDeviceBiometrics();
  }

  List<String> getShuffledNumberPad({bool isSettings = false}) {
    final random = Random();
    var randomNumberPad =
        List<String>.generate(10, (index) => index.toString());
    randomNumberPad.shuffle(random);
    randomNumberPad.insert(randomNumberPad.length - 1,
        !isSettings && isSetBiometrics ? 'bio' : '');
    randomNumberPad.add('<');
    return randomNumberPad;
  }
}
