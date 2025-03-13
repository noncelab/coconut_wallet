import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/balance_manager.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_manager.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

/// 스크립트 상태 변경 이벤트 처리를 담당하는 클래스
class ScriptEventHandler {
  final NodeStateManager _stateManager;
  final BalanceManager _balanceManager;
  final TransactionManager _transactionManager;
  final UtxoManager _utxoManager;
  final AddressRepository _addressRepository;
  final Future<Result<bool>> Function(
          WalletListItemBase walletItem, WalletProvider walletProvider)
      _subscribeWallet;

  ScriptEventHandler(
    this._stateManager,
    this._balanceManager,
    this._transactionManager,
    this._utxoManager,
    this._addressRepository,
    this._subscribeWallet,
  );

  /// 스크립트 상태 변경 이벤트 처리
  Future<void> handleScriptStatusChanged(SubscribeScriptStreamDto dto) async {
    try {
      final now = DateTime.now();
      Logger.log(
          'HandleScriptStatusChanged: ${dto.walletItem.name} - ${dto.scriptStatus.derivationPath}');

      // 지갑 업데이트 상태 초기화
      _stateManager.initWalletUpdateStatus(dto.walletItem.id);

      // 스크립트 상태가 변경되었으면 주소 사용 여부 업데이트
      if (dto.scriptStatus.status != null) {
        _addressRepository.setWalletAddressUsed(
            dto.walletItem, dto.scriptStatus.index, dto.scriptStatus.isChange);
      }

      // 기존 인덱스 저장 (변경 전)
      final oldUsedIndex = dto.scriptStatus.isChange
          ? dto.walletItem.changeUsedIndex
          : dto.walletItem.receiveUsedIndex;

      // 지갑 인덱스 업데이트
      _addressRepository.updateWalletUsedIndex(
        dto.walletItem,
        dto.scriptStatus.index,
        isChange: dto.scriptStatus.isChange,
      );

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
        oldUsedIndex,
        dto.walletProvider,
        dto.scriptStatus.isChange,
      )) {
        final subResult =
            await _subscribeWallet(dto.walletItem, dto.walletProvider);

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
    int oldUsedIndex,
    WalletProvider walletProvider,
    bool isChange,
  ) {
    // receive 또는 change 인덱스가 증가한 경우 추가 구독이 필요
    return isChange
        ? walletItem.changeUsedIndex > oldUsedIndex
        : walletItem.receiveUsedIndex > oldUsedIndex;
  }

  /// 스크립트 상태 변경 배치 처리
  Future<void> handleBatchScriptStatusChanged({
    required WalletListItemBase walletItem,
    required List<ScriptStatus> scriptStatuses,
    required WalletProvider walletProvider,
  }) async {
    try {
      // Balance 병렬 처리
      await _balanceManager.fetchScriptBalanceBatch(walletItem, scriptStatuses);

      // Transaction 병렬 처리
      _stateManager.addWalletSyncState(
          walletItem.id, UpdateElement.transaction);
      final transactionFutures = scriptStatuses.map(
        (status) => _transactionManager.fetchScriptTransaction(
            walletItem, status, walletProvider,
            inBatchProcess: true),
      );
      await Future.wait(transactionFutures);
      _stateManager.addWalletCompletedState(
          walletItem.id, UpdateElement.transaction);

      // UTXO 병렬 처리
      _stateManager.addWalletSyncState(walletItem.id, UpdateElement.utxo);
      await Future.wait(
        scriptStatuses.map((status) => _utxoManager
            .fetchScriptUtxo(walletItem, status, inBatchProcess: true)),
      );
      _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.utxo);

      // 동기화 완료 state 업데이트
      _stateManager.setState(newConnectionState: MainClientState.waiting);
    } catch (e, stackTrace) {
      Logger.error('Failed to handle batch script status change: $e');
      Logger.error('Stack trace: $stackTrace');
      _stateManager.initWalletUpdateStatus(walletItem.id);
      _stateManager.setState(newConnectionState: MainClientState.waiting);
    }
  }
}
