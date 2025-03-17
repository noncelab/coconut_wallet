import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
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
  late final NodeStateManager _stateManager;
  StreamSubscription<IsolateStateMessage>? _stateSubscription;

  Completer<void>? _initCompleter;

  NodeProviderState get state => _stateManager.state;

  bool get isInitialized => _initCompleter?.isCompleted ?? false;
  String get host => _host;
  int get port => _port;
  bool get ssl => _ssl;

  NodeProvider(this._host, this._port, this._ssl,
      {IsolateManager? isolateManager})
      : _isolateManager = isolateManager ?? IsolateManager() {
    _stateManager = NodeStateManager(() => notifyListeners());
    initialize();
    _subscribeToStateChanges();
  }

  Future<void> initialize() async {
    try {
      _initCompleter = Completer<void>();
      await _isolateManager.initialize(host, port, ssl);
      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  void _subscribeToStateChanges() {
    try {
      // 스트림 구독 설정
      _stateSubscription = _isolateManager.stateStream.listen(
        (message) {
          _handleStateMessage(message);
        },
        onError: (error) {
          Logger.error('NodeProvider: Error in state stream: $error');
        },
      );

      // 콜백 등록
      _isolateManager.registerStateCallback(_handleStateMessage);
    } catch (e) {
      Logger.error('NodeProvider: Error setting up state change handling: $e');
    }
  }

  // 상태 메시지 처리 메서드
  void _handleStateMessage(IsolateStateMessage message) {
    try {
      _stateManager.handleIsolateStateMessage(message);
    } catch (e) {
      Logger.error('NodeProvider: Error processing state message: $e');
    }
  }

  Future<Result<bool>> subscribeWallets(
    List<WalletListItemBase> walletItems,
  ) async {
    return await _isolateManager.subscribeWallets(walletItems);
  }

  Future<Result<bool>> subscribeWallet(WalletListItemBase walletItem) async {
    return await _isolateManager.subscribeWallet(walletItem);
  }

  Future<Result<bool>> unsubscribeWallet(WalletListItemBase walletItem) async {
    return await _isolateManager.unsubscribeWallet(walletItem);
  }

  Future<Result<String>> broadcast(Transaction signedTx) async {
    return await _isolateManager.broadcast(signedTx);
  }

  Future<Result<int>> getNetworkMinimumFeeRate() async {
    return await _isolateManager.getNetworkMinimumFeeRate();
  }

  Future<Result<BlockTimestamp>> getLatestBlock() async {
    return await _isolateManager.getLatestBlock();
  }

  Future<Result<String>> getTransaction(String txHash) async {
    return await _isolateManager.getTransaction(txHash);
  }

  Future<Result<RecommendedFee>> getRecommendedFees() async {
    return await _isolateManager.getRecommendedFees();
  }

  void stopFetching() {
    dispose();
  }

  @override
  void dispose() {
    super.dispose();
    _stateSubscription?.cancel();
    _isolateManager.unregisterStateCallback();
    _isolateManager.dispose();
  }
}
