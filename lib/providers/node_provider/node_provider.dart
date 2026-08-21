import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/constants/isolate_constants.dart';
import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/model/node/wallet_fetch_progress.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';

class NodeProvider extends ChangeNotifier {
  final IsolateManager _isolateManager;
  final ConnectivityProvider _connectivityProvider;
  final ValueNotifier<WalletLoadState> _walletLoadStateNotifier;
  final ValueNotifier<List<WalletItemBase>> _walletItemListNotifier;
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();
  ElectrumServer _electrumServer;
  final NetworkType _networkType;
  final AnalyticsService? _analyticsService;

  NodeStateManager? _stateManager;
  StreamSubscription<IsolateStateMessage>? _stateSubscription;
  bool _isFirstInitialization = true;
  bool _isWalletLoaded = false;
  bool _isNetworkInitialized = false;
  Completer<void>? _initCompleter;
  bool _isInitializing = false;
  bool _isClosing = false;
  bool _isPendingInitialization = false;
  bool _hasConnectionError = false;
  bool _isServerChanging = false;

  final _syncStateController = StreamController<NodeSyncState>.broadcast();
  final _walletStateController = StreamController<Map<int, WalletUpdateInfo>>.broadcast();
  final _resyncProgressController = StreamController<Map<int, ResyncProgress>>.broadcast();
  final _fetchProgressController = StreamController<Map<int, WalletFetchProgress>>.broadcast();
  final _currentBlockController = StreamController<BlockTimestamp?>.broadcast();

  final ValueNotifier<BlockTimestamp?> _currentBlockNotifier = ValueNotifier<BlockTimestamp?>(null);
  Timer? _blockUpdateTimer;
  ValueNotifier<BlockTimestamp?> get currentBlockNotifier => _currentBlockNotifier;

  /// 전체 동기화 상태를 구독할 수 있는 스트림
  Stream<NodeSyncState> get syncStateStream {
    return Stream.multi((controller) {
      // 현재 상태를 먼저 전송
      controller.add(state.nodeSyncState);

      final subscription = _syncStateController.stream.listen(controller.add);
      controller.onCancel = () => subscription.cancel();
    });
  }

  /// 특정 지갑의 상태만 구독할 수 있는 스트림
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) {
    return Stream.multi((controller) {
      final initialState = state.registeredWallets[walletId];
      if (initialState != null) {
        controller.add(initialState);
      }

      final subscription = _walletStateController.stream
          .map((wallets) => wallets[walletId])
          .where((state) => state != null)
          .cast<WalletUpdateInfo>()
          .listen(controller.add);
      controller.onCancel = () => subscription.cancel();
    });
  }

  /// 특정 지갑의 재동기화 진행 상태만 구독할 수 있는 스트림
  Stream<ResyncProgress> getResyncProgressStream(int walletId) {
    return Stream.multi((controller) {
      final initialState = _stateManager?.resyncProgressByWallet[walletId];
      if (initialState != null) {
        controller.add(initialState);
      }

      final subscription = _resyncProgressController.stream
          .map((wallets) => wallets[walletId])
          .where((state) => state != null)
          .cast<ResyncProgress>()
          .listen(controller.add);
      controller.onCancel = () => subscription.cancel();
    });
  }

  /// 특정 지갑의 트랜잭션 fetch 진행 상태(dispatched/completed 카운트)를 구독할 수 있는 스트림
  /// syncing/completed 이진 상태보다 정확하게 "지금 진짜로 처리 중인 요청이 있는지"를 알려준다.
  Stream<WalletFetchProgress> getWalletFetchProgressStream(int walletId) {
    return Stream.multi((controller) {
      final initialState = _stateManager?.fetchProgressByWallet[walletId];
      if (initialState != null) {
        controller.add(initialState);
      }

      final subscription = _fetchProgressController.stream
          .map((wallets) => wallets[walletId])
          .where((state) => state != null)
          .cast<WalletFetchProgress>()
          .listen(controller.add);
      controller.onCancel = () => subscription.cancel();
    });
  }

  /// 현재 블록 높이 상태를 구독할 수 있는 스트림
  Stream<BlockTimestamp?> get currentBlockStream {
    return Stream.multi((controller) {
      controller.add(_currentBlockNotifier.value);

      final subscription = _currentBlockController.stream.listen(controller.add);
      controller.onCancel = () => subscription.cancel();
    });
  }

  // 블록 업데이트가 실행 중인지 확인 후, 필요 시 시작
  Future<void> _startBlockUpdates() async {
    if (!isInitialized) return;
    if (_blockUpdateTimer?.isActive ?? false) return;

    if (_blockUpdateTimer != null && _blockUpdateTimer!.isActive) {
      Logger.log('NodeProvider: Block updates already running');
      return;
    }

    await _updateCurrentBlock();
    _blockUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!isInitialized) return;
      _updateCurrentBlock();
    });
  }

  Future<void> _restartBlockUpdates() async {
    _stopBlockUpdates();
    _startBlockUpdates();
  }

  Future<void> _updateCurrentBlock() async {
    if (!isInitialized) return;
    if (_walletItemListNotifier.value.isEmpty) return;
    if (_walletLoadStateNotifier.value != WalletLoadState.loadCompleted) return;

    final Result<BlockTimestamp> result = await getLatestBlock();
    if (result.isSuccess && result.value.height > 0) {
      if (_hasConnectionError) {
        _setConnectionError(false);
      }
      if (_currentBlockNotifier.value?.height != result.value.height) {
        _currentBlockNotifier.value = result.value;
        _currentBlockController.add(result.value);
      }
    } else {
      final wasConnected = !_hasConnectionError;
      _setConnectionError(true);
      if (wasConnected) {
        Logger.error('NodeProvider: 블록 높이 업데이트 실패 - ${result.error}');
      }
      if (_isWalletLoaded && isInitialized && _isFirstInitialization) {
        _stateManager?.setNodeSyncStateToFailed();
      }
    }
  }

  void _stopBlockUpdates() {
    _blockUpdateTimer?.cancel();
    _blockUpdateTimer = null;
  }

  NodeProviderState get state => _stateManager?.state ?? NodeProviderState.initial();
  bool get isInitialized => _initCompleter?.isCompleted ?? false;
  String get host => _electrumServer.host;
  int get port => _electrumServer.port;
  bool get ssl => _electrumServer.ssl;
  bool get isServerChanging => _isServerChanging;
  bool get hasConnectionError => _hasConnectionError;
  int get currentBlockHeight => _currentBlockNotifier.value?.height ?? 0;
  bool get isInitializing => _isInitializing;

  NodeProvider(
    this._electrumServer,
    this._networkType,
    this._connectivityProvider,
    this._walletLoadStateNotifier,
    this._walletItemListNotifier,
    this._analyticsService, {
    IsolateManager? isolateManager,
  }) : _isolateManager = isolateManager ?? IsolateManager() {
    Logger.log('NodeProvider: initialized with $host:$port, ssl=$ssl, networkType=$_networkType');

    _connectivityProvider.addListener(_onConnectivityChanged);
    _walletLoadStateNotifier.addListener(_onWalletLoadStateChanged);
    _walletItemListNotifier.addListener(_onWalletItemListChanged);

    _checkInitialNetworkState();
  }

  void _setConnectionError(bool value) {
    if (_hasConnectionError != value) {
      _hasConnectionError = value;
      notifyListeners();
    }
  }

  void _checkInitialNetworkState() {
    if (_connectivityProvider.isInternetOn) {
      initialize();
    } else {
      _isPendingInitialization = true;
      Logger.log('NodeProvider: 네트워크 연결 대기 중 - 초기화 보류');
    }
  }

  void _onConnectivityChanged() {
    if (_connectivityProvider.isInternetOn) {
      if (_isPendingInitialization || !isInitialized) {
        Logger.log('NodeProvider: 네트워크 연결됨 - 초기화 시작');
        _isPendingInitialization = false;
        initialize().then((_) {
          reconnect();
        });
      }
    } else {
      Logger.log('NodeProvider: 네트워크 연결 끊어짐 - 연결 종료');
      _isPendingInitialization = true;
      closeConnection();
    }
  }

  /// WalletLoadState 변경 감지 및 처리
  void _onWalletLoadStateChanged() {
    final walletLoadState = _walletLoadStateNotifier.value;

    Logger.log('NodeProvider: WalletLoadState 변경 감지: $walletLoadState');

    if (walletLoadState == WalletLoadState.loadCompleted) {
      _isWalletLoaded = true;

      // 네트워크가 이미 초기화되어 있고 최초 실행인 경우 구독 시작
      if (_isNetworkInitialized && _isFirstInitialization) {
        _subscribeInitialWallets();
      } else if (_walletItemListNotifier.value.isNotEmpty) {
        _startBlockUpdates();
      }
    }
  }

  void _subscribeInitialWallets() {
    _isFirstInitialization = false;
    subscribeWallets().then((result) async {
      if (result.isFailure) {
        Logger.error('NodeProvider: 초기 지갑 구독 실패: ${result.error}');
        _stateManager?.setNodeSyncStateToFailed();
      } else {
        _setConnectionError(false);

        await Future.delayed(const Duration(seconds: 1));
        await _startBlockUpdates();
      }
    });
  }

  /// WalletItemList 변경 감지 및 처리
  void _onWalletItemListChanged() {
    if (_isFirstInitialization) {
      // 최초 실행 시에는 _subscribeInitialWallets에서 처리
      return;
    }

    final currentWallets = _walletItemListNotifier.value;
    final registeredWallets = state.registeredWallets.keys.toList();

    // 삭제된 지갑 찾기
    for (final walletId in registeredWallets) {
      if (!currentWallets.any((wallet) => wallet.id == walletId)) {
        _stateManager?.unregisterWalletUpdateState(walletId);
      }
    }

    // 새로 추가된 지갑 찾기
    for (final wallet in currentWallets) {
      if (!registeredWallets.contains(wallet.id)) {
        // 새로운 지갑 발견
        subscribeWallet(wallet).then((result) {
          if (result.isFailure) {
            Logger.error('NodeProvider: [${wallet.name}] 지갑 구독 실패: ${result.error}');
            _stateManager?.setNodeSyncStateToFailed();
          } else {
            _analyticsService?.logEvent(eventName: AnalyticsEventNames.walletAddSyncCompleted);
          }
        });
      }
    }
  }

  void _createStateManager() {
    _stateManager = NodeStateManager(
      () {
        return notifyListeners();
      },
      _syncStateController,
      _walletStateController,
      _resyncProgressController,
      _fetchProgressController,
    );
  }

  /// 안전한 Completer 생성
  void _createNewCompleter() {
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      try {
        _initCompleter!.completeError(Exception('NodeProvider: Previous initialization was cancelled'));
      } catch (e) {
        // 이미 완료된 경우 무시
      }
    }
    _initCompleter = Completer<void>();
  }

  Future<void> initialize() async {
    final hasInternet = _connectivityProvider.isInternetOn;

    if (!hasInternet) {
      Logger.log('NodeProvider: 네트워크가 연결되지 않아 초기화를 보류합니다.');
      _isPendingInitialization = true;
      return;
    }

    // 이미 초기화 중인 경우 기존 작업 완료 대기
    if (_isInitializing) {
      Logger.log('NodeProvider: Already initializing, waiting for completion');
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        try {
          await _initCompleter!.future;
          return;
        } catch (e) {
          // 기존 초기화가 실패한 경우 새로 시도
        }
      } else {
        return; // 이미 성공적으로 완료된 경우
      }
    }

    _isInitializing = true;
    _isPendingInitialization = false;
    _setConnectionError(false); // 초기화 시작 시 에러 상태 리셋

    try {
      _createNewCompleter();
      _createStateManager();
      await _isolateManager.initialize(host, port, ssl, _networkType);
      unawaited(_recordCurrentServerGenesisHash());

      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }

      _subscribeToStateChanges();
      _isNetworkInitialized = true;

      Logger.log('NodeProvider: Initialization completed successfully');

      if (_isWalletLoaded && _isFirstInitialization) {
        _subscribeInitialWallets();
        _startBlockUpdates();
      }
    } catch (e) {
      Logger.error('NodeProvider: 초기화 중 오류 발생: $e');

      // 연결 에러 플래그 설정 (notifyListeners 호출됨)
      _setConnectionError(true);

      // 초기화 실패 시 노드 동기화 상태를 실패로 설정
      if (_stateManager != null) {
        _stateManager!.setNodeSyncStateToFailed();
      }

      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        try {
          _initCompleter!.completeError(e);
        } catch (completerError) {
          // 이미 완료된 경우 무시
        }
      }
      rethrow;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  void _subscribeToStateChanges() {
    try {
      _stateSubscription?.cancel();
      _stateSubscription = null;
      _stateSubscription = _isolateManager.stateStream.listen(
        (message) {
          if (_stateManager == null) {
            Logger.log('NodeProvider: StateManager가 초기화되지 않았습니다.');
            return;
          }
          _stateManager!.handleIsolateStateMessage(message);
        },
        onError: (error) {
          Logger.log('NodeProvider: 상태 스트림 오류: $error');
        },
      );
    } catch (e) {
      Logger.log('NodeProvider: 상태 변경 처리 설정 중 오류: $e');
    }
  }

  Future<Result<bool>> subscribeWallets() async {
    if (_walletLoadStateNotifier.value != WalletLoadState.loadCompleted || _connectivityProvider.isInternetOff) {
      return Result.success(false);
    }
    final walletItems = _walletItemListNotifier.value;

    if (walletItems.isEmpty) {
      Logger.log('NodeProvider: 구독할 지갑이 없습니다.');
      return Result.success(true);
    }

    return _isolateManager.subscribeWallets(walletItems);
  }

  Future<Result<bool>> subscribeWallet(WalletItemBase walletItem) async {
    return _isolateManager.subscribeWallet(walletItem);
  }

  Future<Result<bool>> unsubscribeWallet(WalletItemBase walletItem) async {
    return _isolateManager.unsubscribeWallet(walletItem);
  }

  /// 지갑 재동기화 진입 전, 현재 연결된 일렉트럼 서버 상태가 정상인지 확인
  Future<Result<bool>> verifyCurrentConnectionHealth() async {
    if (_hasConnectionError) {
      return Result.failure(ErrorCodes.nodeConnectionError);
    }
    return _verifyChainCompatibility(_electrumServer);
  }

  /// 지갑의 온체인 데이터를 초기화하고 처음부터 다시 동기화
  Future<Result<bool>> resyncWallet(WalletItemBase walletItem) async {
    return _isolateManager.resyncWallet(walletItem);
  }

  Future<Result<bool>> syncDormantAddresses(WalletItemBase walletItem) async {
    return _isolateManager.syncDormantAddresses(walletItem);
  }

  Future<Result<List<WalletAddress>>> syncViewedAddresses(
    WalletItemBase walletItem,
    List<WalletAddress> addresses,
  ) async {
    return _isolateManager.syncViewedAddresses(walletItem, addresses);
  }

  Future<Result<String>> broadcast(Transaction signedTx) async {
    final result = await _isolateManager.broadcast(signedTx);
    if (result.isFailure) {
      Logger.error('NodeProvider.broadcast: failed code=${result.error.code} message=${result.error.message}');
      FileLogger.logBroadcast('NodeProvider failure code=${result.error.code}');
    }
    return result;
  }

  Future<Result<int>> getNetworkMinimumFeeRate() async {
    return _isolateManager.getNetworkMinimumFeeRate();
  }

  Future<Result<BlockTimestamp>> getLatestBlock() async {
    return _isolateManager.getLatestBlock();
  }

  Future<Result<String>> getTransaction(String txHash) async {
    return _isolateManager.getTransaction(txHash);
  }

  Future<Result<RecommendedFee>> getRecommendedFees() async {
    return _isolateManager.getRecommendedFees();
  }

  Future<Result<SocketConnectionStatus>> getSocketConnectionStatus() async {
    return _isolateManager.getSocketConnectionStatus();
  }

  Future<Result<TransactionRecord>> getTransactionRecord(
    WalletItemBase walletItem,
    String txHash, {
    Duration? timeout,
  }) async {
    Logger.log('NodeProvider: getTransactionRecord called (txHash: $txHash)');
    final result = await _isolateManager.getTransactionRecord(walletItem, txHash, timeout: timeout);
    if (result.isFailure) {
      Logger.error('NodeProvider.getTransactionRecord failed (txHash: $txHash) - error: ${result.error}');
    }
    return result;
  }

  Future<void> reconnect() async {
    _setConnectionError(false); // 재연결 시작 시 에러 상태 리셋
    // 네트워크 연결 상태 확인
    if (_connectivityProvider.isInternetOff) {
      Logger.log('NodeProvider: 네트워크가 연결되지 않아 재연결을 보류합니다.');
      _isPendingInitialization = true;
      return;
    }

    // 이미 초기화 중이거나 종료 중인 경우 대기
    if (_isInitializing || _isClosing) {
      Logger.log('NodeProvider: Reconnect skipped - operation in progress');
      return;
    }

    try {
      Logger.log('NodeProvider: Starting reconnect');
      if (isInitialized) {
        await closeConnection();
      }
      await initialize();
      _setConnectionError(false);

      final walletLoadState = _walletLoadStateNotifier.value;
      final walletItems = _walletItemListNotifier.value;

      if (walletLoadState == WalletLoadState.loadCompleted && walletItems.isNotEmpty) {
        Logger.log('NodeProvider: Wallet Loaded & Wallet Items is Not Empty, start subscribing');
        final result = await subscribeWallets();
        notifyListeners();

        if (result.isSuccess) {
          Logger.log('NodeProvider: Reconnect completed successfully');
          _setConnectionError(false);
          _restartBlockUpdates();
        } else {
          Logger.error('NodeProvider: subscribeWallets failed: ${result.error}');
          _stateManager?.setNodeSyncStateToFailed();
          _setConnectionError(true);
        }
      } else if (walletLoadState == WalletLoadState.loadCompleted && walletItems.isEmpty) {
        Logger.log('NodeProvider: Wallet Loaded & Wallet Items is Empty, set state to completed');
        _stateManager?.setNodeSyncStateToCompleted();
        _setConnectionError(false);
        notifyListeners();
      } else {
        Logger.log('NodeProvider: Wallet Loading, reset flag for auto-subscription');
        _isFirstInitialization = true;
        notifyListeners();
      }
    } catch (e) {
      Logger.error('NodeProvider: Reconnect failed: $e');
      _setConnectionError(true);
      _stateManager?.setNodeSyncStateToFailed();
    }
  }

  /// 완전한 dispose 없이 연결만 중단하는 메서드
  Future<void> closeConnection() async {
    // 이미 종료 중인 경우 중복 실행 방지
    if (_isClosing) {
      Logger.log('NodeProvider: Already closing connection');
      return;
    }

    _isClosing = true;

    try {
      Logger.log('NodeProvider: Closing connection');

      // 블록 업데이트 중단
      _stopBlockUpdates();

      // 스트림 구독 취소
      _stateSubscription?.cancel();
      _stateSubscription = null;

      // 현재 블록 높이 업데이트 중단
      _blockUpdateTimer?.cancel();
      _blockUpdateTimer = null;

      // Isolate 정리
      await _isolateManager.closeIsolate();

      // Completer 안전하게 정리
      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        try {
          _initCompleter!.completeError(Exception('Connection was closed'));
        } catch (e) {
          // 이미 완료된 경우 무시
        }
      }
      _initCompleter = null;
      _stateManager = null;

      notifyListeners();
      Logger.log('NodeProvider: Connection closed successfully');
    } catch (e) {
      Logger.error('NodeProvider: 연결 종료 중 오류 발생: $e');
    } finally {
      _isClosing = false;
    }
  }

  Future<Result<bool>> checkServerConnection(ElectrumServer electrumServer) async {
    final electrumService = ElectrumService();

    try {
      await _establishSocketConnection(electrumService, electrumServer);
      await _verifyProtocolCommunication(electrumService);

      Logger.log('NodeProvider: 서버 연결 테스트 성공 - ${electrumServer.host}:${electrumServer.port}');
      return Result.success(true);
    } catch (e) {
      Logger.error('NodeProvider: 서버 연결 확인 실패 - ${electrumServer.host}:${electrumServer.port}: $e');
      await electrumService.close();
      return Result.failure(ErrorCodes.networkError);
    } finally {
      await electrumService.close();
    }
  }

  Future<void> _establishSocketConnection(ElectrumService service, ElectrumServer server) async {
    final isOnionHost = server.host.trim().toLowerCase().endsWith('.onion');
    final connectionTimeout = isOnionHost ? kIsolateInitTimeoutForOnion : kIsolateInitTimeout;

    await service.connect(server.host, server.port, ssl: server.ssl).timeout(connectionTimeout);

    if (service.connectionStatus != SocketConnectionStatus.connected) {
      throw Exception('Socket connection failed');
    }
  }

  Future<void> _verifyProtocolCommunication(ElectrumService service) async {
    await service.serverVersion().timeout(const Duration(seconds: 5));
  }

  /// 새 서버가 이전에 동기화하던 것과 같은 체인인지 genesis hash로 확인합니다.
  /// 다른 체인의 서버로 전환하면, 그 서버 입장에서는 지갑 주소들이 전부 "본 적 없는" 상태라
  /// 잔액이 0으로 조회되고, 그 결과가 기존 잔액에 그대로 diff 반영되어 덮어써지는 문제가 있어
  /// 전환 자체를 막습니다. 이전에 기록된 genesis hash가 없으면(최초 연결) 그대로 통과시킵니다.
  Future<Result<bool>> _verifyChainCompatibility(ElectrumServer electrumServer) async {
    final electrumService = ElectrumService();

    try {
      await _establishSocketConnection(electrumService, electrumServer);
      final features = await electrumService.serverFeatures().timeout(const Duration(seconds: 5));
      final genesisHash = features.genesisHash;

      if (isBuildNetworkGenesisMismatch(buildNetworkType: _networkType, genesisHash: genesisHash)) {
        Logger.error(
          'NodeProvider: 서버 변경 차단 - 빌드 네트워크($_networkType)와 다른 체인의 서버 (genesis: $genesisHash, '
          '${electrumServer.host}:${electrumServer.port})',
        );
        return Result.failure(ErrorCodes.chainMismatchError);
      }

      // mainnet/testnet은 위 하드코딩 상수 비교만으로 이미 배타적으로 검증되므로,
      // 기준값 비교는 그런 고정값이 없는 regtest에서만 의미가 있다.
      if (_networkType == NetworkType.regtest) {
        final baselineGenesisHash = _sharedPrefs.getBaselineGenesisHash();
        if (isChainGenesisMismatch(baselineGenesisHash: baselineGenesisHash, newGenesisHash: genesisHash)) {
          Logger.error(
            'NodeProvider: 서버 변경 차단 - 체인 불일치 (기준값: $baselineGenesisHash, 새 서버: $genesisHash, '
            '${electrumServer.host}:${electrumServer.port})',
          );
          return Result.failure(ErrorCodes.chainMismatchError);
        }
      }

      return Result.success(true);
    } catch (e) {
      Logger.error('NodeProvider: 체인 확인 실패 - ${electrumServer.host}:${electrumServer.port}: $e');
      return Result.failure(ErrorCodes.networkError);
    } finally {
      await electrumService.close();
    }
  }

  static const String _kMainnetGenesisHash = '000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f';
  static const String _kTestnetGenesisHash = '000000000933ea01ad0ee984209779baaec3ced90fa3f408719526f8d77f4943';

  /// 이 앱 빌드의 네트워크(mainnet/testnet/regtest)와 다른 체인인지,
  /// genesis hash와 직접 대조해서 판단합니다.
  @visibleForTesting
  static bool isBuildNetworkGenesisMismatch({required NetworkType buildNetworkType, required String genesisHash}) {
    if (buildNetworkType == NetworkType.mainnet) {
      return genesisHash != _kMainnetGenesisHash;
    }
    if (buildNetworkType == NetworkType.testnet) {
      return genesisHash != _kTestnetGenesisHash;
    }
    return genesisHash == _kMainnetGenesisHash || genesisHash == _kTestnetGenesisHash;
  }

  /// 두 genesis hash가 다르면(그리고 기준값이 확립되어 있으면) 체인이 다른 것으로 판단합니다.
  /// 기준값이 아직 없으면(최초 연결) 항상 false를 반환합니다.
  @visibleForTesting
  static bool isChainGenesisMismatch({required String? baselineGenesisHash, required String newGenesisHash}) {
    return baselineGenesisHash != null && baselineGenesisHash != newGenesisHash;
  }

  /// 이 앱 빌드의 네트워크(flavor)에 해당하는 coconut 기본 서버에 연결해 genesis hash를
  /// 기준값으로 기록합니다. mainnet/testnet은 하드코딩된 genesis hash로 검증되므로,
  /// 기준값이 필요한 건 regtest뿐이다.
  Future<void> _recordCurrentServerGenesisHash() async {
    if (_networkType != NetworkType.regtest) {
      return;
    }

    if (_sharedPrefs.getBaselineGenesisHash() != null) {
      return;
    }

    final trustedServer = DefaultElectrumServer.regtestServers.first;
    final electrumService = ElectrumService();

    try {
      await _establishSocketConnection(electrumService, trustedServer);
      final features = await electrumService.serverFeatures().timeout(const Duration(seconds: 5));
      await _sharedPrefs.setBaselineGenesisHash(features.genesisHash);
    } catch (e) {
      Logger.error('NodeProvider: 기본 서버 genesis hash 기록 실패 - ${trustedServer.host}:${trustedServer.port}: $e');
    } finally {
      await electrumService.close();
    }
  }

  Future<Result<bool>> changeServer(ElectrumServer electrumServer) async {
    _isServerChanging = true;

    try {
      final chainCheckResult = await _verifyChainCompatibility(electrumServer);
      if (chainCheckResult.isFailure) {
        notifyListeners();
        return Result.failure(chainCheckResult.error);
      }

      await closeConnection();
      _electrumServer = electrumServer;

      Logger.log('NodeProvider: 서버 변경: $host:$port, ssl=$ssl');

      await initialize();

      subscribeWallets().then((result) {
        if (result.isFailure) {
          Logger.error('NodeProvider: 서버 변경 실패: ${result.error}');
          _stateManager?.setNodeSyncStateToFailed();
          notifyListeners();
        }
      });

      Logger.log('NodeProvider: 서버 변경 성공');
      notifyListeners();
      return Result.success(true);
    } catch (e) {
      Logger.error('NodeProvider: 서버 변경 중 초기화 실패: $e');
      _stateManager?.setNodeSyncStateToFailed();
      notifyListeners();
      return Result.failure(ErrorCodes.networkError);
    } finally {
      _isServerChanging = false;
    }
  }

  @override
  void dispose() {
    _connectivityProvider.removeListener(_onConnectivityChanged);
    _walletLoadStateNotifier.removeListener(_onWalletLoadStateChanged);
    _walletItemListNotifier.removeListener(_onWalletItemListChanged);

    closeConnection();

    // Stream Controllers 정리
    _syncStateController.close();
    _walletStateController.close();
    _resyncProgressController.close();
    _fetchProgressController.close();
    _currentBlockController.close();

    super.dispose();
  }
}
