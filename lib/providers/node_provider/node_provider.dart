import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:coconut_wallet/utils/logger.dart';

class NodeProvider extends ChangeNotifier {
  final IsolateManager _isolateManager;
  final String _host;
  final int _port;
  final bool _ssl;
  final NetworkType _networkType;

  NodeStateManager? _stateManager;
  StreamSubscription<IsolateStateMessage>? _stateSubscription;

  Completer<void>? _initCompleter;

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

  NodeProvider(this._host, this._port, this._ssl, this._networkType,
      {IsolateManager? isolateManager})
      : _isolateManager = isolateManager ?? IsolateManager() {
    Logger.log('NodeProvider: initialized with $host:$port, ssl=$ssl, networkType=$_networkType');
    initialize();
  }

  void _createStateManager() {
    _stateManager = NodeStateManager(() => notifyListeners());
  }

  Future<void> initialize() async {
    try {
      _initCompleter = Completer<void>();
      _createStateManager();
      await _isolateManager.initialize(host, port, ssl, _networkType);
      _initCompleter?.complete();
      _subscribeToStateChanges();
      notifyListeners();
    } catch (e) {
      _initCompleter?.completeError(e);
      Logger.error('NodeProvider: 초기화 중 오류 발생: $e');
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

  Future<Result<bool>> subscribeWallets(
    List<WalletListItemBase>? walletItems,
  ) async {
    needSubscribeWallets = false;
    if (walletItems != null) {
      _lastSubscribedWallets = walletItems;
    }
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

  void deleteWallet(int walletId) {
    _lastSubscribedWallets.removeWhere((element) => element.id == walletId);
    _stateManager?.unregisterWalletUpdateState(walletId);
  }

  Future<void> reconnect() async {
    if (_isFirstReconnect) {
      _isFirstReconnect = false;
      return;
    }

    try {
      SocketConnectionStatus socketConnectionStatus;
      needSubscribeWallets = true;
      if (isInitialized && _isolateManager.isInitialized) {
        final result = await _isolateManager.getSocketConnectionStatus();
        if (result.isSuccess && result.value != SocketConnectionStatus.terminated) {
          return;
        }
      }

      _stateSubscription?.cancel();
      _stateSubscription = null;

      final result = await _isolateManager.getSocketConnectionStatus();
      if (result.isSuccess && result.value != SocketConnectionStatus.connected) {
        await initialize();
      }
    } catch (e) {
      Logger.log('NodeProvider: 재연결 중 오류 발생: $e');
      _initCompleter = null;
    }
  }

  /// 완전한 dispose 없이 연결만 중단하는 메서드
  Future<void> closeConnection() async {
    try {
      // 스트림 구독 취소
      _stateSubscription?.cancel();
      _stateSubscription = null;

      // Isolate 정리
      await _isolateManager.closeIsolate();
      _initCompleter = null;

      // StateManager 초기화
      _stateManager = null;

      notifyListeners();
    } catch (e) {
      Logger.log('NodeProvider: 연결 종료 중 오류 발생: $e');
    }
  }
}
