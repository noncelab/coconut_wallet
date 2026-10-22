import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_util.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/transaction.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mock/script_sync_service_mock.dart';
import '../../../mock/script_status_mock.dart';
import '../../../mock/transaction_mock.dart';
import '../../../mock/wallet_mock.dart';

class _FailingTransactionRepository extends TransactionRepository {
  _FailingTransactionRepository(super.realmManager);
  bool rejectNextConfirmedWrite = false;
  bool rejectedWrite = false;

  @override
  Future<void> addAllTransactions(int walletId, List<TransactionRecord> txList) async {
    if (rejectNextConfirmedWrite && txList.any((tx) => tx.blockHeight > 0)) {
      rejectNextConfirmedWrite = false;
      rejectedWrite = true;
      throw StateError('injected transaction write failure');
    }
    await super.addAllTransactions(walletId, txList);
  }
}

void main() {
  for (final mode in [
    'subscribed-only',
    'forced-history-control',
    'failed-fetch-retry',
    'failed-write-retry',
    'stale-refresh',
    'failed-first-history',
    'missing-header-retry',
    'query-boundaries',
  ]) {
    test('receiver parent confirms with its child: $mode', () async {
      final previousNetwork = NetworkType.currentNetworkType;
      ScriptSyncServiceMock.init();
      addTearDown(() {
        ScriptSyncServiceMock.realmManager!.dispose();
        ScriptSyncServiceMock.realmManager = null;
        NetworkType.setNetworkType(previousNetwork);
      });
      SharedPreferences.setMockInitialValues({SharedPrefKeys.kNextIdField: 1});
      await SharedPrefsRepository().init();
      final wallet = WalletMock.createSingleSigWalletItem();
      await ScriptSyncServiceMock.walletRepository.addSinglesigWallet(
        WatchOnlyWallet(
          wallet.name,
          wallet.colorIndex,
          wallet.iconIndex,
          wallet.descriptor,
          null,
          null,
          WalletImportSource.coconutVault.name,
        ),
      );
      await ScriptSyncServiceMock.addressRepository.ensureAddressesInit(walletItemBase: wallet);
      final receive = ScriptStatusMock.createMockScriptStatus(wallet, 0);
      final change = ScriptStatusMock.createMockScriptStatus(wallet, 1);
      // Fixed public descriptors from the repository fixtures; no signer or broadcast.
      final external = WalletMock.createMultiSigWalletItem().walletBase.getAddress(0);
      final funding = TransactionMock.createMockTransaction(toAddress: external, amount: 600000);
      final parent = TransactionMock.createMockTransaction(
        inputTransactionHash: funding.transactionHash,
        toAddress: receive.address,
        amount: 500000,
      );
      final child = TransactionMock.createMockTransaction(
        inputTransactionHash: parent.transactionHash,
        toAddress: change.address,
        amount: 499000,
      );
      final electrum = ScriptSyncServiceMock.electrumService;
      var phase = 0;
      var confirmedParentFetches = 0;
      var failedParentOnce = false;
      var receiveHistoryRequests = 0;
      var failedHistoryOnce = false;
      var omittedHeaderOnce = false;
      var utxoFetches = 0;
      var parentHeaderRequests = 0;
      final childHeight = mode == 'missing-header-retry' ? 101 : 100;
      when(electrum.getHistory(any, any)).thenAnswer((invocation) async {
        final address = invocation.positionalArguments[1] as String;
        if (address == receive.address) {
          receiveHistoryRequests++;
          if (mode == 'failed-first-history' && !failedHistoryOnce) {
            failedHistoryOnce = true;
            throw StateError('injected history lookup failure');
          }
          return [
            GetTxHistoryRes(height: phase == 2 ? 100 : 0, txHash: parent.transactionHash),
            if (phase > 0) GetTxHistoryRes(height: phase == 2 ? childHeight : -1, txHash: child.transactionHash),
          ];
        }
        return phase == 0
            ? []
            : [GetTxHistoryRes(height: phase == 2 ? childHeight : -1, txHash: child.transactionHash)];
      });
      when(electrum.getBalance(any, any)).thenAnswer((invocation) async {
        final address = invocation.positionalArguments[1] as String;
        if (address == receive.address) return GetBalanceRes(confirmed: 0, unconfirmed: phase == 0 ? 500000 : 0);
        return GetBalanceRes(confirmed: phase == 2 ? 499000 : 0, unconfirmed: phase == 1 ? 499000 : 0);
      });
      when(electrum.getUnspentList(any, any)).thenAnswer((invocation) async {
        utxoFetches++;
        final address = invocation.positionalArguments[1] as String;
        if (address == receive.address) {
          return phase == 0 ? [ListUnspentRes(height: 0, txHash: parent.transactionHash, txPos: 0, value: 500000)] : [];
        }
        return phase == 0
            ? []
            : [
              ListUnspentRes(
                height: phase == 2 ? childHeight : -1,
                txHash: child.transactionHash,
                txPos: 0,
                value: 499000,
              ),
            ];
      });
      when(electrum.fetchBlocksByHeight(any)).thenAnswer((invocation) async {
        final heights = invocation.positionalArguments[0] as Set<int>;
        if (phase == 2 && heights.contains(100)) parentHeaderRequests++;
        final omit = mode == 'missing-header-retry' && phase == 2 && !omittedHeaderOnce;
        if (omit) omittedHeaderOnce = true;
        return {
          for (final height in heights)
            if (!omit || height != 100) height: BlockTimestamp(height, DateTime.utc(2026)),
        };
      });
      when(electrum.getTransaction(any)).thenAnswer((invocation) async {
        final hash = invocation.positionalArguments[0] as String;
        if (hash == parent.transactionHash) {
          if (phase == 2) confirmedParentFetches++;
          if (mode == 'failed-fetch-retry' && phase == 2 && !failedParentOnce) {
            failedParentOnce = true;
            throw StateError('injected public-fixture transaction fetch failure');
          }
          return parent.serialize();
        }
        if (hash == child.transactionHash) return child.serialize();
        return funding.serialize();
      });
      when(electrum.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList'))).thenAnswer((
        invocation,
      ) async {
        final tx = invocation.positionalArguments[0] as Transaction;
        return tx.transactionHash == child.transactionHash ? [parent] : [funding];
      });
      final repository = _FailingTransactionRepository(ScriptSyncServiceMock.realmManager!);
      ScriptSyncServiceMock.transactionSyncService = TransactionSyncService(
        electrum,
        repository,
        ScriptSyncServiceMock.transactionRecordService,
        ScriptSyncServiceMock.stateManager,
        ScriptSyncServiceMock.utxoRepository,
        ScriptSyncServiceMock.scriptCallbackService,
      );
      final subscriptions = {receive.address, change.address};
      final sync = ScriptSyncServiceMock.createMockScriptSyncService();
      sync.subscribeWallet = ScriptSyncServiceMock.subscribeWallet;
      sync.unsubscribeAddress = (_, address) async {
        subscriptions.remove(address);
      };
      sync.subscribeAddress = (_, __, address, ___) async {
        subscriptions.add(address);
      };
      final receiveEvent = SubscribeScriptStreamDto(walletItem: wallet, scriptStatus: receive);
      final changeEvent = SubscribeScriptStreamDto(walletItem: wallet, scriptStatus: change);
      if (mode == 'failed-first-history') {
        phase = 1;
        await sync.syncScriptStatus(receiveEvent);
        final safeFailure = {
          'still_subscribed': subscriptions.contains(receive.address),
          'no_utxo_success_callback': utxoFetches == 0,
          'no_parent_record_written': repository.getTransactionRecord(wallet.id, parent.transactionHash) == null,
        };
        print('SAFE_HISTORY_FAILURE ${jsonEncode(safeFailure)}');
        expect(safeFailure, {
          'still_subscribed': true,
          'no_utxo_success_callback': true,
          'no_parent_record_written': true,
        });
      } else {
        await sync.syncScriptStatus(receiveEvent);
        expect(repository.getTransactionRecord(wallet.id, parent.transactionHash)?.blockHeight, 0);
        phase = 1;
      }
      await sync.syncScriptStatus(receiveEvent);
      await sync.syncScriptStatus(changeEvent);
      expect(repository.getTransactionRecord(wallet.id, child.transactionHash)?.blockHeight, 0);
      if (mode == 'query-boundaries') {
        final addresses = ScriptSyncServiceMock.addressRepository;
        final unrelated = ScriptStatusMock.createMockScriptStatus(wallet, 2);
        await addresses.setWalletAddressUsed(wallet, 2, false);
        expect(addresses.isAddressActive(wallet.id, receive.address), isTrue);
        expect(addresses.isAddressDormant(wallet.id, receive.address), isFalse);
        expect(addresses.isAddressActive(wallet.id, unrelated.address), isFalse);
        expect(addresses.isAddressDormant(wallet.id, unrelated.address), isTrue);
        final active = addresses.getActiveUsedAddresses(wallet.id, false).map((row) => row.address).toSet();
        expect(active, contains(receive.address));
        expect(active, isNot(contains(unrelated.address)));
        final pendingParent = repository.getTransactionRecord(wallet.id, parent.transactionHash)!;
        await repository.markAsRbfReplaced(wallet.id, {
          'a' * 64: (originalTransactionHash: parent.transactionHash, previousTransactionHash: parent.transactionHash),
          'b' * 64: (originalTransactionHash: child.transactionHash, previousTransactionHash: child.transactionHash),
        });
        final realm = ScriptSyncServiceMock.realmManager!.realm;
        realm.write(() {
          realm.add(mapTransactionToRealmTransaction(pendingParent, wallet.id + 1, 99999));
        });
        expect(addresses.isAddressActive(wallet.id, receive.address), isFalse);
        expect(addresses.isAddressDormant(wallet.id, receive.address), isTrue);
        expect(
          addresses.getActiveUsedAddresses(wallet.id, false).map((row) => row.address),
          isNot(contains(receive.address)),
        );
        return;
      }
      final unsubscribedWhilePending = !subscriptions.contains(receive.address);
      final dormantWhilePending = ScriptSyncServiceMock.addressRepository.isAddressDormant(wallet.id, receive.address);
      phase = 2;
      repository.rejectNextConfirmedWrite = mode == 'failed-write-retry';
      if (mode == 'stale-refresh') subscriptions.remove(receive.address);
      if (mode != 'stale-refresh' && (mode != 'subscribed-only' || subscriptions.contains(receive.address))) {
        await sync.syncScriptStatus(receiveEvent);
      }
      await sync.syncScriptStatus(changeEvent);
      if (mode == 'stale-refresh') {
        expect(repository.getTransactionRecord(wallet.id, parent.transactionHash)?.blockHeight, 0);
        expect(repository.getTransactionRecord(wallet.id, child.transactionHash)?.blockHeight, greaterThan(0));
        expect(
          ScriptSyncServiceMock.addressRepository
              .getActiveUsedAddresses(wallet.id, false)
              .any((address) => address.address == receive.address),
          isTrue,
          reason: 'Reconnect must include zero-balance addresses with pending history.',
        );
      }
      final beforeRefresh = receiveHistoryRequests;
      await sync.syncDormantAddresses(wallet);
      final dormantRefreshFetchedHistory = receiveHistoryRequests > beforeRefresh;
      if (mode == 'failed-fetch-retry') await sync.syncScriptStatus(receiveEvent);
      final parentRow = repository.getTransactionRecord(wallet.id, parent.transactionHash);
      final childRow = repository.getTransactionRecord(wallet.id, child.transactionHash);
      final observed = {
        'receiver_parent_present': parentRow != null,
        'receiver_parent_confirmed': (parentRow?.blockHeight ?? 0) > 0,
        'receiver_parent_filtered_present': repository
            .getTransactionRecordList(wallet.id)
            .any((r) => r.transactionHash == parent.transactionHash),
        'child_confirmed': (childRow?.blockHeight ?? 0) > 0,
        'receive_unsubscribed_while_pending': unsubscribedWhilePending,
        'receive_dormant_while_pending': dormantWhilePending,
        'dormant_refresh_fetched_history': dormantRefreshFetchedHistory,
        'injected_parent_fetch_failure': failedParentOnce,
        'injected_missing_header': omittedHeaderOnce,
        'parent_header_retried': parentHeaderRequests > 1,
        'parent_retried_after_failed_confirmed_fetch': failedParentOnce && confirmedParentFetches > 1,
      };
      print('SAFE_OBSERVATIONS $mode ${jsonEncode(observed)}');
      if (mode == 'stale-refresh') expect(dormantRefreshFetchedHistory, isTrue);
      if (mode == 'missing-header-retry') {
        expect(omittedHeaderOnce, isTrue);
        expect(parentHeaderRequests, greaterThan(1));
      }
      if (mode == 'failed-write-retry') expect(repository.rejectedWrite, isTrue);
      if (mode == 'failed-fetch-retry') expect(observed['parent_retried_after_failed_confirmed_fetch'], isTrue);
      expect(observed['receiver_parent_present'], isTrue);
      expect(observed['receiver_parent_filtered_present'], isTrue);
      expect(observed['child_confirmed'], isTrue);
      expect(
        observed['receiver_parent_confirmed'],
        isTrue,
        reason: 'A confirmed child must not leave its receiver parent locally unconfirmed.',
      );
    });
  }
  test('older processing claim cannot release or complete a newer confirmation', () async {
    final callbacks = ScriptCallbackService();
    final wallet = WalletMock.createSingleSigWalletItem();
    final status = ScriptStatusMock.createMockScriptStatus(wallet, 0);
    const hash = 'public-fixture-parent';
    final old = callbacks.registerTransactionProcessing(wallet.id, hash, false);
    expect(callbacks.isTransactionProcessable(txHashKey: getTxHashKey(wallet.id, hash), isConfirmed: true), isTrue);
    final current = callbacks.registerTransactionProcessing(wallet.id, hash, true);
    var utxoCallbacks = 0;
    callbacks.registerFetchUtxosCallback(getScriptKey(wallet.id, status.derivationPath), () async {
      utxoCallbacks++;
    });
    await callbacks.registerTransactionDependency(wallet, status, [hash]);
    callbacks.releaseTransactionProcessing(wallet.id, {hash: old});
    await callbacks.registerTransactionCompletion(wallet.id, {hash}, processingStates: {hash: old});
    expect(callbacks.areAllTransactionsCompleted(wallet.id, [hash]), isFalse);
    expect(callbacks.isTransactionProcessable(txHashKey: getTxHashKey(wallet.id, hash), isConfirmed: true), isFalse);
    expect(utxoCallbacks, 0);
    await callbacks.registerTransactionCompletion(wallet.id, {hash}, processingStates: {hash: current});
    expect(callbacks.areAllTransactionsCompleted(wallet.id, [hash]), isTrue);
    expect(utxoCallbacks, 1);
  });
}
