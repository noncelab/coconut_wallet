import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/electrum_server.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:coconut_wallet/utils/logger.dart';

class NodeProvider extends ChangeNotifier {
  final IsolateManager _isolateManager;
  final ConnectivityProvider _connectivityProvider;
  final ValueNotifier<WalletLoadState> _walletLoadStateNotifier;
  final ValueNotifier<List<WalletListItemBase>> _walletItemListNotifier;
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

  final _syncStateController = StreamController<NodeSyncState>.broadcast();
  final _walletStateController = StreamController<Map<int, WalletUpdateInfo>>.broadcast();

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

  NodeProviderState get state => _stateManager?.state ?? NodeProviderState.initial();
  bool get isInitialized => _initCompleter?.isCompleted ?? false;
  String get host => _electrumServer.host;
  int get port => _electrumServer.port;
  bool get ssl => _electrumServer.ssl;

  NodeProvider(this._electrumServer, this._networkType, this._connectivityProvider,
      this._walletLoadStateNotifier, this._walletItemListNotifier, this._analyticsService,
      {IsolateManager? isolateManager})
      : _isolateManager = isolateManager ?? IsolateManager() {
    Logger.log('NodeProvider: initialized with $host:$port, ssl=$ssl, networkType=$_networkType');

    _connectivityProvider.addListener(_onConnectivityChanged);
    _walletLoadStateNotifier.addListener(_onWalletLoadStateChanged);
    _walletItemListNotifier.addListener(_onWalletItemListChanged);

    _checkInitialNetworkState();
  }

  void _checkInitialNetworkState() {
    if (_connectivityProvider.isNetworkOn) {
      initialize();
    } else {
      _isPendingInitialization = true;
      Logger.log('NodeProvider: 네트워크 연결 대기 중 - 초기화 보류');
    }
  }

  void _onConnectivityChanged() {
    if (_connectivityProvider.isNetworkOn) {
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
      }
    }
  }

  void _subscribeInitialWallets() {
    _isFirstInitialization = false;
    subscribeWallets().then((result) {
      if (result.isFailure) {
        Logger.error('NodeProvider: 초기 지갑 구독 실패: ${result.error}');
        _stateManager?.setNodeSyncStateToFailed();
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
            _analyticsService?.logEvent(
              eventName: AnalyticsEventNames.walletAddSyncCompleted,
            );
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
    );
  }

  /// 안전한 Completer 생성
  void _createNewCompleter() {
    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      try {
        _initCompleter!
            .completeError(Exception('NodeProvider: Previous initialization was cancelled'));
      } catch (e) {
        // 이미 완료된 경우 무시
      }
    }
    _initCompleter = Completer<void>();
  }

  Future<void> initialize() async {
    if (_connectivityProvider.isNetworkOff) {
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

    try {
      _createNewCompleter();
      _createStateManager();
      await _isolateManager.initialize(host, port, ssl, _networkType);

      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }

      _subscribeToStateChanges();
      _isNetworkInitialized = true;

      Logger.log('NodeProvider: Initialization completed successfully');

      if (_isWalletLoaded && _isFirstInitialization) {
        _subscribeInitialWallets();
      }
    } catch (e) {
      Logger.error('NodeProvider: 초기화 중 오류 발생: $e');

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
    if (_walletLoadStateNotifier.value != WalletLoadState.loadCompleted ||
        _connectivityProvider.isNetworkOff) {
      return Result.success(false);
    }
    final walletItems = _walletItemListNotifier.value;

    if (walletItems.isEmpty) {
      Logger.log('NodeProvider: 구독할 지갑이 없습니다.');
      return Result.success(true);
    }

    return _isolateManager.subscribeWallets(walletItems);
  }

  Future<Result<bool>> subscribeWallet(WalletListItemBase walletItem) async {
    return _isolateManager.subscribeWallet(walletItem);
  }

  Future<Result<bool>> unsubscribeWallet(WalletListItemBase walletItem) async {
    return _isolateManager.unsubscribeWallet(walletItem);
  }

  Future<Result<String>> broadcast(Transaction signedTx) async {
    return _isolateManager.broadcast(signedTx);
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
      WalletListItemBase walletItem, String txHash) async {
    return _isolateManager.getTransactionRecord(walletItem, txHash);
  }

  Future<void> reconnect() async {
    // 네트워크 연결 상태 확인
    if (_connectivityProvider.isNetworkOff) {
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
      await closeConnection();
      await initialize();
      final result = await subscribeWallets();
      notifyListeners();
      if (result.isSuccess) {
        Logger.log('NodeProvider: Reconnect completed successfully');
      } else {
        _stateManager?.setNodeSyncStateToFailed();
        Logger.error(result.error.toString());
      }
    } catch (e) {
      Logger.error('NodeProvider: Reconnect failed: $e');
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

      // 스트림 구독 취소
      _stateSubscription?.cancel();
      _stateSubscription = null;

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

  Future<Result<bool>> changeServer(ElectrumServer electrumServer) async {
    await closeConnection();
    _electrumServer = electrumServer;

    Logger.log('NodeProvider: 서버 변경: $host:$port, ssl=$ssl');
    try {
      await initialize();
    } catch (e) {
      return Result.failure(ErrorCodes.networkError);
    }

    subscribeWallets().then((result) {
      if (result.isFailure) {
        Logger.error('NodeProvider: 서버 변경 실패: ${result.error}');
      }
    });
    notifyListeners();

    return Result.success(true);
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

    super.dispose();
  }
}
