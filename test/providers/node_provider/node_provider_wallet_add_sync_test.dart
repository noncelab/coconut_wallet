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
  @override
  Future<Result<SocketConnectionStatus>> getSocketConnectionStatus() async => Result.success(
    socketOverride ?? (initialized ? SocketConnectionStatus.connected : SocketConnectionStatus.terminated),
  );
  SocketConnectionStatus? socketOverride;
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

  testWidgets('send retry shares recovery after its previous wait timed out', (tester) async {
    createProvider();
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    await tester.pump();
    final completion = Completer<Result<bool>>();
    isolate.onBulkSubscribe = (_) => completion.future;
    final recovery = provider!.reconnect(reuseInFlight: true);
    await tester.pump();
    final count = isolate.initializationCount;
    final wait = recovery.timeout(
      const Duration(seconds: 15),
      onTimeout: () => Result.failure(ErrorCodes.nodeConnectionError),
    );
    await tester.pump(const Duration(seconds: 15));
    expect((await wait).isFailure, isTrue);
    final retry = provider!.reconnect(reuseInFlight: true);
    expect(identical(retry, recovery), isTrue);
    expect(isolate.initializationCount, count);
    completion.complete(Result.success(true));
    await tester.pump();
    expect((await retry).isSuccess, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await provider!.closeConnection();
    provider!.dispose();
    provider = null;
  });

  testWidgets('send connection becomes ready before slow wallet subscription completes', (tester) async {
    createProvider();
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    await tester.pump();
    final subscription = Completer<Result<bool>>();
    isolate.onBulkSubscribe = (_) => subscription.future;
    final count = isolate.initializationCount;
    final ready = await provider!.ensureConnectedForBroadcast(); // starts the recovery
    expect(ready.isSuccess, isTrue);
    expect(isolate.initializationCount, count + 1);
    final recovery = provider!.reconnect(reuseInFlight: true);
    bool syncFinished = false;
    recovery.then((_) => syncFinished = true);
    await tester.pump(const Duration(seconds: 16));
    expect(syncFinished, isFalse);
    // A retry probes first and proceeds on the live connection without another recovery.
    expect((await provider!.getLatestBlock()).isSuccess, isTrue);
    expect(isolate.initializationCount, count + 1);
    subscription.complete(Result.success(true));
    await tester.pump();
    expect((await recovery).isSuccess, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await provider!.closeConnection();
    provider!.dispose();
    provider = null;
  });

  testWidgets('send rejects readiness superseded by a server change', (tester) async {
    createProvider();
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    await tester.pump();
    final initialization = Completer<void>();
    isolate.onInitialize = () => initialization.future;
    Result<bool>? ready;
    provider!.ensureConnectedForBroadcast().then((value) => ready = value);
    await tester.pump();
    final change = provider!.applyServerChange();
    isolate.onInitialize = null;
    initialization.complete();
    await tester.pump();
    expect(ready?.isFailure, isTrue);
    expect((await change).isSuccess, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await provider!.closeConnection();
    provider!.dispose();
    provider = null;
  });

  for (final disposeWhileWaiting in [false, true]) {
    testWidgets('send shares pending initialization and rejects disposed recovery ($disposeWhileWaiting)', (
      tester,
    ) async {
      createProvider();
      await tester.pump();
      final initialized = Completer<void>();
      isolate.onInitialize = () => initialized.future;
      Result<bool>? first;
      Result<bool>? second;
      provider!.ensureConnectedForBroadcast().then((value) => first = value);
      await tester.pump();
      final count = isolate.initializationCount;
      provider!.ensureConnectedForBroadcast().then((value) => second = value);
      await tester.pump(const Duration(seconds: 16));
      expect(first, isNull);
      expect(second, isNull);
      expect(isolate.initializationCount, count);
      if (disposeWhileWaiting) {
        provider!.dispose();
        provider = null;
      }
      initialized.complete();
      await tester.pump();
      expect(first?.isSuccess, !disposeWhileWaiting);
      expect(second?.isSuccess, !disposeWhileWaiting);
      if (provider != null) {
        await tester.pump(const Duration(seconds: 1));
        await provider!.closeConnection();
        provider!.dispose();
        provider = null;
      }
    });
  }

  for (final fails in [false, true]) {
    testWidgets('send joins direct background initialization without reconnect (fails=$fails)', (tester) async {
      final initialization = Completer<void>();
      isolate.onInitialize = () => initialization.future;
      createProvider();
      await tester.pump();
      Result<bool>? outcome;
      provider!.ensureConnectedForBroadcast().then((value) => outcome = value);
      await tester.pump();
      expect(outcome, isNull);
      expect(isolate.initializationCount, 1);
      if (fails) {
        initialization.completeError(StateError('background initialization failed'));
      } else {
        initialization.complete();
      }
      await tester.pump();
      expect(outcome?.isSuccess, !fails);
      expect(isolate.initializationCount, 1);
      await tester.pump(const Duration(seconds: 1));
      await provider!.closeConnection();
      provider!.dispose();
      provider = null;
    });
  }

  // Network recovery initializes and then reconnects; senders must wait for the final connection.
  testWidgets('send waits for final restored-network connection before becoming ready', (tester) async {
    connectivity.online = false;
    createProvider();
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    await tester.pump();
    final initialization = Completer<void>();
    isolate.onInitialize = () => initialization.future;
    connectivity.setOnline(true); // _initializeInBackground(reconnectOnSuccess: true)
    await tester.pump();
    expect(isolate.initializationCount, 1);

    Result<bool>? outcome;
    provider!.ensureConnectedForBroadcast().then((value) => outcome = value);
    await tester.pump();
    expect(outcome, isNull, reason: 'joins the background initialization instead of failing at once');
    final finalInitialization = Completer<void>();
    final subscription = Completer<Result<bool>>();
    isolate.onInitialize = () => finalInitialization.future;
    isolate.onBulkSubscribe = (_) => subscription.future;
    initialization.complete();
    await tester.pump();
    expect(isolate.initializationCount, 2);
    expect(outcome, isNull, reason: 'intermediate initialization is not send-ready');
    finalInitialization.complete();
    await tester.pump();
    expect(outcome?.isSuccess, isTrue);
    // Slow subscription must not delay send readiness.
    subscription.complete(Result.success(true));
    await tester.pump();

    expect((await provider!.getLatestBlock()).isSuccess, isTrue);

    await tester.pump(const Duration(seconds: 1));
    await provider!.closeConnection();
    provider!.dispose();
    provider = null;
  });

  testWidgets('in-flight reconnect future resolves only after wallet subscription', (tester) async {
    createProvider();
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    await tester.pump();
    final completion = Completer<Result<bool>>();
    isolate.onBulkSubscribe = (_) => completion.future;
    final recovery = provider!.reconnect(reuseInFlight: true);
    await tester.pump();
    expect(isolate.initialized, isTrue);
    expect(
      (await provider!.getLatestBlock()).isSuccess,
      isTrue,
      reason: 'the connection is usable before the bulk sync ends',
    );
    Result<bool>? outcome;
    recovery
        .timeout(const Duration(seconds: 15), onTimeout: () => Result.failure(ErrorCodes.nodeConnectionError))
        .then((value) => outcome = value);
    await tester.pump(const Duration(seconds: 15));
    expect(outcome?.isFailure, isTrue, reason: 'the reconnect future still waits for the slow subscription');
    completion.complete(Result.success(true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await provider!.closeConnection();
    provider!.dispose();
    provider = null;
  });

  testWidgets('a newer reconnect supersedes the shared one and later shared callers join it', (tester) async {
    createProvider();
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    await tester.pump();
    final completion = Completer<Result<bool>>();
    isolate.onBulkSubscribe = (_) => completion.future;
    final shared = provider!.reconnect(reuseInFlight: true);
    await tester.pump();
    final newer = provider!.reconnect(); // e.g. applyServerChange / connectivity recovery
    expect(identical(newer, shared), isFalse);
    await tester.pump();
    expect(identical(provider!.reconnect(reuseInFlight: true), newer), isTrue);
    completion.complete(Result.success(true));
    await tester.pump();
    expect((await shared).isFailure, isTrue);
    expect((await newer).isSuccess, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await provider!.closeConnection();
    provider!.dispose();
    provider = null;
  });

  testWidgets('default reconnect still starts a new attempt while one is in flight', (tester) async {
    createProvider();
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    await tester.pump();
    final completion = Completer<Result<bool>>();
    isolate.onBulkSubscribe = (_) => completion.future;
    final first = provider!.reconnect();
    await tester.pump();
    final count = isolate.initializationCount;
    final second = provider!.reconnect();
    await tester.pump();
    expect(identical(first, second), isFalse);
    expect(isolate.initializationCount, count + 1);
    completion.complete(Result.success(true));
    await tester.pump();
    expect((await second).isSuccess, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await provider!.closeConnection();
    provider!.dispose();
    provider = null;
  });

  testWidgets('send readiness verifies socket state even after initialization succeeded', (tester) async {
    createProvider();
    await tester.pump();
    isolate.socketOverride = SocketConnectionStatus.terminated;
    final failed = await provider!.ensureConnectedForBroadcast();
    expect(failed.isFailure, isTrue);
    isolate.socketOverride = SocketConnectionStatus.connected;
    expect((await provider!.ensureConnectedForBroadcast()).isSuccess, isTrue);
    await provider!.closeConnection();
    provider!.dispose();
    provider = null;
  });

  testWidgets('certificate error survives reconnect readiness without becoming retryable', (tester) async {
    createProvider();
    await tester.pump();
    isolate.onInitialize = () async => throw ErrorCodes.untrustedCertificateError;
    final result = await provider!.ensureConnectedForBroadcast();
    expect(result.isFailure, isTrue);
    expect(result.error.code, ErrorCodes.untrustedCertificateError.code);
    await provider!.closeConnection();
    provider!.dispose();
    provider = null;
  });

  testWidgets('send retry after socket loss during bulk sync starts a fresh recovery', (tester) async {
    createProvider();
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    await tester.pump();
    final staleSubscription = Completer<Result<bool>>();
    isolate.onBulkSubscribe = (_) => staleSubscription.future;
    final stale = provider!.reconnect(); // readiness completes; the bulk sync stays pending
    await tester.pump();
    expect((await provider!.ensureConnectedForBroadcast()).isSuccess, isTrue);

    // The Electrum socket drops while the isolate stays alive, so the sender's probe fails.
    isolate.onBlock = () async => Result.failure(ErrorCodes.nodeConnectionError);
    expect((await provider!.getLatestBlock()).isFailure, isTrue);
    final count = isolate.initializationCount;
    isolate.onBulkSubscribe = null;

    final retry = await provider!.ensureConnectedForBroadcast();
    expect(retry.isSuccess, isTrue);
    expect(isolate.initializationCount, count + 1, reason: 'stale readiness must not be reused');

    staleSubscription.complete(Result.success(true));
    await tester.pump();
    expect((await stale).isFailure, isTrue, reason: 'the superseded reconnect cannot report success');
    await tester.pump(const Duration(seconds: 1));
    await provider!.closeConnection();
    provider!.dispose();
    provider = null;
  });

  testWidgets('send retry still shares a reconnect whose readiness is pending', (tester) async {
    createProvider();
    wallets.value = [_Wallet(1)];
    load.value = WalletLoadState.loadCompleted;
    await tester.pump();
    final initialization = Completer<void>();
    isolate.onInitialize = () => initialization.future;
    final count = isolate.initializationCount;
    Result<bool>? first;
    Result<bool>? second;
    provider!.ensureConnectedForBroadcast().then((value) => first = value);
    await tester.pump();
    provider!.ensureConnectedForBroadcast().then((value) => second = value);
    await tester.pump();
    expect(isolate.initializationCount, count + 1);
    isolate.onInitialize = null;
    initialization.complete();
    await tester.pump();
    expect(first?.isSuccess, isTrue);
    expect(second?.isSuccess, isTrue);
    expect(isolate.initializationCount, count + 1);
    await tester.pump(const Duration(seconds: 1));
    await provider!.closeConnection();
    provider!.dispose();
    provider = null;
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
