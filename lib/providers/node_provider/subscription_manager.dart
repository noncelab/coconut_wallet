import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/balance_manager.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/transaction_manager.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/services/model/response/subscribe_wallet_response.dart';
import 'package:coconut_wallet/services/network/node_client.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

/// NodeProvider의 스크립트 구독 관련 기능을 담당하는 매니저 클래스
class SubscriptionManager {
  final NodeClient _nodeClient;
  final NodeStateManager _stateManager;
  final BalanceManager _balanceManager;
  final TransactionManager _transactionManager;
  final UtxoManager _utxoManager;
  final AddressRepository _addressRepository;
  final SubscriptionRepository _subscriptionRepository;

  // 구독중인 스크립트 상태 변경을 인지하는 컨트롤러
  late StreamController<SubscribeScriptStreamDto> _scriptStatusController;

  Stream<SubscribeScriptStreamDto> get scriptStatusStream =>
      _scriptStatusController.stream;

  SubscriptionManager(
    this._nodeClient,
    this._stateManager,
    this._balanceManager,
    this._transactionManager,
    this._utxoManager,
    this._addressRepository,
    this._subscriptionRepository,
  ) {
    _scriptStatusController =
        StreamController<SubscribeScriptStreamDto>.broadcast();
    _scriptStatusController.stream.listen(_handleScriptStatusChanged);
  }

  /// 스크립트 상태 변경 이벤트 처리
  Future<void> _handleScriptStatusChanged(SubscribeScriptStreamDto dto) async {
    try {
      final now = DateTime.now();
      Logger.log(
          'HandleScriptStatusChanged: ${dto.walletItem.name} - ${dto.scriptStatus.derivationPath}');

      // 기존 인덱스 저장 (변경 전)
      final oldReceiveUsedIndex = dto.walletItem.receiveUsedIndex;
      final oldChangeUsedIndex = dto.walletItem.changeUsedIndex;

      // 지갑 인덱스 업데이트
      int receiveUsedIndex = dto.scriptStatus.isChange
          ? dto.walletItem.receiveUsedIndex
          : dto.scriptStatus.index;
      int changeUsedIndex = dto.scriptStatus.isChange
          ? dto.scriptStatus.index
          : dto.walletItem.changeUsedIndex;
      _addressRepository.updateWalletUsedIndex(
          dto.walletItem, receiveUsedIndex, changeUsedIndex);

      // Balance 동기화
      await _balanceManager.fetchScriptBalance(
          dto.walletItem, dto.scriptStatus);

      // Transaction 동기화, 이벤트를 수신한 시점의 시간을 사용하기 위해 now 파라미터 전달
      await _transactionManager.fetchScriptTransaction(
          dto.walletItem, dto.scriptStatus, dto.walletProvider,
          now: now);

      // UTXO 동기화
      await _utxoManager.fetchScriptUtxo(dto.walletItem, dto.scriptStatus);

      // 새 스크립트 구독 여부 확인 및 처리
      if (_needSubscriptionUpdate(
        dto.walletItem,
        oldReceiveUsedIndex,
        oldChangeUsedIndex,
        dto.walletProvider,
      )) {
        final subResult =
            await subscribeWallet(dto.walletItem, dto.walletProvider);

        if (subResult.isSuccess) {
          Logger.log(
              'Successfully extended script subscription for ${dto.walletItem.name}');
        } else {
          Logger.error(
              'Failed to extend script subscription: ${subResult.error}');
        }
      }

      // 동기화 완료 state 업데이트
      _stateManager.setState(newConnectionState: MainClientState.waiting);
    } catch (e) {
      Logger.error('Failed to handle script status change: $e');
    }
  }

  /// 필요한 경우 추가 스크립트를 구독합니다.
  bool _needSubscriptionUpdate(
    WalletListItemBase walletItem,
    int oldReceiveUsedIndex,
    int oldChangeUsedIndex,
    WalletProvider walletProvider,
  ) {
    // receive 또는 change 인덱스가 증가한 경우 추가 구독이 필요
    return walletItem.receiveUsedIndex > oldReceiveUsedIndex ||
        walletItem.changeUsedIndex > oldChangeUsedIndex;
  }

  /// 스크립트 구독
  /// [walletItem] 지갑 아이템
  /// [walletProvider] 지갑 프로바이더
  Future<Result<bool>> subscribeWallet(
      WalletListItemBase walletItem, WalletProvider walletProvider) async {
    try {
      SubscribeWalletResponse subscribeResponse = await _nodeClient
          .subscribeWallet(walletItem, _scriptStatusController, walletProvider);

      if (subscribeResponse.scriptStatuses.isEmpty) {
        Logger.log('SubscribeWallet: ${walletItem.name} - no script statuses');
        return Result.success(true);
      }

      final changedScriptStatuses = subscribeResponse.scriptStatuses
          .where((status) => status.status != null)
          .toList();

      // 지갑 인덱스 업데이트
      _addressRepository.updateWalletUsedIndex(
          walletItem,
          subscribeResponse.usedReceiveIndex,
          subscribeResponse.usedChangeIndex);

      // 배치 업데이트 처리
      await _handleBatchScriptStatusChanged(
        walletItem: walletItem,
        scriptStatuses: changedScriptStatuses,
        walletProvider: walletProvider,
      );

      // 변경된 상태만 DB에 저장
      _subscriptionRepository.batchUpdateScriptStatuses(
          changedScriptStatuses, walletItem.id);

      Logger.log(
          'SubscribeWallet: ${walletItem.name} - finished / subscribedScriptMap.length: ${walletItem.subscribedScriptMap.length}');
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
      await _nodeClient.unsubscribeWallet(walletItem);
      walletItem.subscribedScriptMap.clear();
      Logger.log('UnsubscribeWallet: ${walletItem.name} - finished');
      return Result.success(true);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 스크립트 상태 변경 배치 처리
  Future<void> _handleBatchScriptStatusChanged({
    required WalletListItemBase walletItem,
    required List<ScriptStatus> scriptStatuses,
    required WalletProvider walletProvider,
  }) async {
    try {
      // Balance 병렬 처리
      _stateManager.addWalletSyncState(walletItem.id, UpdateElement.balance);
      await Future.wait(
        scriptStatuses.map(
            (status) => _balanceManager.fetchScriptBalance(walletItem, status)),
      );
      _stateManager.addWalletCompletedState(
          walletItem.id, UpdateElement.balance);

      // Transaction 병렬 처리
      _stateManager.addWalletSyncState(
          walletItem.id, UpdateElement.transaction);
      final transactionFutures = scriptStatuses.map(
        (status) => _transactionManager.fetchScriptTransaction(
            walletItem, status, walletProvider),
      );
      await Future.wait(transactionFutures);
      _stateManager.addWalletCompletedState(
          walletItem.id, UpdateElement.transaction);

      // UTXO 병렬 처리
      _stateManager.addWalletSyncState(walletItem.id, UpdateElement.utxo);
      await Future.wait(
        scriptStatuses
            .map((status) => _utxoManager.fetchScriptUtxo(walletItem, status)),
      );
      _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.utxo);

      // 동기화 완료 state 업데이트
      _stateManager.setState(newConnectionState: MainClientState.waiting);
    } catch (e) {
      Logger.error('Failed to handle batch script status change: $e');
      _stateManager.setState(newConnectionState: MainClientState.waiting);
    }
  }

  /// 리소스 해제
  void dispose() {
    _scriptStatusController.close();
  }
}
