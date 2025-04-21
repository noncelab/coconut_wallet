import 'dart:async';

import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/balance_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager_interface.dart';

/// NodeProvider의 스크립트 구독 관련 기능을 담당하는 매니저 클래스
class SubscriptionManager {
  final ElectrumService _electrumService;
  final StateManagerInterface _stateManager;
  final BalanceSyncService _balanceSyncService;
  final TransactionSyncService _transactionSyncService;
  final UtxoSyncService _utxoSyncService;
  final AddressRepository _addressRepository;
  final SubscriptionRepository _subscriptionRepository;
  final ScriptCallbackService _scriptCallbackService;

  // 구독중인 스크립트 상태 변경을 인지하는 컨트롤러
  late StreamController<SubscribeScriptStreamDto> _scriptStatusController;
  late SubscriptionService _subscriptionService;
  late ScriptSyncService _scriptSyncService;

  SubscriptionManager(
    this._electrumService,
    this._stateManager,
    this._balanceSyncService,
    this._transactionSyncService,
    this._utxoSyncService,
    this._addressRepository,
    this._subscriptionRepository,
    this._scriptCallbackService,
  ) {
    _scriptStatusController = StreamController<SubscribeScriptStreamDto>.broadcast();

    _subscriptionService = SubscriptionService(
      _electrumService,
      _scriptStatusController,
      _addressRepository,
    );

    _scriptSyncService = ScriptSyncService(
      _stateManager,
      _balanceSyncService,
      _transactionSyncService,
      _utxoSyncService,
      _addressRepository,
      subscribeWallet,
      _scriptCallbackService,
    );

    _scriptStatusController.stream.listen(_scriptSyncService.syncScriptStatus);
  }

  /// 스크립트 구독
  /// [walletItem] 지갑 아이템
  /// [walletProvider] 지갑 프로바이더
  Future<Result<bool>> subscribeWallet(WalletListItemBase walletItem) async {
    try {
      final fetchedScriptStatuses = await _subscriptionService.subscribeWallet(
        walletItem,
      );

      // 사용 이력이 없는 지갑
      if (fetchedScriptStatuses.isEmpty) {
        _stateManager.addWalletCompletedAllStates(walletItem.id);
        return Result.success(true);
      }

      final existingScriptStatusMap = _subscriptionRepository.getScriptStatusMap(
        walletItem.id,
      );

      final updatedScriptStatuses = <ScriptStatus>[];

      for (final status in fetchedScriptStatuses) {
        final existingStatus = existingScriptStatusMap[status.scriptPubKey];

        if (status.status != existingStatus?.status) {
          updatedScriptStatuses.add(status);
        }
      }

      // 변경 이력이 없는 지갑
      if (updatedScriptStatuses.isEmpty) {
        _stateManager.addWalletCompletedAllStates(walletItem.id);
        return Result.success(true);
      }

      // 변경 이력이 있는 지갑에 대해서만 balance, transaction, utxo 업데이트
      await _scriptSyncService.syncBatchScriptStatusList(
        walletItem: walletItem,
        scriptStatuses: updatedScriptStatuses,
      );

      // 변경된 ScriptStatus DB에 저장
      _subscriptionRepository.batchUpdateScriptStatuses(
          walletItem.id, updatedScriptStatuses, existingScriptStatusMap);

      return Result.success(true);
    } catch (e) {
      Logger.error('SubscribeWallet: ${walletItem.name} - failed');
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 스크립트 구독 해제
  /// [walletItem] 지갑 아이템
  Future<Result<bool>> unsubscribeWallet(WalletListItemBase walletItem) async {
    try {
      await _subscriptionService.unsubscribeWallet(walletItem);
      return Result.success(true);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 리소스 해제
  void dispose() {
    _scriptStatusController.close();
  }
}
