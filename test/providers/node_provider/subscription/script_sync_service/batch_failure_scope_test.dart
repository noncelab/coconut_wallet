// A batch fails only for its own work: an earlier balance failure elsewhere in the wallet must not abort it.
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import '../../../../mock/transaction_mock.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../mock/script_status_mock.dart';
import '../../../../mock/script_sync_service_mock.dart';
import '../../../../mock/wallet_mock.dart';

void main() {
  const walletId = 905;
  final wallet = WalletMock.createSingleSigWalletItem(id: walletId);
  late ScriptSyncService sync;
  late List<String> historyRequests;

  setUp(() async {
    ScriptSyncServiceMock.init();
    final realm = ScriptSyncServiceMock.realmManager!.realm;
    realm.write(() {
      realm.add(
        RealmWalletBase(
          wallet.id,
          wallet.colorIndex,
          wallet.iconIndex,
          wallet.descriptor,
          wallet.name,
          WalletType.singleSignature.name,
        ),
      );
    });
    final addresses = ScriptSyncServiceMock.addressRepository;
    await addresses.ensureAddressesInit(walletItemBase: wallet);
    await addresses.ensureAddressesExist(walletItemBase: wallet, cursor: 0, count: 50, isChange: false);
    ScriptSyncServiceMock.walletRepository.updateWalletBalance(wallet.id, Balance(0, 0));

    historyRequests = [];
    final electrum = ScriptSyncServiceMock.electrumService;
    when(electrum.getBalance(any, any)).thenAnswer((_) async => GetBalanceRes(confirmed: 0, unconfirmed: 0));
    when(electrum.getUnspentList(any, any)).thenAnswer((_) async => <ListUnspentRes>[]);
    when(electrum.getHistory(any, any)).thenAnswer((call) async {
      historyRequests.add(call.positionalArguments[1] as String);
      return <GetTxHistoryRes>[];
    });
    sync =
        ScriptSyncServiceMock.createMockScriptSyncService()
          ..subscribeWallet = ScriptSyncServiceMock.subscribeWallet
          ..unsubscribeAddress = ScriptSyncServiceMock.unsubscribeAddress
          ..subscribeAddress = ScriptSyncServiceMock.subscribeAddress;
  });
  tearDown(() {
    ScriptSyncServiceMock.realmManager?.dispose();
    ScriptSyncServiceMock.realmManager = null;
  });

  List<ScriptStatus> scripts(int from, int count) =>
      List.generate(count, (i) => ScriptStatusMock.createMockScriptStatus(wallet, from + i));

  /// A dormant-address balance check (app resume) times out for [address].
  Future<void> failBalanceOnce(String address) async {
    final electrum = ScriptSyncServiceMock.electrumService;
    when(electrum.getBalance(any, address)).thenThrow(StateError('injected get_balance timeout'));
    await ScriptSyncServiceMock.balanceSyncService.fetchScriptBalanceBatch(wallet, scripts(40, 1));
    when(electrum.getBalance(any, address)).thenAnswer((_) async => GetBalanceRes(confirmed: 0, unconfirmed: 0));
    expect(ScriptSyncServiceMock.balanceSyncService.hasBalanceFetchFailures(walletId), isTrue);
  }

  test('an earlier balance failure on an address outside the batch does not abort it', () async {
    await failBalanceOnce(scripts(40, 1).single.address);

    await sync.syncBatchScriptStatusList(walletItem: wallet, scriptStatuses: scripts(0, 2));

    expect(historyRequests, hasLength(2), reason: 'the batch synced its own transactions');
    expect(ScriptSyncServiceMock.balanceSyncService.hasBalanceFetchFailures(walletId), isTrue);
  });

  test('a failed 20-script chunk does not skip the later chunks; the first error is rethrown after them', () async {
    final batch = scripts(0, 45); // chunks of 20, 20 and 5
    final electrum = ScriptSyncServiceMock.electrumService;
    when(electrum.getHistory(any, batch.first.address)).thenAnswer((call) async {
      historyRequests.add(call.positionalArguments[1] as String);
      throw StateError('injected get_history timeout');
    });

    await expectLater(
      sync.syncBatchScriptStatusList(walletItem: wallet, scriptStatuses: batch),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('get_history'))),
    );

    expect(historyRequests.toSet(), batch.map((s) => s.address).toSet());
    for (final script in batch) {
      verify(electrum.getUnspentList(any, script.address)).called(1);
    }
    final progress = ScriptSyncServiceMock.stateManager.fetchProgressByWallet[walletId]!;
    expect((progress.dispatched, progress.completed), (45, 45));
  });

  test('a failed shared transaction keeps dependent scripts retryable while every address gets its coins', () async {
    final batch = scripts(0, 3);
    final electrum = ScriptSyncServiceMock.electrumService;
    final parent = TransactionMock.createMockTransaction(toAddress: wallet.walletBase.getAddress(999), amount: 10000);
    final bad = TransactionMock.createMockTransaction(
      toAddress: batch[0].address,
      amount: 1000,
      inputTransactionHash: parent.transactionHash,
      change: (address: batch[1].address, amount: 8000),
    );
    final goodParent = TransactionMock.createMockTransaction(
      toAddress: wallet.walletBase.getAddress(999),
      amount: 11000,
    );
    final good = TransactionMock.createMockTransaction(
      toAddress: batch[2].address,
      amount: 9000,
      inputTransactionHash: goodParent.transactionHash,
    );
    for (final script in batch) {
      final tx = script == batch.last ? good : bad;
      when(
        electrum.getHistory(any, script.address),
      ).thenAnswer((_) async => [GetTxHistoryRes(height: 100, txHash: tx.transactionHash)]);
    }
    when(electrum.getTransaction(bad.transactionHash)).thenAnswer((_) async => bad.serialize());
    when(electrum.getTransaction(good.transactionHash)).thenAnswer((_) async => good.serialize());
    when(electrum.fetchBlocksByHeight(any)).thenAnswer((_) async => {100: BlockTimestamp(100, DateTime(2026))});
    var failed = true;
    when(electrum.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList'))).thenAnswer((call) async {
      if (failed && (call.positionalArguments.first as Transaction).transactionHash == bad.transactionHash) {
        throw StateError('missing parent');
      }
      return [parent, goodParent];
    });
    when(
      electrum.getUnspentList(any, batch.last.address),
    ).thenAnswer((_) async => [ListUnspentRes(txHash: good.transactionHash, txPos: 0, value: 9000, height: 100)]);
    await expectLater(sync.syncBatchScriptStatusList(walletItem: wallet, scriptStatuses: batch), throwsStateError);
    verify(electrum.getUnspentList(any, batch[0].address)).called(1);
    verify(electrum.getUnspentList(any, batch[1].address)).called(1);
    verify(electrum.getUnspentList(any, batch.last.address)).called(1);
    final records = ScriptSyncServiceMock.transactionRepository;
    expect(records.getTransactionRecord(walletId, bad.transactionHash), isNull);
    expect(records.getTransactionRecord(walletId, good.transactionHash)?.blockHeight, 100);
    expect(ScriptSyncServiceMock.utxoRepository.getUtxoStateList(walletId).single.amount, 9000);
    final progress = ScriptSyncServiceMock.stateManager.fetchProgressByWallet[walletId]!;
    expect(progress.completed, progress.dispatched);
    failed = false;
    await sync.syncBatchScriptStatusList(walletItem: wallet, scriptStatuses: batch);
    expect(records.getTransactionRecord(walletId, bad.transactionHash)?.blockHeight, 100);
    for (final script in batch.take(2)) {
      verify(electrum.getUnspentList(any, script.address)).called(1);
    }
  });

  test('an incomplete script receives new coins but preserves reservations and skips every pending cleanup', () async {
    final batch = scripts(0, 2);
    final electrum = ScriptSyncServiceMock.electrumService;
    final utxos = ScriptSyncServiceMock.utxoRepository;
    final reservedHash = '11' * 32;
    final orphanHash = '22' * 32;
    final incomingHash = '33' * 32;
    final healthyHash = '44' * 32;
    final spenderHash = '55' * 32;
    await utxos.addAllUtxos(walletId, [
      for (final (hash, script) in [(reservedHash, batch.first), (orphanHash, batch.last)])
        UtxoState(
          transactionHash: hash,
          index: 0,
          amount: 1000,
          derivationPath: script.derivationPath,
          blockHeight: 100,
          to: script.address,
          timestamp: DateTime(2026),
          status: UtxoStatus.outgoing,
          spentByTransactionHash: spenderHash,
        ),
    ]);
    when(electrum.getHistory(any, batch.first.address)).thenThrow(StateError('history timeout'));
    when(electrum.getUnspentList(any, batch.first.address)).thenAnswer(
      (_) async => [
        ListUnspentRes(txHash: reservedHash, txPos: 0, value: 1000, height: 100),
        ListUnspentRes(txHash: incomingHash, txPos: 0, value: 2000, height: 0),
        ListUnspentRes(txHash: healthyHash, txPos: 0, value: 3000, height: 100),
      ],
    );

    await expectLater(sync.syncBatchScriptStatusList(walletItem: wallet, scriptStatuses: batch), throwsStateError);

    expect(utxos.getUtxoState(walletId, getUtxoId(reservedHash, 0))?.status, UtxoStatus.outgoing);
    expect(utxos.getUtxoState(walletId, getUtxoId(reservedHash, 0))?.spentByTransactionHash, spenderHash);
    expect(utxos.getUtxoState(walletId, getUtxoId(incomingHash, 0))?.status, UtxoStatus.incoming);
    expect(utxos.getUtxoState(walletId, getUtxoId(healthyHash, 0))?.status, UtxoStatus.unspent);
    expect(utxos.getUtxoState(walletId, getUtxoId(orphanHash, 0)), isNull);
    final progress = ScriptSyncServiceMock.stateManager.fetchProgressByWallet[walletId]!;
    expect(progress.completed, progress.dispatched);
  });

  test('a balance failure on an address inside the batch still aborts it', () async {
    final batch = scripts(0, 2);
    final electrum = ScriptSyncServiceMock.electrumService;
    when(electrum.getBalance(any, batch.last.address)).thenThrow(StateError('injected get_balance timeout'));

    await expectLater(sync.syncBatchScriptStatusList(walletItem: wallet, scriptStatuses: batch), throwsStateError);
    expect(historyRequests, isEmpty);
  });
}
