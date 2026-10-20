import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/wallet_appearance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPrefsRepository prefs;
  late WalletAppearanceRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    repository = WalletAppearanceRepository(prefs);
  });

  test('nothing saved → empty', () {
    expect(repository.loadBackgrounds(), isEmpty);
  });

  test('backgrounds load back per wallet', () async {
    const photo = WalletPhotoBackground(fileName: 'wallet_2_1.jpg', aspectRatio: 0.75, focusY: 0.5);
    await repository.setBackground(1, const WalletSkinBackground('sky'));
    await repository.setBackground(2, photo);

    expect(repository.loadBackgrounds(), {1: const WalletSkinBackground('sky'), 2: photo});
  });

  test('null background clears the wallet and the key when nothing is left', () async {
    await repository.setBackground(1, const WalletSkinBackground('sky'));
    await repository.setBackground(1, null);

    expect(repository.loadBackgrounds(), isEmpty);
    expect(prefs.isContainsKey(SharedPrefKeys.kWalletAppearanceMap), isFalse);
  });

  test('remove drops only that wallet', () async {
    await repository.setBackground(1, const WalletSkinBackground('sky'));
    await repository.setBackground(2, const WalletSkinBackground('rose'));
    await repository.remove(1);

    expect(repository.loadBackgrounds(), {2: const WalletSkinBackground('rose')});
  });

  test('broken JSON → empty instead of throwing', () async {
    await prefs.setString(SharedPrefKeys.kWalletAppearanceMap, '{not json');

    expect(repository.loadBackgrounds(), isEmpty);
  });

  test('cleared on password reset', () {
    expect(SharedPrefKeys.keysToReset, contains(SharedPrefKeys.kWalletAppearanceMap));
  });
}
