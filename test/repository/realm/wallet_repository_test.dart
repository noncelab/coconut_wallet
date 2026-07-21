import 'dart:convert';

import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_realm_manager.dart';

const _parentTaprootXpub =
    "tpubDDMbU29QrSafD2Ui4yGv31Xp3PPSMvudreoohYjR8xLTng7hbsjYwUTeRhiKULFqX16M5M8zZh9siw5i6RRyisc6LtWjr1FwBYTiZUGGYJN";
const _childTaprootXpub =
    "tpubDCp2emt17Ng6ujD8BC6ScL4vfwhN3nAJQ8kCqLjRQHxcFhWt6YK5Ws6UcKD6HgLCZuwU8DryKo7h2gpieLa7Q9YF1AqfL9XiF7349nHaLi8";
const _inheritanceMiniscript = "and_v(v:pk([70C4E9DE/86'/1'/0']$_childTaprootXpub/<0;1>/*),older(500000000))";
const _oneParentDescriptor = "tr([9B1441E4/86'/1'/0']$_parentTaprootXpub/<0;1>/*,{$_inheritanceMiniscript})#w0hf4lu5";
const _singlesigDescriptor =
    "wpkh([D45AA182/84'/1'/0']vpub5YtEovN9MqeUZxWqdpUKngsiaLCPFY34KpWGQVk9Tjq8G5SYcRFj9s5aCKeAQYGunG7LrFkA5obtH8kPJiv92JtWHfRvnir6PDvhd4p93Pp/<0;1>/*)#rcn2hj6y";

void main() {
  late TestRealmManager realmManager;
  late WalletRepository walletRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // ignore: deprecated_member_use
    SharedPrefsRepository().setSharedPreferencesForTest(await SharedPreferences.getInstance());
    realmManager = await setupTestRealmManager();
    walletRepository = WalletRepository(realmManager, TransactionDraftRepository(realmManager));
  });

  tearDown(() {
    realmManager.reset();
    realmManager.realm.close();
  });

  group('WalletRepository - 싱글시그', () {
    WatchOnlyWallet createSinglesigWallet({
      String name = 'Hot Wallet',
      WalletImportSource source = WalletImportSource.coconutVault,
    }) {
      return WatchOnlyWallet(name, 0, 0, _singlesigDescriptor, null, null, source.name);
    }

    test('지갑 삭제 테스트', () async {
      final walletBase = RealmWalletBase(
        1,
        0,
        0,
        'encrypted_descriptor',
        'Test Wallet',
        WalletType.singleSignature.name,
      );
      realmManager.realm.write(() => realmManager.realm.add(walletBase));

      await walletRepository.deleteWallet(1);

      expect(realmManager.realm.all<RealmWalletBase>().length, 0);
    });

    test('핫월렛 생성 시 지갑과 local signer metadata가 함께 저장됨', () async {
      final created = await walletRepository.addHotWallet(
        createSinglesigWallet(),
        secureStorageKey: 'local_wallet_seed_regtest_1',
        backupVerified: true,
        createdAt: DateTime.utc(2026, 7, 20),
      );

      final wallet = (await walletRepository.getWalletItemList()).single;
      expect(created.id, wallet.id);
      expect(wallet.hasLocalKey, isTrue);
      expect(wallet.signingMethod, WalletSigningMethod.localSigner);
      expect(wallet.localSignerMetadata?.secureStorageKey, 'local_wallet_seed_regtest_1');
      expect(wallet.localSignerMetadata?.masterFingerprint, 'D45AA182');
    });

    test('외부 출처 싱글시그는 핫월렛 생성 경로로 저장할 수 없음', () async {
      expect(
        () => walletRepository.addHotWallet(
          createSinglesigWallet(source: WalletImportSource.keystone),
          secureStorageKey: 'local_wallet_seed_regtest_1',
          backupVerified: true,
          createdAt: DateTime.utc(2026, 7, 20),
        ),
        throwsArgumentError,
      );
      expect(realmManager.realm.all<RealmLocalSignerMetadata>(), isEmpty);
      expect(realmManager.realm.all<RealmWalletBase>(), isEmpty);
    });

    test('같은 descriptor의 Watch-only와 핫월렛을 각각 저장할 수 있음', () async {
      await walletRepository.addSinglesigWallet(createSinglesigWallet(name: 'Watch-only'));
      await walletRepository.addHotWallet(
        createSinglesigWallet(),
        secureStorageKey: 'local_wallet_seed_regtest_1',
        backupVerified: true,
        createdAt: DateTime.utc(2026, 7, 20),
      );

      final wallets = await walletRepository.getWalletItemList();
      expect(wallets, hasLength(2));
      expect(wallets.where((wallet) => wallet.hasLocalKey), hasLength(1));
      expect(wallets.where((wallet) => !wallet.hasLocalKey), hasLength(1));
    });
  });

  group('WalletRepository - 탭루트', () {
    final createdAtInVault = DateTime.utc(2026, 5, 20, 1, 2, 3);
    final scriptPathJson = jsonEncode([
      {
        'miniscript': _inheritanceMiniscript,
        'extendedPublicKeys': [_childTaprootXpub],
      },
    ]);

    RealmTaprootWallet createRealmTaprootWallet(int id, RealmWalletBase walletBase) {
      return RealmTaprootWallet(
        id,
        jsonEncode([_parentTaprootXpub]),
        scriptPathJson,
        walletBase: walletBase,
        createdAtInVault: createdAtInVault,
      );
    }

    test('addTaprootWallet: RealmWalletBase와 RealmTaprootWallet 모두 생성', () async {
      final watchOnlyWallet = WatchOnlyWallet.fromJson({
        'name': 'Taproot Wallet',
        'colorIndex': 0,
        'iconIndex': 0,
        'descriptor': _oneParentDescriptor,
        'walletImportSource': WalletImportSource.coconutVault.name,
        'createdAt': createdAtInVault.toIso8601String(),
        'keyPathSeedInfos': [_parentTaprootXpub],
        'scriptPathSeedInfos': [
          {
            'miniscript': _inheritanceMiniscript,
            'extendedPublicKeys': [_childTaprootXpub],
          },
        ],
      });

      final result = await walletRepository.addTaprootWallet(watchOnlyWallet);

      expect(realmManager.realm.all<RealmWalletBase>().length, 1);
      expect(realmManager.realm.all<RealmTaprootWallet>().length, 1);
      expect(result, isA<TaprootWalletItem>());
      expect(result.keyPathSeedInfos, [_parentTaprootXpub]);
      expect(result.scriptPathSeedInfos.length, 1);
      expect(result.scriptPathSeedInfos.first.miniscript, _inheritanceMiniscript);
      expect(result.createdAtInVault, createdAtInVault);
    });

    test('getWalletItemList: 탭루트 지갑이 TaprootWalletListItem으로 반환', () async {
      final walletBase = RealmWalletBase(1, 0, 0, _oneParentDescriptor, 'Taproot Wallet', WalletType.taproot.name);
      realmManager.realm.write(() {
        realmManager.realm.add(walletBase);
        realmManager.realm.add(createRealmTaprootWallet(1, walletBase));
      });

      final list = await walletRepository.getWalletItemList();

      expect(list.length, 1);
      expect(list.first, isA<TaprootWalletItem>());
      final item = list.first as TaprootWalletItem;
      expect(item.keyPathSeedInfos, [_parentTaprootXpub]);
      expect(item.scriptPathSeedInfos.first.miniscript, _inheritanceMiniscript);
      expect(item.createdAtInVault, createdAtInVault);
    });

    test('deleteWallet: RealmTaprootWallet도 함께 삭제', () async {
      final walletBase = RealmWalletBase(1, 0, 0, _oneParentDescriptor, 'Taproot Wallet', WalletType.taproot.name);
      realmManager.realm.write(() {
        realmManager.realm.add(walletBase);
        realmManager.realm.add(createRealmTaprootWallet(1, walletBase));
      });

      await walletRepository.deleteWallet(1);

      expect(realmManager.realm.all<RealmWalletBase>().length, 0);
      expect(realmManager.realm.all<RealmTaprootWallet>().length, 0);
    });

    test('지갑 삭제 시 local signer metadata도 함께 삭제됨', () async {
      final walletBase = RealmWalletBase(1, 0, 0, _oneParentDescriptor, 'Taproot Wallet', WalletType.taproot.name);
      realmManager.realm.write(() {
        realmManager.realm.add(walletBase);
        realmManager.realm.add(createRealmTaprootWallet(1, walletBase));
        realmManager.realm.add(
          RealmLocalSignerMetadata(
            1,
            'local_wallet_seed_regtest_1',
            '9B1441E4',
            "m/86'/1'/0'",
            0,
            true,
            DateTime.utc(2026, 7, 20),
          ),
        );
      });

      await walletRepository.deleteWallet(1);

      expect(realmManager.realm.all<RealmLocalSignerMetadata>(), isEmpty);
    });
  });
}
