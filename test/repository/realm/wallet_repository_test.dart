import 'dart:convert';

import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mock/utxo_mock.dart';
import 'test_realm_manager.dart';

const _parentTaprootXpub =
    "tpubDDMbU29QrSafD2Ui4yGv31Xp3PPSMvudreoohYjR8xLTng7hbsjYwUTeRhiKULFqX16M5M8zZh9siw5i6RRyisc6LtWjr1FwBYTiZUGGYJN";
const _childTaprootXpub =
    "tpubDCp2emt17Ng6ujD8BC6ScL4vfwhN3nAJQ8kCqLjRQHxcFhWt6YK5Ws6UcKD6HgLCZuwU8DryKo7h2gpieLa7Q9YF1AqfL9XiF7349nHaLi8";
const _inheritanceMiniscript = "and_v(v:pk([70C4E9DE/86'/1'/0']$_childTaprootXpub/<0;1>/*),after(500000000))";
const _oneParentDescriptor = "tr([9B1441E4/86'/1'/0']$_parentTaprootXpub/<0;1>/*,{$_inheritanceMiniscript})#652j50l8";

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

    test('deleteWallet: RealmUtxoTag도 함께 삭제', () async {
      final walletBase = RealmWalletBase(
        1,
        0,
        0,
        'encrypted_descriptor',
        'Test Wallet',
        WalletType.singleSignature.name,
      );

      realmManager.realm.write(() {
        realmManager.realm.add(walletBase);
        realmManager.realm.add(
          RealmUtxoTag('tag-id-1', 1, '삭제 대상 태그', 0, DateTime.utc(2026, 8, 28))..utxoIdList.add('utxo-id-1'),
        );
        realmManager.realm.add(
          RealmUtxoTag('tag-id-2', 2, '다른 지갑 태그', 0, DateTime.utc(2026, 8, 28))..utxoIdList.add('utxo-id-2'),
        );
      });

      await walletRepository.deleteWallet(1);

      expect(realmManager.realm.query<RealmUtxoTag>('walletId == 1').length, 0);
      expect(realmManager.realm.query<RealmUtxoTag>('walletId == 2').length, 1);
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
  });

  group('WalletRepository - 재동기화', () {
    void seedWalletData(int walletId, {int usedReceiveIndex = 5, int usedChangeIndex = 3}) {
      realmManager.realm.write(() {
        realmManager.realm.add(
          RealmWalletBase(
            walletId,
            0,
            0,
            'encrypted_descriptor_$walletId',
            'Test Wallet $walletId',
            WalletType.singleSignature.name,
            usedReceiveIndex: usedReceiveIndex,
            usedChangeIndex: usedChangeIndex,
            generatedReceiveIndex: usedReceiveIndex + 10,
            generatedChangeIndex: usedChangeIndex + 10,
          ),
        );
        realmManager.realm.add(
          RealmTransaction(
            walletId * 1000 + 1,
            'tx_hash_$walletId',
            walletId,
            DateTime.now(),
            100,
            'received',
            10000,
            500,
            140.5,
            DateTime.now(),
          ),
        );
        realmManager.realm.add(RealmWalletBalance(walletId, walletId, 10000, 10000, 0));
        realmManager.realm.add(
          RealmWalletAddress(walletId * 1000 + 1, walletId, 'address_$walletId', 0, false, "m/0/0", true, 10000, 0, 10000),
        );
        realmManager.realm.add(
          UtxoMock.createMockUtxo(
            walletId: walletId,
            address: 'address_$walletId',
            transactionHash: 'utxo_tx_hash_$walletId',
          ),
        );
        realmManager.realm.add(RealmScriptStatus('script_pub_key_$walletId', 'status_$walletId', walletId, DateTime.now()));
        realmManager.realm.add(
          RealmUtxoTag('tag_id_$walletId', walletId, 'tag_name_$walletId', 0, DateTime.now(), utxoIdList: [
            getUtxoId('utxo_tx_hash_$walletId', 0),
          ]),
        );
        realmManager.realm.add(
          RealmTransactionMemo(
            getTransactionMemoId('tx_hash_$walletId', walletId),
            'tx_hash_$walletId',
            walletId,
            'memo_$walletId',
            DateTime.now(),
          ),
        );
      });
    }

    test('트랜잭션/잔액/주소/UTXO/스크립트상태 삭제, 지갑 row는 유지하고 인덱스만 리셋', () async {
      seedWalletData(1);

      await walletRepository.resetWalletForResync(1);

      expect(realmManager.realm.query<RealmTransaction>('walletId == 1').isEmpty, isTrue);
      expect(realmManager.realm.query<RealmWalletBalance>('walletId == 1').isEmpty, isTrue);
      expect(realmManager.realm.query<RealmWalletAddress>('walletId == 1').isEmpty, isTrue);
      expect(realmManager.realm.query<RealmUtxo>('walletId == 1').isEmpty, isTrue);
      expect(realmManager.realm.query<RealmScriptStatus>('walletId == 1').isEmpty, isTrue);

      final walletBase = realmManager.realm.find<RealmWalletBase>(1);
      expect(walletBase, isNotNull);
      expect(walletBase!.usedReceiveIndex, -1);
      expect(walletBase.usedChangeIndex, -1);
      expect(walletBase.generatedReceiveIndex, -1);
      expect(walletBase.generatedChangeIndex, -1);
    });

    test('UTXO 태그와 트랜잭션 메모는 건드리지 않음', () async {
      seedWalletData(1);

      await walletRepository.resetWalletForResync(1);

      expect(realmManager.realm.query<RealmUtxoTag>('walletId == 1').length, 1);
      expect(realmManager.realm.query<RealmTransactionMemo>('walletId == 1').length, 1);
    });

    test('다른 지갑의 데이터는 영향받지 않음', () async {
      seedWalletData(1);
      seedWalletData(2, usedReceiveIndex: 7, usedChangeIndex: 4);

      await walletRepository.resetWalletForResync(1);

      expect(realmManager.realm.query<RealmTransaction>('walletId == 2').length, 1);
      expect(realmManager.realm.query<RealmWalletBalance>('walletId == 2').length, 1);
      expect(realmManager.realm.query<RealmWalletAddress>('walletId == 2').length, 1);
      expect(realmManager.realm.query<RealmUtxo>('walletId == 2').length, 1);
      expect(realmManager.realm.query<RealmScriptStatus>('walletId == 2').length, 1);

      final wallet2Base = realmManager.realm.find<RealmWalletBase>(2);
      expect(wallet2Base!.usedReceiveIndex, 7);
      expect(wallet2Base.usedChangeIndex, 4);
    });
  });
}
