import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
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

/// 외부 월렛 추가, 삭제, 로드 테스트(공개확장키, 디스크립터)
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

  setUp(() async {
    realmManager = RealmManager();
    walletRepository = WalletRepository(realmManager);
    realmManager.reset();

    final prefs = SharedPrefsRepository();
    await prefs.init();
    await prefs.clearSharedPref();
    await SecureStorageRepository().deleteAll();
  });

  tearDown(() async {
    realmManager.realm.close();
  });

  group('ExternalWallet add test', () {
    setUp(() async {
      await skipTutorial(true);
    });

    // 1. 기존 월렛이 추가된 상태에서 외부 월렛 CRUD 테스트
    testWidgets('[Wallet O]', (tester) async {
      await setWalletData(true);
      await externalWalletCrudFlow(tester, walletRepository);
    });

    // 2. 기존 월렛이 없는 상태에서 외부 월렛 CRUD 테스트
    testWidgets('[Wallet X]', (tester) async {
      await setWalletData(false);
      await externalWalletCrudFlow(tester, walletRepository);
    });
  });
}

Future<void> externalWalletCrudFlow(WidgetTester tester, WalletRepository walletRepository) async {
  int initialWalletCount = (await walletRepository.getWalletItemList()).length;

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

  // fix: 첫 테스트에서만 Connectivity 리스너가 호출되는 문제가 있다. 두 번째 테스트부터 임의로 함수를 호출하여 isolate.subscribeWallets가 호출되도록 한다.
  walletProvider.setIsNetworkOn(true);

  // Wallet Data(xpub)
  String testPubKey =
      "vpub5ZZ1q76vi2LR9PeQDoV13u8TZwsyqKa7yBfD3GnPPvBjVU9ZnBTMkwzCHCVBZaPHDKJNEdMKo8MTyrQ9234idzSG9nHFD6hsUB8HJ14NBg7";
  Descriptor descriptor =
      Descriptor.forSingleSignature(AddressType.p2wpkh, testPubKey, "84'/1'/0'", "98C7D774");
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
    "walletImportSource": WalletImportSource.extendedPublicKey.name
  };

  // Add External Wallets
  var xpubWalletResult =
      await walletProvider.syncFromVault(WatchOnlyWallet.fromJson(xpubWalletData));
  var descriptorWalletResult =
      await walletProvider.syncFromVault(WatchOnlyWallet.fromJson(descriptorWalletData));

  expect(xpubWalletResult.walletId != null, true);
  expect(descriptorWalletResult.walletId != null, true);

  // Verify Wallets
  var xpubWallet = walletProvider.getWalletById(xpubWalletResult.walletId!);
  verifyWalletListItem(xpubWallet, xpubWalletData);

  var descriptorWallet = walletProvider.getWalletById(descriptorWalletResult.walletId!);
  verifyWalletListItem(descriptorWallet, descriptorWalletData);

  // Load from Realm
  var walletBaseList = await walletRepository.getWalletItemList();
  expect(walletBaseList.length, initialWalletCount + 2);

  // Verify Wallets
  var extendedPublicKeyWalletFromRealm = walletBaseList
      .firstWhere((v) => v.walletImportSource == WalletImportSource.extendedPublicKey);
  var descriptorWalletFromRealm = walletBaseList
      .firstWhere((v) => v.walletImportSource == WalletImportSource.extendedPublicKey);
  verifyWalletListItem(extendedPublicKeyWalletFromRealm, xpubWalletData);
  verifyWalletListItem(descriptorWalletFromRealm, descriptorWalletData);

  // Delete Wallets
  await walletProvider.deleteWallet(xpubWalletResult.walletId!);
  await walletProvider.deleteWallet(descriptorWalletResult.walletId!);
  expect(walletProvider.walletItemList.length, initialWalletCount);
}
