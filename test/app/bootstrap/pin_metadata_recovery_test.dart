import 'dart:convert';
import 'package:coconut_wallet/app/bootstrap/app_bootstrap.dart';
import 'package:coconut_wallet/constants/secure_keys.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/security/pin_auth_service_test.dart' show MemoryStorage, TestKdf;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({SharedPrefKeys.kHasLaunchedBefore: true});
    await SharedPrefsRepository().init();
  });
  test('startup recovers PIN-enabled metadata and length after an interrupted setting write', () async {
    final storage = MemoryStorage();
    final service = PinAuthService(storage: storage, kdf: TestKdf());
    await service.setPin('001234');
    await AppBootstrap.restorePinMetadata(pinAuth: service);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsSetPin), isTrue);
    expect(SharedPrefsRepository().getInt(SharedPrefKeys.kPinLength), 6);
  });
  test('startup also restores the lock for existing legacy verifiers', () async {
    final storage = MemoryStorage()..values[kSecureStoragePinKey] = sha256.convert(utf8.encode('1234')).toString();
    await AppBootstrap.restorePinMetadata(pinAuth: PinAuthService(storage: storage));
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsSetPin), isTrue);
  });
  test('a fresh install does not restore a stale iOS Keychain PIN before onboarding clears it', () async {
    await SharedPrefsRepository().setBool(SharedPrefKeys.kHasLaunchedBefore, false);
    final storage = MemoryStorage()..values[kSecureStoragePinKey] = sha256.convert(utf8.encode('1234')).toString();
    await AppBootstrap.restorePinMetadata(pinAuth: PinAuthService(storage: storage));
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsSetPin), isFalse);
  });
  test('explicit disable repairs stale PIN and biometric metadata after restart', () async {
    final prefs = SharedPrefsRepository();
    await prefs.setBool(SharedPrefKeys.kIsSetPin, true);
    await prefs.setBool(SharedPrefKeys.kIsSetBiometrics, true);
    await prefs.setInt(SharedPrefKeys.kPinLength, 4);
    final storage = MemoryStorage();
    final service = PinAuthService(storage: storage, kdf: TestKdf());
    await service.setPin('1234');
    await service.verify('1234');
    await service.deletePin();
    await AppBootstrap.restorePinMetadata(pinAuth: PinAuthService(storage: storage));
    expect(prefs.getBool(SharedPrefKeys.kIsSetPin), isFalse);
    expect(prefs.getBool(SharedPrefKeys.kIsSetBiometrics), isFalse);
    expect(prefs.getInt(SharedPrefKeys.kPinLength), 0);
  });
  test('missing verifier alone cannot disable an existing PIN lock', () async {
    await SharedPrefsRepository().setBool(SharedPrefKeys.kIsSetPin, true);
    await AppBootstrap.restorePinMetadata(pinAuth: PinAuthService(storage: MemoryStorage()));
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsSetPin), isTrue);
  });
  test('corrupt or unavailable storage cannot disable authentication at startup', () async {
    final storage = MemoryStorage()..failRead = true;
    await AppBootstrap.restorePinMetadata(pinAuth: PinAuthService(storage: storage));
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsSetPin), isTrue);
  });
}
