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
import 'package:flutter/foundation.dart' show visibleForTesting;
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
  final Set<int> _failedWalletSyncs = {};
  final Map<(int, String), ScriptStatus> _failedScriptSyncs = {};
  final Map<int, DateTime> _lastDormantSyncAt = {};
  final Set<(int, String)> _failedDormantChecks = {};
  // 주소 목록에서 이력 조회에 실패한 주소(지갑 구독 뒤 다시 확인하려고 주소 정보를 함께 둔다)
  final Map<(int, String), WalletAddress> _failedViewedChecks = {};
  final Map<(int, String), String> _resyncedDormantHistory = {};
  final Map<(int, String), DateTime> _lastAddressCheckAt = {};

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

  Future<void> restorePendingUtxoLocks(int walletId) {
    return _utxoSyncService.restorePendingUtxoLocks(walletId);
  }

  Iterable<ScriptStatus> getFailedScripts(int walletId) =>
      _failedScriptSyncs.entries.where((entry) => entry.key.$1 == walletId).map((entry) => entry.value);

  /// 이 주소를 확인하거나 동기화하는 데 성공했을 때 그 주소의 실패 표시를 지운다. 다른 주소의 실패는 건드리지 않는다.
  /// 주소 목록 실패는 확인에 성공하면 지운다. 휴면 재확인 실패는 이력을 확인했을 때만([historyChecked]) 지운다.
  /// 잔액만 맞아도 기록에 빠진 거래가 있을 수 있어서다. 잔액 조회 실패는 잔액까지 맞는 것을 알았을 때만([balanceKnown]) 지운다.
  /// 동기화 실패(다음 구독 때 다시 처리할 목록)는 동기화가 성공할 때만 따로 지운다.
  void _clearCheckFailures(int walletId, String address, {required bool historyChecked, required bool balanceKnown}) {
    final key = (walletId, address);
    _failedViewedChecks.remove(key);
    if (historyChecked) _failedDormantChecks.remove(key);
    if (balanceKnown) _balanceSyncService.clearBalanceFetchFailure(walletId, address);
  }

  /// 새 구독 응답이 저장된 상태와 같은 주소만 확인 완료로 처리한다. 캐시 재사용·배치 대상은 호출자가 제외한다.
  void markSubscribedAddressesChecked(int walletId, Iterable<String> addresses) {
    for (final address in addresses) {
      _clearCheckFailures(walletId, address, historyChecked: true, balanceKnown: true);
    }
  }

  /// 주소 목록에서 이력 조회에 실패한 주소를 스로틀 없이 다시 확인한다. 지갑 구독 범위 밖이라(gap 밖 등)
  /// 구독으로는 확인되지 않는 주소가 지갑 구독·재동기화 뒤에도 실패로 남지 않게 한다. 다시 실패하면 그대로 남는다.
  Future<void> recheckViewedFailures(WalletItemBase walletItem) async {
    final failedAddresses = [
      for (final entry in _failedViewedChecks.entries)
        if (entry.key.$1 == walletItem.id) entry.value,
    ];
    if (failedAddresses.isEmpty) return;
    final restoredAddresses = <WalletAddress>[];
    // 같은 거래의 모든 내 출력을 세도록 재확인 대상 행을 먼저 전부 복원한다.
    for (final address in failedAddresses) {
      try {
        await _addressRepository.ensureAddressesExist(
          walletItemBase: walletItem,
          cursor: address.index,
          count: 1,
          isChange: address.isChange,
        );
        restoredAddresses.add(address);
      } catch (e, stackTrace) {
        _failedViewedChecks[(walletItem.id, address.address)] = address;
        Logger.error('Failed to restore viewed address: $e');
        Logger.error('Stack trace: $stackTrace');
      }
    }
    for (final address in restoredAddresses) {
      try {
        final addresses = await _addressRepository.getWalletAddressList(
          walletItem,
          address.index - 1,
          1,
          address.isChange,
          false,
        );
        await _checkViewedAddresses(walletItem, addresses, DateTime.now());
      } catch (e, stackTrace) {
        // 재확인 오류가 완료된 지갑 구독·재동기화의 잠금 복원을 막지 않게 해당 주소만 실패로 남긴다.
        _failedViewedChecks[(walletItem.id, address.address)] = address;
        Logger.error('Failed to recheck viewed address: $e');
        Logger.error('Stack trace: $stackTrace');
      }
    }
  }

  /// DB를 초기화하면 이전에 맞춘 이력으로 현재 잔액을 증명할 수 없다. 같은 지갑 큐 안에서 호출한다.
  void clearDormantHistory(int walletId) {
    _resyncedDormantHistory.removeWhere((key, _) => key.$1 == walletId);
  }

  @visibleForTesting
  bool hasSyncFailure(int walletId, String address) {
    final key = (walletId, address);
    return _failedScriptSyncs.containsKey(key) ||
        _failedViewedChecks.containsKey(key) ||
        _failedDormantChecks.contains(key) ||
        _balanceSyncService.hasBalanceFetchFailure(walletId, address);
  }

  /// 주소가 dormant(사용됐지만 잔액/미확정 트랜잭션 없음) 상태가 됐으면 실시간 구독에서 제외한다.
  Future<void> _unsubscribeIfDormant(WalletItemBase walletItem, String address) async {
    if (!_addressRepository.isAddressDormant(walletItem.id, address)) {
      return;
    }
    await _unsubscribeAddress(walletItem, address);
  }

  /// dormant 주소(실시간 구독에서 제외된, 과거 사용됐지만 잔액이 없던 주소)와 구멍(사용 인덱스 앞의 미사용 주소)을
  /// 거래 이력으로 배치 재확인한다. 받고 다 쓴 주소는 잔액으로는 안 보이므로 이력을 보고, 기록과 맞지 않는 주소만
  /// 다시 동기화한다. 동기화 뒤 잔액이나 미확정 거래가 남은 주소만 구독에 남는다.
  /// 짧은 시간 안에 여러 화면에서 중복 호출되는 것을 막기 위해 지갑별로 스로틀한다.
  Future<void> syncDormantAddresses(WalletItemBase walletItem) async {
    final lastSyncAt = _lastDormantSyncAt[walletItem.id];
    if (lastSyncAt != null && DateTime.now().difference(lastSyncAt) < _dormantSyncThrottle) {
      return;
    }
    _lastDormantSyncAt[walletItem.id] = DateTime.now();

    final dormantAddresses = [
      ..._addressRepository.getDormantUsedAddresses(walletItem.id),
      ..._addressRepository.getUnusedAddressesBelowUsedIndex(walletItem.id),
    ];
    if (dormantAddresses.isEmpty) {
      return;
    }

    final (:toResync, :failed) = await _transactionSyncService.findDormantAddressesToResync(
      walletItem,
      dormantAddresses,
    );
    // 조회에 실패한 주소는 사용 표시도 동기화도 하지 않는다. 다음 재확인에서 다시 조회하고, 그때까지 지갑 동기화는 실패로 둔다.
    // 이번에 확인한 주소의 실패만 고친다. 기록과 맞는 것까지 확인했으면(완전한 이력으로 잔액 일치, 또는 잔액 재조회 성공)
    // 잔액 조회 실패도 지운다. 다시 동기화할 주소의 잔액 조회 실패는 동기화가 성공할 때 지워진다.
    for (final addr in dormantAddresses) {
      if (failed.contains(addr.address)) {
        _failedDormantChecks.add((walletItem.id, addr.address));
      } else {
        _clearCheckFailures(
          walletItem.id,
          addr.address,
          historyChecked: true,
          balanceKnown: !toResync.containsKey(addr.address),
        );
      }
    }

    for (final addr in dormantAddresses) {
      final history = toResync[addr.address];
      final key = (walletItem.id, addr.address);
      if (history == null) {
        continue;
      }
      // 앱이 켜져 있는 동안 같은 이력으로 이미 맞춘 주소는 다시 하지 않는다(기록이 불완전해도 재확인마다 반복하지 않게).
      // 이력이 그대로라 잔액도 그때 맞춘 그대로다.
      if (_resyncedDormantHistory[key] == history) {
        _clearCheckFailures(walletItem.id, addr.address, historyChecked: true, balanceKnown: true);
        continue;
      }
      // 이력이 있는 구멍은 사용됨으로 표시해야 다음 실행부터 활성 주소로 구독된다.
      if (!addr.isUsed) {
        await _addressRepository.setWalletAddressUsed(walletItem, addr.index, addr.isChange);
      }

      // 동기화하는 동안 오는 알림을 놓치지 않게 먼저 구독한다. 끝난 뒤 잔액·미확정 거래가 없으면 처리 끝에서 다시 해제된다.
      await _subscribeAddress(walletItem, addr.index, addr.address, addr.isChange);

      await _processScriptStatus(
        SubscribeScriptStreamDto(
          walletItem: walletItem,
          scriptStatus: ScriptStatus(
            derivationPath: addr.derivationPath,
            address: addr.address,
            index: addr.index,
            isChange: addr.isChange,
            scriptPubKey: '',
            status: null,
            timestamp: DateTime.now(),
          ),
        ),
        DateTime.now(),
      );
      if (!_failedScriptSyncs.containsKey(key)) {
        _resyncedDormantHistory[key] = history;
      }
    }
  }

  /// 사용자가 화면에서 실제로 보고 있는(스크롤로 로드된) 주소들을 온디맨드로 확인한다.
  /// 최근에 이미 확인한 주소는 세션 내 짧은 시간 동안 다시 확인하지 않는다.
  /// 사용 주소는 잔액을 다시 받는다. 쉬고 있던 사용 주소에 돈이 다시 들어왔으면 구독하고 거래까지 받는다.
  /// 미사용 주소는 받고 다 쓴 경우도 찾도록 잔액 대신 거래 이력을 묻는다. 이력이 있으면 usedIndex(모니터링 윈도우)는
  /// 그대로 두고 그 주소만 개별적으로 사용됨으로 표시 + 구독 대상에 추가한다.
  /// 새로 사용이 발견된 주소 목록을 반환
  Future<List<WalletAddress>> syncViewedAddresses(WalletItemBase walletItem, List<WalletAddress> addresses) async {
    final now = DateTime.now();
    final addressesToCheck =
        addresses.where((addr) {
          final lastCheckedAt = _lastAddressCheckAt[(walletItem.id, addr.address)];
          return lastCheckedAt == null || now.difference(lastCheckedAt) >= _addressCheckThrottle;
        }).toList();

    if (addressesToCheck.isEmpty) {
      return [];
    }

    for (final addr in addressesToCheck) {
      _lastAddressCheckAt[(walletItem.id, addr.address)] = now;
    }
    return _checkViewedAddresses(walletItem, addressesToCheck, now);
  }

  Future<List<WalletAddress>> _checkViewedAddresses(
    WalletItemBase walletItem,
    List<WalletAddress> addressesToCheck,
    DateTime now,
  ) async {
    final usedAddresses = [
      for (final addr in addressesToCheck)
        if (addr.isUsed) addr,
    ];
    final unusedAddresses = [
      for (final addr in addressesToCheck)
        if (!addr.isUsed) addr,
    ];
    if (usedAddresses.isNotEmpty) {
      await _balanceSyncService.fetchScriptBalanceBatch(walletItem, [
        for (final addr in usedAddresses)
          ScriptStatus(
            derivationPath: addr.derivationPath,
            address: addr.address,
            index: addr.index,
            isChange: addr.isChange,
            scriptPubKey: '',
            status: null,
            timestamp: now,
          ),
      ]);
    }
    var addressesWithHistory = <String>{};
    var failedAddresses = <String>{};
    if (unusedAddresses.isNotEmpty) {
      final (:toResync, :failed) = await _transactionSyncService.findDormantAddressesToResync(
        walletItem,
        unusedAddresses,
      );
      addressesWithHistory = toResync.keys.toSet();
      failedAddresses = failed;
    }
    // 이력 조회에 실패한 주소는 다음에 볼 때 다시 묻고 그때까지 지갑 동기화는 실패로 둔다(잔액 조회 실패는 잔액 서비스가 남긴다).
    // 이번에 확인한 주소의 실패만 고친다. 사용 주소는 잔액 조회가 성공했으면, 미사용 주소는 이력이 비어 있으면 잔액까지 확인한 것이다.
    for (final addr in addressesToCheck) {
      if (failedAddresses.contains(addr.address)) {
        _failedViewedChecks[(walletItem.id, addr.address)] = addr;
      } else if (addr.isUsed) {
        // 사용 주소는 잔액만 물었다. 잔액이 맞아도 기록에 빠진 거래가 있을 수 있어 휴면 재확인 실패는 남긴다.
        _clearCheckFailures(
          walletItem.id,
          addr.address,
          historyChecked: false,
          balanceKnown: !_balanceSyncService.hasBalanceFetchFailure(walletItem.id, addr.address),
        );
      } else {
        _clearCheckFailures(
          walletItem.id,
          addr.address,
          historyChecked: true,
          balanceKnown: !addressesWithHistory.contains(addr.address),
        );
      }
    }

    final discoveredAddresses = <WalletAddress>[];
    for (final addr in addressesToCheck) {
      final isNewlyUsed = !addr.isUsed && addressesWithHistory.contains(addr.address);
      // 쉬고 있던 사용 주소에 돈이 다시 들어왔으면 거래까지 받고 구독한다. 잔액만 오르면 휴면 재확인 대상에서도 빠진다.
      final isRefunded =
          addr.isUsed &&
          addr.total == 0 &&
          addr.unconfirmed == 0 &&
          _addressRepository.isAddressActive(walletItem.id, addr.address);
      if (!isNewlyUsed && !isRefunded) {
        continue;
      }
      if (isNewlyUsed) {
        await _addressRepository.setWalletAddressUsed(walletItem, addr.index, addr.isChange);
      }
      await _subscribeAddress(walletItem, addr.index, addr.address, addr.isChange);
      if (isNewlyUsed) {
        discoveredAddresses.add(addr);
      }

      await _processScriptStatus(
        SubscribeScriptStreamDto(
          walletItem: walletItem,
          scriptStatus: ScriptStatus(
            derivationPath: addr.derivationPath,
            address: addr.address,
            index: addr.index,
            isChange: addr.isChange,
            scriptPubKey: '',
            status: null,
            timestamp: now,
          ),
          updateUsedIndex: false,
        ),
        now,
      );
    }

    return discoveredAddresses;
  }

  /// 지갑 ID별로 작업을 도착 순서대로 직렬 처리합니다.
  /// 이미 이 큐 안에서 실행 중인 작업(예: [_processScriptStatus])에서
  /// 재귀적으로 호출하면 자기 자신의 완료를 기다리게 되어 데드락이 나므로, 중첩 호출하지 않도록 주의합니다.
  Future<T> runQueued<T>(int walletId, Future<T> Function() task) {
    final startsQueue = !_walletSyncQueues.containsKey(walletId);
    final previousSync = _walletSyncQueues[walletId] ?? Future<void>.value();
    final completer = Completer<T>();

    final queuedSync = previousSync.then((_) async {
      try {
        final result = await task();
        if (result is Result && result.isFailure) _failedWalletSyncs.add(walletId);
        completer.complete(result);
      } catch (e, stackTrace) {
        _failedWalletSyncs.add(walletId);
        completer.completeError(e, stackTrace);
      }
    });

    late final Future<void> queuedSyncWithCleanup;
    queuedSyncWithCleanup = queuedSync.whenComplete(() {
      if (identical(_walletSyncQueues[walletId], queuedSyncWithCleanup)) {
        _walletSyncQueues.remove(walletId);
        final failed =
            _failedWalletSyncs.remove(walletId) ||
            _failedScriptSyncs.keys.any((entry) => entry.$1 == walletId) ||
            _failedDormantChecks.any((entry) => entry.$1 == walletId) ||
            _failedViewedChecks.keys.any((entry) => entry.$1 == walletId) ||
            _balanceSyncService.hasBalanceFetchFailures(walletId);
        _stateManager.setWalletSyncQueueState(
          walletId,
          false,
          failed ? null : _balanceSyncService.getWalletBalance(walletId),
        );
      }
    });
    _walletSyncQueues[walletId] = queuedSyncWithCleanup;
    if (startsQueue) {
      _stateManager.setWalletSyncQueueState(walletId, true, _balanceSyncService.getWalletBalance(walletId));
    }

    return completer.future.whenComplete(() => queuedSyncWithCleanup);
  }

  /// 스크립트 상태 변경 이벤트 처리
  Future<void> syncScriptStatus(SubscribeScriptStreamDto dto) {
    final receivedAt = DateTime.now();
    return runQueued(dto.walletItem.id, () => _processScriptStatus(dto, receivedAt));
  }

  /// [dto.updateUsedIndex]가 false면 usedIndex(모니터링 윈도우) 갱신과 그에 따른 구독 확장을 건너뛴다.
  /// 예: gap window 밖에서 개별적으로 사용된 주소 발견
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
      if (dto.updateUsedIndex) {
        await _addressRepository.updateWalletUsedIndex(
          dto.walletItem,
          dto.scriptStatus.index,
          isChange: dto.scriptStatus.isChange,
        );
      }

      // 스크립트 상태가 변경되었으면 주소 사용 여부 업데이트
      if (dto.scriptStatus.status != null) {
        await _addressRepository.setWalletAddressUsed(
          dto.walletItem,
          dto.scriptStatus.index,
          dto.scriptStatus.isChange,
        );
      }
      // 새 출력 주소를 모두 저장한 뒤 거래의 내 주소 여부를 판정한다.
      if (dto.updateUsedIndex &&
          ((dto.retrySubscription && dto.scriptStatus.index == oldUsedIndex) ||
              _needSubscriptionUpdate(dto.walletItem, oldUsedIndex, dto.scriptStatus.isChange))) {
        final subResult = await _subscribeWallet(dto.walletItem);

        if (subResult.isSuccess) {
          Logger.log('Successfully extended script subscription for ${dto.walletItem.name}');
        } else {
          throw StateError('Failed to extend script subscription: ${subResult.error}');
        }
      }
      // 구독 완료
      _stateManager.addWalletCompletedState(dto.walletItem.id, UpdateElement.subscription);

      // Balance 동기화
      await _balanceSyncService.fetchScriptBalance(dto.walletItem, dto.scriptStatus);

      // Transaction 동기화
      _stateManager.addWalletFetchDispatched(dto.walletItem.id, 1);
      final fetchResult = await _transactionSyncService.fetchScriptTransaction(
        dto.walletItem,
        dto.scriptStatus,
        now: receivedAt,
      );
      _stateManager.addWalletFetchCompleted(dto.walletItem.id, 1);
      await _scriptCallbackService.registerTransactionDependency(
        dto.walletItem,
        dto.scriptStatus,
        fetchResult.txHashes,
      );
      await _unsubscribeIfDormant(dto.walletItem, dto.scriptStatus.address);

      // 이번 이벤트가 트리거한 주소 외에 같은 트랜잭션으로 UTXO가 함께 소비된 주소가 있다면,
      // 그 주소들 자신의 구독 이벤트가 실패/누락되어도 잔액이 stale 상태로 남지 않도록 동기화한다.
      if (fetchResult.coSpentAddresses.isNotEmpty) {
        await _syncCoSpentAddressBalances(dto.walletItem, fetchResult.coSpentAddresses);
      }

      _failedScriptSyncs.remove((dto.walletItem.id, dto.scriptStatus.address));
      // 이 주소를 서버 기준으로 다시 맞췄으니 그 주소의 확인 실패 표시도 지운다.
      _clearCheckFailures(dto.walletItem.id, dto.scriptStatus.address, historyChecked: true, balanceKnown: true);
    } catch (e, stackTrace) {
      _failedScriptSyncs[(dto.walletItem.id, dto.scriptStatus.address)] = dto.scriptStatus;
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
        // 잔액만 확인했으니 휴면 재확인 실패(이력)는 남긴다.
        _clearCheckFailures(walletId, address, historyChecked: false, balanceKnown: true);
        await _unsubscribeIfDormant(walletItem, address);
      } catch (e, stackTrace) {
        _failedWalletSyncs.add(walletId);
        Logger.error('Failed to sync balance for co-spent address $address: $e');
        Logger.error('Stack trace: $stackTrace');
      }
    }
  }

  /// 스크립트 상태 변경 배치 처리
  /// [onProgress]는 재동기화 화면 진행률 표시 등 선택적 용도로만 사용한다(기본 null, 일반 흐름에는 영향 없음).
  /// balance/transaction/utxo 세 단계 각각이 scriptStatuses 전체를 한 번씩 처리하므로, 전체 작업량을
  /// scriptStatuses.length * 3으로 보고 각 단계의 배치/청크가 끝날 때마다 누적치를 보고한다 —
  /// balance만 대상 스크립트가 적어도(예: transaction 청크 20개 미만) 최소 한 번은 진행률이 찍힌다.
  Future<void> syncBatchScriptStatusList({
    required WalletItemBase walletItem,
    required List<ScriptStatus> scriptStatuses,
    void Function(int completed, int total)? onProgress,
  }) async {
    try {
      final now = DateTime.now();
      final totalStartTime = DateTime.now();
      final progressTotal = scriptStatuses.length * 3;
      int progressCompleted = 0;
      void reportProgress(int delta) {
        progressCompleted += delta;
        onProgress?.call(progressCompleted, progressTotal);
      }

      // Balance 병렬 처리
      final balanceStartTime = DateTime.now();
      await _balanceSyncService.fetchScriptBalanceBatch(walletItem, scriptStatuses, onBatchProgress: reportProgress);
      if (_balanceSyncService.hasBalanceFetchFailures(walletItem.id)) {
        throw StateError('Incomplete wallet balance synchronization');
      }
      final balanceEndTime = DateTime.now();
      final balanceDuration = balanceEndTime.difference(balanceStartTime);
      Logger.performance('Balance sync completed in ${balanceDuration.inMilliseconds}ms for ${walletItem.name}');

      // Transaction 병렬 처리
      _stateManager.addWalletSyncState(walletItem.id, UpdateElement.transaction);
      _stateManager.addWalletFetchDispatched(walletItem.id, scriptStatuses.length);
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
        reportProgress(batch.length);
        _stateManager.addWalletFetchCompleted(walletItem.id, batch.length);

        if (i + chunkSize < scriptStatuses.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.transaction);
      await Future.wait(scriptStatuses.map((s) => _unsubscribeIfDormant(walletItem, s.address)));

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
      reportProgress(scriptStatuses.length);

      // 최초 지갑 구독 시 Outgoing Transaction이 있을 경우 UTXO가 생성되지 않을 경우 임의로 UTXO를 생성해야 함
      await _utxoSyncService.createOutgoingUtxos(walletItem);

      // orphaned UTXO가 있으면 정리함
      await _utxoSyncService.cleanupOrphanedUtxos(walletItem);

      await _utxoSyncService.restorePendingUtxoLocks(walletItem.id);

      for (final script in scriptStatuses) {
        _failedScriptSyncs.remove((walletItem.id, script.address));
        _clearCheckFailures(walletItem.id, script.address, historyChecked: true, balanceKnown: true);
      }
      _failedWalletSyncs.remove(walletItem.id);

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
      for (final script in scriptStatuses) {
        _failedScriptSyncs[(walletItem.id, script.address)] = script;
      }
      Logger.error('Failed to handle batch script status change: $e');
      Logger.error('Stack trace: $stackTrace');
      _stateManager.initWalletUpdateStatus(walletItem.id);
      _stateManager.setNodeSyncStateToCompleted();
      rethrow;
    }
  }
}
