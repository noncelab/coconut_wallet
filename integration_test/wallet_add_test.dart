import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/wallet_list_screen.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/descriptor_util.dart';
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
/// 한번에 아래 모든 테스트 실행 시 walletProvider, nodeProvider 간 통신에 문제가 있어서
/// 개별적으로 테스트 실행이 필요할 수 있습니다.
/// 이미 통과한 테스트는 주석처리하는 방식으로 실행 부탁드립니다.
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
      await setTwoSinglesAndOneMultiCoconutWallets(true);
      await validateExternalWalletCrudFlow(tester, walletRepository);
    });

    // 2. 기존 월렛이 없는 상태에서 외부 월렛 CRUD 테스트
    testWidgets('[Wallet X]', (tester) async {
      await setTwoSinglesAndOneMultiCoconutWallets(false);
      await validateExternalWalletCrudFlow(tester, walletRepository);
    });

    // 3. 코코넛볼트로부터 추가된 상태에서 같은 Extended PubKey를 가지는 외부 지갑 추가 실패
    testWidgets('[Wallet O] 같은 Extended PubKey를 가지는 외부 지갑 추가 실패', (tester) async {
      await setTwoSinglesAndOneMultiCoconutWallets(true);
      await validateDuplicatedExternalWalletAddFailed(tester, walletRepository);
    });
  });

  group('외부 지갑 추가된 상태에서 CoconutVault add test', () {
// 외부 지갑이 이미 추가된 상태에서 같은 Extended PubKey를 가지는 코코넛 지갑 추가 실패
    testWidgets('[Wallet O] 같은 Extended PubKey를 가지는 코코넛 지갑 추가 실패', (tester) async {
      await setOneExternalWallet();
      await validateDuplicatedCoconutVaultAddFailed(tester, walletRepository);
    });
  });
}

Future<void> validateExternalWalletCrudFlow(
    WidgetTester tester, WalletRepository walletRepository) async {
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
  await Future.delayed(const Duration(seconds: 2));

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
      await walletProvider.syncFromCoconutVault(WatchOnlyWallet.fromJson(xpubWalletData));
  var descriptorWalletResult =
      await walletProvider.syncFromCoconutVault(WatchOnlyWallet.fromJson(descriptorWalletData));

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
  var extendedPublicKeyWallets = walletBaseList
      .where((v) => v.walletImportSource == WalletImportSource.extendedPublicKey)
      .toList();
  verifyWalletListItem(extendedPublicKeyWallets[1], xpubWalletData);
  verifyWalletListItem(extendedPublicKeyWallets[0], descriptorWalletData);

  // Delete Wallets
  await walletProvider.deleteWallet(xpubWalletResult.walletId!);
  await walletProvider.deleteWallet(descriptorWalletResult.walletId!);
  expect(walletProvider.walletItemList.length, initialWalletCount);
}

Future<void> validateDuplicatedExternalWalletAddFailed(
    WidgetTester tester, WalletRepository walletRepository) async {
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
  //walletProvider.setIsNetworkOn(true);

  final walletFromExtendedPubKey = WalletAddService()
      .createExtendedPublicKeyWallet(singleSigWallet1ExtendedPublicKey, 'zpub', null);

  var pubKeyWalletAddResult = await walletProvider.syncFromThirdParty(walletFromExtendedPubKey);
  expect(pubKeyWalletAddResult.result, WalletSyncResult.existingWalletUpdateImpossible);
  expect(pubKeyWalletAddResult.walletId, isNotNull);
  expect(pubKeyWalletAddResult.walletId, isNot(-1));

  final walletFromDescriptor1 = WalletAddService().createWalletFromDescriptor(
      descriptor: singleSigWallet1['descriptor'] as String,
      name: "zpub",
      walletImportSource: WalletImportSource.extendedPublicKey);

  var descriptorWalletAddResult = await walletProvider.syncFromThirdParty(walletFromDescriptor1);
  expect(descriptorWalletAddResult.result, WalletSyncResult.existingWalletUpdateImpossible);
  expect(descriptorWalletAddResult.walletId, isNotNull);
  expect(descriptorWalletAddResult.walletId, isNot(-1));

  final walletFromDescriptor2 = WalletAddService().createWalletFromDescriptor(
      descriptor: DescriptorUtil.normalizeDescriptor(singleSigWallet1SimpleDescriptor),
      name: "zpub",
      walletImportSource: WalletImportSource.extendedPublicKey);

  var descriptorWalletAddResult2 = await walletProvider.syncFromThirdParty(walletFromDescriptor2);
  expect(descriptorWalletAddResult2.result, WalletSyncResult.existingWalletUpdateImpossible);
  expect(descriptorWalletAddResult2.walletId, isNotNull);
  expect(descriptorWalletAddResult2.walletId, isNot(-1));
}

Future<void> validateDuplicatedCoconutVaultAddFailed(
    WidgetTester tester, WalletRepository walletRepository) async {
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
  //walletProvider.setIsNetworkOn(true);

  var coconutWallet = WatchOnlyWallet(
    "coconut지갑1",
    0,
    0,
    externalWallet1FullDescriptor,
    null,
    null,
    WalletImportSource.coconutVault.name,
  );

  var coconutWalletAddResult = await walletProvider.syncFromCoconutVault(coconutWallet);
  expect(coconutWalletAddResult.result, WalletSyncResult.existingWalletUpdateImpossible);
  expect(coconutWalletAddResult.walletId, isNotNull);
  expect(coconutWalletAddResult.walletId, isNot(-1));
}
