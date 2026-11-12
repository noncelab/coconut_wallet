import 'package:coconut_wallet/model/ark/ark_balance.dart';
import 'package:coconut_wallet/model/ark/ark_snapshot.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/ark.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:realm/realm.dart';

/// The cached Ark (bark) data of hot wallets, keyed by wallet id. See [RealmArkWalletState].
class ArkRepository extends BaseRepository {
  ArkRepository(super._realmManager);

  /// The last snapshot saved for [walletId], or null if its Ark wallet has never synced.
  ArkSnapshot? getSnapshot(int walletId) {
    final state = realm.find<RealmArkWalletState>(walletId);
    if (state == null) return null;
    return ArkSnapshot(
      balance: mapRealmToArkBalance(state),
      vtxos: realm.query<RealmArkVtxo>('walletId == $walletId').map(mapRealmToArkVtxo).toList(),
      movements: realm.query<RealmArkMovement>('walletId == $walletId').map(mapRealmToArkMovement).toList(),
      recovery: mapRealmToArkRecovery(state),
      syncedAt: state.lastSyncedAt?.toLocal(),
      address: state.address,
      addressIndex: state.addressIndex,
    );
  }

  ArkBalance? getBalance(int walletId) {
    final state = realm.find<RealmArkWalletState>(walletId);
    return state == null ? null : mapRealmToArkBalance(state);
  }

  /// Replaces the cached data of [walletId] with [snapshot]. Returns false, writing nothing, when
  /// the hot wallet no longer exists: a sync that finishes after a delete mustn't bring it back.
  Future<bool> saveSnapshot(int walletId, ArkSnapshot snapshot) {
    final oldVtxos = realm.query<RealmArkVtxo>('walletId == $walletId');
    final oldMovements = realm.query<RealmArkMovement>('walletId == $walletId');
    return realm.writeAsync(() {
      if (realm.find<RealmHotWalletMetadata>(walletId) == null) return false;
      realm.deleteMany(oldVtxos);
      realm.deleteMany(oldMovements);
      realm.add(mapArkSnapshotToRealmState(walletId, snapshot), update: true);
      realm.addAll(snapshot.vtxos.map((vtxo) => mapArkVtxoToRealm(walletId, vtxo)));
      realm.addAll(snapshot.movements.map((movement) => mapArkMovementToRealm(walletId, movement)));
      return true;
    });
  }

  Future<void> deleteCache(int walletId) => realm.writeAsync(() => deleteArkCacheInWrite(realm, walletId));
}

/// Deletes the cached Ark data of [walletId]; call it inside a write transaction.
void deleteArkCacheInWrite(Realm realm, int walletId) {
  final state = realm.find<RealmArkWalletState>(walletId);
  if (state != null) realm.delete(state);
  realm.deleteMany(realm.query<RealmArkVtxo>('walletId == $walletId'));
  realm.deleteMany(realm.query<RealmArkMovement>('walletId == $walletId'));
}
