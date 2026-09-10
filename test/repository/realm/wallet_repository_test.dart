import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mock/realm/realm_transaction_mock.dart';
import '../../mock/realm/realm_utxo_mock.dart';
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
    // ignore: deprecated_member_use_from_same_package
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

    test('삭제된 지갑의 잔액 조회와 누적 요청을 무시함', () async {
      final firstHotWallet = await walletRepository.addHotWallet(
        createSinglesigWallet(name: 'Hot Wallet 1'),
        secureStorageKey: 'local_wallet_seed_regtest_1',
        backupVerified: true,
        enterPassphraseWhenSigning: false,
        createdAt: DateTime.utc(2026, 8, 11),
      );
      await walletRepository.addHotWallet(
        createSinglesigWallet(name: 'Hot Wallet 2'),
        secureStorageKey: 'local_wallet_seed_regtest_2',
        backupVerified: true,
        enterPassphraseWhenSigning: false,
        createdAt: DateTime.utc(2026, 8, 11),
      );
      final watchOnlyWallet = await walletRepository.addSinglesigWallet(
        createSinglesigWallet(name: 'Watch-only Wallet', source: WalletImportSource.extendedPublicKey),
      );

      await walletRepository.deleteWallet(watchOnlyWallet.id);

      expect(walletRepository.getWalletBalance(watchOnlyWallet.id), isNull);
      expect(await walletRepository.accumulateWalletBalance(watchOnlyWallet.id, Balance(1, 0)), isNull);
      expect(walletRepository.getWalletBalance(firstHotWallet.id), isNotNull);
    });

    test('핫월렛 생성 시 지갑과 hot wallet metadata가 함께 저장됨', () async {
      final created = await walletRepository.addHotWallet(
        createSinglesigWallet(),
        secureStorageKey: 'local_wallet_seed_regtest_1',
        backupVerified: true,
        enterPassphraseWhenSigning: true,
        createdAt: DateTime.utc(2026, 7, 20),
        lifecycleState: HotWalletLifecycleState.active,
      );

      final wallet = (await walletRepository.getWalletItemList()).single;
      expect(created.id, wallet.id);
      expect(wallet.hasLocalKey, isTrue);
      expect(wallet.signingMethod, WalletSigningMethod.localSigner);
      expect(wallet.hotWalletMetadata?.secureStorageKey, 'local_wallet_seed_regtest_1');
      expect(wallet.hotWalletMetadata?.masterFingerprint, 'D45AA182');
      expect(wallet.hotWalletMetadata?.enterPassphraseWhenSigning, isTrue);
    });

    test('외부 출처 싱글시그는 핫월렛 생성 경로로 저장할 수 없음', () async {
      expect(
        () => walletRepository.addHotWallet(
          createSinglesigWallet(source: WalletImportSource.keystone),
          secureStorageKey: 'local_wallet_seed_regtest_1',
          backupVerified: true,
          enterPassphraseWhenSigning: false,
          createdAt: DateTime.utc(2026, 7, 20),
        ),
        throwsArgumentError,
      );
      expect(realmManager.realm.all<RealmHotWalletMetadata>(), isEmpty);
      expect(realmManager.realm.all<RealmWalletBase>(), isEmpty);
    });

    test('같은 descriptor의 Watch-only와 핫월렛을 각각 저장할 수 있음', () async {
      await walletRepository.addSinglesigWallet(createSinglesigWallet(name: 'Watch-only'));
      await walletRepository.addHotWallet(
        createSinglesigWallet(),
        secureStorageKey: 'local_wallet_seed_regtest_1',
        backupVerified: true,
        enterPassphraseWhenSigning: false,
        createdAt: DateTime.utc(2026, 7, 20),
        lifecycleState: HotWalletLifecycleState.active,
      );

      final wallets = await walletRepository.getWalletItemList();
      expect(wallets, hasLength(2));
      expect(wallets.where((wallet) => wallet.hasLocalKey), hasLength(1));
      expect(wallets.where((wallet) => !wallet.hasLocalKey), hasLength(1));
    });

    test('Watch-only를 같은 ID의 핫월렛으로 승격하면 캐시와 지갑 정보가 유지됨', () async {
      final watchOnly = await walletRepository.addSinglesigWallet(
        createSinglesigWallet(name: 'Existing Watch-only', source: WalletImportSource.extendedPublicKey),
      );
      final walletBase = realmManager.realm.find<RealmWalletBase>(watchOnly.id)!;
      final createdAt = DateTime.utc(2026, 9, 9);
      realmManager.realm.write(() {
        walletBase.generatedReceiveIndex = 30;
        walletBase.usedReceiveIndex = 12;
        realmManager.realm.add(
          RealmWalletAddress(
            1001,
            watchOnly.id,
            'tb1qcachedaddress',
            12,
            false,
            'm/84\'/1\'/0\'/0/12',
            true,
            100,
            0,
            100,
          ),
        );
        realmManager.realm.add(RealmWalletBalance(1002, watchOnly.id, 100, 100, 0));
        realmManager.realm.add(
          RealmTransactionMock.getMock(id: 1003, walletId: watchOnly.id, transactionHash: 'preserved-tx'),
        );
        realmManager.realm.add(
          RealmUtxoMock.getMock(id: 'preserved-tx:0', walletId: watchOnly.id, transactionHash: 'preserved-tx'),
        );
        realmManager.realm.add(
          RealmUtxoTag('tag-1', watchOnly.id, 'Preserved tag', 2, createdAt, utxoIdList: const ['preserved-tx:0']),
        );
        realmManager.realm.add(
          RealmScriptStatus('${watchOnly.id}:script', '0014script', 'status', watchOnly.id, createdAt),
        );
      });

      final promoted = await walletRepository.promoteWatchOnlyWalletToHotWallet(
        watchOnly.id,
        expectedDescriptor: _singlesigDescriptor,
        secureStorageKey: 'hot_wallet_secret_promoted',
        backupVerified: true,
        enterPassphraseWhenSigning: false,
        createdAt: createdAt,
      );

      expect(promoted.id, watchOnly.id);
      expect(promoted.name, 'Existing Watch-only');
      expect(promoted.hasLocalKey, isTrue);
      expect(realmManager.realm.find<RealmWalletBase>(watchOnly.id)?.generatedReceiveIndex, 30);
      expect(realmManager.realm.find<RealmWalletBase>(watchOnly.id)?.usedReceiveIndex, 12);
      expect(realmManager.realm.query<RealmWalletAddress>('walletId == ${watchOnly.id}'), hasLength(1));
      expect(realmManager.realm.query<RealmWalletBalance>('walletId == ${watchOnly.id}'), hasLength(1));
      expect(realmManager.realm.query<RealmTransaction>('walletId == ${watchOnly.id}'), hasLength(1));
      expect(realmManager.realm.query<RealmUtxo>('walletId == ${watchOnly.id}'), hasLength(1));
      expect(realmManager.realm.query<RealmUtxoTag>('walletId == ${watchOnly.id}'), hasLength(1));
      expect(realmManager.realm.query<RealmScriptStatus>('walletId == ${watchOnly.id}'), hasLength(1));
      expect(realmManager.realm.find<RealmExternalWallet>(watchOnly.id), isNull);
      expect(
        realmManager.realm.find<RealmHotWalletMetadata>(watchOnly.id)?.lifecycleStateName,
        HotWalletLifecycleState.active.name,
      );
      expect((await walletRepository.getWalletItemList()).single.id, watchOnly.id);
    });

    test('Watch-only 승격 검증이 실패하면 기존 지갑을 변경하지 않음', () async {
      final watchOnly = await walletRepository.addSinglesigWallet(
        createSinglesigWallet(name: 'Existing Watch-only', source: WalletImportSource.extendedPublicKey),
      );
      final differentDescriptor = SingleSignatureVault.random().descriptor;

      await expectLater(
        walletRepository.promoteWatchOnlyWalletToHotWallet(
          watchOnly.id,
          expectedDescriptor: differentDescriptor,
          secureStorageKey: 'hot_wallet_secret_invalid',
          backupVerified: true,
          enterPassphraseWhenSigning: false,
          createdAt: DateTime.utc(2026, 9, 9),
        ),
        throwsA(isA<StateError>()),
      );

      expect(realmManager.realm.find<RealmWalletBase>(watchOnly.id), isNotNull);
      expect(realmManager.realm.find<RealmExternalWallet>(watchOnly.id), isNotNull);
      expect(realmManager.realm.find<RealmHotWalletMetadata>(watchOnly.id), isNull);
      expect((await walletRepository.getWalletItemList()).single.hasLocalKey, isFalse);
    });

    test('active가 아닌 핫월렛은 지갑 목록에 포함하지 않음', () async {
      final creating = await walletRepository.addHotWallet(
        createSinglesigWallet(name: 'Creating Wallet'),
        secureStorageKey: 'hot_wallet_secret_creating',
        backupVerified: false,
        enterPassphraseWhenSigning: false,
        createdAt: DateTime.utc(2026, 9, 9),
      );
      final deleting = await walletRepository.addHotWallet(
        createSinglesigWallet(name: 'Deleting Wallet'),
        secureStorageKey: 'hot_wallet_secret_deleting',
        backupVerified: true,
        enterPassphraseWhenSigning: false,
        createdAt: DateTime.utc(2026, 9, 9),
        lifecycleState: HotWalletLifecycleState.deleting,
      );
      final recoveryRequired = await walletRepository.addHotWallet(
        createSinglesigWallet(name: 'Recovery Wallet'),
        secureStorageKey: 'hot_wallet_secret_recovery',
        backupVerified: true,
        enterPassphraseWhenSigning: false,
        createdAt: DateTime.utc(2026, 9, 9),
        lifecycleState: HotWalletLifecycleState.recoveryRequired,
      );
      final active = await walletRepository.addHotWallet(
        createSinglesigWallet(name: 'Active Wallet'),
        secureStorageKey: 'hot_wallet_secret_active',
        backupVerified: true,
        enterPassphraseWhenSigning: false,
        createdAt: DateTime.utc(2026, 9, 9),
        lifecycleState: HotWalletLifecycleState.active,
      );

      final wallets = await walletRepository.getWalletItemList();

      expect(wallets.map((wallet) => wallet.id), [active.id]);
      expect(wallets.map((wallet) => wallet.id), isNot(contains(creating.id)));
      expect(wallets.map((wallet) => wallet.id), isNot(contains(deleting.id)));
      expect(wallets.map((wallet) => wallet.id), isNot(contains(recoveryRequired.id)));
    });

    test('lifecycle 상태를 active로 변경하면 지갑 목록에 포함됨', () async {
      final wallet = await walletRepository.addHotWallet(
        createSinglesigWallet(),
        secureStorageKey: 'hot_wallet_secret_pending',
        backupVerified: false,
        enterPassphraseWhenSigning: false,
        createdAt: DateTime.utc(2026, 9, 9),
      );
      expect(await walletRepository.getWalletItemList(), isEmpty);

      await walletRepository.updateHotWalletLifecycleState(wallet.id, HotWalletLifecycleState.active);

      expect((await walletRepository.getWalletItemList()).single.id, wallet.id);
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

    test('지갑 삭제 시 hot wallet metadata도 함께 삭제됨', () async {
      final walletBase = RealmWalletBase(1, 0, 0, _oneParentDescriptor, 'Taproot Wallet', WalletType.taproot.name);
      realmManager.realm.write(() {
        realmManager.realm.add(walletBase);
        realmManager.realm.add(createRealmTaprootWallet(1, walletBase));
        realmManager.realm.add(
          RealmHotWalletMetadata(
            1,
            'local_wallet_seed_regtest_1',
            '9B1441E4',
            "m/86'/1'/0'",
            0,
            true,
            false,
            DateTime.utc(2026, 7, 20),
            HotWalletLifecycleState.active.name,
          ),
        );
      });

      await walletRepository.deleteWallet(1);

      expect(realmManager.realm.all<RealmHotWalletMetadata>(), isEmpty);
    });
  });
}
