import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/network_constants.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:coconut_wallet/providers/view_model/home/home_connection_status_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

class _Wallet extends Mock implements WalletProvider {
  final ValueNotifier<WalletLoadState> loadState = ValueNotifier(WalletLoadState.never);
  final ValueNotifier<BlockTimestamp?> blockHeight = ValueNotifier(null);

  @override
  ValueNotifier<WalletLoadState> get walletLoadStateNotifier => loadState;

  @override
  ValueNotifier<BlockTimestamp?> get currentBlockHeightNotifier => blockHeight;
}

class _Node extends Mock implements NodeProvider {
  final List<VoidCallback> listeners = [];
  final ValueNotifier<BlockTimestamp?> block = ValueNotifier(null);
  bool connectionError = false;
  bool initializing = false;
  bool connectionEstablished = true;
  NodeSyncState currentSyncState = NodeSyncState.completed;
  late Stream<NodeSyncState> syncStream;
  Completer<void>? refreshing;
  int refreshCount = 0;
  bool refreshSucceeds = true;

  @override
  Future<bool> refreshWallets() async {
    refreshCount++;
    await refreshing?.future;
    return refreshSucceeds;
  }

  Future<bool>? startedRefresh;

  @override
  Future<bool>? get walletsRefresh => startedRefresh;

  @override
  void addListener(VoidCallback listener) => listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);

  @override
  ValueNotifier<BlockTimestamp?> get currentBlockNotifier => block;

  @override
  bool get hasConnectionError => connectionError;

  @override
  bool get isInitializing => initializing;

  @override
  bool get isConnected =>
      connectionEstablished && !initializing && !connectionError && currentSyncState != NodeSyncState.failed;

  @override
  NodeProviderState get state => NodeProviderState(nodeSyncState: currentSyncState, registeredWallets: {});

  @override
  Stream<NodeSyncState> get syncStateStream => syncStream;
}

class _Connectivity extends ChangeNotifier implements ConnectivityProvider {
  bool internetOn = true;
  bool vpnActive = false;

  @override
  bool get isInternetOn => internetOn;

  @override
  bool get isInternetOff => !internetOn;

  @override
  bool get isVpnActive => vpnActive;

  @override
  bool get isVpnInactive => !vpnActive;

  @override
  Future<void> refreshConnectivity() async {}

  void setInternet(bool on) {
    internetOn = on;
    notifyListeners();
  }

  void setVpn(bool active) {
    vpnActive = active;
    notifyListeners();
  }
}

class _WalletItem extends Mock implements WalletItemBase {
  @override
  int get id => 1;
}

class _ControlledIsolate extends Mock implements IsolateManager {
  final states = StreamController<IsolateStateMessage>.broadcast();
  Completer<void>? initialization;
  Completer<void>? closing;
  Completer<Result<BlockTimestamp>>? blockRequest;
  int initializeCount = 0;
  int subscribeCount = 0;
  final dormantSyncedWalletIds = <int>[];
  Completer<void>? dormantSync;
  Result<bool> dormantResult = Result.success(true);
  final subscribeGates = <Completer<void>>[];
  bool holdNextSubscribe = false;
  final subscribedWalletIds = <int>[];
  Result<bool> subscribeWalletResult = Result.success(true);

  @override
  Future<Result<bool>> subscribeWallet(WalletItemBase walletItem) async {
    subscribedWalletIds.add(walletItem.id);
    return subscribeWalletResult;
  }

  Completer<Result<bool>>? _heldSubscribe;

  @override
  Stream<IsolateStateMessage> get stateStream => states.stream;

  @override
  Future<void> initialize(String host, int port, bool ssl, NetworkType networkType, [String? fingerprint]) async {
    initializeCount++;
    await initialization?.future;
  }

  @override
  Future<void> closeIsolate() async {
    final held = _heldSubscribe;
    _heldSubscribe = null;
    if (held != null && !held.isCompleted) held.complete(Result.failure(ErrorCodes.nodeConnectionError));
    await closing?.future;
  }

  @override
  Future<Result<bool>> subscribeWallets(List<WalletItemBase> wallets) async {
    subscribeCount++;
    if (subscribeGates.isNotEmpty) await subscribeGates.removeAt(0).future;
    if (holdNextSubscribe) {
      holdNextSubscribe = false;
      final result = await (_heldSubscribe = Completer<Result<bool>>()).future;
      if (result.isFailure) return result;
    }
    states.add(IsolateStateMessage(IsolateStateMethod.setNodeSyncStateToCompleted, []));
    return Result.success(true);
  }

  @override
  Future<Result<bool>> syncDormantAddresses(WalletItemBase walletItem) async {
    dormantSyncedWalletIds.add(walletItem.id);
    await dormantSync?.future;
    return dormantResult;
  }

  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async =>
      blockRequest?.future ?? Result.success(BlockTimestamp(1, DateTime(2026)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Wallet wallet;
  late _Node node;
  late _Connectivity connectivity;
  late StreamController<NodeSyncState> sync;
  late ValueNotifier<List<WalletItemBase>> walletItems;

  void notifyNode() {
    for (final listener in List<VoidCallback>.of(node.listeners)) {
      listener();
    }
  }

  HomeConnectionStatusViewModel createViewModel() {
    final viewModel = HomeConnectionStatusViewModel(connectivity, node, walletItems);
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  /// 첫 진입 표시가 끝나 아무것도 보이지 않는 홈
  HomeConnectionStatusViewModel createSettledViewModel() {
    final viewModel = HomeConnectionStatusViewModel(connectivity, node, walletItems, showsInitialStatus: false);
    addTearDown(viewModel.dispose);
    sync.add(NodeSyncState.completed);
    return viewModel;
  }

  setUp(() {
    NetworkType.setNetworkType(NetworkType.mainnet);
    wallet = _Wallet();
    node = _Node();
    connectivity = _Connectivity();
    sync = StreamController<NodeSyncState>.broadcast(sync: true);
    node.syncStream = sync.stream;
    walletItems = ValueNotifier([_WalletItem()]);
  });

  tearDown(() {
    sync.close();
    node.block.dispose();
    wallet.loadState.dispose();
    wallet.blockHeight.dispose();
    walletItems.dispose();
  });

  for (final state in NodeSyncState.values) {
    for (final initializing in [false, true]) {
      test('VPN 감지가 남아도 오프라인이 우선한다: $state, initializing=$initializing', () {
        connectivity.vpnActive = true;
        final viewModel = createViewModel();
        sync.add(state);
        node.initializing = initializing;
        node.connectionError = true;

        connectivity.setInternet(false);

        expect(viewModel.networkStatus, NetworkStatus.offline);
        expect(viewModel.showElectrumReconnected, isFalse);
      });
    }
  }

  for (final cold in [false, true]) {
    testWidgets('VPN 감지가 남아도 실제 노드의 연결 종료·초기화 보류는 오프라인이다: cold=$cold', (tester) async {
      final isolate = _ControlledIsolate();
      final wallets = ValueNotifier<List<WalletItemBase>>([]);
      connectivity.internetOn = false;
      connectivity.vpnActive = true;
      final realNode = NodeProvider(
        ElectrumServer.custom('localhost', 50001, false),
        NetworkType.mainnet,
        connectivity,
        wallet.loadState,
        wallets,
        null,
        isolateManager: isolate,
      );
      if (!cold) {
        connectivity.internetOn = true;
        await realNode.initialize();
      }
      final viewModel = HomeConnectionStatusViewModel(connectivity, realNode, wallets);
      try {
        await tester.pump();
        if (!cold) {
          isolate.states.add(IsolateStateMessage(IsolateStateMethod.setNodeSyncStateToCompleted, []));
          await tester.pump();
          connectivity.setInternet(false);
          await tester.pump();
        }

        expect(realNode.isConnected, isFalse);
        expect(viewModel.networkStatus, NetworkStatus.offline);
        expect(viewModel.showElectrumReconnected, isFalse);
        await tester.pump(const Duration(seconds: 6));
        expect(viewModel.networkStatus, NetworkStatus.offline);
        expect(viewModel.showElectrumReconnected, isFalse);
      } finally {
        viewModel.dispose();
        realNode.dispose();
        await tester.pump();
        await isolate.states.close();
        wallets.dispose();
      }
    });
  }

  testWidgets('처음 진입해 바로 연결되면 연결됨을 보여 준 뒤 업데이트 완료로 넘어간다', (tester) async {
    final viewModel = createViewModel();
    sync.add(NodeSyncState.completed);

    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isTrue);
    await tester.pump(kHomeConnectedNoticeDuration);
    expect(viewModel.showElectrumReconnected, isFalse);
    expect(viewModel.showUpdateCompleted, isTrue);
    await tester.pump(kHomeUpdateCompletedNoticeDuration);
    expect(viewModel.showUpdateCompleted, isFalse);
  });

  testWidgets('실제 재연결 순서에서도 소켓 연결 성공 전에는 복구 문구를 켜지 않는다', (tester) async {
    final isolate = _ControlledIsolate();
    final wallets = ValueNotifier<List<WalletItemBase>>([_WalletItem()]);
    connectivity.internetOn = false;
    final realNode = NodeProvider(
      ElectrumServer.custom('localhost', 50001, false),
      NetworkType.mainnet,
      connectivity,
      wallet.loadState,
      wallets,
      null,
      isolateManager: isolate,
    );
    connectivity.internetOn = true;
    await realNode.initialize();
    final viewModel = HomeConnectionStatusViewModel(connectivity, realNode, wallets);
    try {
      await tester.pump();
      isolate.states.add(IsolateStateMessage(IsolateStateMethod.setNodeSyncStateToCompleted, []));
      await tester.pump();
      expect(viewModel.showElectrumReconnected, isTrue, reason: '첫 진입 연결');
      await tester.pump(kHomeConnectedNoticeDuration + kHomeUpdateCompletedNoticeDuration);
      expect(viewModel.showElectrumReconnected, isFalse);
      final blockRequest = Completer<Result<BlockTimestamp>>();
      isolate.blockRequest = blockRequest;
      wallet.loadState.value = WalletLoadState.loadCompleted;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      isolate.states.add(IsolateStateMessage(IsolateStateMethod.setNodeSyncStateToFailed, []));
      await tester.pump();
      isolate.states.add(IsolateStateMessage(IsolateStateMethod.setNodeSyncStateToCompleted, []));
      await tester.pump();
      expect(viewModel.showElectrumReconnected, isTrue);

      isolate.closing = Completer<void>();
      isolate.initialization = Completer<void>();
      isolate.blockRequest = null;
      blockRequest.complete(Result.failure(ErrorCodes.networkError));
      await tester.pump();
      expect(viewModel.showElectrumReconnected, isFalse, reason: '블록 요청 실패 후 재연결 시작은 연결 성공이 아니다');
      expect(viewModel.networkStatus, NetworkStatus.connectionFailed);

      isolate.closing!.complete();
      await tester.pump();
      expect(realNode.isInitializing, isTrue);
      expect(viewModel.showElectrumReconnected, isFalse);
      await tester.pump(const Duration(seconds: 3));
      expect(viewModel.showElectrumReconnected, isFalse);

      isolate.initialization!.complete();
      await tester.pump();
      expect(viewModel.showElectrumReconnected, isTrue);
      await tester.pump(kHomeConnectedNoticeDuration - const Duration(milliseconds: 100));
      expect(viewModel.showElectrumReconnected, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(viewModel.showElectrumReconnected, isFalse);
    } finally {
      if (isolate.closing != null && !isolate.closing!.isCompleted) isolate.closing!.complete();
      if (isolate.initialization != null && !isolate.initialization!.isCompleted) isolate.initialization!.complete();
      await tester.pump();
      viewModel.dispose();
      realNode.dispose();
      await tester.pump();
      await isolate.states.close();
      wallets.dispose();
    }
  });

  test('서버 연결 실패를 보여 준 뒤 다시 동기화되면 성공 문구를 켠다', () {
    final viewModel = createSettledViewModel();

    sync.add(NodeSyncState.failed);
    expect(viewModel.networkStatus, NetworkStatus.connectionFailed);
    expect(viewModel.showElectrumReconnected, isFalse);

    sync.add(NodeSyncState.syncing);
    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isTrue);
  });

  test('인터넷이 끊겼다가 돌아오면 성공 문구를 켠다', () {
    final viewModel = createSettledViewModel();

    connectivity.setInternet(false);
    expect(viewModel.networkStatus, NetworkStatus.offline);
    expect(viewModel.showElectrumReconnected, isFalse);

    connectivity.setInternet(true);
    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isTrue);
  });

  test('VPN 때문에 막혔다가 풀리면 성공 문구를 켠다', () {
    final viewModel = createSettledViewModel();
    sync.add(NodeSyncState.failed);
    connectivity.setVpn(true);
    notifyNode();

    expect(viewModel.networkStatus, NetworkStatus.vpnBlocked);
    expect(viewModel.showElectrumReconnected, isFalse);

    connectivity.setVpn(false);
    sync.add(NodeSyncState.syncing);
    expect(viewModel.showElectrumReconnected, isTrue);
  });

  test('재연결을 시작만 한 상태에서는 성공 문구를 켜지 않는다', () {
    final viewModel = createSettledViewModel();
    sync.add(NodeSyncState.failed);
    node.initializing = true;
    notifyNode();

    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isFalse);

    node.initializing = false;
    sync.add(NodeSyncState.syncing);
    expect(viewModel.showElectrumReconnected, isTrue);
  });

  test('오류가 없어도 실제 연결이 없으면 성공 문구를 켜지 않고, 연결 종료 시 안내를 취소한다', () {
    final viewModel = createSettledViewModel();
    connectivity.setInternet(false);
    node.connectionEstablished = false;
    connectivity.setInternet(true);
    expect(viewModel.showElectrumReconnected, isFalse);

    node.connectionEstablished = true;
    notifyNode();
    expect(viewModel.showElectrumReconnected, isTrue);

    node.connectionEstablished = false;
    notifyNode();
    expect(viewModel.showElectrumReconnected, isFalse);
  });

  test('실패 상태 알림이 동기화 스트림보다 먼저 와도 복구 중 재실패는 지연 없이 표시한다', () {
    final viewModel = createViewModel();
    connectivity.setInternet(false);
    connectivity.setInternet(true);
    expect(viewModel.showElectrumReconnected, isTrue);

    node.currentSyncState = NodeSyncState.failed;
    notifyNode();
    sync.add(NodeSyncState.failed);
    expect(viewModel.showElectrumReconnected, isFalse);
    expect(viewModel.networkStatus, NetworkStatus.connectionFailed);
  });

  test('동기화 중에도 연결 오류가 남아 있으면 성공 문구를 켜지 않는다', () {
    final viewModel = createSettledViewModel();
    sync.add(NodeSyncState.failed);
    node.connectionError = true;
    sync.add(NodeSyncState.syncing);

    expect(viewModel.showElectrumReconnected, isFalse);

    node.connectionError = false;
    notifyNode();
    expect(viewModel.showElectrumReconnected, isTrue);
  });

  testWidgets('연결됨은 잠깐 뒤 업데이트 완료로 바뀌고 같은 연결로는 다시 켜지지 않는다', (tester) async {
    final viewModel = createSettledViewModel();
    sync.add(NodeSyncState.failed);
    sync.add(NodeSyncState.completed);
    expect(viewModel.showElectrumReconnected, isTrue);

    await tester.pump(kHomeConnectedNoticeDuration);
    expect(viewModel.showElectrumReconnected, isFalse);
    expect(viewModel.showUpdateCompleted, isTrue);

    notifyNode();
    expect(viewModel.showElectrumReconnected, isFalse);
    await tester.pump(kHomeUpdateCompletedNoticeDuration);
  });

  testWidgets('성공 문구가 떠 있는 동안 다시 끊기면 끄고, 다음 복구 때 다시 켠다', (tester) async {
    final viewModel = createSettledViewModel();
    connectivity.setInternet(false);
    connectivity.setInternet(true);
    expect(viewModel.showElectrumReconnected, isTrue);

    connectivity.setInternet(false);
    expect(viewModel.showElectrumReconnected, isFalse);
    expect(viewModel.networkStatus, NetworkStatus.offline);

    connectivity.setInternet(true);
    expect(viewModel.showElectrumReconnected, isTrue);
    await tester.pump(kHomeConnectedNoticeDuration);
    await tester.pump(kHomeUpdateCompletedNoticeDuration);
  });

  test('첫 실행에서 실패가 지연으로 가려진 채 연결되면 첫 연결로 연결됨을 보여 준다', () {
    final viewModel = createViewModel();
    sync.add(NodeSyncState.failed);

    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isFalse);

    sync.add(NodeSyncState.syncing);
    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isTrue);
  });

  for (final useConnectionError in [false, true]) {
    testWidgets('복구 안내 중 ${useConnectionError ? '연결 오류' : '동기화 실패'}는 즉시 오류로 바꾸고 다음 복구까지 유지한다', (tester) async {
      final viewModel = createViewModel();
      connectivity.setInternet(false);
      connectivity.setInternet(true);
      expect(viewModel.showElectrumReconnected, isTrue);
      await tester.pump(const Duration(milliseconds: 500));

      if (useConnectionError) {
        node.connectionError = true;
        notifyNode();
      } else {
        sync.add(NodeSyncState.failed);
      }
      expect(viewModel.showElectrumReconnected, isFalse);
      expect(viewModel.networkStatus, NetworkStatus.connectionFailed);

      notifyNode();
      await tester.pump(const Duration(seconds: 2));
      expect(viewModel.networkStatus, NetworkStatus.connectionFailed);
      expect(viewModel.showElectrumReconnected, isFalse);
      connectivity.setVpn(true);
      expect(viewModel.networkStatus, NetworkStatus.vpnBlocked);
      connectivity.setVpn(false);

      node.initializing = true;
      node.connectionError = false;
      sync.add(NodeSyncState.init);
      notifyNode();
      expect(viewModel.showElectrumReconnected, isFalse);
      node.initializing = false;
      sync.add(NodeSyncState.syncing);
      expect(viewModel.networkStatus, NetworkStatus.online);
      expect(viewModel.showElectrumReconnected, isTrue);

      await tester.pump(kHomeConnectedNoticeDuration - const Duration(milliseconds: 100));
      expect(viewModel.showElectrumReconnected, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(viewModel.showElectrumReconnected, isFalse);

      sync.add(NodeSyncState.failed);
      expect(viewModel.networkStatus, NetworkStatus.online);
      expect(viewModel.showElectrumReconnected, isFalse);
      await tester.pump(kHomeErrorDisplayDelayDuration);
    });
  }

  test('처음 서버 연결 실패의 기존 5초 지연은 유지한다', () async {
    final viewModel = createViewModel();
    sync.add(NodeSyncState.failed);
    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 5100));
    expect(viewModel.networkStatus, NetworkStatus.connectionFailed);
    expect(viewModel.showElectrumReconnected, isFalse);
  });

  testWidgets('처음 진입하면 연결됨 → 업데이트 중 → 업데이트 완료 순서로 보여 준다', (tester) async {
    final viewModel = createViewModel();
    sync.add(NodeSyncState.syncing);
    expect(viewModel.showElectrumReconnected, isTrue);
    expect(viewModel.isSyncing, isFalse);

    await tester.pump(kHomeConnectedNoticeDuration);
    expect(viewModel.showElectrumReconnected, isFalse);
    expect(viewModel.isSyncing, isTrue);

    sync.add(NodeSyncState.completed);
    expect(viewModel.isSyncing, isFalse);
    expect(viewModel.showUpdateCompleted, isTrue);
    await tester.pump(kHomeUpdateCompletedNoticeDuration);
    expect(viewModel.showUpdateCompleted, isFalse);
  });

  testWidgets('홈이 지갑 로딩보다 먼저 만들어져도 지갑이 채워지면 첫 진입 순서를 보여 준다', (tester) async {
    final wallets = walletItems.value;
    walletItems.value = [];
    final viewModel = createViewModel();
    sync.add(NodeSyncState.completed);
    expect(viewModel.showElectrumReconnected, isFalse);

    walletItems.value = wallets;
    sync.add(NodeSyncState.syncing);
    expect(viewModel.showElectrumReconnected, isTrue);

    await tester.pump(kHomeConnectedNoticeDuration);
    expect(viewModel.isSyncing, isTrue);
    sync.add(NodeSyncState.completed);
    expect(viewModel.showUpdateCompleted, isTrue);
    await tester.pump(kHomeUpdateCompletedNoticeDuration);
  });

  test('첫 동기화가 끝난 뒤 다시 동기화할 때는 동기화 표시를 켜지 않는다', () {
    final viewModel = createViewModel();
    sync.add(NodeSyncState.syncing);
    sync.add(NodeSyncState.completed);
    sync.add(NodeSyncState.syncing);

    expect(viewModel.isSyncing, isFalse);
  });

  test('지갑이 없으면 동기화 중이거나 첫 연결 실패를 기다리는 동안에도 동기화 표시를 켜지 않는다', () {
    walletItems.value = [];
    final viewModel = createViewModel();
    sync.add(NodeSyncState.syncing);
    expect(viewModel.isSyncing, isFalse);

    sync.add(NodeSyncState.failed);
    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.isSyncing, isFalse);
  });

  testWidgets('첫 화면 진입 전에 생긴 연결 오류도 5초 뒤 알림을 보내 오류로 바꾼다', (tester) async {
    node.connectionError = true;
    node.currentSyncState = NodeSyncState.failed;
    sync.add(NodeSyncState.failed);
    final viewModel = createViewModel();
    var notified = false;
    viewModel.addListener(() => notified = true);
    sync.add(NodeSyncState.failed);
    expect(viewModel.isSyncing, isTrue);

    await tester.pump(kHomeErrorDisplayDelayDuration);
    expect(notified, isTrue);
    expect(viewModel.isSyncing, isFalse);
    expect(viewModel.networkStatus, NetworkStatus.connectionFailed);
  });

  testWidgets('당겨서 새로고침하면 다시 연결된 뒤 연결됨 → 업데이트 중 → 업데이트 완료를 한 번씩 보여 준다', (tester) async {
    final viewModel = createSettledViewModel();
    node.refreshing = Completer<void>();

    final refresh = viewModel.refresh();
    expect(node.refreshCount, 1);
    expect(viewModel.showElectrumReconnected, isFalse, reason: '닫기 전의 기존 연결로는 켜지 않는다');

    node.connectionEstablished = false;
    sync.add(NodeSyncState.init);
    notifyNode();
    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isFalse);

    node.connectionEstablished = true;
    sync.add(NodeSyncState.syncing);
    expect(viewModel.showElectrumReconnected, isTrue);

    await tester.pump(kHomeConnectedNoticeDuration);
    expect(viewModel.showElectrumReconnected, isFalse);
    expect(viewModel.isSyncing, isTrue);

    sync.add(NodeSyncState.completed);
    node.refreshing!.complete();
    await refresh;
    expect(viewModel.isSyncing, isFalse);
    expect(viewModel.showElectrumReconnected, isFalse);
    expect(viewModel.showUpdateCompleted, isTrue);

    await tester.pump(kHomeUpdateCompletedNoticeDuration);
    expect(viewModel.showUpdateCompleted, isFalse);
  });

  testWidgets('연결 실패를 보여 주던 중 새로고침으로 복구되면 업데이트 완료를 보여 준다', (tester) async {
    final viewModel = createSettledViewModel();
    sync.add(NodeSyncState.failed);
    expect(viewModel.networkStatus, NetworkStatus.connectionFailed);
    node.refreshing = Completer<void>();

    final refresh = viewModel.refresh();
    sync.add(NodeSyncState.syncing);
    sync.add(NodeSyncState.completed);
    node.refreshing!.complete();
    await refresh;

    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isFalse);
    expect(viewModel.showUpdateCompleted, isTrue);
    await tester.pump(kHomeUpdateCompletedNoticeDuration);
  });

  testWidgets('새로고침이 끝나면 업데이트 완료를 잠깐 보여 준 뒤 감춘다', (tester) async {
    final viewModel = createSettledViewModel();
    node.refreshing = Completer<void>();

    final refresh = viewModel.refresh();
    expect(viewModel.showUpdateCompleted, isFalse);
    node.refreshing!.complete();
    await refresh;
    expect(viewModel.showUpdateCompleted, isTrue);
    expect(viewModel.isSyncing, isFalse);

    await tester.pump(kHomeUpdateCompletedNoticeDuration - const Duration(milliseconds: 100));
    expect(viewModel.showUpdateCompleted, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(viewModel.showUpdateCompleted, isFalse);
  });

  test('새로고침이 연결 실패로 끝나면 업데이트 완료를 보여 주지 않는다', () async {
    final viewModel = createSettledViewModel();
    node.refreshing = Completer<void>();

    final refresh = viewModel.refresh();
    node.connectionError = true;
    node.currentSyncState = NodeSyncState.failed;
    sync.add(NodeSyncState.failed);
    node.refreshing!.complete();
    await refresh;

    expect(viewModel.showUpdateCompleted, isFalse);
    expect(viewModel.networkStatus, NetworkStatus.connectionFailed);
  });

  test('새로고침 중에 다시 당겨도 서버 동기화는 한 번만 시작한다', () async {
    final viewModel = createSettledViewModel();
    node.refreshing = Completer<void>();

    final first = viewModel.refresh();
    final second = viewModel.refresh();
    expect(node.refreshCount, 1);

    node.refreshing!.complete();
    await Future.wait([first, second]);
    expect(viewModel.isSyncing, isFalse);
  });

  testWidgets('앱 복귀처럼 다른 곳에서 시작한 재동기화도 연결됨 → 업데이트 중 → 업데이트 완료로 보여 준다', (tester) async {
    final viewModel = createSettledViewModel();
    final started = Completer<bool>();
    node.startedRefresh = started.future;
    notifyNode();
    expect(node.refreshCount, 0);

    node.connectionEstablished = false;
    sync.add(NodeSyncState.init);
    notifyNode();
    expect(viewModel.showElectrumReconnected, isFalse);

    node.connectionEstablished = true;
    sync.add(NodeSyncState.syncing);
    expect(viewModel.showElectrumReconnected, isTrue);
    await tester.pump(kHomeConnectedNoticeDuration);
    expect(viewModel.isSyncing, isTrue);

    sync.add(NodeSyncState.completed);
    node.startedRefresh = null;
    started.complete(true);
    await tester.pump();
    expect(viewModel.showUpdateCompleted, isTrue);

    final refresh = viewModel.refresh();
    expect(node.refreshCount, 1, reason: '끝난 재동기화는 다시 따라가지 않는다');
    await refresh;
    await tester.pump(kHomeUpdateCompletedNoticeDuration);
  });

  testWidgets('노드 동기화가 끝나도 휴면 주소 확인까지 새로고침이 끝나야 업데이트 완료를 보여 준다', (tester) async {
    final viewModel = createSettledViewModel();
    node.refreshing = Completer<void>();

    final refresh = viewModel.refresh();
    node.connectionEstablished = false;
    sync.add(NodeSyncState.init);
    notifyNode();
    node.connectionEstablished = true;
    sync.add(NodeSyncState.syncing);
    sync.add(NodeSyncState.completed);
    expect(viewModel.showElectrumReconnected, isTrue);

    await tester.pump(kHomeConnectedNoticeDuration);
    expect(viewModel.isSyncing, isTrue);
    expect(viewModel.showUpdateCompleted, isFalse);

    node.refreshing!.complete();
    await refresh;
    expect(viewModel.isSyncing, isFalse);
    expect(viewModel.showUpdateCompleted, isTrue);
    await tester.pump(kHomeUpdateCompletedNoticeDuration);
  });

  testWidgets('다시 연결한 뒤 새로고침이 실패로 끝나면 업데이트 완료를 보여 주지 않는다', (tester) async {
    final viewModel = createSettledViewModel();
    node.refreshing = Completer<void>();
    node.refreshSucceeds = false;

    final refresh = viewModel.refresh();
    node.connectionEstablished = false;
    sync.add(NodeSyncState.init);
    notifyNode();
    node.connectionEstablished = true;
    sync.add(NodeSyncState.syncing);
    sync.add(NodeSyncState.completed);
    await tester.pump(kHomeConnectedNoticeDuration);
    expect(viewModel.isSyncing, isTrue);

    node.refreshing!.complete();
    await refresh;
    expect(viewModel.showUpdateCompleted, isFalse);
    expect(viewModel.isSyncing, isFalse);
    await tester.pump(kHomeUpdateCompletedNoticeDuration);
    expect(viewModel.showUpdateCompleted, isFalse);
  });

  testWidgets('기다리던 동기화가 대기 시간을 넘겨도 끝나지 않았으면 업데이트 중을 유지하고, 끝난 뒤에 업데이트 완료를 보여 준다', (tester) async {
    final viewModel = createSettledViewModel();
    node.currentSyncState = NodeSyncState.syncing;
    sync.add(NodeSyncState.syncing);
    node.refreshing = Completer<void>();
    node.refreshSucceeds = false;

    final refresh = viewModel.refresh();
    expect(viewModel.isSyncing, isTrue, reason: '기다리는 동안에도 업데이트 중을 보여 준다');
    expect(viewModel.showElectrumReconnected, isFalse);
    node.refreshing!.complete();
    await refresh;
    expect(viewModel.showUpdateCompleted, isFalse);
    expect(viewModel.isSyncing, isTrue);

    node.currentSyncState = NodeSyncState.completed;
    sync.add(NodeSyncState.completed);
    expect(viewModel.showUpdateCompleted, isTrue);
    await tester.pump(kHomeUpdateCompletedNoticeDuration);
  });

  test('VPN 감지가 남은 오프라인에서 새로고침이 실패하면 업데이트 완료를 보여 주지 않는다', () async {
    final viewModel = createSettledViewModel();
    connectivity.vpnActive = true;
    connectivity.setInternet(false);
    expect(viewModel.networkStatus, NetworkStatus.offline);
    node.refreshSucceeds = false;

    await viewModel.refresh();

    expect(viewModel.showUpdateCompleted, isFalse);
    expect(viewModel.isSyncing, isFalse);
  });

  group('NodeProvider.refreshWallets', () {
    late _ControlledIsolate isolate;
    late ValueNotifier<List<WalletItemBase>> wallets;
    late NodeProvider realNode;

    Future<void> startConnected(WidgetTester tester) async {
      isolate = _ControlledIsolate();
      wallets = ValueNotifier<List<WalletItemBase>>([_WalletItem()]);
      connectivity.internetOn = false;
      realNode = NodeProvider(
        ElectrumServer.custom('localhost', 50001, false),
        NetworkType.mainnet,
        connectivity,
        wallet.loadState,
        wallets,
        null,
        isolateManager: isolate,
      );
      connectivity.internetOn = true;
      await realNode.initialize();
      wallet.loadState.value = WalletLoadState.loadCompleted;
      await tester.pump(const Duration(seconds: 1));
      isolate.states.add(IsolateStateMessage(IsolateStateMethod.setNodeSyncStateToCompleted, []));
      await tester.pump();
    }

    Future<void> stop(WidgetTester tester) async {
      realNode.dispose();
      await tester.pump();
      await isolate.states.close();
      wallets.dispose();
    }

    testWidgets('연결을 다시 맺어 지갑을 다시 구독하고 휴면 주소도 확인한다', (tester) async {
      await startConnected(tester);
      try {
        final initialized = isolate.initializeCount;
        final subscribed = isolate.subscribeCount;

        var done = false;
        unawaited(realNode.refreshWallets().then((_) => done = true));
        for (var i = 0; i < 10 && !done; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(done, isTrue);

        expect(isolate.initializeCount, initialized + 1);
        expect(isolate.subscribeCount, subscribed + 1);
        expect(isolate.dormantSyncedWalletIds, [1]);
        expect(await realNode.refreshWallets(), isTrue);
      } finally {
        await stop(tester);
      }
    });

    testWidgets('휴면 주소 확인은 기다리지 않고, 느리거나 실패해도 성공으로 끝난다', (tester) async {
      await startConnected(tester);
      try {
        isolate.dormantSync = Completer<void>();
        isolate.dormantResult = Result.failure(ErrorCodes.networkError);
        bool? result;
        unawaited(realNode.refreshWallets().then((value) => result = value));
        for (var i = 0; i < 10 && result == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(result, isTrue);
        expect(isolate.dormantSyncedWalletIds, [1], reason: '휴면 주소 확인은 백그라운드에서 시작한다');
        expect(realNode.walletsRefresh, isNull);
        isolate.dormantSync!.complete();
      } finally {
        await stop(tester);
      }
    });

    testWidgets('진행 중인 재연결의 재구독 중에 서버를 바꾸면 합치지 않고 다시 연결하고, 새로고침은 그 재연결까지 기다린다', (tester) async {
      await startConnected(tester);
      try {
        final initialized = isolate.initializeCount;
        final firstSubscribe = Completer<void>();
        final secondSubscribe = Completer<void>();
        isolate.subscribeGates.addAll([firstSubscribe, secondSubscribe]);

        unawaited(realNode.reconnect());
        await tester.pump(const Duration(milliseconds: 100));
        expect(isolate.initializeCount, initialized + 1);

        bool? result;
        unawaited(realNode.refreshWallets().then((value) => result = value));
        await tester.pump(const Duration(milliseconds: 100));

        unawaited(realNode.applyServerChange());
        await tester.pump(const Duration(milliseconds: 100));
        expect(isolate.initializeCount, initialized + 2, reason: '서버 변경은 진행 중인 재연결에 합치지 않는다');

        firstSubscribe.complete();
        await tester.pump(const Duration(milliseconds: 100));
        expect(result, isNull, reason: '새로고침은 더 새로운 재연결까지 기다린다');

        secondSubscribe.complete();
        for (var i = 0; i < 10 && result == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(result, isTrue);
      } finally {
        await stop(tester);
      }
    });

    testWidgets('진행 중인 재연결이 초기화 중일 때 서버를 바꾸면 초기화가 끝난 뒤 다시 연결한다', (tester) async {
      await startConnected(tester);
      try {
        final initialized = isolate.initializeCount;
        isolate.initialization = Completer<void>();
        unawaited(realNode.reconnect());
        await tester.pump(const Duration(milliseconds: 100));
        expect(isolate.initializeCount, initialized + 1);

        Result<bool>? applied;
        unawaited(realNode.applyServerChange().then((value) => applied = value));
        await tester.pump(const Duration(milliseconds: 100));
        expect(applied, isNull, reason: '초기화 중이라고 건너뛰지 않고 기다린다');

        isolate.initialization!.complete();
        for (var i = 0; i < 10 && applied == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(applied?.isSuccess, isTrue);
        expect(isolate.initializeCount, initialized + 2, reason: '바뀐 엔드포인트로 다시 초기화한다');
      } finally {
        await stop(tester);
      }
    });

    testWidgets('진행 중인 재연결이 오래 걸려도 새로고침은 대기 상한이 지나면 실패로 끝난다', (tester) async {
      await startConnected(tester);
      try {
        final gate = Completer<void>();
        isolate.subscribeGates.add(gate);
        unawaited(realNode.reconnect());
        await tester.pump(const Duration(milliseconds: 100));

        bool? result;
        unawaited(realNode.refreshWallets().then((value) => result = value));
        await tester.pump(kNodeRefreshWaitTimeout - const Duration(seconds: 1));
        expect(result, isNull);
        await tester.pump(const Duration(seconds: 2));
        expect(result, isFalse);
        expect(realNode.walletsRefresh, isNull);

        gate.complete();
        await tester.pump(kNodeRefreshWaitTimeout);
      } finally {
        await stop(tester);
      }
    });

    testWidgets('새 재연결에 밀려난 재연결은 실패 상태와 연결 오류를 남기지 않는다', (tester) async {
      await startConnected(tester);
      try {
        final syncStates = <NodeSyncState>[];
        final connectionErrors = <bool>[];
        void record() {
          syncStates.add(realNode.state.nodeSyncState);
          connectionErrors.add(realNode.hasConnectionError);
        }

        realNode.addListener(record);
        isolate.holdNextSubscribe = true;
        Result<bool>? superseded;
        unawaited(realNode.reconnect().then((value) => superseded = value));
        await tester.pump(const Duration(milliseconds: 100));
        expect(superseded, isNull, reason: '첫 재연결은 재구독 단계에서 대기 중');

        Result<bool>? applied;
        unawaited(realNode.applyServerChange().then((value) => applied = value));
        for (var i = 0; i < 10 && applied == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        realNode.removeListener(record);

        expect(superseded?.isFailure, isTrue, reason: '닫힌 isolate의 재구독은 실패로 돌아온다');
        expect(applied?.isSuccess, isTrue);
        expect(syncStates, isNot(contains(NodeSyncState.failed)));
        expect(connectionErrors, isNot(contains(true)));
      } finally {
        await stop(tester);
      }
    });

    testWidgets('연결이 정상이면 지갑 하나만 다시 구독하고 재연결하지 않는다', (tester) async {
      await startConnected(tester);
      try {
        final initialized = isolate.initializeCount;
        final subscribed = isolate.subscribeCount;
        final wallet = wallets.value.single;

        bool? result;
        unawaited(realNode.refreshWallet(wallet).then((value) => result = value));
        for (var i = 0; i < 10 && result == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(result, isTrue);
        expect(isolate.subscribedWalletIds, [wallet.id]);
        expect(isolate.initializeCount, initialized, reason: '연결을 다시 맺지 않는다');
        expect(isolate.subscribeCount, subscribed, reason: '모든 지갑을 다시 구독하지 않는다');
        expect(isolate.dormantSyncedWalletIds, [wallet.id]);
      } finally {
        await stop(tester);
      }
    });

    testWidgets('지갑 하나만 다시 구독하다 실패하면 전체 재연결로 넘어간다', (tester) async {
      await startConnected(tester);
      try {
        final initialized = isolate.initializeCount;
        isolate.subscribeWalletResult = Result.failure(ErrorCodes.nodeConnectionError);

        bool? result;
        unawaited(realNode.refreshWallet(wallets.value.single).then((value) => result = value));
        for (var i = 0; i < 20 && result == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(result, isTrue);
        expect(isolate.initializeCount, initialized + 1);
      } finally {
        await stop(tester);
      }
    });

    testWidgets('연결에 문제가 있으면 지갑 하나가 아니라 전체 재연결한다', (tester) async {
      await startConnected(tester);
      try {
        final initialized = isolate.initializeCount;
        isolate.states.add(IsolateStateMessage(IsolateStateMethod.setNodeSyncStateToFailed, []));
        await tester.pump();

        bool? result;
        unawaited(realNode.refreshWallet(wallets.value.single).then((value) => result = value));
        for (var i = 0; i < 20 && result == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(isolate.subscribedWalletIds, isEmpty);
        expect(isolate.initializeCount, initialized + 1);
      } finally {
        await stop(tester);
      }
    });

    testWidgets('다른 재연결이 연결을 닫는 중이면 그 재연결과 재구독이 끝난 뒤에 끝난다', (tester) async {
      await startConnected(tester);
      try {
        final initialized = isolate.initializeCount;
        final subscribed = isolate.subscribeCount;
        isolate.closing = Completer<void>();
        unawaited(realNode.reconnect());
        await tester.pump();

        bool? result;
        unawaited(realNode.refreshWallets().then((value) => result = value));
        await tester.pump(const Duration(seconds: 1));
        expect(result, isNull, reason: '닫히기 전 연결의 completed로 끝내지 않는다');

        isolate.closing!.complete();
        isolate.closing = null;
        for (var i = 0; i < 20 && result == null; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(result, isTrue);
        expect(isolate.initializeCount, initialized + 1, reason: '진행 중인 재연결을 공유한다');
        expect(isolate.subscribeCount, subscribed + 1);
      } finally {
        await stop(tester);
      }
    });

    testWidgets('기다리던 동기화가 대기 시간 안에 끝나지 않으면 실패로 끝난다', (tester) async {
      await startConnected(tester);
      try {
        isolate.states.add(IsolateStateMessage(IsolateStateMethod.setNodeSyncStateToSyncing, []));
        await tester.pump();

        bool? result;
        unawaited(realNode.refreshWallets().then((value) => result = value));
        await tester.pump(kNodeRefreshWaitTimeout + const Duration(seconds: 1));
        for (var i = 0; i < 10 && result == null; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
        }
        expect(result, isFalse);
      } finally {
        await stop(tester);
      }
    });

    test('인터넷이 꺼져 있으면 아무것도 하지 않고 실패로 끝난다', () async {
      final isolate = _ControlledIsolate();
      final wallets = ValueNotifier<List<WalletItemBase>>([_WalletItem()]);
      connectivity.internetOn = false;
      final offlineNode = NodeProvider(
        ElectrumServer.custom('localhost', 50001, false),
        NetworkType.mainnet,
        connectivity,
        wallet.loadState,
        wallets,
        null,
        isolateManager: isolate,
      );
      addTearDown(() async {
        offlineNode.dispose();
        await isolate.states.close();
        wallets.dispose();
      });

      expect(await offlineNode.refreshWallets(), isFalse);
      expect(offlineNode.walletsRefresh, isNull);
      expect(isolate.initializeCount, 0);
    });

    testWidgets('동시에 여러 곳에서 요청해도 한 번만 다시 연결하고, 진행 중인 재동기화를 알린다', (tester) async {
      await startConnected(tester);
      try {
        final initialized = isolate.initializeCount;
        var notified = 0;
        realNode.addListener(() => notified++);

        final first = realNode.refreshWallets();
        final second = realNode.refreshWallets();
        expect(identical(first, second), isTrue);
        expect(realNode.walletsRefresh, same(first));
        expect(notified, greaterThan(0));

        var done = false;
        unawaited(first.then((_) => done = true));
        for (var i = 0; i < 10 && !done; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(done, isTrue);
        expect(isolate.initializeCount, initialized + 1);
        expect(realNode.walletsRefresh, isNull);
      } finally {
        await stop(tester);
      }
    });

    testWidgets('이미 동기화 중이면 새로 연결하지 않고 끝날 때까지 기다린다', (tester) async {
      await startConnected(tester);
      try {
        final initialized = isolate.initializeCount;
        isolate.states.add(IsolateStateMessage(IsolateStateMethod.setNodeSyncStateToSyncing, []));
        await tester.pump();

        var done = false;
        unawaited(realNode.refreshWallets().then((_) => done = true));
        await tester.pump(const Duration(seconds: 1));
        expect(done, isFalse);

        isolate.states.add(IsolateStateMessage(IsolateStateMethod.setNodeSyncStateToCompleted, []));
        for (var i = 0; i < 10 && !done; i++) {
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
        }
        expect(done, isTrue);
        expect(isolate.initializeCount, initialized);
      } finally {
        await stop(tester);
      }
    });
  });
}
