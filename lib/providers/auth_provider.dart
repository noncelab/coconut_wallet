import 'dart:math';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/hash_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../constants/secure_keys.dart';

class AuthProvider extends ChangeNotifier {
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();
  final SecureStorageRepository _secureStorageService = SecureStorageRepository();
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

  /// 비밀번호 길이
  late int _pinLength;
  int get pinLength => _pinLength;

  /// 인증 활성화 여부
  bool get isAuthEnabled => _isSetPin;

  /// 생체인식 인증 활성화 여부
  bool get isBiometricsAuthEnabled => _canCheckBiometrics && _isSetBiometrics;

  AuthProvider() {
    _isSetBiometrics = _sharedPrefs.getBool(SharedPrefKeys.kIsSetBiometrics);
    _canCheckBiometrics = _sharedPrefs.getBool(SharedPrefKeys.kCanCheckBiometrics);
    _isSetPin = _sharedPrefs.getBool(SharedPrefKeys.kIsSetPin);
    _pinLength = _sharedPrefs.getInt(SharedPrefKeys.kPinLength);
    if (_pinLength == 0) {
      _pinLength = 4;
    }
    checkDeviceBiometrics();
  }

  /// 생체인증 성공했는지 여부 반환
  Future<bool> isBiometricsAuthValid() async {
    return isBiometricsAuthEnabled && await authenticateWithBiometrics();
  }

  /// 기기의 생체인증 가능 여부 업데이트
  Future<void> checkDeviceBiometrics() async {
    List<BiometricType> availableBiometrics = [];

    try {
      final isEnabledBiometrics = await _auth.canCheckBiometrics;
      availableBiometrics = await _auth.getAvailableBiometrics();
      _canCheckBiometrics = isEnabledBiometrics && availableBiometrics.isNotEmpty;
      _sharedPrefs.setBool(SharedPrefKeys.kCanCheckBiometrics, _canCheckBiometrics);

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
        localizedReason: t.bio_auth_required,
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
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
  Future<void> savePinSet(String hashedPin, int pinLength) async {
    await _secureStorageService.write(key: kSecureStoragePinKey, value: hashedPin);
    _isSetPin = true;
    _pinLength = pinLength;
    _sharedPrefs.setBool(SharedPrefKeys.kIsSetPin, _isSetPin);
    _sharedPrefs.setInt(SharedPrefKeys.kPinLength, pinLength);
    notifyListeners();
  }

  /// 비밀번호 삭제
  Future<void> deletePin() async {
    await _secureStorageService.delete(key: kSecureStoragePinKey);
    _isSetPin = false;
    _isSetBiometrics = false;
    _pinLength = 0;
    _sharedPrefs.setBool(SharedPrefKeys.kIsSetPin, _isSetPin);
    _sharedPrefs.setBool(SharedPrefKeys.kIsSetBiometrics, _isSetBiometrics);
    _sharedPrefs.deleteSharedPrefsWithKey(SharedPrefKeys.kPinLength);
    notifyListeners();
  }

  /// 비밀번호 검증
  Future<bool> verifyPin(String inputPin) async {
    String hashedInput = generateHashString(inputPin);
    final savedPin = await _secureStorageService.read(key: kSecureStoragePinKey);
    return savedPin == hashedInput;
  }

  /// 비밀번호 분실
  Future<void> resetPassword() async {
    _isSetBiometrics = false;
    _canCheckBiometrics = false;
    _isSetPin = false;
    _pinLength = 0;

    await _secureStorageService.deleteAll();
    await _sharedPrefs.deleteMultipleKeys(SharedPrefKeys.keysToReset);
    await checkDeviceBiometrics();
  }

  List<String> getShuffledNumberPad({bool isSettings = false}) {
    final random = Random();
    var randomNumberPad = List<String>.generate(10, (index) => index.toString());
    randomNumberPad.shuffle(random);
    randomNumberPad.insert(randomNumberPad.length - 1, !isSettings && _isSetBiometrics ? 'bio' : '');
    randomNumberPad.add('<');
    return randomNumberPad;
  }
}
