import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_home_view_model.dart';
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
  Map<int, Balance> fetchWalletBalanceMap() => {};

  @override
  ValueNotifier<WalletLoadState> get walletLoadStateNotifier => loadState;

  @override
  ValueNotifier<BlockTimestamp?> get currentBlockHeightNotifier => blockHeight;
}

class _Preference extends Mock implements PreferenceProvider {
  @override
  bool isHomeFeatureEnabled(HomeFeatureType type) => false;

  @override
  bool get isBalanceHidden => false;

  @override
  bool get isFiatBalanceHidden => false;

  @override
  int? get fakeBalanceTotalAmount => null;

  @override
  Map<int, dynamic> getFakeBalanceMap() => {};

  @override
  List<int> get excludedFromTotalBalanceWalletIds => const [];

  @override
  int get analysisPeriod => 30;

  @override
  AnalysisTransactionType get selectedAnalysisTransactionType => AnalysisTransactionType.all;

  @override
  bool get isManualUtxoSelectionMode => false;
}

class _Node extends Mock implements NodeProvider {
  final List<VoidCallback> listeners = [];
  final ValueNotifier<BlockTimestamp?> block = ValueNotifier(null);
  bool connectionError = false;
  bool initializing = false;
  bool connectionEstablished = true;
  NodeSyncState currentSyncState = NodeSyncState.completed;
  late Stream<NodeSyncState> syncStream;

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

class _WalletItem extends Mock implements WalletItemBase {}

class _ControlledIsolate extends Mock implements IsolateManager {
  final states = StreamController<IsolateStateMessage>.broadcast();
  Completer<void>? initialization;
  Completer<void>? closing;
  Completer<Result<BlockTimestamp>>? blockRequest;

  @override
  Stream<IsolateStateMessage> get stateStream => states.stream;

  @override
  Future<void> initialize(String host, int port, bool ssl, NetworkType networkType, [String? fingerprint]) async {
    await initialization?.future;
  }

  @override
  Future<void> closeIsolate() async {
    await closing?.future;
  }

  @override
  Future<Result<bool>> subscribeWallets(List<WalletItemBase> wallets) async => Result.success(true);

  @override
  Future<Result<BlockTimestamp>> getLatestBlock() async =>
      blockRequest?.future ?? Result.success(BlockTimestamp(1, DateTime(2026)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Wallet wallet;
  late _Preference preference;
  late _Node node;
  late _Connectivity connectivity;
  late StreamController<NodeSyncState> sync;

  void notifyNode() {
    for (final listener in List<VoidCallback>.of(node.listeners)) {
      listener();
    }
  }

  WalletHomeViewModel createViewModel() {
    final viewModel = WalletHomeViewModel(wallet, preference, connectivity, node);
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  setUp(() {
    NetworkType.setNetworkType(NetworkType.mainnet);
    wallet = _Wallet();
    preference = _Preference();
    node = _Node();
    connectivity = _Connectivity();
    sync = StreamController<NodeSyncState>.broadcast(sync: true);
    node.syncStream = sync.stream;
  });

  tearDown(() {
    sync.close();
    node.block.dispose();
    wallet.loadState.dispose();
    wallet.blockHeight.dispose();
  });

  test('처음부터 연결되면 성공 문구를 켜지 않는다', () {
    final viewModel = createViewModel();

    sync.add(NodeSyncState.completed);
    viewModel.setEditWidgetMode(true);

    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isFalse);
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
    final viewModel = WalletHomeViewModel(wallet, preference, connectivity, realNode);
    try {
      await tester.pump();
      isolate.states.add(IsolateStateMessage(IsolateStateMethod.setNodeSyncStateToCompleted, []));
      await tester.pump();
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
      await tester.pump(const Duration(milliseconds: 1900));
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
    final viewModel = createViewModel();
    sync.add(NodeSyncState.completed);

    sync.add(NodeSyncState.failed);
    expect(viewModel.networkStatus, NetworkStatus.connectionFailed);
    expect(viewModel.showElectrumReconnected, isFalse);

    sync.add(NodeSyncState.syncing);
    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isTrue);
  });

  test('인터넷이 끊겼다가 돌아오면 성공 문구를 켠다', () {
    final viewModel = createViewModel();
    sync.add(NodeSyncState.completed);

    connectivity.setInternet(false);
    expect(viewModel.networkStatus, NetworkStatus.offline);
    expect(viewModel.showElectrumReconnected, isFalse);

    connectivity.setInternet(true);
    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isTrue);
  });

  test('VPN 때문에 막혔다가 풀리면 성공 문구를 켠다', () {
    final viewModel = createViewModel();
    sync.add(NodeSyncState.completed);
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
    final viewModel = createViewModel();
    sync.add(NodeSyncState.completed);
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
    final viewModel = createViewModel();
    sync.add(NodeSyncState.completed);
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
    final viewModel = createViewModel();
    sync.add(NodeSyncState.completed);
    sync.add(NodeSyncState.failed);
    node.connectionError = true;
    sync.add(NodeSyncState.syncing);

    expect(viewModel.showElectrumReconnected, isFalse);

    node.connectionError = false;
    notifyNode();
    expect(viewModel.showElectrumReconnected, isTrue);
  });

  testWidgets('성공 문구는 2초 뒤에 사라지고 같은 연결로는 다시 켜지지 않는다', (tester) async {
    final viewModel = createViewModel();
    sync.add(NodeSyncState.completed);
    sync.add(NodeSyncState.failed);
    sync.add(NodeSyncState.completed);
    expect(viewModel.showElectrumReconnected, isTrue);

    await tester.pump(kElectrumReconnectedNoticeDuration);
    expect(viewModel.showElectrumReconnected, isFalse);

    notifyNode();
    expect(viewModel.showElectrumReconnected, isFalse);
  });

  testWidgets('성공 문구가 떠 있는 동안 다시 끊기면 끄고, 다음 복구 때 다시 켠다', (tester) async {
    final viewModel = createViewModel();
    sync.add(NodeSyncState.completed);
    connectivity.setInternet(false);
    connectivity.setInternet(true);
    expect(viewModel.showElectrumReconnected, isTrue);

    connectivity.setInternet(false);
    expect(viewModel.showElectrumReconnected, isFalse);
    expect(viewModel.networkStatus, NetworkStatus.offline);

    connectivity.setInternet(true);
    expect(viewModel.showElectrumReconnected, isTrue);
    await tester.pump(kElectrumReconnectedNoticeDuration);
  });

  test('첫 실행 지연으로 실패 문구가 안 보이면 바로 복구돼도 성공 문구를 켜지 않는다', () {
    final viewModel = createViewModel();
    sync.add(NodeSyncState.failed);

    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isFalse);

    sync.add(NodeSyncState.syncing);
    expect(viewModel.networkStatus, NetworkStatus.online);
    expect(viewModel.showElectrumReconnected, isFalse);
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

      await tester.pump(const Duration(milliseconds: 1900));
      expect(viewModel.showElectrumReconnected, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(viewModel.showElectrumReconnected, isFalse);

      sync.add(NodeSyncState.failed);
      expect(viewModel.networkStatus, NetworkStatus.online);
      expect(viewModel.showElectrumReconnected, isFalse);
      await tester.pump(kErrorDisplayDelayDuration);
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

  test('잔액 화면 갱신만으로는 성공 문구가 켜지지 않는다', () {
    final viewModel = createViewModel();
    sync.add(NodeSyncState.completed);
    viewModel.setEditWidgetMode(true);
    viewModel.setEditWidgetMode(false);

    expect(viewModel.showElectrumReconnected, isFalse);
  });
}
