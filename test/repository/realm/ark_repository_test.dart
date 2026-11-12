import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/model/ark/ark_snapshot.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/repository/realm/ark_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mock/ark/ark_fixtures.dart';
import 'test_realm_manager.dart';

void main() {
  late TestRealmManager realmManager;
  late ArkRepository arkRepository;

  void addHotWallet(int walletId) {
    realmManager.realm.write(() {
      realmManager.realm.add(
        RealmWalletBase(walletId, 0, 0, 'descriptor_$walletId', 'Hot $walletId', WalletType.singleSignature.name),
      );
      realmManager.realm.add(
        RealmHotWalletMetadata(
          walletId,
          'hot_wallet_secret_$walletId',
          'D45AA182',
          "m/84'/1'/0'",
          0,
          true,
          false,
          DateTime.utc(2026, 10, 19),
          HotWalletLifecycleState.active.name,
        ),
      );
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // ignore: deprecated_member_use_from_same_package
    SharedPrefsRepository().setSharedPreferencesForTest(await SharedPreferences.getInstance());
    realmManager = await setupTestRealmManager();
    arkRepository = ArkRepository(realmManager);
  });

  tearDown(() {
    realmManager.reset();
    realmManager.dispose();
  });

  test('a saved snapshot reads back the same', () async {
    addHotWallet(1);
    final txid = 'b' * 64;
    final snapshot = createArkSnapshot(
      movements: [
        createArkMovement(
          id: 7,
          subsystemName: 'bark.board',
          subsystemKind: 'board',
          metadataJson: '{"chain_anchor":"$txid:0"}',
          receivedOn: ['{"type":"ark","value":"$arkAddress"}'],
          paymentHash: 'hash',
        ),
      ],
      recovery: const ArkRecovery(ArkRecoveryState.completed, 'Completed: 1 VTXOs recovered'),
      addressIndex: 3,
    );

    expect(await arkRepository.saveSnapshot(1, snapshot), isTrue);
    final cached = arkRepository.getSnapshot(1)!;

    expect(cached.hasSameContent(snapshot), isTrue);
    expect(cached.syncedAt!.isAtSameMomentAs(snapshot.syncedAt!), isTrue);
    expect(cached.movements.single.kind, ArkMovementKind.board);
    expect(cached.movements.single.linkedTxid, txid);
    expect(cached.movements.single.receivedOnDestinations.single.value, arkAddress);
    expect(cached.movements.single.createdAt.isAtSameMomentAs(snapshot.movements.single.createdAt), isTrue);
    expect(cached.recovery.state, ArkRecoveryState.completed);
    expect(arkRepository.getBalance(1)!.total, 50000);
  });

  test('saving replaces the previous VTXOs and movements', () async {
    addHotWallet(1);
    await arkRepository.saveSnapshot(1, createArkSnapshot(vtxos: [createArkVtxo(id: 'old:0')]));
    await arkRepository.saveSnapshot(
      1,
      createArkSnapshot(vtxos: [createArkVtxo(id: 'new:0'), createArkVtxo(id: 'new:1')], movements: []),
    );

    final cached = arkRepository.getSnapshot(1)!;
    expect(cached.vtxos.map((vtxo) => vtxo.id), unorderedEquals(['new:0', 'new:1']));
    expect(cached.movements, isEmpty);
  });

  test('snapshots of other wallets are kept apart', () async {
    addHotWallet(1);
    addHotWallet(2);
    await arkRepository.saveSnapshot(1, createArkSnapshot(vtxos: [createArkVtxo(id: 'one:0')]));
    await arkRepository.saveSnapshot(2, createArkSnapshot(vtxos: [createArkVtxo(id: 'two:0')], movements: []));

    expect(arkRepository.getSnapshot(1)!.vtxos.single.id, 'one:0');
    expect(arkRepository.getSnapshot(1)!.movements, hasLength(1));
    expect(arkRepository.getSnapshot(2)!.vtxos.single.id, 'two:0');
  });

  test('nothing is saved for a hot wallet that no longer exists', () async {
    expect(await arkRepository.saveSnapshot(1, createArkSnapshot()), isFalse);
    expect(arkRepository.getSnapshot(1), isNull);
    expect(realmManager.realm.all<RealmArkVtxo>(), isEmpty);
  });

  test('deleting the wallet deletes its Ark cache', () async {
    addHotWallet(1);
    addHotWallet(2);
    await arkRepository.saveSnapshot(1, createArkSnapshot());
    await arkRepository.saveSnapshot(2, createArkSnapshot(vtxos: [createArkVtxo(id: 'two:0')]));

    await WalletRepository(realmManager, TransactionDraftRepository(realmManager)).deleteWallet(1);

    expect(arkRepository.getSnapshot(1), isNull);
    expect(realmManager.realm.query<RealmArkVtxo>('walletId == 1'), isEmpty);
    expect(realmManager.realm.query<RealmArkMovement>('walletId == 1'), isEmpty);
    expect(arkRepository.getSnapshot(2), isNotNull);
  });
}
