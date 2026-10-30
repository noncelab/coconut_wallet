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
  for (final corrupt in [false, true]) {
    for (final enabled in [false, true]) {
      test('startup read failure preserves existing PIN metadata: corrupt=$corrupt enabled=$enabled', () async {
        final prefs = SharedPrefsRepository();
        await prefs.setBool(SharedPrefKeys.kIsSetPin, enabled);
        await prefs.setBool(SharedPrefKeys.kIsSetBiometrics, enabled);
        if (enabled) await prefs.setInt(SharedPrefKeys.kPinLength, 6);
        final storage = MemoryStorage();
        if (corrupt) {
          storage.values[PinAuthService.recordKey] = 'not-json';
        } else {
          storage.failRead = true;
        }
        await expectLater(
          AppBootstrap.restorePinMetadata(pinAuth: PinAuthService(storage: storage)),
          throwsA(isA<PinAuthException>()),
        );
        expect(prefs.getBool(SharedPrefKeys.kIsSetPin), enabled);
        expect(prefs.getBool(SharedPrefKeys.kIsSetBiometrics), enabled);
        expect(prefs.getInt(SharedPrefKeys.kPinLength), enabled ? 6 : 0);
      });
    }
  }

  test('unset PIN stays disabled after a transient read failure and a healthy restart', () async {
    final prefs = SharedPrefsRepository();
    await prefs.setBool(SharedPrefKeys.kIsSetPin, false);
    final storage = MemoryStorage()..failRead = true;
    await expectLater(
      AppBootstrap.restorePinMetadata(pinAuth: PinAuthService(storage: storage)),
      throwsA(isA<PinAuthException>()),
    );
    expect(prefs.getBool(SharedPrefKeys.kIsSetPin), isFalse);
    storage.failRead = false;
    await prefs.init();
    final restarted = PinAuthService(storage: storage, kdf: TestKdf());
    expect(await restarted.configuration(), (configured: false, length: null, explicitlyDisabled: false));
    await AppBootstrap.restorePinMetadata(pinAuth: restarted);
    expect(prefs.getBool(SharedPrefKeys.kIsSetPin), isFalse);
    expect(storage.values, isEmpty);
    // 실패가 복구된 뒤에는 정상적으로 새 PIN을 설정할 수 있다.
    await restarted.setPin('001234');
    await AppBootstrap.restorePinMetadata(pinAuth: restarted);
    expect(prefs.getBool(SharedPrefKeys.kIsSetPin), isTrue);
    expect(prefs.getInt(SharedPrefKeys.kPinLength), 6);
  });

  for (final enabled in [false, true]) {
    test('configured PIN is restored after a transient read failure and healthy retry: enabled=$enabled', () async {
      final prefs = SharedPrefsRepository();
      await prefs.setBool(SharedPrefKeys.kIsSetPin, enabled);
      final storage = MemoryStorage();
      await PinAuthService(storage: storage, kdf: TestKdf()).setPin('1234');
      final original = Map<String, String>.from(storage.values);
      storage.failRead = true;
      await expectLater(
        AppBootstrap.restorePinMetadata(pinAuth: PinAuthService(storage: storage)),
        throwsA(isA<PinAuthException>()),
      );
      expect(prefs.getBool(SharedPrefKeys.kIsSetPin), enabled);
      expect(storage.values, original);
      storage.failRead = false;
      final restarted = PinAuthService(storage: storage, kdf: TestKdf());
      await AppBootstrap.restorePinMetadata(pinAuth: restarted);
      expect(prefs.getBool(SharedPrefKeys.kIsSetPin), isTrue);
      expect((await restarted.verify('1234')).outcome, PinVerificationOutcome.success);
    });
  }
}
