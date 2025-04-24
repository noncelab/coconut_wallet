import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/wallet_list_screen.dart';
import 'package:provider/provider.dart';
import 'integration_test_utils.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:coconut_wallet/main.dart' as app;

/// 백업 데이터 암호화/복호화 및 파일 저장 기능 테스트
///
/// 실행 명령어:
/// ```bash
/// flutter test integration_test/wallet_add_test.dart --flavor regtest
/// ```
///
/// 자세한 내용은 README.md 참고
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late RealmManager realmManager;
  late WalletRepository walletRepository;
  late AddressRepository addressRepository;

  setUp(() async {
    realmManager = RealmManager();
    walletRepository = WalletRepository(realmManager);
    addressRepository = AddressRepository(realmManager);
    realmManager.reset();

    final prefs = SharedPrefsRepository();
    await prefs.init();
    await prefs.clearSharedPref();
    await SecureStorageRepository().deleteAll();
  });

  tearDown(() async {
    realmManager.realm.close();
  });

  group('Wallet add test', () {
    setUp(() async {
      await skipTutorial(true);
    });

    testWidgets('Add external wallets', (tester) async {
      // 지갑 3개 추가(싱글 2개, 멀티 1개)
      int count = await addWallets();
      expect(count, 3, reason: "count has to be 3");

      app.main();
      await tester.pumpAndSettle();

      final Finder walletListScreen = find.byType(WalletListScreen);
      await waitForWidget(tester, walletListScreen,
          timeoutMessage: 'walletListScreen not found after 60 seconds');
      await tester.pumpAndSettle();

      final walletProvider = Provider.of<WalletProvider>(
        tester.element(find.byType(WalletListScreen)),
        listen: false,
      );

      // Wallet Data(xpub)
      String testPubKey =
          "vpub5ZZ1q76vi2LR9PeQDoV13u8TZwsyqKa7yBfD3GnPPvBjVU9ZnBTMkwzCHCVBZaPHDKJNEdMKo8MTyrQ9234idzSG9nHFD6hsUB8HJ14NBg7";
      Descriptor descriptor =
          Descriptor.forSingleSignature("wpkh", testPubKey, "84'/1'/0'", "98C7D774");
      var xpubWalletData = {
        "name": "xpub 1",
        "colorIndex": 3,
        "iconIndex": 3,
        "descriptor": descriptor.serialize(),
        "walletImportSource": WalletImportSource.extendedPublicKey.name
      };

      // Wallet Data(Descriptor)
      String testDescriptor =
          "wpkh([DB348FF2/84'/1'/0']vpub5Y73YLZeBJ628GtaKTHzLVgwF5gS9k523WiJepSuc3qU9Mj88r9jb1noAtzrUgpZNpq1qSAsdWqqYhAfnDExDiAR3E5LDAAziQPmWuWBrvL/<0;1>/*)#hw3qekj8";
      var descriptorWalletData = {
        "name": "descriptor 1",
        "colorIndex": 4,
        "iconIndex": 4,
        "descriptor": testDescriptor,
        "walletImportSource": WalletImportSource.descriptor.name
      };

      var xpubWalletResult =
          await walletProvider.syncFromVault(WatchOnlyWallet.fromJson(xpubWalletData));
      var descriptorWalletResult =
          await walletProvider.syncFromVault(WatchOnlyWallet.fromJson(descriptorWalletData));

      expect(xpubWalletResult.walletId != null, true);
      expect(descriptorWalletResult.walletId != null, true);

      // Verify Wallet
      var xpubWallet = walletProvider.getWalletById(xpubWalletResult.walletId!);
      verifyWalletListItem(xpubWallet, xpubWalletData);

      var descriptorWallet = walletProvider.getWalletById(descriptorWalletResult.walletId!);
      verifyWalletListItem(descriptorWallet, descriptorWalletData);

      // Load from Realm
      var walletBaseList = await walletRepository.getWalletItemList();
      expect(walletBaseList.length, 5);

      // Verify Wallet
      var extendedPublicKeyWalletFromRealm = walletBaseList
          .firstWhere((v) => v.walletImportSource == WalletImportSource.extendedPublicKey);
      var descriptorWalletFromRealm =
          walletBaseList.firstWhere((v) => v.walletImportSource == WalletImportSource.descriptor);
      verifyWalletListItem(extendedPublicKeyWalletFromRealm, xpubWalletData);
      verifyWalletListItem(descriptorWalletFromRealm, descriptorWalletData);

      // Delete Wallet
      await walletProvider.deleteWallet(xpubWalletResult.walletId!);
      await walletProvider.deleteWallet(descriptorWalletResult.walletId!);
      expect(walletProvider.walletItemList.length, 3);
    });
  });
}
