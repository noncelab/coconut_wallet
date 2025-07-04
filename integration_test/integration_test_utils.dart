import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/secure_keys.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/secure_storage/secure_storage_repository.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/hash_util.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Coconut Import
const singleSigWallet1ExtendedPublicKey =
    'vpub5ZUp3fZ5qRUehB8c5Gmu2SuCQaD57jbostKFDExNdU55KQZEaXMpk7g32SDMGyJki7p7xjMdXaCeQmrvrsVTfntGu7Jd8WpsAdjDk357J7B';
const singleSigWallet1SimpleDescriptor = "[3C3204A6/84'/1'/0']$singleSigWallet1ExtendedPublicKey";
final singleSigWallet1 = {
  "name": "test1",
  "colorIndex": 0,
  "iconIndex": 0,
  "descriptor": "wpkh([3C3204A6/84'/1'/0']$singleSigWallet1ExtendedPublicKey/<0;1>/*)#9d8xrtmf"
};
const singleSigWallet2ExtendedPublicKey =
    'vpub5ZPbEKFRmz3KQL2p2eHXjYX27jTiBjZ7ZfsEXdxQHaqtwoEQ9qsGQGPtxUt7sF6kinSjSjKYi211HEAFctu3EHoXkYa6omVvnQQyWBup83W';
final singleSigWallet2 = {
  "name": "test2",
  "colorIndex": 0,
  "iconIndex": 5,
  "descriptor": "wpkh([65B3CF82/84'/1'/0']$singleSigWallet2ExtendedPublicKey/<0;1>/*)#7udh8lv2"
};
final multiSigWallet1 = {
  "name": "multi1",
  "colorIndex": 0,
  "iconIndex": 19,
  "descriptor":
      "wsh(sortedmulti(1,[3C3204A6/48'/1'/0'/2']Vpub5mLfhEdPaAydje9dtq2pm8mkuDYtzAzQCm5sdXVspjNNjuSuxW47wFvL2JxHCCAmAYo4ZtvbcZtUYGc3Bi5NuwTfA9HPidpFzVskTA8SqN8/<0;1>/*,[65B3CF82/48'/1'/0'/2']Vpub5mDfvU9A4gVA3z1sLzWppBvZGZsL15qba6BzxbPwHFYzGXkKzqWTP6tXqSguyEEBMDBvfngdFr1SBskSRToVsTrLVFumDbdy8tEfW9ErqhM/<0;1>/*))#tl8eflmy",
  "requiredSignatureCount": 1,
  "signers": [
    {"innerVaultId": 2, "name": "test1", "iconIndex": 0, "colorIndex": 0, "memo": null},
    {"innerVaultId": 3, "name": "test2", "iconIndex": 5, "colorIndex": 0, "memo": null}
  ]
};

// External Import
const externalWallet1ExtendedPublicKey =
    'vpub5ZmsGxFEH9VdhXPaGm5SbwN8zSMk6yAAgtszTgn2ztUAArSWG2miXE3BWxVq7bdM3tfrwp4PVQkZ73EbfjHB5EBrQHnHp8RsXqaUynwFi5h';
const externalWallet1FullDescriptor =
    "wpkh([E08C091D/84'/1'/0']$externalWallet1ExtendedPublicKey/<0;1>/*)#83zwur2j";
final exSingleSigWallet1 = {
  "name": "zpub",
  "colorIndex": 0,
  "iconIndex": 0,
  "descriptor": SingleSignatureWallet.fromExtendedPublicKey(AddressType.p2wpkh,
          externalWallet1ExtendedPublicKey, WalletAddService.masterFingerprintPlaceholder)
      .descriptor,
  "walletImportSource": WalletImportSource.extendedPublicKey.name
};

/// Waits for a widget to appear on the screen with a timeout (100초).
/// Returns true if the widget was found, false if it timed out.
Future<bool> waitForWidget(WidgetTester tester, Finder finder,
    {String? timeoutMessage, int timeoutSeconds = 60}) async {
  bool found = false;
  for (int i = 0; i < timeoutSeconds && !found; i++) {
    await tester.pump(const Duration(seconds: 1));
    found = finder.evaluate().isNotEmpty;
  }
  if (timeoutMessage != null) {
    expect(found, true, reason: timeoutMessage);
  }
  return found;
}

Future<void> waitForWidgetAndTap(WidgetTester tester, Finder element, String elementName,
    {int timeoutSeconds = 60}) async {
  await waitForWidget(tester, element,
      timeoutMessage: "$elementName not found after $timeoutSeconds seconds",
      timeoutSeconds: timeoutSeconds);
  await tester.tap(element);
  await tester.pumpAndSettle();
}

Future<void> setTwoSinglesAndOneMultiCoconutWallets(bool isEnabled,
    {RealmManager? realmManager}) async {
  if (!isEnabled) return;
  await addWallets(realmManager: realmManager);
}

Future<void> skipTutorial(bool skip) async {
  final prefs = await SharedPreferences.getInstance();
  prefs.setBool(SharedPrefKeys.kHasLaunchedBefore, skip);
}

Future<void> savePinCode(String pinCode) async {
  final SecureStorageRepository storageService = SecureStorageRepository();
  final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
  await storageService.write(key: kSecureStoragePinKey, value: generateHashString(pinCode));
  await sharedPreferences.setBool(SharedPrefKeys.kIsSetPin, true);
}

void verifyWalletListItem(WalletListItemBase wallet, Map<String, dynamic> walletData) {
  expect(wallet.name, walletData["name"]);
  expect(wallet.colorIndex, walletData["colorIndex"]);
  expect(wallet.iconIndex, walletData["iconIndex"]);
  expect(wallet.descriptor, walletData["descriptor"]);
  expect(wallet.walletType,
      walletData["signers"] == null ? WalletType.singleSignature : WalletType.multiSignature);
  expect(wallet.walletImportSource.name,
      walletData["walletImportSource"] ?? WalletImportSource.coconutVault.name);
}

Future<void> _setWalletCount(int count) async {
  final prefs = await SharedPreferences.getInstance();
  prefs.setInt(SharedPrefKeys.kWalletCount, count);
}

Future<int> addWallets({WalletProvider? walletProvider, RealmManager? realmManager}) async {
  if (walletProvider != null) {
    await walletProvider.syncFromCoconutVault(WatchOnlyWallet.fromJson(singleSigWallet1));
    await walletProvider.syncFromCoconutVault(WatchOnlyWallet.fromJson(singleSigWallet2));
    await walletProvider.syncFromCoconutVault(WatchOnlyWallet.fromJson(multiSigWallet1));
  } else {
    var realmManagerForSetup = realmManager ?? RealmManager();
    var walletRepository = WalletRepository(realmManagerForSetup);
    var addressRepository = AddressRepository(realmManagerForSetup);

    var item1 =
        await walletRepository.addSinglesigWallet(WatchOnlyWallet.fromJson(singleSigWallet1));
    await addressRepository.ensureAddressesInit(walletItemBase: item1);

    var item2 =
        await walletRepository.addSinglesigWallet(WatchOnlyWallet.fromJson(singleSigWallet2));
    await addressRepository.ensureAddressesInit(walletItemBase: item2);

    var item3 = await walletRepository.addMultisigWallet(WatchOnlyWallet.fromJson(multiSigWallet1));
    await addressRepository.ensureAddressesInit(walletItemBase: item3);
    await _setWalletCount(3);
  }

  return 3;
}

Future<void> setOneExternalWallet({WalletProvider? walletProvider}) async {
  if (walletProvider != null) {
    await walletProvider.syncFromThirdParty(WatchOnlyWallet.fromJson(exSingleSigWallet1));
  } else {
    var realmManager = RealmManager();
    var walletRepository = WalletRepository(realmManager);
    var addressRepository = AddressRepository(realmManager);

    var item1 =
        await walletRepository.addSinglesigWallet(WatchOnlyWallet.fromJson(exSingleSigWallet1));
    await addressRepository.ensureAddressesInit(walletItemBase: item1);
  }
}
