import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart' as bitcoin;
import 'package:coconut_wallet/constants/realm_constants.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realm/realm.dart';

import '../../mock/realm/realm_transaction_mock.dart';
import '../../mock/transaction_mock.dart';
import '../../mock/utxo_mock.dart';
import '../../mock/wallet_mock.dart';

// Pause before acquiring the write lock; a second Realm can commit a reservation.
class _QueuedRealm extends Realm {
  _QueuedRealm(super.config);
  Completer<void>? queued;
  Completer<void>? release;
  bool failAfterWrite = false;

  @override
  Future<T> writeAsync<T>(T Function() callback, [CancellationToken? cancellationToken]) async {
    final pending = release;
    if (pending != null) {
      release = null;
      queued!.complete();
      await pending.future;
    }
    return super.writeAsync(() {
      final result = callback();
      if (failAfterWrite) {
        failAfterWrite = false;
        throw StateError('injected write rollback');
      }
      return result;
    }, cancellationToken);
  }
}

class _Manager extends Fake implements RealmManager {
  _Manager(this.realm);
  @override
  final Realm realm;
}

Future<void> _reserveInAnotherIsolate(String path, String hex) async {
  final realm = Realm(Configuration.local(realmAllSchemas, path: path, schemaVersion: kRealmVersion));
  try {
    await UtxoRepository(_Manager(realm)).markUnspentInputsAsOutgoing(1, bitcoin.Transaction.parse(hex));
  } finally {
    realm.close();
  }
}

Future<void> _runReservationInAnotherIsolate(String path, String hex) =>
    Isolate.run(() => _reserveInAnotherIsolate(path, hex));

void main() {
  final wallet = WalletMock.createSingleSigWalletItem();
  final payment = TransactionMock.createMockTransaction(toAddress: wallet.walletBase.getAddress(1), amount: 50000);
  final competing = TransactionMock.createMockTransaction(
    toAddress: wallet.walletBase.getAddress(1),
    amount: 49000,
    inputTransactionHash: payment.inputs.single.transactionHash,
  );
  final fundingHash = payment.inputs.single.transactionHash;
  final outpoint = getUtxoId(fundingHash, 0);
  late Directory directory;
  late _QueuedRealm syncRealm;
  late Realm mainRealm;
  late UtxoRepository syncUtxos;
  late UtxoRepository mainUtxos;
  late TransactionRepository transactions;
  late UtxoState unspent;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('utxo_write_order_');
    final config = Configuration.local(
      realmAllSchemas,
      path: '${directory.path}/wallet.realm',
      schemaVersion: kRealmVersion,
    );
    syncRealm = _QueuedRealm(config);
    mainRealm = Realm(config);
    syncUtxos = UtxoRepository(_Manager(syncRealm));
    mainUtxos = UtxoRepository(_Manager(mainRealm));
    transactions = TransactionRepository(_Manager(syncRealm));
    mainRealm.write(() {
      mainRealm.add(
        UtxoMock.createUnspentRealmUtxo(
          walletId: 1,
          address: wallet.walletBase.getAddress(0),
          transactionHash: fundingHash,
        ),
      );
      mainRealm.add(RealmUtxoTag('tag', 1, 'keep', 0, DateTime.now(), utxoIdList: [outpoint]));
      mainRealm.add(RealmPendingUtxoLock('1:$outpoint', 1, outpoint));
      mainRealm.add(RealmTransactionMock.getMock(transactionHash: fundingHash));
      mainRealm.add(RealmCpfpHistory(1, 1, 'replaced-parent', fundingHash, 1, 2, DateTime.now()));
    });
    unspent = mainUtxos.getUtxoState(1, outpoint)!;
  });

  tearDown(() async {
    syncRealm.close();
    mainRealm.close();
    await directory.delete(recursive: true);
  });

  test('v10 reopening retains coins, reservations, locks, tags and drafts without migration', () {
    final path = '${directory.path}/v10.realm';
    expect(kRealmVersion, 10);
    final old = Realm(Configuration.local(realmAllSchemas, path: path, schemaVersion: 10));
    old.write(() {
      for (final status in [UtxoStatus.unspent, UtxoStatus.outgoing, UtxoStatus.locked]) {
        old.add(
          UtxoMock.createMockUtxo(
            walletId: 1,
            address: wallet.walletBase.getAddress(0),
            transactionHash: fundingHash,
            index: status.index,
            status: status,
            spentByTransactionHash: status == UtxoStatus.outgoing ? payment.transactionHash : null,
          ),
        );
      }
      old.add(RealmUtxoTag('tag', 1, 'keep', 0, DateTime.now(), utxoIdList: [outpoint]));
      old.add(
        RealmTransactionDraft(1, 1, DateTime.now(), 1, false, selectedUtxoIds: [outpoint], txWaitingForSign: 'draft'),
      );
    });
    old.close();
    var migratedFrom = -1;
    final upgraded = Realm(
      Configuration.local(
        realmAllSchemas,
        path: path,
        schemaVersion: kRealmVersion,
        migrationCallback: (migration, oldVersion) {
          migratedFrom = oldVersion;
        },
      ),
    );
    try {
      expect(migratedFrom, -1);
      final rows = upgraded.all<RealmUtxo>();
      expect(rows.map((u) => u.status), unorderedEquals(['unspent', 'outgoing', 'locked']));
      expect(RealmUtxo.schema.any((p) => p.name == 'stateVersion'), isFalse);
      expect(rows.singleWhere((u) => u.status == 'outgoing').spentByTransactionHash, payment.transactionHash);
      expect(upgraded.all<RealmUtxoTag>().single.utxoIdList, [outpoint]);
      expect(upgraded.all<RealmTransactionDraft>().single.txWaitingForSign, 'draft');
    } finally {
      upgraded.close();
    }
  });

  test('an ordinary refresh does not allocate a counter, retries share one and confirmed spend clears it', () async {
    await mainUtxos.addAllUtxos(1, [unspent]);
    expect(mainRealm.all<RealmIntegerId>(), isEmpty);
    await mainUtxos.markUnspentInputsAsOutgoing(1, payment);
    final first = mainUtxos.snapshotUtxoVersions(1)['1:$outpoint']!;
    await mainUtxos.markUnspentInputsAsOutgoing(1, payment);
    expect(mainUtxos.snapshotUtxoVersions(1)['1:$outpoint'], greaterThan(first));
    expect(mainRealm.all<RealmIntegerId>(), hasLength(1));
    await mainUtxos.deleteUtxosByTransaction(1, payment);
    expect(mainRealm.all<RealmIntegerId>(), isEmpty);
    expect(mainRealm.find<RealmUtxo>('1:$outpoint')!.isDeleted, isTrue);
    expect(mainUtxos.snapshotUtxoVersions(1), isEmpty);
    expect(mainUtxos.snapshotUtxoVersions(1, address: unspent.to), isEmpty);
  });

  test('an address refresh removes legacy outpoints only for that wallet', () async {
    final id = getUtxoId(fundingHash, 7);
    mainRealm.write(() {
      for (final index in [7, 8]) {
        mainRealm.add(
          UtxoMock.createMockUtxo(
            id: getUtxoId(fundingHash, index),
            walletId: index == 7 ? 1 : 10,
            address: unspent.to,
            transactionHash: fundingHash,
            index: index,
          ),
        );
      }
    });
    final versions = mainUtxos.snapshotUtxoVersions(1, address: unspent.to);
    await mainUtxos.addAllUtxos(1, [unspent], expectedVersions: versions);
    expect(mainRealm.find<RealmUtxo>(id), isNull);
    expect(mainRealm.find<RealmUtxo>(getUtxoId(fundingHash, 8))!.walletId, 10);
    expect(mainRealm.find<RealmUtxo>('1:$outpoint'), isNotNull);
  });

  test('a persisted reservation in another isolate rejects an earlier snapshot', () async {
    final snapshots = syncUtxos.snapshotUtxoVersions(1);
    final path = mainRealm.config.path;
    final hex = payment.serialize();
    await _runReservationInAnotherIsolate(path, hex);
    expect((await syncUtxos.addAllUtxos(1, [unspent], expectedVersions: snapshots)).isSuccess, isTrue);
    expect(mainUtxos.getUtxoState(1, outpoint)!.status, UtxoStatus.outgoing);
    expect(mainUtxos.snapshotUtxoVersions(1)['1:$outpoint'], isNot(snapshots['1:$outpoint']));
    final reopened = Realm(Configuration.local(realmAllSchemas, path: path, schemaVersion: kRealmVersion));
    try {
      expect(reopened.find<RealmUtxo>('1:$outpoint')!.spentByTransactionHash, payment.transactionHash);
      expect(reopened.find<RealmUtxo>('1:$outpoint')!.status, mainRealm.find<RealmUtxo>('1:$outpoint')!.status);
    } finally {
      reopened.close();
    }
  });

  test('observing the same outgoing transaction invalidates an older unspent response', () async {
    await mainUtxos.markUnspentInputsAsOutgoing(1, payment);
    final versions = syncUtxos.snapshotUtxoVersions(1);
    await syncUtxos.markUtxoAsOutgoing(1, payment);
    expect((await syncUtxos.addAllUtxos(1, [unspent], expectedVersions: versions)).isSuccess, isTrue);
    expect(mainUtxos.getUtxoState(1, outpoint)!.status, UtxoStatus.outgoing);
    expect(mainUtxos.getUtxoState(1, outpoint)!.spentByTransactionHash, payment.transactionHash);
  });

  Future<void> writePath(String path) async {
    switch (path) {
      case 'listunspent':
        await syncUtxos.addAllUtxos(1, [unspent]);
      case 'unconfirmed transaction':
        await syncUtxos.markUtxoAsOutgoing(1, competing);
      case 'local finalize':
        await syncUtxos.markUnspentInputsAsOutgoing(1, competing);
      case 'cleanup':
        await syncUtxos.deleteUtxoList(1, [outpoint]);
      case 'RBF outputs':
        await syncUtxos.deleteUtxosByReplacedTransactionHashSet(1, {fundingHash});
      case 'CPFP outputs':
        final versions = syncUtxos.snapshotUtxoVersions(1);
        await transactions.deleteOrphanedCpfpTransaction(1, {'replaced-parent'}, expectedVersions: versions);
      case 'confirmed consumption':
        await syncUtxos.deleteUtxosByTransaction(1, competing);
      case 'toggle lock':
        await syncUtxos.toggleUtxoLockStatus(1, outpoint);
      case 'import locks':
        await syncUtxos.lockAllUtxos(1, [outpoint]);
      case 'lock selection':
        await syncUtxos.updateUtxoStatus(1, [outpoint], UtxoStatus.locked);
      case 'unlock selection':
        await syncUtxos.updateUtxoStatus(1, [outpoint], UtxoStatus.unspent);
      case 'restore locks':
        await syncUtxos.restoreLockedUtxos(1, {outpoint});
      case 'restore pending locks':
        await syncUtxos.restorePendingUtxoLocks(1);
    }
  }

  test('an old consumption reports its conflict and preserves the newer spender', () async {
    await mainUtxos.markUnspentInputsAsOutgoing(1, payment);
    final earlier = syncUtxos.snapshotUtxoVersions(1);
    await mainUtxos.markUtxoAsOutgoing(1, competing);
    final replacement = TransactionMock.createMockTransaction(
      toAddress: wallet.walletBase.getAddress(1),
      amount: 48000,
      inputTransactionHash: fundingHash,
    );
    expect(await syncUtxos.markUtxoAsOutgoing(1, replacement, expectedVersions: earlier), isFalse);
    expect(mainUtxos.getUtxoState(1, outpoint)?.spentByTransactionHash, competing.transactionHash);
  });

  test('a history entry with no known wallet inputs does not open a write transaction', () async {
    final foreign = TransactionMock.createMockTransaction(toAddress: wallet.walletBase.getAddress(1), amount: 12345);
    syncRealm.failAfterWrite = true;
    await syncUtxos.markUtxoAsOutgoing(1, foreign);
    await syncUtxos.deleteUtxosByTransaction(1, foreign);
    expect(syncRealm.failAfterWrite, isTrue);
  });

  for (final unlockAgain in [false, true]) {
    test('observed consumption survives a concurrent user lock change unlock=$unlockAgain', () async {
      final release = Completer<void>();
      syncRealm.queued = Completer<void>();
      syncRealm.release = release;
      final updating = syncUtxos.markUtxoAsOutgoing(1, payment);
      await syncRealm.queued!.future;
      await mainUtxos.updateUtxoStatus(1, [outpoint], UtxoStatus.locked);
      if (unlockAgain) await mainUtxos.updateUtxoStatus(1, [outpoint], UtxoStatus.unspent);
      release.complete();
      await updating;
      final row = mainUtxos.getUtxoState(1, outpoint)!;
      expect(row.status, UtxoStatus.outgoing);
      expect(row.spentByTransactionHash, payment.transactionHash);
      expect(mainUtxos.getValidatedSelectedUtxoList(1, [outpoint]).$1, isEmpty);
    });
  }

  test('CPFP cleanup rolls back with its records and preserves user metadata on removal', () async {
    syncRealm.failAfterWrite = true;
    await expectLater(writePath('CPFP outputs'), throwsStateError);
    expect(mainUtxos.getUtxoState(1, outpoint)!.status, UtxoStatus.unspent);
    expect(mainRealm.all<RealmCpfpHistory>(), hasLength(1));
    expect(mainRealm.all<RealmTransaction>(), hasLength(1));
    expect(mainRealm.all<RealmUtxoTag>().single.utxoIdList, [outpoint]);
    await writePath('CPFP outputs');
    expect(mainUtxos.getUtxoState(1, outpoint), isNull);
    expect(mainRealm.all<RealmCpfpHistory>(), isEmpty);
    expect(mainRealm.all<RealmTransaction>(), isEmpty);
    expect(mainRealm.all<RealmUtxoTag>().single.utxoIdList, [outpoint]);
    expect(mainRealm.find<RealmPendingUtxoLock>('1:$outpoint'), isNotNull);
    expect(mainRealm.find<RealmUtxo>('1:$outpoint'), isNull);
  });

  for (final initiallyMissing in [false, true]) {
    test('only a new list can rediscover an orphaned CPFP output, initiallyMissing=$initiallyMissing', () async {
      if (initiallyMissing) {
        mainRealm.write(() => mainRealm.delete(mainRealm.find<RealmUtxo>('1:$outpoint')!));
      }
      final stale = syncUtxos.snapshotUtxoVersions(1, address: unspent.to);
      if (initiallyMissing) await mainUtxos.addAllUtxos(1, [unspent]);
      await writePath('CPFP outputs');
      await syncUtxos.addAllUtxos(1, [unspent], expectedVersions: stale);
      expect(mainUtxos.getUtxoState(1, outpoint), isNull);
      final fresh = syncUtxos.snapshotUtxoVersions(1, address: unspent.to);
      final beforeReappearance = Map.of(fresh);
      await syncUtxos.addAllUtxos(1, [unspent], expectedVersions: fresh);
      expect(mainUtxos.getUtxoState(1, outpoint)?.status, UtxoStatus.unspent);
      await mainUtxos.restorePendingUtxoLocks(1);
      expect(mainUtxos.getUtxoState(1, outpoint)?.status, UtxoStatus.locked);
      expect(mainRealm.all<RealmUtxoTag>().single.utxoIdList, [outpoint]);
      await mainUtxos.markUnspentInputsAsOutgoing(1, payment);
      await syncUtxos.addAllUtxos(1, [unspent], expectedVersions: beforeReappearance);
      expect(mainUtxos.getUtxoState(1, outpoint)?.spentByTransactionHash, payment.transactionHash);
    });
  }

  test('a confirmed spend while a CPFP output is missing also prevents a fresh list from recreating it', () async {
    await writePath('CPFP outputs');
    final stale = syncUtxos.snapshotUtxoVersions(1, address: unspent.to);
    await mainUtxos.deleteUtxosByTransaction(1, payment);
    for (final versions in [stale, syncUtxos.snapshotUtxoVersions(1, address: unspent.to)]) {
      await syncUtxos.addAllUtxos(1, [unspent], expectedVersions: versions);
      expect(mainUtxos.getUtxoState(1, outpoint), isNull);
    }
    expect(mainRealm.all<RealmUtxoTag>().single.utxoIdList, isEmpty);
    expect(mainRealm.find<RealmPendingUtxoLock>('1:$outpoint'), isNull);
  });

  test('a user lock that wins the write lock cannot prevent a dispatched payment reservation', () async {
    mainRealm.write(() => mainRealm.delete(mainRealm.find<RealmPendingUtxoLock>('1:$outpoint')!));
    final release = Completer<void>();
    syncRealm.queued = Completer<void>();
    syncRealm.release = release;
    final reserving = syncUtxos.markUnspentInputsAsOutgoing(1, payment);
    await syncRealm.queued!.future;
    await mainUtxos.lockAllUtxos(1, [outpoint]);
    release.complete();
    await reserving;
    await mainUtxos.toggleUtxoLockStatus(1, outpoint);
    expect(mainUtxos.getUtxoState(1, outpoint)!.status, UtxoStatus.outgoing);
    expect(mainUtxos.getUtxoState(1, outpoint)!.spentByTransactionHash, payment.transactionHash);
    expect(mainUtxos.getValidatedSelectedUtxoList(1, [outpoint]).$1, isEmpty);
    expect(mainRealm.find<RealmPendingUtxoLock>('1:$outpoint'), isNotNull);
    await syncUtxos.addAllUtxos(1, [unspent]);
    await syncUtxos.restorePendingUtxoLocks(1);
    expect(mainUtxos.getUtxoState(1, outpoint)!.status, UtxoStatus.locked);
    expect(mainRealm.find<RealmPendingUtxoLock>('1:$outpoint'), isNull);
  });

  test('incoming input reservation policy remains unchanged pending a product decision', () async {
    final incoming = UtxoState(
      transactionHash: fundingHash,
      index: 0,
      amount: unspent.amount,
      derivationPath: unspent.derivationPath,
      blockHeight: 0,
      to: unspent.to,
      timestamp: unspent.timestamp,
      status: UtxoStatus.incoming,
    );
    await mainUtxos.addAllUtxos(1, [incoming]);
    await mainUtxos.markUnspentInputsAsOutgoing(1, payment);
    expect(mainUtxos.getUtxoState(1, outpoint)!.status, UtxoStatus.incoming);
  });

  for (final path in [
    'listunspent',
    'unconfirmed transaction',
    'local finalize',
    'cleanup',
    'RBF outputs',
    'CPFP outputs',
    'confirmed consumption',
    'toggle lock',
    'import locks',
    'lock selection',
    'unlock selection',
    'restore locks',
    'restore pending locks',
  ]) {
    for (final startsAfterReservation in [false, true]) {
      test('$path starts ${startsAfterReservation ? 'after' : 'before'} reservation', () async {
        if (startsAfterReservation) {
          await mainUtxos.markUnspentInputsAsOutgoing(1, payment);
        }
        syncRealm.refresh();
        final release = Completer<void>();
        syncRealm.queued = Completer<void>();
        syncRealm.release = release;
        final writing = writePath(path);
        // Some no-op paths need no transaction once they see the reservation.
        final didQueue = await Future.any([syncRealm.queued!.future.then((_) => true), writing.then((_) => false)]);
        if (!startsAfterReservation) {
          expect(didQueue, isTrue);
          await mainUtxos.markUnspentInputsAsOutgoing(1, payment);
        }
        release.complete();
        await writing;

        final row = mainUtxos.getUtxoState(1, outpoint, includeDeleted: true);
        final stored = mainRealm.find<RealmUtxo>('1:$outpoint');
        if (path == 'confirmed consumption' ||
            (startsAfterReservation && ['cleanup', 'RBF outputs', 'CPFP outputs'].contains(path))) {
          expect(stored == null || stored.isDeleted, isTrue);
          expect(mainUtxos.getValidatedSelectedUtxoList(1, [outpoint]).$1, isEmpty);
          expect(mainRealm.find<RealmPendingUtxoLock>('1:$outpoint'), path == 'CPFP outputs' ? isNotNull : isNull);
        } else if (startsAfterReservation && path == 'listunspent') {
          expect(row!.status, UtxoStatus.unspent);
          expect(row.spentByTransactionHash, isNull);
          expect(mainUtxos.getValidatedSelectedUtxoList(1, [outpoint]).$1, hasLength(1));
        } else {
          expect(row, isNotNull);
          expect(stored!.isDeleted, isFalse);
          expect(row!.status, UtxoStatus.outgoing);
          expect(
            row.spentByTransactionHash,
            startsAfterReservation && path == 'unconfirmed transaction'
                ? competing.transactionHash
                : payment.transactionHash,
          );
          expect(mainUtxos.getValidatedSelectedUtxoList(1, [outpoint]).$1, isEmpty);
          expect(mainUtxos.getUtxoTagsByTxHash(1, outpoint).value.single.name, 'keep');
        }
      });
    }
  }
}
