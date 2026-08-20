import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
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
  late Future<Result<bool>> Function(WalletItemBase walletItem) _subscribeWallet;
  late Future<void> Function(WalletItemBase walletItem, String address) _unsubscribeAddress;
  late Future<void> Function(WalletItemBase walletItem, int index, String address, bool isChange) _subscribeAddress;
  final Map<int, Future<void>> _walletSyncQueues = {};
  final Map<int, DateTime> _lastDormantSyncAt = {};
  final Map<String, DateTime> _lastAddressCheckAt = {};

  static const Duration _electrumIndexingDelay = Duration(seconds: 1);
  static const Duration _dormantSyncThrottle = Duration(seconds: 30);
  static const Duration _addressCheckThrottle = Duration(minutes: 1);

  ScriptSyncService(
    this._stateManager,
    this._balanceSyncService,
    this._transactionSyncService,
    this._utxoSyncService,
    this._addressRepository,
    this._scriptCallbackService,
  );

  set subscribeWallet(Future<Result<bool>> Function(WalletItemBase walletItem) subscribeWallet) {
    _subscribeWallet = subscribeWallet;
  }

  set unsubscribeAddress(Future<void> Function(WalletItemBase walletItem, String address) unsubscribeAddress) {
    _unsubscribeAddress = unsubscribeAddress;
  }

  set subscribeAddress(
    Future<void> Function(WalletItemBase walletItem, int index, String address, bool isChange) subscribeAddress,
  ) {
    _subscribeAddress = subscribeAddress;
  }

  /// 주소가 dormant(사용됐지만 잔액/미확정 트랜잭션 없음) 상태가 됐으면 실시간 구독에서 제외한다.
  Future<void> _unsubscribeIfDormant(WalletItemBase walletItem, String address) async {
    if (!_addressRepository.isAddressDormant(walletItem.id, address)) {
      return;
    }
    await _unsubscribeAddress(walletItem, address);
  }

  /// dormant 주소(실시간 구독에서 제외된, 과거 사용됐지만 잔액이 없던 주소)들의 잔액을 배치로
  /// 다시 확인한다. 재사용이나 리오그로 잔액이 다시 생긴 주소가 있으면 재구독한다.
  /// 짧은 시간 안에 여러 화면에서 중복 호출되는 것을 막기 위해 지갑별로 스로틀한다.
  Future<void> syncDormantAddresses(WalletItemBase walletItem) async {
    final lastSyncAt = _lastDormantSyncAt[walletItem.id];
    if (lastSyncAt != null && DateTime.now().difference(lastSyncAt) < _dormantSyncThrottle) {
      return;
    }
    _lastDormantSyncAt[walletItem.id] = DateTime.now();

    final dormantAddresses = _addressRepository.getDormantUsedAddresses(walletItem.id);
    if (dormantAddresses.isEmpty) {
      return;
    }

    final dormantScriptStatuses =
        dormantAddresses
            .map(
              (addr) => ScriptStatus(
                derivationPath: addr.derivationPath,
                address: addr.address,
                index: addr.index,
                isChange: addr.isChange,
                scriptPubKey: '',
                status: null,
                timestamp: DateTime.now(),
              ),
            )
            .toList();

    await _balanceSyncService.fetchScriptBalanceBatch(walletItem, dormantScriptStatuses);

    for (final addr in dormantAddresses) {
      if (!_addressRepository.isAddressDormant(walletItem.id, addr.address)) {
        await _subscribeAddress(walletItem, addr.index, addr.address, addr.isChange);
      }
    }
  }

  /// 사용자가 화면에서 실제로 보고 있는(스크롤로 로드된) 주소들의 잔액을 온디맨드로 확인한다.
  /// 최근에 이미 확인한 주소는 세션 내 짧은 시간 동안 다시 확인하지 않는다.
  /// gap 윈도우 밖이라 아직 미사용으로 표시된 주소에서 잔액이 발견되면, usedIndex(모니터링 윈도우)는
  /// 그대로 두고 그 주소만 개별적으로 사용됨으로 표시 + 구독 대상에 추가한다.
  Future<void> syncViewedAddresses(WalletItemBase walletItem, List<WalletAddress> addresses) async {
    final now = DateTime.now();
    final addressesToCheck =
        addresses.where((addr) {
          final lastCheckedAt = _lastAddressCheckAt[addr.address];
          return lastCheckedAt == null || now.difference(lastCheckedAt) >= _addressCheckThrottle;
        }).toList();

    if (addressesToCheck.isEmpty) {
      return;
    }

    for (final addr in addressesToCheck) {
      _lastAddressCheckAt[addr.address] = now;
    }

    final scriptStatuses =
        addressesToCheck
            .map(
              (addr) => ScriptStatus(
                derivationPath: addr.derivationPath,
                address: addr.address,
                index: addr.index,
                isChange: addr.isChange,
                scriptPubKey: '',
                status: null,
                timestamp: now,
              ),
            )
            .toList();

    await _balanceSyncService.fetchScriptBalanceBatch(walletItem, scriptStatuses);

    for (final addr in addressesToCheck) {
      if (addr.isUsed) {
        continue;
      }
      if (!_addressRepository.isAddressActive(walletItem.id, addr.address)) {
        continue;
      }
      await _addressRepository.setWalletAddressUsed(walletItem, addr.index, addr.isChange);
      await _subscribeAddress(walletItem, addr.index, addr.address, addr.isChange);
    }
  }

  /// 지갑 ID별로 작업을 도착 순서대로 직렬 처리합니다.
  /// 이미 이 큐 안에서 실행 중인 작업(예: [_processScriptStatus])에서
  /// 재귀적으로 호출하면 자기 자신의 완료를 기다리게 되어 데드락이 나므로, 중첩 호출하지 않도록 주의합니다.
  Future<T> runQueued<T>(int walletId, Future<T> Function() task) {
    final previousSync = _walletSyncQueues[walletId] ?? Future<void>.value();
    final completer = Completer<T>();

    final queuedSync = previousSync.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, stackTrace) {
        completer.completeError(e, stackTrace);
      }
    });

    late final Future<void> queuedSyncWithCleanup;
    queuedSyncWithCleanup = queuedSync.whenComplete(() {
      if (identical(_walletSyncQueues[walletId], queuedSyncWithCleanup)) {
        _walletSyncQueues.remove(walletId);
      }
    });
    _walletSyncQueues[walletId] = queuedSyncWithCleanup;

    return completer.future;
  }

  /// 스크립트 상태 변경 이벤트 처리
  Future<void> syncScriptStatus(SubscribeScriptStreamDto dto) {
    final receivedAt = DateTime.now();
    return runQueued(dto.walletItem.id, () => _processScriptStatus(dto, receivedAt));
  }

  Future<void> _processScriptStatus(SubscribeScriptStreamDto dto, DateTime receivedAt) async {
    try {
      final remainingIndexingDelay = _electrumIndexingDelay - DateTime.now().difference(receivedAt);
      if (!remainingIndexingDelay.isNegative) {
        await Future.delayed(remainingIndexingDelay);
      }

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
      await _unsubscribeIfDormant(dto.walletItem, dto.scriptStatus.address);

      // Transaction 동기화
      final fetchResult = await _transactionSyncService.fetchScriptTransaction(
        dto.walletItem,
        dto.scriptStatus,
        now: receivedAt,
      );
      await _scriptCallbackService.registerTransactionDependency(
        dto.walletItem,
        dto.scriptStatus,
        fetchResult.txHashes,
      );

      // 이번 이벤트가 트리거한 주소 외에 같은 트랜잭션으로 UTXO가 함께 소비된 주소가 있다면,
      // 그 주소들 자신의 구독 이벤트가 실패/누락되어도 잔액이 stale 상태로 남지 않도록 동기화한다.
      if (fetchResult.coSpentAddresses.isNotEmpty) {
        await _syncCoSpentAddressBalances(dto.walletItem, fetchResult.coSpentAddresses);
      }

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
  bool _needSubscriptionUpdate(WalletItemBase walletItem, int oldUsedIndex, bool isChange) {
    // receive 또는 change 인덱스가 증가한 경우 추가 구독이 필요
    return isChange ? walletItem.changeUsedIndex > oldUsedIndex : walletItem.receiveUsedIndex > oldUsedIndex;
  }

  /// 같은 트랜잭션에서 함께 소비된, 이번 이벤트를 트리거하지 않은 다른 지갑 주소들의 잔액을 강제로 동기화한다.
  /// 그 주소 자신의 구독 이벤트가 실패/누락되어 잔액 diff가 반영되지 않은 채 UTXO만 삭제되는 경우를 방지한다.
  Future<void> _syncCoSpentAddressBalances(WalletItemBase walletItem, Set<String> addresses) async {
    final walletId = walletItem.id;

    Logger.log('Syncing co-spent address balances for wallet $walletId: $addresses');

    for (final address in addresses) {
      final addressInfo = _addressRepository.getIndexAndIsChange(walletId, address);
      if (addressInfo == null) {
        continue;
      }

      try {
        await _balanceSyncService.syncAddressBalance(
          walletItem,
          address: address,
          index: addressInfo.index,
          isChange: addressInfo.isChange,
        );
        await _unsubscribeIfDormant(walletItem, address);
      } catch (e, stackTrace) {
        Logger.error('Failed to sync balance for co-spent address $address: $e');
        Logger.error('Stack trace: $stackTrace');
      }
    }
  }

  /// 스크립트 상태 변경 배치 처리
  Future<void> syncBatchScriptStatusList({
    required WalletItemBase walletItem,
    required List<ScriptStatus> scriptStatuses,
  }) async {
    try {
      final now = DateTime.now();
      final totalStartTime = DateTime.now();

      // Balance 병렬 처리
      final balanceStartTime = DateTime.now();
      await _balanceSyncService.fetchScriptBalanceBatch(walletItem, scriptStatuses);
      await Future.wait(scriptStatuses.map((s) => _unsubscribeIfDormant(walletItem, s.address)));
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
