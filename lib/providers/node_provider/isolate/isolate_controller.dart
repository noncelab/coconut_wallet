import 'dart:isolate';

import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/state/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/network_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/floresta_rpc_client.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

class IsolateController {
  final SubscriptionService _subscriptionService;
  final NetworkService _networkManager;
  final IsolateStateManager _isolateStateManager;
  final ElectrumService _electrumService;
  final TransactionRecordService _transactionRecordService;
  final FlorestaRpcClient? _florestaClient;
  IsolateController(
    this._subscriptionService,
    this._networkManager,
    this._isolateStateManager,
    this._electrumService,
    this._transactionRecordService, {
    FlorestaRpcClient? florestaClient,
  }) : _florestaClient = florestaClient;

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
        case IsolateControllerCommand.florestaRegisterDescriptors:
          if (_florestaClient == null) {
            isolateToMainSendPort.send(Result.failure(ErrorCodes.withMessage(ErrorCodes.nodeUnknown, 'Floresta client not initialized')));
            return;
          }
          try {
            final walletItems = params[0] as List<dynamic>;
            Logger.log('IsolateController: florestaRegisterDescriptors started, wallets=${walletItems.length}');
            for (final walletItem in walletItems) {
              final descriptor = walletItem.descriptor as String?;
              final walletId = walletItem.id;
              Logger.log('IsolateController: registering walletId=$walletId descriptor=${descriptor != null && descriptor.isNotEmpty ? 'present' : 'missing'}');
              if (descriptor != null && descriptor.isNotEmpty) {
                await _florestaClient.loadDescriptor(descriptor);
              } else {
                Logger.log('IsolateController: skipping walletId=$walletId, descriptor is null or empty');
              }
            }
            Logger.log('IsolateController: florestaRegisterDescriptors completed');
            isolateToMainSendPort.send(Result.success(true));
          } catch (e) {
            Logger.error('IsolateController: florestaRegisterDescriptors failed: $e');
            isolateToMainSendPort.send(Result.failure(ErrorCodes.withMessage(ErrorCodes.nodeUnknown, 'florestaRegisterDescriptors: $e')));
          }
          break;
        case IsolateControllerCommand.florestaRescan:
          if (_florestaClient == null) {
            isolateToMainSendPort.send(Result.failure(ErrorCodes.withMessage(ErrorCodes.nodeUnknown, 'Floresta client not initialized')));
            return;
          }
          try {
            final startHeight = params.isNotEmpty ? params[0] as int? : null;
            await _florestaClient.rescan(startHeight: startHeight);
            isolateToMainSendPort.send(Result.success(true));
          } catch (e) {
            Logger.error('IsolateController: florestaRescan failed: $e');
            isolateToMainSendPort.send(Result.failure(ErrorCodes.withMessage(ErrorCodes.nodeUnknown, 'florestaRescan: $e')));
          }
          break;
      }
    } catch (e, stack) {
      Logger.error('IsolateController: Error in $messageType: $e');
      Logger.error(stack);
      isolateToMainSendPort.send(Exception('Error in isolate processing: $e'));
    }
  }
}
