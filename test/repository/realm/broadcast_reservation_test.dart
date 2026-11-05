import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/utxo_mock.dart';
import '../../mock/wallet_mock.dart';
import 'test_realm_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final hash = 'aa' * 32;
  final spender = 'bb' * 32;
  final replacement = 'cc' * 32;
  late TestRealmManager manager;
  late UtxoRepository ui;
  late UtxoRepository sync;
  late Duration now;
  late Duration start;

  Transaction spend(List<int> indexes) => Transaction.withInputsAndOutputs(
    [for (final index in indexes) TransactionInput.forPayment(hash, index)],
    [TransactionOutput.forPayment(1000, WalletMock.createSingleSigWalletItem().walletBase.getAddress(5))],
    AddressType.p2wpkh,
  );
  String id(int index) => getUtxoId(hash, index);
  RealmUtxo row(int index, [int walletId = 1]) => manager.realm.find<RealmUtxo>(getRealmUtxoId(walletId, hash, index))!;
  UtxoState? coin(int index, [int walletId = 1]) => ui.getUtxoState(walletId, id(index));

  setUp(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    manager = TestRealmManager();
    start = now = Duration.zero;
    ui = UtxoRepository(manager, clock: () => now);
    sync = UtxoRepository(manager);
    manager.realm.write(() {
      for (var i = 0; i < 6; i++) {
        final r = UtxoMock.createMockUtxo(
          walletId: 1,
          address: 'owned',
          transactionHash: hash,
          index: i,
          amount: 10000,
          status:
              [
                UtxoStatus.unspent,
                UtxoStatus.incoming,
                UtxoStatus.outgoing,
                UtxoStatus.locked,
                UtxoStatus.unspent,
                UtxoStatus.unspent,
              ][i],
          spentByTransactionHash: i == 2 ? 'old-spender' : null,
        );
        r.isDeleted = i == 4;
        manager.realm.add(r);
      }
      manager.realm.add(
        UtxoMock.createUnspentRealmUtxo(walletId: 2, address: 'owned', transactionHash: hash, index: 0),
      );
    });
  });
  tearDown(() => manager.dispose());

  test('all reads share the projection, including twin, status queries and draft validation', () {
    final cached = coin(0)!;
    ui.reserveBroadcastInputs(spend([0, 1, 2, 3, 4, 99]), spender);
    expect(cached.status, UtxoStatus.unspent, reason: 'already-open snapshots are unchanged');
    expect(ui.getUtxoStateList(1).map((u) => u.status), [
      UtxoStatus.outgoing,
      UtxoStatus.outgoing,
      UtxoStatus.outgoing,
      UtxoStatus.locked,
      UtxoStatus.unspent,
    ]);
    expect(ui.getUtxosByStatus(1, UtxoStatus.unspent).map((u) => u.index), [5]);
    expect(ui.getUtxosByStatus(1, UtxoStatus.incoming), isEmpty);
    expect(ui.getUtxosByStatus(1, UtxoStatus.outgoing).map((u) => u.index), [0, 1, 2]);
    expect(ui.getUtxosByStatus(1, UtxoStatus.locked).map((u) => u.index), [3]);
    expect(ui.getUtxoStateList(1).map((u) => u.amount), everyElement(10000));
    expect(coin(0)!.amount, cached.amount);
    expect(coin(0)!.spentByTransactionHash, spender);
    expect(coin(1)!.spentByTransactionHash, spender);
    expect(coin(2)!.spentByTransactionHash, 'old-spender');
    expect(coin(3)!.status, UtxoStatus.locked);
    expect(coin(4), isNull);
    expect(coin(99), isNull);
    expect(ui.getUtxoState(1, id(4), includeDeleted: true)!.status, UtxoStatus.unspent);
    expect(coin(0, 2)!.status, UtxoStatus.outgoing);
    expect(ui.getValidatedSelectedUtxoList(1, [id(0), id(1), id(5)]).$1.map((u) => u.index), [5]);
    expect(ui.getValidatedSelectedUtxoList(1, [id(0)]).$2, SelectedUtxoExcludedStatus.used);
    expect(row(0).status, 'unspent');
    expect(row(0).spentByTransactionHash, isNull);
    expect(row(1).status, 'incoming');
    expect(row(0, 2).status, 'unspent');
    expect(sync.getUtxosByStatus(1, UtxoStatus.unspent).map((u) => u.index), [0, 5]);
  });

  test('mark-first outgoing never clears reservation, so late listunspent cannot undo it', () async {
    ui.reserveBroadcastInputs(spend([0]), spender);
    await sync.reserveSpentInputs(1, spend([0]));
    final recordedSpender = row(0).spentByTransactionHash;
    expect(coin(0)!.spentByTransactionHash, recordedSpender);
    manager.realm.write(() => row(0).status = 'unspent');
    expect(coin(0)!.status, UtxoStatus.outgoing);
    expect(coin(0)!.spentByTransactionHash, spender);
    expect(sync.getUtxoState(1, id(0))!.status, UtxoStatus.unspent);
  });

  test('expiry is exactly thirty minutes and a restart has no reservation', () {
    ui.reserveBroadcastInputs(spend([0]), spender);
    expect(UtxoRepository(manager).getUtxoState(1, id(0))!.status, UtxoStatus.unspent);
    now = start + const Duration(minutes: 30) - const Duration(microseconds: 1);
    expect(coin(0)!.status, UtxoStatus.outgoing);
    now = start + const Duration(minutes: 30);
    expect(coin(0)!.status, UtxoStatus.unspent);
    now = start;
    expect(coin(0)!.status, UtxoStatus.unspent, reason: 'expiry was pruned, not only hidden');
  });

  test('adds prune expired entries and replacements refresh only their own input entries', () {
    ui.reserveBroadcastInputs(spend([0, 1]), spender);
    now = start + const Duration(minutes: 10);
    ui.reserveBroadcastInputs(spend([0, 5]), replacement);
    expect(coin(0)!.spentByTransactionHash, replacement);
    expect(coin(1)!.spentByTransactionHash, spender);
    now = start + const Duration(minutes: 30);
    ui.reserveBroadcastInputs(spend([5]), replacement);
    now = start;
    expect(coin(1)!.status, UtxoStatus.incoming, reason: 'adding pruned expired entries');
    expect(coin(0)!.status, UtxoStatus.outgoing);
    now = start + const Duration(minutes: 40);
    expect(coin(0)!.status, UtxoStatus.unspent);
    expect(coin(5)!.status, UtxoStatus.outgoing);
    now = start + const Duration(minutes: 60);
    expect(coin(5)!.status, UtxoStatus.unspent);
  });
}
