import 'dart:isolate';

import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/state/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/network_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

class IsolateController {
  final SubscriptionService _subscriptionService;
  final NetworkService _networkManager;
  final IsolateStateManager _isolateStateManager;
  final ElectrumService _electrumService;
  final TransactionRecordService _transactionRecordService;
  IsolateController(
    this._subscriptionService,
    this._networkManager,
    this._isolateStateManager,
    this._electrumService,
    this._transactionRecordService,
  );

  Future<void> executeNetworkCommand(
    IsolateControllerCommand messageType,
    SendPort isolateToMainSendPort,
    List params,
  ) async {
    try {
      switch (messageType) {
        case IsolateControllerCommand.subscribeWallets:
          final walletItems = params[0];
          // 지갑별 status 초기화
          for (var walletItem in walletItems) {
            _isolateStateManager.initWalletUpdateStatus(walletItem.id);
          }

          // 동기화 중 state 업데이트
          _isolateStateManager.setNodeSyncStateToSyncing();

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
          final walletItem = params[0];
          _isolateStateManager.initWalletUpdateStatus(walletItem.id);
          isolateToMainSendPort.send(await _subscriptionService.subscribeWallet(walletItem));
          break;
        case IsolateControllerCommand.unsubscribeWallet:
          isolateToMainSendPort.send(await _subscriptionService.unsubscribeWallet(params[0]));
          break;
        case IsolateControllerCommand.syncDormantAddresses:
          isolateToMainSendPort.send(await _subscriptionService.syncDormantAddresses(params[0]));
          break;
        case IsolateControllerCommand.syncViewedAddresses:
          isolateToMainSendPort.send(await _subscriptionService.syncViewedAddresses(params[0], params[1]));
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
          isolateToMainSendPort.send(Result.success(_electrumService.connectionStatus));
          break;
        case IsolateControllerCommand.getTransactionRecord:
          final txHash = params[1] as String;
          Logger.log('IsolateController: getTransactionRecord executing in isolate (txHash: $txHash)');
          isolateToMainSendPort.send(await _transactionRecordService.getTransactionRecord(params[0], params[1]));
          break;
      }
    } catch (e, stack) {
      Logger.error('IsolateController: Error in $messageType: $e');
      Logger.error(stack);
      // 원시 Exception을 보내면 수신 측(IsolateManager._send) Result<T> 캐스팅이 실패
      // 진짜 에러 내용을 볼 수 없음. 항상 Result.failure로 감싸서 보낸다.
      isolateToMainSendPort.send(Result.failure(ErrorCodes.withMessage(ErrorCodes.nodeIsolateError, e.toString())));
    }
  }
}
