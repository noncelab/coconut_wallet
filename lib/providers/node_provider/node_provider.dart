import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/providers/node_provider/node_state_manager.dart';
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
  NodeStateManager? _stateManager;
  StreamSubscription<IsolateStateMessage>? _stateSubscription;

  Completer<void>? _initCompleter;

  NodeProviderState get state => _stateManager?.state ?? NodeProviderState.initial();

  bool get isInitialized => _initCompleter?.isCompleted ?? false;
  String get host => _host;
  int get port => _port;
  bool get ssl => _ssl;

  bool _needSubscribeWallets = false;

  bool get needSubscribe => _needSubscribeWallets;

  NodeProvider(this._host, this._port, this._ssl, {IsolateManager? isolateManager})
      : _isolateManager = isolateManager ?? IsolateManager() {
    initialize();
  }

  void _createStateManager() {
    _stateManager ??= NodeStateManager(() => notifyListeners());
  }

  Future<void> initialize() async {
    try {
      _initCompleter = Completer<void>();
      _createStateManager();
      await _isolateManager.initialize(host, port, ssl);
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
          _handleStateMessage(message);
        },
        onError: (error) {
          Logger.log('NodeProvider: 상태 스트림 오류: $error');
        },
      );
    } catch (e) {
      Logger.log('NodeProvider: 상태 변경 처리 설정 중 오류: $e');
    }
  }

  void _handleStateMessage(IsolateStateMessage message) {
    try {
      if (_stateManager != null) {
        _stateManager!.handleIsolateStateMessage(message);
      }
    } catch (e) {
      Logger.error('NodeProvider: Error processing state message: $e');
    }
  }

  Future<Result<bool>> subscribeWallets(
    List<WalletListItemBase> walletItems,
  ) async {
    _needSubscribeWallets = false;
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

  void unregisterWalletUpdateState(int walletId) {
    _stateManager?.unregisterWalletUpdateState(walletId);
  }

  Future<void> reconnect() async {
    try {
      _needSubscribeWallets = true;
      if (isInitialized && _isolateManager.isInitialized) {
        return;
      }

      _stateSubscription?.cancel();
      _stateSubscription = null;

      final socketConnectionStatus = await _isolateManager.getSocketConnectionStatus();

      if (socketConnectionStatus != SocketConnectionStatus.connected) {
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
