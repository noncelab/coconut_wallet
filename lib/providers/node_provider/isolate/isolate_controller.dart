import 'dart:isolate';

import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/network_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

class IsolateController {
  final SubscriptionService _subscriptionService;
  final NetworkService _networkManager;
  final IsolateStateManager _isolateStateManager;
  final ElectrumService _electrumService;
  IsolateController(this._subscriptionService, this._networkManager, this._isolateStateManager,
      this._electrumService);

  Future<void> executeNetworkCommand(
      IsolateControllerCommand messageType, SendPort isolateToMainSendPort, List params) async {
    try {
      switch (messageType) {
        case IsolateControllerCommand.subscribeWallets:
          final walletItems = params[0];
          // 지갑별 status 초기화
          for (var walletItem in walletItems) {
            _isolateStateManager.initWalletUpdateStatus(walletItem.id);
          }

          // 동기화 중 state 업데이트
          _isolateStateManager.setMainClientSyncingState();

          for (var walletItem in walletItems) {
            final result = await _subscriptionService.subscribeWallet(walletItem);
            if (result.isFailure) {
              isolateToMainSendPort.send(result);
              return;
            }
          }

          isolateToMainSendPort.send(Result.success(true));
          break;
        case IsolateControllerCommand.subscribeWallet:
          isolateToMainSendPort.send(await _subscriptionService.subscribeWallet(params[0]));
          break;
        case IsolateControllerCommand.unsubscribeWallet:
          isolateToMainSendPort.send(await _subscriptionService.unsubscribeWallet(params[0]));
          break;
        case IsolateControllerCommand.broadcast:
          isolateToMainSendPort.send(await _networkManager.broadcast(params[0]));
          break;
        case IsolateControllerCommand.getNetworkMinimumFeeRate:
          isolateToMainSendPort.send(await _networkManager.getNetworkMinimumFeeRate());
          break;
        case IsolateControllerCommand.getLatestBlock:
          isolateToMainSendPort.send(await _networkManager.getLatestBlock());
          break;
        case IsolateControllerCommand.getTransaction:
          isolateToMainSendPort.send(await _networkManager.getTransaction(params[0]));
          break;
        case IsolateControllerCommand.getRecommendedFees:
          isolateToMainSendPort.send(await _networkManager.getRecommendedFees());
          break;
        case IsolateControllerCommand.getSocketConnectionStatus:
          isolateToMainSendPort.send(_electrumService.connectionStatus);
          break;
      }
    } catch (e, stack) {
      Logger.error('Error in isolate processing: $e');
      Logger.error(stack);
      isolateToMainSendPort.send(Exception('Error in isolate processing: $e'));
    }
  }
}
