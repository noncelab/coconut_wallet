import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/balance_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_util.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/providers/node_provider/state/state_manager_interface.dart';

/// 스크립트 상태 변경 이벤트 처리를 담당하는 클래스
class ScriptSyncService {
  final StateManagerInterface _stateManager;
  final BalanceSyncService _balanceSyncService;
  final TransactionSyncService _transactionSyncService;
  final UtxoSyncService _utxoSyncService;
  final AddressRepository _addressRepository;
  final ScriptCallbackService _scriptCallbackService;
  late Future<Result<bool>> Function(WalletListItemBase walletItem) _subscribeWallet;

  ScriptSyncService(
    this._stateManager,
    this._balanceSyncService,
    this._transactionSyncService,
    this._utxoSyncService,
    this._addressRepository,
    this._scriptCallbackService,
  );

  set subscribeWallet(Future<Result<bool>> Function(WalletListItemBase walletItem) subscribeWallet) {
    _subscribeWallet = subscribeWallet;
  }

  /// 스크립트 상태 변경 이벤트 처리
  Future<void> syncScriptStatus(SubscribeScriptStreamDto dto) async {
    try {
      final now = DateTime.now();

      // TODO: 네트워크 혼잡한 상황 비동기 처리 필요
      // 네트워크가 혼잡할 경우 일렉트럼 서버에서 이벤트 수신 시점에 데이터 정합성이 안맞는 상황이 있음.
      // 일렉트럼 서버가 데이터 인덱싱을 완료하는 시점을 정확히 알 수 없어서 1초 대기
      await Future.delayed(const Duration(seconds: 1));

      // 지갑 업데이트 상태 초기화
      _stateManager.initWalletUpdateStatus(dto.walletItem.id);

      //fetchScriptUtxo 함수에서 트랜잭션 정보가 필요함. 따라서 실제 트랜잭션 정보가 모두 처리된 후에 호출되도록 콜백함수 등록
      _scriptCallbackService.registerFetchUtxosCallback(
        getScriptKey(dto.walletItem.id, dto.scriptStatus.derivationPath),
        () async {
          // UTXO 동기화가 트랜잭션 동기화에 의존성이 있으므로 Utxo 동기화 상태도 업데이트
          _stateManager.addWalletSyncState(dto.walletItem.id, UpdateElement.utxo);

          await _utxoSyncService.fetchScriptUtxo(dto.walletItem, dto.scriptStatus);
        },
      );

      // 기존 인덱스 저장 (변경 전)
      final oldUsedIndex = dto.scriptStatus.isChange ? dto.walletItem.changeUsedIndex : dto.walletItem.receiveUsedIndex;

      // 지갑 인덱스 업데이트
      await _addressRepository.updateWalletUsedIndex(
        dto.walletItem,
        dto.scriptStatus.index,
        isChange: dto.scriptStatus.isChange,
      );

      // 스크립트 상태가 변경되었으면 주소 사용 여부 업데이트
      if (dto.scriptStatus.status != null) {
        await _addressRepository.setWalletAddressUsed(
          dto.walletItem,
          dto.scriptStatus.index,
          dto.scriptStatus.isChange,
        );
      }
      // 구독 완료
      _stateManager.addWalletCompletedState(dto.walletItem.id, UpdateElement.subscription);

      // Balance 동기화
      await _balanceSyncService.fetchScriptBalance(dto.walletItem, dto.scriptStatus);

      // Transaction 동기화, 이벤트를 수신한 시점의 시간을 사용하기 위해 now 파라미터 전달
      final txHashes = await _transactionSyncService.fetchScriptTransaction(dto.walletItem, dto.scriptStatus, now: now);
      await _scriptCallbackService.registerTransactionDependency(dto.walletItem, dto.scriptStatus, txHashes);

      // 새 스크립트 구독 여부 확인 및 처리
      if (_needSubscriptionUpdate(dto.walletItem, oldUsedIndex, dto.scriptStatus.isChange)) {
        final subResult = await _subscribeWallet(dto.walletItem);

        if (subResult.isSuccess) {
          Logger.log('Successfully extended script subscription for ${dto.walletItem.name}');
        } else {
          Logger.error('Failed to extend script subscription: ${subResult.error}');
        }
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to handle script status change: $e');
      Logger.error('Stack trace: $stackTrace');
      // 오류 발생 시에도 상태 초기화
      _stateManager.setNodeSyncStateToCompleted();
    }
  }

  /// 필요한 경우 추가 스크립트를 구독합니다.
  bool _needSubscriptionUpdate(WalletListItemBase walletItem, int oldUsedIndex, bool isChange) {
    // receive 또는 change 인덱스가 증가한 경우 추가 구독이 필요
    return isChange ? walletItem.changeUsedIndex > oldUsedIndex : walletItem.receiveUsedIndex > oldUsedIndex;
  }

  /// 스크립트 상태 변경 배치 처리
  Future<void> syncBatchScriptStatusList({
    required WalletListItemBase walletItem,
    required List<ScriptStatus> scriptStatuses,
  }) async {
    try {
      final now = DateTime.now();
      final totalStartTime = DateTime.now();

      // Balance 병렬 처리
      final balanceStartTime = DateTime.now();
      await _balanceSyncService.fetchScriptBalanceBatch(walletItem, scriptStatuses);
      final balanceEndTime = DateTime.now();
      final balanceDuration = balanceEndTime.difference(balanceStartTime);
      Logger.performance('Balance sync completed in ${balanceDuration.inMilliseconds}ms for ${walletItem.name}');

      // Transaction 병렬 처리
      _stateManager.addWalletSyncState(walletItem.id, UpdateElement.transaction);
      final transactionStartTime = DateTime.now();

      const chunkSize = 20;
      for (int i = 0; i < scriptStatuses.length; i += chunkSize) {
        final endIndex = (i + chunkSize < scriptStatuses.length) ? i + chunkSize : scriptStatuses.length;
        final batch = scriptStatuses.sublist(i, endIndex);
        final transactionFutures = batch.map(
          (status) =>
              _transactionSyncService.fetchScriptTransaction(walletItem, status, inBatchProcess: true, now: now),
        );
        await Future.wait(transactionFutures);

        if (i + chunkSize < scriptStatuses.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.transaction);

      final transactionEndTime = DateTime.now();
      final transactionDuration = transactionEndTime.difference(transactionStartTime);

      Logger.performance(
        'Transaction sync completed in ${transactionDuration.inMilliseconds}ms for ${walletItem.name} (${scriptStatuses.length} scripts)',
      );

      // UTXO 병렬 처리
      _stateManager.addWalletSyncState(walletItem.id, UpdateElement.utxo);
      final utxoStartTime = DateTime.now();

      await Future.wait(
        scriptStatuses.map((status) => _utxoSyncService.fetchScriptUtxo(walletItem, status, inBatchProcess: true)),
      );

      // 최초 지갑 구독 시 Outgoing Transaction이 있을 경우 UTXO가 생성되지 않을 경우 임의로 UTXO를 생성해야 함
      await _utxoSyncService.createOutgoingUtxos(walletItem);

      // orphaned UTXO가 있으면 정리함
      await _utxoSyncService.cleanupOrphanedUtxos(walletItem);

      _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.utxo);

      final utxoEndTime = DateTime.now();
      final utxoDuration = utxoEndTime.difference(utxoStartTime);
      Logger.performance(
        'UTXO sync completed in ${utxoDuration.inMilliseconds}ms for ${walletItem.name} (${scriptStatuses.length} scripts)',
      );

      // 전체 소요 시간 로그
      final totalEndTime = DateTime.now();
      final totalDuration = totalEndTime.difference(totalStartTime);
      Logger.performance(
        'Total batch sync completed in ${totalDuration.inMilliseconds}ms for ${walletItem.name} (${scriptStatuses.length} scripts)',
      );
      Logger.performance(
        'Sync breakdown - Balance: ${balanceDuration.inMilliseconds}ms, Transaction: ${transactionDuration.inMilliseconds}ms, UTXO: ${utxoDuration.inMilliseconds}ms',
      );
    } catch (e, stackTrace) {
      Logger.error('Failed to handle batch script status change: $e');
      Logger.error('Stack trace: $stackTrace');
      _stateManager.initWalletUpdateStatus(walletItem.id);
      _stateManager.setNodeSyncStateToCompleted();
    }
  }
}
