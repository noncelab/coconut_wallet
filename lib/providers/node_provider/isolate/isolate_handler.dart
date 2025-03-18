import 'dart:isolate';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/network_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription_manager.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_manager.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

class IsolateHandler {
  final SubscriptionManager _subscriptionManager;
  final TransactionManager _transactionManager;
  final NetworkManager _networkManager;
  final IsolateStateManager _isolateStateManager;
  IsolateHandler(this._subscriptionManager, this._transactionManager,
      this._networkManager, this._isolateStateManager);

  Future<void> handleMessage(IsolateHandlerMessage messageType,
      SendPort isolateToMainSendPort, List params) async {
    try {
      switch (messageType) {
        case IsolateHandlerMessage.subscribeWallets:
          final walletItems = params[0];
          // 지갑별 status 초기화
          for (var walletItem in walletItems) {
            _isolateStateManager.initWalletUpdateStatus(walletItem.id);
          }

          // 동기화 중 state 업데이트
          _isolateStateManager.setState(
            newConnectionState: MainClientState.syncing,
            newUpdatedWallets: null,
            notify: true,
          );

          for (var walletItem in walletItems) {
            final result =
                await _subscriptionManager.subscribeWallet(walletItem);
            if (result.isFailure) {
              isolateToMainSendPort.send(result);
              return;
            }
          }

          // 동기화 완료 state 업데이트
          _isolateStateManager.setState(
            newConnectionState: MainClientState.waiting,
            newUpdatedWallets: null,
            notify: true,
          );
          isolateToMainSendPort.send(Result.success(true));
          break;
        case IsolateHandlerMessage.subscribeWallet:
          isolateToMainSendPort
              .send(await _subscriptionManager.subscribeWallet(params[0]));
          break;
        case IsolateHandlerMessage.unsubscribeWallet:
          isolateToMainSendPort
              .send(await _subscriptionManager.unsubscribeWallet(params[0]));
          break;
        case IsolateHandlerMessage.broadcast:
          isolateToMainSendPort
              .send(await _transactionManager.broadcast(params[0]));
          break;
        case IsolateHandlerMessage.getNetworkMinimumFeeRate:
          isolateToMainSendPort
              .send(await _networkManager.getNetworkMinimumFeeRate());
          break;
        case IsolateHandlerMessage.getLatestBlock:
          isolateToMainSendPort.send(await _networkManager.getLatestBlock());
          break;
        case IsolateHandlerMessage.getTransaction:
          isolateToMainSendPort
              .send(await _transactionManager.getTransaction(params[0]));
          break;
        case IsolateHandlerMessage.getRecommendedFees:
          isolateToMainSendPort
              .send(await _networkManager.getRecommendedFees());
          break;
      }
    } catch (e, stack) {
      Logger.error('Error in isolate processing: $e');
      Logger.error(stack);
      isolateToMainSendPort.send(Exception('Error in isolate processing: $e'));
    }
  }
}
