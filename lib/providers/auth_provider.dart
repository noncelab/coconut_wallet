import 'package:coconut_wallet/services/security/app_reset_service.dart';
import 'dart:math';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class AuthProvider extends ChangeNotifier {
  static const MethodChannel _osChannel = MethodChannel('onl.coconut.wallet/os');

  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();
  final SecureStorageRepository _secureStorageService = SecureStorageRepository();
  final LocalAuthentication _auth = LocalAuthentication();
  final PinAuthService _pinAuth;

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

  AuthProvider({PinAuthService? pinAuth}) : _pinAuth = pinAuth ?? PinAuthService() {
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

  /// 기기 잠금 비밀번호(PIN, 패턴, 비밀번호)가 설정되어 있는지 확인
  Future<bool> isDevicePasscodeSet() async {
    try {
      return await _osChannel.invokeMethod<bool>('isDevicePasscodeSet') ?? false;
    } on MissingPluginException {
      Logger.warning('AUTH_PLATFORM_OPERATION_FAILED');
      return await _auth.isDeviceSupported();
    } on PlatformException {
      Logger.warning('AUTH_PLATFORM_OPERATION_FAILED');
      return false;
    }
  }

  /// 기기의 화면 잠금 설정 화면 열기
  Future<void> openDeviceSecuritySettings() async {
    try {
      await _osChannel.invokeMethod<void>('openDeviceSecuritySettings');
    } on MissingPluginException {
      Logger.warning('AUTH_PLATFORM_OPERATION_FAILED');
    } on PlatformException {
      Logger.warning('AUTH_PLATFORM_OPERATION_FAILED');
    }
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
    } catch (_) {
      // 생체 인식 기능 비활성화, 사용자가 권한 거부, 기기 하드웨어에 문제가 있는 경우, 기기 호환성 문제, 플랫폼 제한
      Logger.warning('AUTH_PLATFORM_OPERATION_FAILED');
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

      if (authenticated) await _pinAuth.onBiometricAuthenticationSucceeded();
      if (isSave) {
        await saveIsSetBiometrics(authenticated);
      }

      return authenticated;
    } catch (_) {
      Logger.warning('AUTH_PLATFORM_OPERATION_FAILED');
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
  Future<void> savePin(String pin) async {
    await _pinAuth.setPin(pin);
    _isSetPin = true;
    _pinLength = pin.length;
    try {
      await _sharedPrefs.setBool(SharedPrefKeys.kIsSetPin, _isSetPin);
      await _sharedPrefs.setInt(SharedPrefKeys.kPinLength, _pinLength);
    } catch (_) {
      // 보안 저장은 완료됐으므로 실패로 표시하지 않고 다음 시작 시 복구합니다.
      Logger.warning('AUTH_METADATA_WRITE_FAILED');
    }
    notifyListeners();
  }

  /// 비밀번호 삭제
  Future<void> deletePin() async {
    await _pinAuth.deletePin();
    _isSetPin = false;
    _isSetBiometrics = false;
    _pinLength = 0;
    try {
      await _sharedPrefs.setBool(SharedPrefKeys.kIsSetPin, _isSetPin);
      await _sharedPrefs.setBool(SharedPrefKeys.kIsSetBiometrics, _isSetBiometrics);
      await _sharedPrefs.deleteSharedPrefsWithKey(SharedPrefKeys.kPinLength);
    } catch (_) {
      Logger.warning('AUTH_METADATA_WRITE_FAILED');
    }
    notifyListeners();
  }

  /// 비밀번호 검증
  Future<PinVerificationResult> verifyPinResult(String inputPin) => _pinAuth.verify(inputPin);

  Future<bool> verifyPin(String inputPin) async =>
      (await verifyPinResult(inputPin)).outcome == PinVerificationOutcome.success;

  Future<PinAuthStatus> getPinAuthStatus() => _pinAuth.status();

  /// 비밀번호 분실
  Future<void> resetPassword({required void Function() resetWallets}) async {
    await AppResetService().perform(
      resetSecureStorage: () => _pinAuth.resetStorage(_secureStorageService.deleteAll),
      resetWallets: resetWallets,
    );
    _isSetBiometrics = false;
    _canCheckBiometrics = false;
    _isSetPin = false;
    _pinLength = 0;
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
