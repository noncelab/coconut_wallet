import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_event_names.dart';
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

  test('active initialization failures still propagate to their caller', () async {
    connectivity.online = false;
    createProvider();
    connectivity.online = true;
    isolate.onInitialize = () async => throw StateError('test initialization failure');

    await expectLater(provider!.initialize(), throwsStateError);
    expect(provider!.hasConnectionError, true);
  });
}
