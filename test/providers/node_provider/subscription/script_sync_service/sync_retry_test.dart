// Bounded automatic retry after a failed wallet queue (10/30/90 s, one timer per wallet).
import 'dart:async';

import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/node/wallet_fetch_progress.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/state/state_manager_interface.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_connection_status_view_model.dart';
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

  /// [random] 0.5 keeps the delays exactly 10/30/90 s.
  ScriptSyncService createSync({StateManagerInterface? state, double random = 0.5}) =>
      ScriptSyncService(
          state ?? ScriptSyncServiceMock.stateManager,
          ScriptSyncServiceMock.balanceSyncService,
          ScriptSyncServiceMock.transactionSyncService,
          ScriptSyncServiceMock.utxoSyncService,
          ScriptSyncServiceMock.addressRepository,
          ScriptSyncServiceMock.scriptCallbackService,
          createTimer: clock.create,
          random: () => random,
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

  test('retry delays are spread ±20% so wallets that failed together do not retry together', () async {
    for (final (random, millis) in [(0.0, 8000), (0.9999, 11999)]) {
      clock = ManualTimers();
      await failQueue(createSync(random: random));
      expect(clock.pendingDelays.single.inMilliseconds, millis);
    }
  });

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

  test('a clean queue while a retry is pending resets the count the late retry starts from', () async {
    final sync = createSync();
    resubscribe = () async => _failure;
    await failQueue(sync);
    await elapse(sync);
    await elapse(sync);
    expect(clock.pendingDelays, [const Duration(seconds: 90)], reason: 'precondition: the third attempt is pending');

    await sync.runQueued(_walletId, () async => Result.success(true)); // a push syncs cleanly; the timer stays
    await elapse(sync); // the late retry fails again

    expect(clock.pendingDelays, [const Duration(seconds: 30)], reason: 'one attempt used since the reset, not three');
  });

  test('a retry is skipped while the socket is disconnected and the next delay is armed', () async {
    final sync = createSync();
    connected = false;
    await failQueue(sync);
    await elapse(sync);
    expect(calls, isEmpty);
    expect(clock.pendingDelays, [const Duration(seconds: 30)]);
  });

  test('cancelRetry drops the pending timer', () async {
    final sync = createSync();
    await failQueue(sync);
    sync.cancelRetry(_walletId); // e.g. resync wipes the wallet, or the wallet is deleted
    expect(clock.pendingDelays, isEmpty);
    await sync.runQueued(_walletId, () async {});
    expect(calls, isEmpty, reason: 'a cancelled wallet is not retried again');
  });

  test('a retry whose timer fires while other work holds the queue waits for that work to end', () async {
    final sync = createSync();
    resubscribe = () async => _failure;
    await failQueue(sync);
    final hold = Completer<void>();
    final busy = sync.runQueued(_walletId, () async {
      await hold.future;
      return _failure; // the busy work fails too
    }, retryWallet: _wallet);
    clock.elapse();
    expect(calls, isEmpty, reason: 'no retry runs behind or inside the busy work');
    hold.complete();
    await busy;
    expect(clock.pendingDelays, [const Duration(seconds: 10)], reason: 'the failed drain schedules it again');
  });

  // Review round 2 (Codex): a subscription failure leaves no record a later clean queue could cover, so a retry that
  // came due during such a queue (e.g. a viewed-address check) must run after it, not be dropped.
  test('a retry that comes due during a clean viewed-address check runs after it', () async {
    final sync = createSync();
    await failQueue(sync); // a failed subscription
    final hold = Completer<void>();
    final check = sync.runQueued(_walletId, () async {
      await hold.future;
      return Result.success(<String>[]); // a clean syncViewedAddresses
    }, retryWallet: _wallet);
    clock.elapse();
    expect(calls, isEmpty, reason: 'it does not run inside the check');
    hold.complete();
    await check;
    await pumpEventQueue();
    expect(calls, ['resubscribe']);
  });

  test('a retry deferred behind a busy queue is dropped when the wallet is resynced or deleted meanwhile', () async {
    final sync = createSync();
    await failQueue(sync);
    final hold = Completer<void>();
    final check = sync.runQueued(_walletId, () async => hold.future);
    clock.elapse();
    sync.cancelRetry(_walletId);
    hold.complete();
    await check;
    await pumpEventQueue();
    expect(calls, isEmpty);
    expect(clock.pendingDelays, isEmpty);
  });

  // Review round 2 (Codex 3, Claude F): a dormant or viewed check can reach a new isolate before the bulk subscription
  // and register its main-isolate copy first. The object that owns the subscription must still own the retry.
  test('the subscription owner replaces an earlier main-isolate copy as the retry wallet', () async {
    final sync = createSync();
    WalletItemBase? retried;
    sync.subscribeWallet = (wallet) {
      retried = wallet;
      return resubscribe();
    };
    final copy = WalletMock.createSingleSigWalletItem(id: _walletId); // what a dormant check sends
    await sync.runQueued(_walletId, () async => Result.success(true), retryWallet: copy, retryWalletIsCopy: true);
    await sync.runQueued(_walletId, () async => Result.success(true), retryWallet: _wallet); // the bulk subscribe
    await sync.runQueued(_walletId, () async => _failure, retryWallet: copy, retryWalletIsCopy: true); // a failed check
    clock.elapse();
    await pumpEventQueue();
    expect(identical(retried, _wallet), isTrue);
  });

  // Review round 1 (Codex probe): cancellation while the running retry awaits its balance re-fetch. This is also the
  // test that fails without the generation check (Claude nit 6): the registration alone cannot tell the cancel.
  test('[codex-cancel-running-retry] cancellation during balance retry must prevent resubscribe', () async {
    final sync = createSync();
    final script = ScriptStatusMock.createMockScriptStatus(_wallet, 3);
    when(ScriptSyncServiceMock.electrumService.getBalance(any, script.address)).thenThrow(StateError('timeout'));
    await sync.runQueued(
      _walletId,
      () => ScriptSyncServiceMock.balanceSyncService.fetchScriptBalanceBatch(_wallet, [script]),
      retryWallet: _wallet,
    );
    final entered = Completer<void>();
    final response = Completer<GetBalanceRes>();
    when(ScriptSyncServiceMock.electrumService.getBalance(any, script.address)).thenAnswer((_) {
      entered.complete();
      return response.future;
    });
    clock.elapse();
    await entered.future;
    sync.cancelRetry(_walletId); // SubscriptionService.unsubscribeWallet does this before its awaited unsubscribe.
    response.complete(GetBalanceRes(confirmed: 0, unconfirmed: 0));
    await sync.runQueued(_walletId, () async {});
    expect(calls, isNot(contains('resubscribe')), reason: 'the captured wallet belongs to the cancelled generation');
  });

  test('a removed wallet drops its pushes and retry registrations for good (wallet IDs are never reused)', () async {
    final sync = createSync();
    final push = SubscribeScriptStreamDto(
      walletItem: _wallet,
      scriptStatus: ScriptStatusMock.createMockScriptStatus(_wallet, 0),
      updateUsedIndex: false,
    );
    sync.removeWallet(_walletId);
    await sync.syncScriptStatus(push); // a push through a callback that is still attached
    await failQueue(sync); // a retry registration is refused while removed
    expect(calls, isEmpty, reason: 'the push was dropped before any request');
    expect(clock.pendingDelays, isEmpty);
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

  group('automatic retry: the home status holds still, wallet data always reaches the screen', () {
    setUp(() => CoconutWalletApp.kFaucetHost = 'http://localhost');

    test('failing retries keep the failed state; neither the home status nor the wallet detail spins', () async {
      final node = _Node();
      node.manager.initWalletUpdateStatus(_walletId); // IsolateController.subscribeWallets
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
      final home = HomeConnectionStatusViewModel(_Connectivity(), node, ValueNotifier<List<WalletItemBase>>([_wallet]));
      addTearDown(() async {
        detail.dispose();
        home.dispose();
        await node.close();
      });
      resubscribe = () async => _failure;
      await failQueue(sync); // e.g. a push failed: the failed state is on screen
      await pumpEventQueue();
      expect(node.state.nodeSyncState, NodeSyncState.failed);

      final nodeStates = <NodeSyncState>[];
      final subscription = node.syncStateStream.listen(nodeStates.add);
      addTearDown(subscription.cancel);
      final homeBefore = (home.showElectrumReconnected, home.isSyncing);
      final homeChanges = <(bool, bool)>[];
      home.addListener(() {
        final now = (home.showElectrumReconnected, home.isSyncing);
        if (now != homeBefore) homeChanges.add(now);
      });
      var detailSpun = false;
      detail.addListener(() => detailSpun |= detail.isWalletSyncing);
      var walletEvents = 0;
      final walletSubscription = node.getWalletStateStream(_walletId).listen((_) => walletEvents++);
      addTearDown(walletSubscription.cancel);

      for (var attempt = 0; attempt < 2; attempt++) {
        final retry = Completer<Result<bool>>();
        resubscribe = () {
          node.manager.addWalletSyncState(_walletId, UpdateElement.subscription); // as SubscriptionService reports
          return retry.future;
        };
        clock.elapse(); // the retry starts
        await pumpEventQueue();
        expect(detail.isWalletSyncing, isFalse, reason: 'a retry does not spin the wallet detail over the failure');
        retry.complete(_failure);
        await pumpEventQueue();
      }
      expect(nodeStates, isEmpty, reason: 'the failed state stays on screen while retries fail');
      expect(homeChanges, isEmpty, reason: 'no reconnected/updating flashes on the home status');
      expect(detailSpun, isFalse);
      expect(walletEvents, greaterThan(0), reason: 'wallet events are never held back');
      expect(node.state.registeredWallets[_walletId]!.isSyncQueued, isFalse);

      resubscribe = () async => Result.success(true);
      clock.elapse(); // the third retry succeeds
      await pumpEventQueue();
      expect(nodeStates, [NodeSyncState.completed], reason: 'only the success is published');
      expect(node.state.registeredWallets[_walletId]!.balance, WalletSyncState.completed);
      // The success delivers the global and the wallet update one microtask apart, before any frame; check what settles.
      expect(detail.isWalletSyncing, isFalse);
    });

    test('once a retry ends, ordinary syncs (push, refresh) show their progress as before', () async {
      final node = _Node();
      node.manager.initWalletUpdateStatus(_walletId);
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
      resubscribe = () async => _failure;
      await failQueue(sync);
      clock.elapse(); // a retry fails
      await pumpEventQueue();
      expect(node.state.nodeSyncState, NodeSyncState.failed);

      final hold = Completer<Result<bool>>();
      final pushed = sync.runQueued(_walletId, () => hold.future, retryWallet: _wallet);
      await pumpEventQueue();
      expect(detail.isWalletSyncing, isTrue, reason: 'an ordinary sync spins the wallet detail as today');
      expect(node.state.nodeSyncState, NodeSyncState.syncing);
      hold.complete(Result.success(true));
      await pushed;
      await pumpEventQueue();
      expect(detail.isWalletSyncing, isFalse);
      expect(node.state.nodeSyncState, NodeSyncState.completed);
    });

    // Review round 2: a clean queue (e.g. a push) can show completed while a subscription failure still waits for its
    // retry. A retry that then fails must show the failure again instead of leaving completed on screen.
    test('a retry that fails after another sync showed completed shows the failure again', () async {
      final node = _Node();
      node.manager.initWalletUpdateStatus(_walletId);
      final sync = createSync(state: node.manager);
      addTearDown(node.close);
      await failQueue(sync); // a failed subscription; its retry is pending
      await sync.runQueued(_walletId, () async => Result.success(true)); // a clean push
      expect(node.state.nodeSyncState, NodeSyncState.completed, reason: 'precondition');
      resubscribe = () async => _failure;
      clock.elapse(); // the pending retry fails
      await pumpEventQueue();
      expect(node.state.nodeSyncState, NodeSyncState.failed);
      expect(node.state.registeredWallets[_walletId]!.balance, WalletSyncState.waiting);
    });

    // Review round 2 (Claude B): a payment push that joins the queue of a retry that then fails must still reach the
    // screen (the transaction list reloads on the wallet's completed steps).
    test('a push that joins a failing retry still reaches the screen', () async {
      final node = _Node();
      node.manager.initWalletUpdateStatus(_walletId);
      final sync = createSync(state: node.manager);
      addTearDown(node.close);
      await failQueue(sync);
      final events = <WalletUpdateInfo>[];
      final subscription = node.getWalletStateStream(_walletId).listen(events.add);
      addTearDown(subscription.cancel);
      final retry = Completer<Result<bool>>();
      resubscribe = () => retry.future;
      clock.elapse(); // the retry runs
      await pumpEventQueue();
      final pushed = sync.runQueued(_walletId, () async {
        // what _processScriptStatus reports for a new payment
        node.manager.addWalletSyncState(_walletId, UpdateElement.transaction);
        node.manager.addWalletCompletedState(_walletId, UpdateElement.transaction);
        return Result.success(true);
      }, retryWallet: _wallet);
      retry.complete(_failure);
      await pushed;
      await pumpEventQueue();
      expect(events.map((e) => e.transaction), contains(WalletSyncState.completed));
      expect(node.state.nodeSyncState, NodeSyncState.failed, reason: 'the retry itself failed');
    });

    // A deleted wallet must not come back into the screen state as failed and keep the global state failed.
    for (final silentRetry in [false, true]) {
      final what = silentRetry ? 'its retry' : 'a sync';
      test('$what that ends after the wallet was deleted does not keep the global state failed', () async {
        final node = _Node();
        final other = WalletMock.createSingleSigWalletItem(id: _walletId + 1);
        for (final id in [_walletId, other.id]) {
          node.manager.initWalletUpdateStatus(id);
        }
        final sync = createSync(state: node.manager);
        addTearDown(node.close);
        await sync.runQueued(other.id, () async => Result.success(true)); // the other wallet is fine
        final response = Completer<Result<bool>>();
        Future<void> running;
        if (silentRetry) {
          await failQueue(sync);
          resubscribe = () => response.future;
          clock.elapse();
          running = sync.runQueued(_walletId, () async {}); // joins the retry's queue to await its end
        } else {
          running = sync.runQueued(_walletId, () => response.future, retryWallet: _wallet); // e.g. a subscribe
        }
        await pumpEventQueue();
        sync.removeWallet(_walletId); // the user deletes the wallet (SubscriptionService.unsubscribeWallet)
        node.manager.unregisterWalletUpdateState(_walletId); // NodeProvider drops the deleted wallet's state
        response.complete(_failure); // e.g. the late subscribe response refused for the deleted wallet
        await running;
        await sync.runQueued(other.id, () async => Result.success(true)); // the next sync recomputes the state

        expect(node.state.registeredWallets.keys, [other.id], reason: 'the deleted wallet is not registered again');
        expect(node.state.nodeSyncState, NodeSyncState.completed);
        expect(clock.pendingDelays, isEmpty, reason: 'a deleted wallet is not retried');
      });
    }
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
  @override
  bool get hasConnectionError => false; // the socket is fine: only the wallet's sync failed
  @override
  bool get isInitializing => false;
  @override
  bool get isConnected => manager.state.nodeSyncState != NodeSyncState.failed;
  @override
  Future<bool>? get walletsRefresh => null;
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

class _Connectivity extends ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
  @override
  bool get isInternetOff => false;
  @override
  bool get isVpnActive => false;
  @override
  bool get isVpnInactive => true;
  @override
  Future<void> refreshConnectivity() async {}
}
