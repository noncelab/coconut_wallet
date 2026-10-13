import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/security/app_reset_service.dart';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';
import 'package:coconut_wallet/app/bootstrap/app_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pin_auth_service_test.dart' show MemoryStorage, TestKdf;

class _RejectedResetIntent extends Fake implements SharedPreferences {
  @override
  Future<bool> setBool(String key, bool value) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      SharedPrefKeys.kHasLaunchedBefore: true,
      SharedPrefKeys.kIsSetPin: true,
      SharedPrefKeys.kPinLength: 4,
      SharedPrefKeys.kIsSetBiometrics: true,
      SharedPrefKeys.kWalletCount: 2,
    });
    await SharedPrefsRepository().init();
  });

  test('interrupted reset after secure deletion finishes wallets and metadata before unlocking', () async {
    final storage = MemoryStorage();
    final pinAuth = PinAuthService(storage: storage, kdf: TestKdf());
    await pinAuth.setPin('1234');
    final reset = AppResetService();
    var wallets = 2;
    await expectLater(
      reset.perform(
        resetSecureStorage: () => pinAuth.resetStorage(() async => storage.values.clear()),
        resetWallets: () => throw StateError('interrupted'),
      ),
      throwsA(isA<PinAuthException>()),
    );
    expect(reset.isPending, isTrue);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsSetPin), isTrue);
    expect(storage.values, isEmpty);

    final restarted = PinAuthService(storage: storage, kdf: TestKdf());
    await AppResetService().recoverIfPending(
      resetSecureStorage: () => restarted.resetStorage(() async => storage.values.clear()),
      resetWallets: () => wallets = 0,
    );
    await AppBootstrap.restorePinMetadata(pinAuth: restarted);
    expect(wallets, 0);
    expect(reset.isPending, isFalse);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsSetPin), isFalse);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsSetBiometrics), isFalse);
    expect(SharedPrefsRepository().getInt(SharedPrefKeys.kPinLength), 0);
    expect(SharedPrefsRepository().getInt(SharedPrefKeys.kWalletCount), 0);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kHasLaunchedBefore), isTrue);
  });

  test('secure reset failure preserves the recovery flag and prevents wallet and metadata clearing', () async {
    var walletsCleared = false;
    await expectLater(
      AppResetService().perform(
        resetSecureStorage: () async => throw StateError('unavailable'),
        resetWallets: () => walletsCleared = true,
      ),
      throwsA(isA<PinAuthException>()),
    );
    expect(AppResetService().isPending, isTrue);
    expect(walletsCleared, isFalse);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsSetPin), isTrue);
  });

  test('recovery failure retains the pending reset for the next launch', () async {
    await SharedPrefsRepository().setBool(SharedPrefKeys.kAppResetPending, true);
    await expectLater(
      AppResetService().recoverIfPending(
        resetSecureStorage: () async {},
        resetWallets: () => throw StateError('unavailable'),
      ),
      throwsA(isA<PinAuthException>()),
    );
    expect(AppResetService().isPending, isTrue);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsSetPin), isTrue);
  });

  test('failure to persist reset intent prevents any destructive operation', () async {
    // ignore: deprecated_member_use_from_same_package
    SharedPrefsRepository().setSharedPreferencesForTest(_RejectedResetIntent());
    var secureCleared = false;
    var walletsCleared = false;
    await expectLater(
      AppResetService().perform(
        resetSecureStorage: () async => secureCleared = true,
        resetWallets: () => walletsCleared = true,
      ),
      throwsA(isA<PinAuthException>()),
    );
    expect(secureCleared, isFalse);
    expect(walletsCleared, isFalse);
  });

  test('normal startup without pending reset does not delete any data', () async {
    await AppResetService().recoverIfPending(
      resetSecureStorage: () async => fail('unexpected secure reset'),
      resetWallets: () => fail('unexpected wallet reset'),
    );
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kIsSetPin), isTrue);
    expect(SharedPrefsRepository().getInt(SharedPrefKeys.kWalletCount), 2);
  });
}
