import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
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
  final String _host;
  final int _port;
  final bool _ssl;
  final NetworkType _networkType;

  NodeStateManager? _stateManager;
  StreamSubscription<IsolateStateMessage>? _stateSubscription;

  Completer<void>? _initCompleter;
  bool _isInitializing = false;
  bool _isClosing = false;
  bool _pendingInitialization = false;

  NodeProviderState get state => _stateManager?.state ?? NodeProviderState.initial();

  bool get isInitialized => _initCompleter?.isCompleted ?? false;
  String get host => _host;
  int get port => _port;
  bool get ssl => _ssl;

  bool needSubscribeWallets = false;
  List<WalletListItemBase> _lastSubscribedWallets = [];

  /// 정상적으로 연결된 후 다시 연결이 끊겼을 떄에만 이 함수가 동작하도록 설계되어 있음.
  /// 최초 [reconnect] 호출은 앱 실행 시 `_checkConnectivity` 에서 호출되어 state 처리 관련된 로직이 일부 비정상적으로 동작함.
  /// 따라서 최초 호출 1번만 동작을 하지 않도록 함
  bool _isFirstReconnect = true;

  NodeProvider(this._host, this._port, this._ssl, this._networkType, this._connectivityProvider,
      this._walletLoadStateNotifier, this._walletItemListNotifier,
      {IsolateManager? isolateManager})
      : _isolateManager = isolateManager ?? IsolateManager() {
    Logger.log('NodeProvider: initialized with $host:$port, ssl=$ssl, networkType=$_networkType');

    _connectivityProvider.addListener(_onConnectivityChanged);
    _walletLoadStateNotifier.addListener(_onWalletLoadStateChanged);
    _walletItemListNotifier.addListener(_onWalletItemListChanged);

    _checkInitialNetworkState();
  }

  void _checkInitialNetworkState() {
    if (_connectivityProvider.isNetworkOn == true) {
      initialize();
    } else {
      _pendingInitialization = true;
      Logger.log('NodeProvider: 네트워크 연결 대기 중 - 초기화 보류');
    }
  }

  void _onConnectivityChanged() {
    final isNetworkOn = _connectivityProvider.isNetworkOn;

    if (isNetworkOn == true) {
      if (_pendingInitialization || !isInitialized) {
        Logger.log('NodeProvider: 네트워크 연결됨 - 초기화 시작');
        _pendingInitialization = false;
        initialize().then((_) {
          reconnect();
        });
      }
    } else {
      Logger.log('NodeProvider: 네트워크 연결 끊어짐 - 연결 종료');
      _pendingInitialization = true;
      closeConnection();
    }
  }

  /// WalletLoadState 변경 감지 및 처리
  void _onWalletLoadStateChanged() {
    final walletLoadState = _walletLoadStateNotifier.value;

    Logger.log('NodeProvider: WalletLoadState 변경 감지: $walletLoadState');

    if (walletLoadState == WalletLoadState.loadCompleted) {
      subscribeWallets(walletItems: _walletItemListNotifier.value);
    }
  }

  /// WalletItemList 변경 감지 및 처리
  void _onWalletItemListChanged() {
    final walletItemList = _walletItemListNotifier.value;
    Logger.log('NodeProvider: WalletItemList 변경 감지: ${walletItemList.length}개 지갑');

    // 필요한 경우 여기에 추가 로직 구현
  }

  void _createStateManager() {
    _stateManager = NodeStateManager(() {
      _printWalletStatus();
      return notifyListeners();
    });
  }

  void _printWalletStatus() {
    // UpdateStatus를 심볼로 변환하는 함수
    String statusToSymbol(WalletSyncState status) {
      switch (status) {
        case WalletSyncState.waiting:
          return '⏳'; // 대기 중
        case WalletSyncState.syncing:
          return '🔄'; // 동기화 중
        case WalletSyncState.completed:
          return '✅'; // 완료됨
      }
    }

    // ConnectionState를 심볼로 변환하는 함수
    String connectionStateToSymbol(NodeSyncState state) {
      switch (state) {
        case NodeSyncState.syncing:
          return '🔄 동기화 중';
        case NodeSyncState.completed:
          return '🟢 대기 중ㅤ';
        case NodeSyncState.failed:
          return '🔴 실패';
      }
    }

    final connectionState = state.nodeSyncState;
    final connectionStateSymbol = connectionStateToSymbol(connectionState);
    final buffer = StringBuffer();

    if (state.registeredWallets.isEmpty) {
      buffer.writeln('--> 등록된 지갑이 없습니다.');
      buffer.writeln('--> connectionState: $connectionState');
      Logger.log(buffer.toString());
      return;
    }

    // 등록된 지갑의 키 목록 얻기
    final walletKeys = state.registeredWallets.keys.toList();

    // 테이블 헤더 출력 (connectionState 포함)
    buffer.writeln('\n');
    buffer.writeln('┌───────────────────────────────────────┐');
    buffer.writeln('│ 연결 상태: $connectionStateSymbol${' ' * (23 - connectionStateSymbol.length)}│');
    buffer.writeln('├─────────┬─────────┬─────────┬─────────┤');
    buffer.writeln('│ 지갑 ID │  잔액   │  거래   │  UTXO   │');
    buffer.writeln('├─────────┼─────────┼─────────┼─────────┤');

    // 각 지갑 상태 출력
    for (int i = 0; i < walletKeys.length; i++) {
      final key = walletKeys[i];
      final value = state.registeredWallets[key]!;

      final balanceSymbol = statusToSymbol(value.balance);
      final transactionSymbol = statusToSymbol(value.transaction);
      final utxoSymbol = statusToSymbol(value.utxo);

      buffer.writeln(
          '│ ${key.toString().padRight(7)} │   $balanceSymbol    │   $transactionSymbol    │   $utxoSymbol    │');

      // 마지막 행이 아니면 행 구분선 추가
      if (i < walletKeys.length - 1) {
        buffer.writeln('├─────────┼─────────┼─────────┼─────────┤');
      }
    }

    buffer.writeln('└─────────┴─────────┴─────────┴─────────┘');
    Logger.log(buffer.toString());
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
    if (_connectivityProvider.isNetworkOn != true) {
      Logger.log('NodeProvider: 네트워크가 연결되지 않아 초기화를 보류합니다.');
      _pendingInitialization = true;
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
    _pendingInitialization = false;

    try {
      Logger.log('NodeProvider: Starting initialization');
      _createNewCompleter();
      _createStateManager();
      await _isolateManager.initialize(host, port, ssl, _networkType);

      if (_initCompleter != null && !_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }

      _subscribeToStateChanges();

      // 초기화 완료 후 대기 중인 지갑 구독 처리
      if (needSubscribeWallets && _lastSubscribedWallets.isNotEmpty) {
        Logger.log('NodeProvider: 초기화 완료 - 대기 중인 지갑 구독 시작');
        await subscribeWallets();
      }

      notifyListeners();
      Logger.log('NodeProvider: Initialization completed successfully');
    } catch (e) {
      Logger.error('NodeProvider: 초기화 중 오류 발생: $e');
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

  Future<Result<bool>> subscribeWallets({List<WalletListItemBase>? walletItems}) async {
    if (walletItems != null) {
      _lastSubscribedWallets = walletItems;
    }
    if (_walletLoadStateNotifier.value != WalletLoadState.loadCompleted ||
        _connectivityProvider.isNetworkOn != true) {
      return Result.success(false);
    }

    needSubscribeWallets = false;
    if (_lastSubscribedWallets.isEmpty) {
      Logger.log('NodeProvider: 구독할 지갑이 없습니다.');
      return Result.success(true);
    }
    return _isolateManager.subscribeWallets(_lastSubscribedWallets);
  }

  Future<Result<bool>> subscribeWallet(WalletListItemBase walletItem) async {
    final isAlreadySubscribed = _lastSubscribedWallets.any((wallet) => wallet.id == walletItem.id);
    if (!isAlreadySubscribed) {
      _lastSubscribedWallets.add(walletItem);
    }
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

  void deleteWallet(int walletId) {
    _lastSubscribedWallets.removeWhere((element) => element.id == walletId);
    _stateManager?.unregisterWalletUpdateState(walletId);
  }

  Future<void> reconnect() async {
    if (_isFirstReconnect) {
      _isFirstReconnect = false;
      return;
    }

    // 네트워크 연결 상태 확인
    if (_connectivityProvider.isNetworkOn != true) {
      Logger.log('NodeProvider: 네트워크가 연결되지 않아 재연결을 보류합니다.');
      _pendingInitialization = true;
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
      await subscribeWallets();
      notifyListeners();
      Logger.log('NodeProvider: Reconnect completed successfully');
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

      // StateManager 초기화
      _stateManager = null;

      notifyListeners();
      Logger.log('NodeProvider: Connection closed successfully');
    } catch (e) {
      Logger.error('NodeProvider: 연결 종료 중 오류 발생: $e');
    } finally {
      _isClosing = false;
    }
  }

  @override
  void dispose() {
    _connectivityProvider.removeListener(_onConnectivityChanged);
    _walletLoadStateNotifier.removeListener(_onWalletLoadStateChanged);
    _walletItemListNotifier.removeListener(_onWalletItemListChanged);

    // 기존 정리 로직
    closeConnection();
    super.dispose();
  }
}
