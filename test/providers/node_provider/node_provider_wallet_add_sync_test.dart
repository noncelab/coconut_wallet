import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

class _Connectivity extends ChangeNotifier implements ConnectivityProvider {
  bool online = true;

  @override
  bool get isInternetOn => online;
  @override
  bool get isInternetOff => !online;
  @override
  bool get isVpnActive => false;
  @override
  bool get isVpnInactive => true;
  @override
  Future<void> refreshConnectivity() async {}

  void setOnline(bool value) {
    online = value;
    notifyListeners();
  }
}

class _Wallet extends Fake implements WalletItemBase {
  _Wallet(this.id, {this.hasLocalKey = false});

  @override
  final int id;
  @override
  final bool hasLocalKey;
  @override
  WalletType get walletType => WalletType.singleSignature;
  @override
  String get name => 'test wallet';
}

class _Analytics extends AnalyticsService {
  _Analytics() : super(null, true);

  final List<({String name, Map<String, Object> parameters})> events = [];

  @override
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async {
    events.add((name: eventName, parameters: AnalyticsService.normalizeParameters(parameters)));
  }

  List<({String name, Map<String, Object> parameters})> get addResults =>
      events.where((event) => event.name.startsWith('wallet_add_sync_')).toList();
}

class _Isolate extends Fake implements IsolateManager {
  bool initialized = false;
  final stateController = StreamController<IsolateStateMessage>.broadcast();
  final List<int> individualSubscriptions = [];
  final List<List<int>> bulkSubscriptions = [];
  Future<Result<bool>> Function(WalletItemBase)? onSubscribe;
  Future<void> Function()? onInitialize;
  Future<Result<bool>> Function(List<WalletItemBase>)? onBulkSubscribe;
  Future<Result<BlockTimestamp>> Function()? onBlock;
  int initializationCount = 0;
  int blockRequestCount = 0;

  @override
  Stream<IsolateStateMessage> get stateStream => stateController.stream;

  @override
  Future<void> initialize(
    String host,
    int port,
    bool ssl,
    NetworkType networkType, [
    String? pinnedCertFingerprint,
  ]) async {
    initializationCount++;
    if (onInitialize != null) await onInitialize!();
    initialized = true;
  }

  @override
  Future<Result<bool>> subscribeWallets(List<WalletItemBase> wallets) async {
    bulkSubscriptions.add(wallets.map((wallet) => wallet.id).toList());
    if (onBulkSubscribe != null) return onBulkSubscribe!(wallets);
    return Result.success(true);
  }

  @override
  Future<Result<bool>> subscribeWallet(WalletItemBase wallet) async {
    individualSubscriptions.add(wallet.id);
    if (onSubscribe != null) return onSubscribe!(wallet);
    return initialized ? Result.success(true) : Result.failure(ErrorCodes.nodeIsolateError);
  }

  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async {
    blockRequestCount++;
    return onBlock != null ? onBlock!() : Result.success(BlockTimestamp(1, DateTime(2026)));
  }

  @override
  Future<void> closeIsolate() async {
    initialized = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Connectivity connectivity;
  late _Isolate isolate;
  late _Analytics analytics;
  late ValueNotifier<WalletLoadState> load;
  late ValueNotifier<List<WalletItemBase>> wallets;
  NodeProvider? provider;

  setUp(() {
    connectivity = _Connectivity();
    isolate = _Isolate();
    analytics = _Analytics();
    load = ValueNotifier(WalletLoadState.loadingFromDB);
    wallets = ValueNotifier([]);
  });

  tearDown(() async {
    if (provider != null) {
      // Initial subscription delays starting the block timer by one second.
      await Future<void>.delayed(const Duration(milliseconds: 1050));
      await provider!.closeConnection();
      provider!.dispose();
      provider = null;
      await pumpEventQueue();
    }
    await isolate.stateController.close();
    load.dispose();
    wallets.dispose();
    connectivity.dispose();
  });

  void createProvider({bool Function(int)? hasHistory}) {
    provider = NodeProvider(
      const ElectrumServer('unused.example', 50002, true),
      NetworkType.mainnet,
      connectivity,
      load,
      wallets,
      analytics,
      isolateManager: isolate,
      hasTransactionHistory: hasHistory,
    );
  }

  Future<void> loadExistingWallets({bool Function(int)? hasHistory}) async {
    createProvider(hasHistory: hasHistory);
    wallets.value = [_Wallet(1, hasLocalKey: true), _Wallet(2, hasLocalKey: true), _Wallet(3)];
    load.value = WalletLoadState.loadCompleted;
    await pumpEventQueue();
  }

  void expectAddResults(List<({String name, Map<String, Object> parameters})> expected) {
    expect(analytics.addResults.map((event) => event.name), expected.map((event) => event.name));
    expect(analytics.addResults.map((event) => event.parameters), expected.map((event) => event.parameters));
  }

  test('offline addition reports only the new wallet, even when all registered states were cleared', () async {
    await loadExistingWallets();
    connectivity.setOnline(false);
    await pumpEventQueue();
    expect(provider!.state.registeredWallets, isEmpty);

    wallets.value = [...wallets.value, _Wallet(4)];
    await pumpEventQueue();

    expect(isolate.individualSubscriptions, [4]);
    expectAddResults([
      (name: AnalyticsEventNames.walletAddSyncFailed, parameters: <String, Object>{'wallet_type': 'watchOnly'}),
    ]);
  });

  test('initial database load is bulk sync, not new-wallet sync', () async {
    await loadExistingWallets();

    expect(isolate.bulkSubscriptions, [
      [1, 2, 3],
    ]);
    expect(isolate.individualSubscriptions, isEmpty);
    expect(analytics.addResults, isEmpty);
  });

  // AppGuard closes the connection when the app is paused with a failed sync; on resume it must reconnect.
  test('after a closed connection, reconnect() subscribes the wallets again but initialize() alone does not', () async {
    await loadExistingWallets();
    await provider!.closeConnection();
    await provider!.initialize(); // what AppGuard called on resume before
    expect(isolate.bulkSubscriptions, hasLength(1), reason: 'only the startup subscription: the wallets stay idle');

    await provider!.closeConnection();
    expect((await provider!.reconnect()).isSuccess, isTrue); // what AppGuard calls now
    expect(isolate.bulkSubscriptions, hasLength(2));
  });

  test('already-loaded wallets are subscribed when the provider is created later', () async {
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    createProvider();
    await pumpEventQueue();

    expect(isolate.bulkSubscriptions, [
      [1],
    ]);
    expect(analytics.addResults, isEmpty);
  });

  test('new-wallet success does not include unregistered existing wallets', () async {
    await loadExistingWallets();
    expect(provider!.state.registeredWallets, isEmpty);

    wallets.value = [...wallets.value, _Wallet(4)];
    await pumpEventQueue();

    expect(isolate.individualSubscriptions, [4]);
    expectAddResults([
      (name: AnalyticsEventNames.walletAddSyncCompleted, parameters: <String, Object>{'wallet_type': 'watchOnly'}),
    ]);
  });

  test('list notifications, reorder and same-ID changes do not duplicate an in-flight addition', () async {
    await loadExistingWallets();
    final completion = Completer<Result<bool>>();
    isolate.onSubscribe = (_) => completion.future;

    wallets.value = [...wallets.value, _Wallet(4)];
    wallets.value = List.of(wallets.value);
    wallets.value = wallets.value.reversed.toList();
    wallets.value = wallets.value.map((wallet) => _Wallet(wallet.id, hasLocalKey: wallet.hasLocalKey)).toList();

    expect(isolate.individualSubscriptions, [4]);
    expect(analytics.addResults, isEmpty);

    completion.complete(Result.success(true));
    await pumpEventQueue();
    wallets.value = List.of(wallets.value);
    await pumpEventQueue();

    expect(isolate.individualSubscriptions, [4]);
    expect(analytics.addResults, hasLength(1));
  });

  test('offline addition before any network initialization still produces its own failure', () async {
    connectivity.online = false;
    await loadExistingWallets();
    expect(isolate.bulkSubscriptions, isEmpty);
    expect(analytics.addResults, isEmpty);

    wallets.value = [...wallets.value, _Wallet(4)];
    await pumpEventQueue();

    expect(isolate.individualSubscriptions, [4]);
    expectAddResults([
      (name: AnalyticsEventNames.walletAddSyncFailed, parameters: <String, Object>{'wallet_type': 'watchOnly'}),
    ]);

    connectivity.setOnline(true);
    await pumpEventQueue();
    wallets.value = List.of(wallets.value);
    await pumpEventQueue();

    expect(isolate.bulkSubscriptions, isNotEmpty);
    expect(isolate.individualSubscriptions, [4]);
    expect(analytics.addResults, hasLength(1), reason: 'reconnection must not become another new-wallet outcome');
  });

  test('failure is not repeated by preference updates or reconnection', () async {
    await loadExistingWallets();
    connectivity.setOnline(false);
    await pumpEventQueue();
    wallets.value = [...wallets.value, _Wallet(4)];
    await pumpEventQueue();
    wallets.value = List.of(wallets.value);
    await pumpEventQueue();

    connectivity.setOnline(true);
    await pumpEventQueue();
    wallets.value = wallets.value.reversed.toList();
    await pumpEventQueue();

    expect(isolate.individualSubscriptions, [4]);
    expect(analytics.addResults, hasLength(1));
  });

  test('deleting a wallet before its subscription resolves suppresses its late result', () async {
    await loadExistingWallets();
    final completion = Completer<Result<bool>>();
    isolate.onSubscribe = (_) => completion.future;
    wallets.value = [...wallets.value, _Wallet(4)];
    wallets.value = wallets.value.where((wallet) => wallet.id != 4).toList();

    completion.complete(Result.failure(ErrorCodes.nodeConnectionError));
    await pumpEventQueue();

    expect(analytics.addResults, isEmpty);
  });

  test('reusing a deleted ID cannot attribute the old request result to its replacement', () async {
    await loadExistingWallets();
    final oldCompletion = Completer<Result<bool>>();
    final newCompletion = Completer<Result<bool>>();
    isolate.onSubscribe =
        (_) => isolate.individualSubscriptions.length == 1 ? oldCompletion.future : newCompletion.future;
    wallets.value = [...wallets.value, _Wallet(4, hasLocalKey: true)];
    wallets.value = wallets.value.where((wallet) => wallet.id != 4).toList();
    wallets.value = [...wallets.value, _Wallet(4)];

    newCompletion.complete(Result.success(true));
    await pumpEventQueue();
    oldCompletion.complete(Result.failure(ErrorCodes.nodeConnectionError));
    await pumpEventQueue();

    expect(isolate.individualSubscriptions, [4, 4]);
    expectAddResults([
      (name: AnalyticsEventNames.walletAddSyncCompleted, parameters: <String, Object>{'wallet_type': 'watchOnly'}),
    ]);
  });

  test('hot-wallet history is queried only for the newly added hot wallet and sends no local IDs', () async {
    final queriedIds = <int>[];
    await loadExistingWallets(
      hasHistory: (id) {
        queriedIds.add(id);
        return true;
      },
    );

    wallets.value = [...wallets.value, _Wallet(4, hasLocalKey: true)];
    await pumpEventQueue();

    expect(queriedIds, [4]);
    expectAddResults([
      (
        name: AnalyticsEventNames.walletAddSyncCompleted,
        parameters: <String, Object>{'wallet_type': 'hotWallet', 'has_history': 'true'},
      ),
    ]);
  });

  test('watch-only success omits history and same-ID watch-only conversion is not another addition', () async {
    await loadExistingWallets(hasHistory: (_) => throw StateError('must not query watch-only history'));
    wallets.value = [...wallets.value, _Wallet(4)];
    await pumpEventQueue();
    wallets.value = [...wallets.value.where((wallet) => wallet.id != 4), _Wallet(4, hasLocalKey: true)];
    await pumpEventQueue();

    expect(isolate.individualSubscriptions, [4]);
    expectAddResults([
      (name: AnalyticsEventNames.walletAddSyncCompleted, parameters: <String, Object>{'wallet_type': 'watchOnly'}),
    ]);
  });

  test('dispose suppresses a pending new-wallet result', () async {
    await loadExistingWallets();
    final completion = Completer<Result<bool>>();
    isolate.onSubscribe = (_) => completion.future;
    wallets.value = [...wallets.value, _Wallet(4)];
    // Let the existing initial-sync timer finish before disposing the provider.
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    provider!.dispose();
    provider = null;
    await pumpEventQueue();

    completion.complete(Result.success(true));
    await pumpEventQueue();

    expect(analytics.addResults, isEmpty);
  });

  testWidgets('a block response after disposal cannot publish or restart block updates', (tester) async {
    final blockCompletion = Completer<Result<BlockTimestamp>>();
    isolate.onBlock = () => blockCompletion.future;
    createProvider();
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    await tester.pump();
    expect(isolate.blockRequestCount, 1);

    provider!.dispose();
    provider = null;
    await tester.pump();
    blockCompletion.complete(Result.success(BlockTimestamp(2, DateTime(2026))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));

    expect(tester.takeException(), isNull);
    expect(isolate.blockRequestCount, 1);
    expect(isolate.initializationCount, 1);
  });

  for (final fails in [false, true]) {
    testWidgets('disposal during initialization cancels waiters and late ${fails ? 'failure' : 'success'}', (
      tester,
    ) async {
      final initialization = Completer<void>();
      isolate.onInitialize = () => initialization.future;
      createProvider();
      wallets.value = [_Wallet(1)];
      load.value = WalletLoadState.loadCompleted;
      final waitingInitialization = provider!.initialize();

      provider!.dispose();
      provider = null;
      await tester.pump();
      await waitingInitialization;
      if (fails) {
        initialization.completeError(StateError('cancelled initialization'));
      } else {
        initialization.complete();
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 11));

      expect(tester.takeException(), isNull);
      expect(isolate.initializationCount, 1);
      expect(isolate.initialized, false, reason: 'late initialization success must release its isolate');
      expect(isolate.bulkSubscriptions, isEmpty);
      expect(isolate.blockRequestCount, 0);
      expect(analytics.events, isEmpty);
    });
  }

  testWidgets('initial bulk result after disposal cannot record success or restart updates', (tester) async {
    final bulkCompletion = Completer<Result<bool>>();
    isolate.onBulkSubscribe = (_) => bulkCompletion.future;
    createProvider();
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    await tester.pump();
    final blockRequests = isolate.blockRequestCount;

    provider!.dispose();
    provider = null;
    await tester.pump();
    bulkCompletion.complete(Result.success(true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));

    expect(tester.takeException(), isNull);
    expect(analytics.events, isEmpty);
    expect(isolate.blockRequestCount, blockRequests);
  });

  testWidgets('reconnect bulk result after disposal cannot record success or reopen the connection', (tester) async {
    createProvider();
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    await tester.pump();
    final recordedEvents = analytics.events.length;
    final blockRequests = isolate.blockRequestCount;
    final bulkCompletion = Completer<Result<bool>>();
    isolate.onBulkSubscribe = (_) => bulkCompletion.future;
    final reconnect = provider!.reconnect();
    await tester.pump();
    expect(isolate.initializationCount, 2);

    provider!.dispose();
    provider = null;
    await tester.pump();
    bulkCompletion.complete(Result.success(true));
    await tester.pump();
    final result = await reconnect;
    await tester.pump(const Duration(seconds: 11));

    expect(result.isFailure, true);
    expect(tester.takeException(), isNull);
    expect(analytics.events, hasLength(recordedEvents));
    expect(isolate.initializationCount, 2);
    expect(isolate.blockRequestCount, blockRequests);
  });

  for (final initializationFails in [false, true]) {
    final failure = initializationFails ? 'initialization' : 'wallet subscription';
    testWidgets('a reconnect whose $failure fails keeps probing and reconnects again', (tester) async {
      createProvider();
      wallets.value = [_Wallet(1)];
      load.value = WalletLoadState.loadCompleted;
      await tester.pump();
      await tester.pump(const Duration(seconds: 2)); // the initial sync starts the block timer after 1 s
      isolate.onBlock = () async => Result.failure(ErrorCodes.nodeConnectionError); // the server stays unreachable
      if (initializationFails) {
        isolate.onInitialize = () async => throw StateError('server unreachable');
      } else {
        isolate.onBulkSubscribe = (_) async => Result.failure(ErrorCodes.nodeConnectionError);
      }

      final result = await provider!.reconnect();
      final initializations = isolate.initializationCount;
      await tester.pump(const Duration(seconds: 13)); // first probe after 10 s ±20%

      expect(result.isFailure, isTrue);
      expect(isolate.initializationCount, greaterThan(initializations), reason: 'nothing else would ever retry');
      expect(tester.takeException(), isNull);
      await provider!.closeConnection();
      provider!.dispose();
      provider = null;
      await tester.pump();
    });
  }

  // Review round 1 (Codex outage probe): during an outage the reconnects back off instead of every 10 s.
  group('reconnect backoff during an outage', () {
    late bool serverUp;

    /// A synced provider whose server then refuses connections. A block request succeeds only on a live isolate of a
    /// reachable server. Returns the initialization count after the first failed reconnect.
    Future<int> startOutage(WidgetTester tester) async {
      serverUp = true;
      isolate.onInitialize = () async {
        if (!serverUp) throw StateError('server refuses connection');
      };
      isolate.onBlock =
          () async =>
              serverUp && isolate.initialized
                  ? Result.success(BlockTimestamp(2, DateTime(2026)))
                  : Result.failure(ErrorCodes.nodeConnectionError);
      createProvider();
      wallets.value = [_Wallet(1)];
      load.value = WalletLoadState.loadCompleted;
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      serverUp = false;
      expect((await provider!.reconnect()).isFailure, isTrue);
      return isolate.initializationCount;
    }

    Future<void> close(WidgetTester tester) async {
      await provider!.closeConnection();
      provider!.dispose();
      provider = null;
      await tester.pump();
    }

    testWidgets('delays double from 10 s to a 5 min cap with ±20% jitter', (tester) async {
      final start = await startOutage(tester);
      var elapsed = 0;
      // Reconnect k happens after 10, 20, 40, 80, 160, 300 s (each ±20%), so these windows hold for any jitter.
      final expected = {7: 0, 13: 1, 23: 1, 37: 2, 55: 2, 85: 3, 119: 3, 181: 4, 247: 4, 373: 5, 487: 5, 733: 6};
      final observed = <int, int>{};
      for (final second in expected.keys) {
        await tester.pump(Duration(seconds: second - elapsed));
        elapsed = second;
        observed[second] = isolate.initializationCount - start;
      }
      expect(observed, expected);
      await close(tester);
    });

    testWidgets('a healthy connection resets the backoff', (tester) async {
      final start = await startOutage(tester);
      await tester.pump(const Duration(seconds: 37)); // two more failed reconnects; the next waits 40 s ±20%
      expect(isolate.initializationCount - start, 2);
      serverUp = true;
      await tester.pump(const Duration(seconds: 49));
      expect(isolate.initializationCount - start, 3, reason: 'the pending probe reconnected successfully');
      expect(provider!.hasConnectionError, isFalse);

      serverUp = false;
      expect((await provider!.reconnect()).isFailure, isTrue);
      final afterSecondOutage = isolate.initializationCount;
      await tester.pump(const Duration(seconds: 13));
      expect(isolate.initializationCount - afterSecondOutage, 1, reason: 'the delay starts over at 10 s');
      await close(tester);
    });

    testWidgets('no probe runs while the app is in the background', (tester) async {
      addTearDown(() => tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));
      final start = await startOutage(tester); // a probe is pending
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 10));
      expect(isolate.initializationCount, start, reason: 'the pending probe fires in the background and stops');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect((await provider!.reconnect()).isFailure, isTrue); // AppGuard reconnects on resume
      final afterResume = isolate.initializationCount;
      await tester.pump(const Duration(seconds: 25)); // the second failure in a row waits 20 s ±20%
      expect(isolate.initializationCount - afterResume, 1, reason: 'probing resumes in the foreground');
      await close(tester);
    });
  });

  for (final crossErrorZone in [false, true]) {
    test('overlapping initialization retries StateError across error zones=$crossErrorZone', () async {
      connectivity.online = false;
      createProvider();
      connectivity.online = true;
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final firstDone = Completer<void>();
      final secondDone = Completer<bool>();
      final failure = StateError('first initialization failed');
      final failureStack = StackTrace.fromString('original initialization failure stack');
      final uncaught = <Object>[];
      Object? firstError;
      StackTrace? firstStack;
      Object? secondError;
      isolate.onInitialize = () async {
        if (isolate.initializationCount == 1) {
          firstStarted.complete();
          await releaseFirst.future;
          Error.throwWithStackTrace(failure, failureStack);
        }
      };
      late Zone creationZone;
      runZonedGuarded(() {
        creationZone = Zone.current;
        unawaited(() async {
          try {
            await provider!.initialize();
          } catch (error, stack) {
            firstError = error;
            firstStack = stack;
          } finally {
            firstDone.complete();
          }
        }());
      }, (error, _) => uncaught.add(error));
      await firstStarted.future;
      final consumerZone =
          crossErrorZone
              ? creationZone.fork(
                specification: ZoneSpecification(handleUncaughtError: (_, __, ___, error, ____) => uncaught.add(error)),
              )
              : creationZone;
      expect(creationZone.inSameErrorZone(consumerZone), !crossErrorZone);
      consumerZone.run(() async {
        try {
          await provider!.initialize();
        } catch (error) {
          secondError = error;
        } finally {
          secondDone.complete(true);
        }
      });
      expect(isolate.initializationCount, 1, reason: 'the concurrent caller first waits for the pending attempt');
      releaseFirst.complete();
      await firstDone.future.timeout(const Duration(seconds: 2));
      final settled = await secondDone.future.timeout(const Duration(seconds: 2), onTimeout: () => false);

      expect(firstError, same(failure));
      expect(firstStack.toString(), failureStack.toString());
      expect(uncaught, isEmpty);
      expect(settled, true, reason: 'the waiting caller must retry without hanging');
      expect(secondError, isNull);
      expect(isolate.initializationCount, 2);
      expect(isolate.initialized, true);
      expect(provider!.isInitialized, true);
      expect(provider!.hasConnectionError, false);
      await provider!.closeConnection();
      expect(isolate.initialized, false, reason: 'the retried connection remains owned and can be closed');
    });
  }

  test('active initialization failures still propagate to their caller', () async {
    connectivity.online = false;
    createProvider();
    connectivity.online = true;
    isolate.onInitialize = () async => throw StateError('test initialization failure');

    await expectLater(provider!.initialize(), throwsStateError);
    expect(provider!.hasConnectionError, true);
  });

  // Nobody awaits these initializations: a failure they leave unhandled is an uncaught error, which fails the test.
  group('a self-started initialization handles its own failure', () {
    test('at construction', () async {
      isolate.onInitialize = () async => throw StateError('test initialization failure');
      createProvider();
      await pumpEventQueue();

      expect(isolate.initializationCount, 1);
      expect(provider!.hasConnectionError, true);
      expect(provider!.state.nodeSyncState, NodeSyncState.failed);
    });

    test('when connectivity returns, and does not reconnect after it', () async {
      connectivity.online = false;
      createProvider();
      isolate.onInitialize = () async => throw StateError('test initialization failure');
      connectivity.setOnline(true);
      await pumpEventQueue();

      expect(isolate.initializationCount, 1, reason: 'reconnect only follows a successful initialization');
      expect(provider!.hasConnectionError, true);
      expect(provider!.state.nodeSyncState, NodeSyncState.failed);
    });

    test('when going offline closes the connection before it completes', () async {
      final initialization = Completer<void>();
      connectivity.online = false;
      createProvider();
      isolate.onInitialize = () => initialization.future;
      connectivity.setOnline(true);
      await pumpEventQueue();
      connectivity.setOnline(false);
      await pumpEventQueue();
      initialization.completeError(Exception('Isolate was closed before initialization completed'));
      await pumpEventQueue();

      expect(isolate.initializationCount, 1);
      expect(provider!.hasConnectionError, true);
    });
  });

  group('wallet_bulk_sync_completed counts only real bulk syncs', () {
    int bulkCompleted() =>
        analytics.events.where((event) => event.name == AnalyticsEventNames.walletBulkSyncCompleted).length;
    int bulkFailed() =>
        analytics.events.where((event) => event.name == AnalyticsEventNames.walletBulkSyncFailed).length;

    test('is logged once when existing wallets are subscribed at startup', () async {
      await loadExistingWallets();

      expect(isolate.bulkSubscriptions, hasLength(1));
      expect(bulkCompleted(), 1);
    });

    test('is not logged when there are no wallets to subscribe', () async {
      createProvider();
      load.value = WalletLoadState.loadCompleted;
      await pumpEventQueue();

      expect(isolate.bulkSubscriptions, isEmpty);
      expect(bulkCompleted(), 0);
      expect(bulkFailed(), 0);
    });

    test('is not logged when the internet drops right before the startup subscription', () async {
      createProvider();
      await pumpEventQueue();
      // Dropped, but the connectivity listener has not run yet.
      connectivity.online = false;
      wallets.value = [_Wallet(1)];
      load.value = WalletLoadState.loadCompleted;
      await pumpEventQueue();

      expect(isolate.bulkSubscriptions, isEmpty);
      expect(bulkCompleted(), 0);
      expect(bulkFailed(), 0);
    });

    test('is not logged when the internet drops while reconnecting', () async {
      await loadExistingWallets();
      expect(bulkCompleted(), 1);
      isolate.onInitialize = () async {
        connectivity.online = false;
      };

      final result = await provider!.reconnect();

      expect(result.isSuccess, isTrue);
      expect(isolate.bulkSubscriptions, hasLength(1));
      expect(bulkCompleted(), 1);
      expect(bulkFailed(), 0);
    });
  });
}
