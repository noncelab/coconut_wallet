// Bounded automatic retry after a failed wallet queue (10/30/90 s, one timer per wallet).
import 'dart:async';

import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/model/node/wallet_fetch_progress.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/state/state_manager_interface.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../mock/manual_timers.dart';
import '../../../../mock/script_status_mock.dart';
import '../../../../mock/script_sync_service_mock.dart';
import '../../../../mock/wallet_mock.dart';

const _walletId = 906;
final _wallet = WalletMock.createSingleSigWalletItem(id: _walletId);
final _failure = Result<bool>.failure(ErrorCodes.nodeUnknown);

void main() {
  late ManualTimers clock;
  late List<String> calls; // getBalance:<address> and resubscribe, in order
  late Future<Result<bool>> Function() resubscribe;
  late bool connected;

  setUp(() async {
    ScriptSyncServiceMock.init();
    final realm = ScriptSyncServiceMock.realmManager!.realm;
    realm.write(() {
      realm.add(
        RealmWalletBase(
          _wallet.id,
          _wallet.colorIndex,
          _wallet.iconIndex,
          _wallet.descriptor,
          _wallet.name,
          WalletType.singleSignature.name,
        ),
      );
    });
    final addresses = ScriptSyncServiceMock.addressRepository;
    await addresses.ensureAddressesInit(walletItemBase: _wallet);
    await addresses.ensureAddressesExist(walletItemBase: _wallet, cursor: 0, count: 10, isChange: false);
    ScriptSyncServiceMock.walletRepository.updateWalletBalance(_walletId, Balance(0, 0));
    clock = ManualTimers();
    calls = [];
    resubscribe = () async => Result.success(true);
    connected = true;
    when(ScriptSyncServiceMock.electrumService.getBalance(any, any)).thenAnswer((call) async {
      calls.add('getBalance:${call.positionalArguments[1]}');
      return GetBalanceRes(confirmed: 0, unconfirmed: 0);
    });
  });
  tearDown(() {
    ScriptSyncServiceMock.realmManager?.dispose();
    ScriptSyncServiceMock.realmManager = null;
  });

  ScriptSyncService createSync({StateManagerInterface? state}) =>
      ScriptSyncService(
          state ?? ScriptSyncServiceMock.stateManager,
          ScriptSyncServiceMock.balanceSyncService,
          ScriptSyncServiceMock.transactionSyncService,
          ScriptSyncServiceMock.utxoSyncService,
          ScriptSyncServiceMock.addressRepository,
          ScriptSyncServiceMock.scriptCallbackService,
          createTimer: clock.create,
        )
        ..subscribeWallet = (_) {
          calls.add('resubscribe');
          return resubscribe();
        }
        ..isConnected = () => connected;

  /// A subscription that failed (e.g. a timed-out subscribe request) for [wallet].
  Future<void> failQueue(ScriptSyncService sync, [WalletItemBase? wallet]) =>
      sync.runQueued((wallet ?? _wallet).id, () async => _failure, retryWallet: wallet ?? _wallet);

  /// Lets the retry the clock started run to the end of its queue.
  Future<void> elapse(ScriptSyncService sync, [int walletId = _walletId]) async {
    clock.elapse();
    await sync.runQueued(walletId, () async {});
  }

  test('a failed queue retries after 10 s, re-fetching failed balances before it resubscribes', () async {
    final sync = createSync();
    final address = ScriptStatusMock.createMockScriptStatus(_wallet, 3).address;
    when(ScriptSyncServiceMock.electrumService.getBalance(any, address)).thenThrow(StateError('timeout'));
    await sync.runQueued(
      _walletId,
      () => ScriptSyncServiceMock.balanceSyncService.fetchScriptBalanceBatch(_wallet, [
        ScriptStatusMock.createMockScriptStatus(_wallet, 3),
      ]),
      retryWallet: _wallet,
    );
    expect(clock.pendingDelays, [const Duration(seconds: 10)]);
    when(ScriptSyncServiceMock.electrumService.getBalance(any, address)).thenAnswer((_) async {
      calls.add('getBalance:$address');
      return GetBalanceRes(confirmed: 0, unconfirmed: 0);
    });

    await elapse(sync);

    expect(calls, ['getBalance:$address', 'resubscribe']);
    expect(ScriptSyncServiceMock.balanceSyncService.hasBalanceFetchFailures(_walletId), isFalse);
    expect(clock.pendingDelays, isEmpty, reason: 'a clean retry schedules nothing more');
    expect(ScriptSyncServiceMock.stateManager.state.registeredWallets[_walletId]!.balance, WalletSyncState.completed);
  });

  test('failures while a retry is pending do not stack timers', () async {
    final sync = createSync();
    await failQueue(sync);
    await failQueue(sync);
    expect(clock.pendingDelays, [const Duration(seconds: 10)]);
  });

  test('stops after 10/30/90 s and keeps the failure; a clean queue resets the count', () async {
    final sync = createSync();
    resubscribe = () async => _failure;
    await failQueue(sync);
    for (final delay in [30, 90]) {
      await elapse(sync);
      expect(clock.pendingDelays, [Duration(seconds: delay)]);
    }
    await elapse(sync);
    expect(calls, ['resubscribe', 'resubscribe', 'resubscribe']);
    expect(clock.pendingDelays, isEmpty, reason: 'capped at three attempts');
    expect(ScriptSyncServiceMock.stateManager.state.nodeSyncState, NodeSyncState.failed);

    await sync.runQueued(_walletId, () async => Result.success(true)); // e.g. a later push syncs cleanly
    await failQueue(sync);
    expect(clock.pendingDelays, [const Duration(seconds: 10)], reason: 'the count starts over');
  });

  test('a retry is skipped while the socket is disconnected and the next delay is armed', () async {
    final sync = createSync();
    connected = false;
    await failQueue(sync);
    await elapse(sync);
    expect(calls, isEmpty);
    expect(clock.pendingDelays, [const Duration(seconds: 30)]);
  });

  test('cancelRetry drops the pending timer, and a retry already queued does nothing', () async {
    final sync = createSync();
    await failQueue(sync);
    sync.cancelRetry(_walletId);
    expect(clock.pendingDelays, isEmpty);

    await failQueue(sync);
    final hold = Completer<void>();
    final busy = sync.runQueued(_walletId, () => hold.future);
    clock.elapse(); // the retry queues behind the running work
    sync.cancelRetry(_walletId); // e.g. resync wipes the wallet, or the wallet is deleted
    hold.complete();
    await busy;
    await sync.runQueued(_walletId, () async {});

    expect(calls, isEmpty);
    expect(clock.pendingDelays, isEmpty, reason: 'a cancelled wallet is not retried again');
  });

  test('empty retry delays (ScriptSyncServiceMock) never arm a timer', () async {
    final sync = ScriptSyncService(
      ScriptSyncServiceMock.stateManager,
      ScriptSyncServiceMock.balanceSyncService,
      ScriptSyncServiceMock.transactionSyncService,
      ScriptSyncServiceMock.utxoSyncService,
      ScriptSyncServiceMock.addressRepository,
      ScriptSyncServiceMock.scriptCallbackService,
      retryDelays: const [],
      createTimer: clock.create,
    );
    await failQueue(sync);
    expect(clock.pendingDelays, isEmpty);
  });

  group('wallet detail indicator', () {
    setUp(() => CoconutWalletApp.kFaucetHost = 'http://localhost');

    test('a failed wallet stops spinning while another wallet syncs, spins only during its own retry', () async {
      final node = _Node();
      final other = WalletMock.createSingleSigWalletItem(id: _walletId + 1);
      for (final id in [_walletId, other.id]) {
        node.manager.initWalletUpdateStatus(id); // IsolateController.subscribeWallets
      }
      node.manager.setNodeSyncStateToSyncing();
      final sync = createSync(state: node.manager);
      final detail = WalletDetailViewModel(
        _walletId,
        _Wallets(),
        _Transactions(),
        node,
        initialUnit: BitcoinUnit.btc,
        sharedPrefs: _Prefs(),
      );
      addTearDown(() async {
        detail.dispose();
        await node.close();
      });
      final otherDone = Completer<void>();
      final otherQueue = sync.runQueued(other.id, () => otherDone.future); // the other wallet keeps syncing

      await failQueue(sync);
      await pumpEventQueue();
      expect(node.state.nodeSyncState, NodeSyncState.syncing, reason: 'precondition: the other wallet is syncing');
      expect(detail.isWalletSyncing, isFalse, reason: 'the failed wallet must not spin for the other wallet');

      final retryDone = Completer<Result<bool>>();
      resubscribe = () => retryDone.future;
      clock.elapse();
      await pumpEventQueue();
      expect(detail.isWalletSyncing, isTrue, reason: 'its own retry runs');

      retryDone.complete(Result.success(true));
      await sync.runQueued(_walletId, () async {});
      await pumpEventQueue();
      expect(detail.isWalletSyncing, isFalse, reason: 'the retry succeeded');
      expect(node.state.registeredWallets[_walletId]!.balance, WalletSyncState.completed);

      otherDone.complete();
      await otherQueue;
    });
  });
}

class _Node extends Fake with ChangeNotifier implements NodeProvider {
  final nodeEvents = StreamController<NodeSyncState>.broadcast();
  final walletEvents = StreamController<Map<int, WalletUpdateInfo>>.broadcast();
  final resyncEvents = StreamController<Map<int, ResyncProgress>>.broadcast();
  final fetchEvents = StreamController<Map<int, WalletFetchProgress>>.broadcast();
  late final manager = NodeStateManager(notifyListeners, nodeEvents, walletEvents, resyncEvents, fetchEvents);
  @override
  NodeProviderState get state => manager.state;
  @override
  Stream<NodeSyncState> get syncStateStream => nodeEvents.stream;
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) =>
      walletEvents.stream.where((e) => e.containsKey(walletId)).map((e) => e[walletId]!);
  Future<void> close() async {
    await Future.wait([nodeEvents.close(), walletEvents.close(), resyncEvents.close(), fetchEvents.close()]);
    dispose();
  }
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  @override
  WalletItemBase getWalletById(int id) => _wallet;
}

class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {
  @override
  void initTxList(int id) {}
}

class _Prefs extends Fake implements SharedPrefsRepository {}
