import 'dart:async';
import 'dart:math';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
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
  final Set<int> _failedWalletSyncs = {};
  final Map<(int, String), ScriptStatus> _failedScriptSyncs = {};
  final Map<int, DateTime> _lastDormantSyncAt = {};
  final Map<String, DateTime> _lastAddressCheckAt = {};

  // 실패 뒤 자동 재시도: 초기 간격 뒤에는 5분마다, 지갑마다 타이머 하나. 깨끗한 큐가 횟수를 초기화한다.
  final List<Duration> _retryDelays;
  final Timer Function(Duration delay, void Function() callback) _createTimer;
  bool Function() _isConnected = () => true;
  final double Function() _random;
  final Map<int, WalletItemBase> _retryWallets = {}; // 재시도에 쓸 지갑 객체(구독을 가진 객체가 우선)
  final Map<int, Timer> _retryTimers = {};
  final Map<int, int> _retryAttempts = {};
  final Map<int, int> _retryGenerations = {};
  final Map<int, int> _deferredRetries = {}; // 큐가 바빠 미룬 재시도: 지갑 → 예약 때 세대
  final Set<int> _removedWallets = {};
  bool _retrySuspended = false;

  static const Duration _electrumIndexingDelay = Duration(seconds: 1);
  static const Duration _dormantSyncThrottle = Duration(seconds: 30);
  static const Duration _addressCheckThrottle = Duration(minutes: 1);
  static const List<Duration> defaultRetryDelays = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(seconds: 90),
  ];

  /// [retryDelays]가 비어 있으면 자동 재시도를 하지 않는다. 각 간격은 ±20% 흔든다.
  /// [createTimer]와 [random](0 이상 1 미만)은 테스트에서 시계와 흔들림을 고정할 때 쓴다.
  ScriptSyncService(
    this._stateManager,
    this._balanceSyncService,
    this._transactionSyncService,
    this._utxoSyncService,
    this._addressRepository,
    this._scriptCallbackService, {
    List<Duration> retryDelays = defaultRetryDelays,
    Timer Function(Duration delay, void Function() callback) createTimer = Timer.new,
    double Function()? random,
  }) : _retryDelays = retryDelays,
       _createTimer = createTimer,
       _random = random ?? Random().nextDouble;

  set subscribeWallet(Future<Result<bool>> Function(WalletItemBase walletItem) subscribeWallet) {
    _subscribeWallet = subscribeWallet;
  }

  /// 소켓이 연결돼 있는지. 끊긴 동안의 재시도는 건너뛴다(재연결은 isolate를 새로 만든다).
  set isConnected(bool Function() isConnected) {
    _isConnected = isConnected;
  }

  /// 기존 앱 생명주기 신호로 타이머만 멈춘다. 이미 실행 중인 작업은 정상적으로 큐를 비우게 둔다.
  /// 복귀 때 미뤄 둔 재시도를 바로 실행하므로 짧은 복귀가 반복돼도 재시도가 사라지지 않는다.
  void setRetrySuspended(bool suspended) {
    if (_retrySuspended == suspended) return;
    _retrySuspended = suspended;
    if (suspended) {
      for (final entry in _retryTimers.entries) {
        entry.value.cancel();
        _deferredRetries[entry.key] = _retryGenerations[entry.key] ?? 0;
      }
      _retryTimers.clear();
    } else {
      for (final entry in _deferredRetries.entries.toList()) {
        if (_walletSyncQueues.containsKey(entry.key)) continue;
        _deferredRetries.remove(entry.key);
        _startRetry(entry.key, entry.value);
      }
    }
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
      if (_addressRepository.isAddressDormant(walletItem.id, addr.address)) {
        continue;
      }

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
    }
  }

  /// 사용자가 화면에서 실제로 보고 있는(스크롤로 로드된) 주소들의 잔액을 온디맨드로 확인한다.
  /// 최근에 이미 확인한 주소는 세션 내 짧은 시간 동안 다시 확인하지 않는다.
  /// gap 윈도우 밖이라 아직 미사용으로 표시된 주소에서 잔액이 발견되면, usedIndex(모니터링 윈도우)는
  /// 그대로 두고 그 주소만 개별적으로 사용됨으로 표시 + 구독 대상에 추가한다.
  /// 새로 사용이 발견된 주소 목록을 반환
  Future<List<WalletAddress>> syncViewedAddresses(WalletItemBase walletItem, List<WalletAddress> addresses) async {
    final now = DateTime.now();
    final addressesToCheck =
        addresses.where((addr) {
          final lastCheckedAt = _lastAddressCheckAt[addr.address];
          return lastCheckedAt == null || now.difference(lastCheckedAt) >= _addressCheckThrottle;
        }).toList();

    if (addressesToCheck.isEmpty) {
      return [];
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

    final discoveredAddresses = <WalletAddress>[];
    for (final addr in addressesToCheck) {
      if (addr.isUsed) {
        continue;
      }
      if (!_addressRepository.isAddressActive(walletItem.id, addr.address)) {
        continue;
      }
      await _addressRepository.setWalletAddressUsed(walletItem, addr.index, addr.isChange);
      await _subscribeAddress(walletItem, addr.index, addr.address, addr.isChange);
      discoveredAddresses.add(addr);

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
  /// [retryWallet]을 주면 큐가 실패로 끝났을 때 자동 재시도한다. 재시도는 지갑 구독([ownsSubscription])이 넘긴 객체,
  /// 곧 구독 콜백과 전체 구독 캐시를 가진 객체를 쓴다. 휴면·조회 확인이 보내는 메인 isolate 사본과, 그 확인이 다시
  /// 붙인 콜백을 타고 오는 푸시의 사본은 캐시가 비었거나 일부라 그것으로 재시도하면 스크립트를 거의 다 다시 구독하므로,
  /// 비어 있는 자리만 채운다.
  Future<T> runQueued<T>(
    int walletId,
    Future<T> Function() task, {
    WalletItemBase? retryWallet,
    bool ownsSubscription = false,
  }) {
    if (retryWallet != null && !_removedWallets.contains(walletId)) {
      if (ownsSubscription) {
        _retryWallets[walletId] = retryWallet;
      } else {
        _retryWallets.putIfAbsent(walletId, () => retryWallet);
      }
    }
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
            _balanceSyncService.hasBalanceFetchFailures(walletId);
        _stateManager.setWalletSyncQueueState(
          walletId,
          false,
          failed ? null : _balanceSyncService.getWalletBalance(walletId),
        );
        final deferred = _deferredRetries.remove(walletId);
        if (failed) {
          _scheduleRetry(walletId); // 미룬 재시도는 이 예약이 대신한다
        } else {
          _retryAttempts.remove(walletId);
          // 미룬 재시도는 깨끗한 큐 뒤에도 돈다. 그 큐(예: 조회 주소 확인)가 실패한 구독을 다시 했는지는 알 수 없다.
          // 그 사이 지갑이 삭제·재동기화돼 세대가 바뀌었으면 버린다.
          if (deferred != null && deferred == (_retryGenerations[walletId] ?? 0)) _startRetry(walletId, deferred);
        }
      }
    });
    _walletSyncQueues[walletId] = queuedSyncWithCleanup;
    if (startsQueue) {
      _stateManager.setWalletSyncQueueState(walletId, true, _balanceSyncService.getWalletBalance(walletId));
    }

    return completer.future.whenComplete(() => queuedSyncWithCleanup);
  }

  /// 실패가 남은 동안 초기 10/30/90초 뒤에도 5분 간격으로 계속 시도한다.
  void _scheduleRetry(int walletId) {
    final attempt = _retryAttempts[walletId] ?? 0;
    if (!_retryWallets.containsKey(walletId) || _retryDelays.isEmpty || _retryTimers.containsKey(walletId)) {
      return;
    }
    final generation = _retryGenerations[walletId] ?? 0;
    if (_retrySuspended) {
      _deferredRetries[walletId] = generation;
      return;
    }
    final delay = attempt < _retryDelays.length ? _retryDelays[attempt] : const Duration(minutes: 5);
    // 같은 순간에 실패한 기기들이 같은 박자로 다시 묻지 않도록 ±20% 흔든다.
    _retryTimers[walletId] = _createTimer(delay * (0.8 + 0.4 * _random()), () {
      _retryTimers.remove(walletId);
      // 다른 작업이 큐를 쓰고 있으면 그 큐가 끝난 뒤로 미룬다(재시도 표시가 그 작업의 전체 상태 진행을 가리지 않게).
      if (_retrySuspended || _walletSyncQueues.containsKey(walletId)) {
        _deferredRetries[walletId] = generation;
      } else {
        _startRetry(walletId, generation);
      }
    });
  }

  /// 자동 재시도. 지갑 상태(진행·완료·잔액)는 평소처럼 알리고, 재시도 작업이 도는 동안에만 전체(홈 연결) 상태를
  /// 바꾸지 않는다(실패 → 동기화 중 → 실패로 깜빡이지 않게). 결과는 큐가 끝날 때 평소처럼 알린다.
  void _startRetry(int walletId, int generation) {
    if (!_retryWallets.containsKey(walletId) || generation != (_retryGenerations[walletId] ?? 0)) return;
    if (_retrySuspended) {
      _deferredRetries[walletId] = generation;
      return;
    }
    // 기다리는 동안 깨끗한 큐가 횟수를 초기화했을 수 있어, 예약 시점 값이 아니라 지금 값에 더한다.
    _retryAttempts.update(walletId, (count) => min(count + 1, _retryDelays.length), ifAbsent: () => 1);
    _stateManager.setWalletRetrying(walletId, true);
    runQueued(walletId, () async {
      try {
        return await _retryWalletSync(walletId, generation);
      } finally {
        // 같은 큐에 뒤이어 들어온 작업(푸시 등)의 진행은 평소처럼 전체 상태에 반영한다.
        _stateManager.setWalletRetrying(walletId, false);
      }
    }).ignore();
  }

  /// 기억한 잔액 실패를 먼저 다시 조회한 뒤(잔액이 생긴 주소가 활성 주소로 구독되도록) 바뀐·실패한 스크립트를 다시 동기화한다.
  Future<Result<bool>> _retryWalletSync(int walletId, int generation) async {
    bool cancelled() => generation != (_retryGenerations[walletId] ?? 0);
    final wallet = _retryWallets[walletId];
    if (wallet == null || cancelled() || _retrySuspended || !_isConnected()) {
      return Result.failure(ErrorCodes.nodeConnectionError);
    }
    Logger.log('ScriptSyncService: retrying sync of ${wallet.name}');
    try {
      await _balanceSyncService.retryFailedBalances(wallet);
    } catch (e) {
      Logger.error('ScriptSyncService: balance retry failed for ${wallet.name}: $e');
    }
    // 잔액을 기다리는 사이 지갑이 삭제·재동기화됐으면 다시 구독하지 않는다.
    // 구독 응답을 기다리는 사이의 삭제는 SubscriptionService가 늦게 붙은 콜백을 떼어 막는다.
    if (cancelled()) return Result.failure(ErrorCodes.nodeConnectionError);
    return _subscribeWallet(wallet);
  }

  /// 지갑 삭제·재동기화 때 예약된 재시도를 버린다. 이미 큐에 들어간 재시도도 실행될 때 건너뛴다.
  void cancelRetry(int walletId) {
    _retryGenerations[walletId] = (_retryGenerations[walletId] ?? 0) + 1;
    _retryTimers.remove(walletId)?.cancel();
    _retryWallets.remove(walletId);
    _retryAttempts.remove(walletId);
    _deferredRetries.remove(walletId);
  }

  /// 지갑 삭제: 재시도를 버리고, 이후 이 지갑의 푸시, 늦게 끝난 구독 응답과 늦게 온 구독 요청을 받지 않는다.
  /// 지갑 ID는 다시 쓰이지 않으므로 풀지 않는다.
  /// 삭제 때 돌던 작업이 늦게 보낸 상태는 메인의 NodeStateManager가 버린다(삭제된 지갑을 다시 등록하지 않는다).
  void removeWallet(int walletId) {
    cancelRetry(walletId);
    _removedWallets.add(walletId);
  }

  bool isWalletRemoved(int walletId) => _removedWallets.contains(walletId);

  /// 스크립트 상태 변경 이벤트 처리
  Future<void> syncScriptStatus(SubscribeScriptStreamDto dto) {
    if (_removedWallets.contains(dto.walletItem.id)) return Future.value(); // 삭제된 지갑에 남은 콜백의 푸시
    final receivedAt = DateTime.now();
    return runQueued(dto.walletItem.id, () => _processScriptStatus(dto, receivedAt), retryWallet: dto.walletItem);
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

      // Transaction 동기화 (실패해도 완료로 세야 거래 목록의 "업데이트 중"이 끝난다)
      _stateManager.addWalletFetchDispatched(dto.walletItem.id, 1);
      final FetchScriptTransactionResult fetchResult;
      try {
        fetchResult = await _transactionSyncService.fetchScriptTransaction(
          dto.walletItem,
          dto.scriptStatus,
          now: receivedAt,
        );
      } finally {
        _stateManager.addWalletFetchCompleted(dto.walletItem.id, 1);
      }
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
    // 시작한 단계는 실패해도 완료로 센다. 진행 카운터가 남으면 뒤의 성공이 완료를 알리지 못해 화면이 저장된 데이터를
    // 다시 읽지 않는다(잔액 단계는 fetchScriptBalanceBatch가 스스로 정리한다).
    var transactionOpen = false;
    var utxoOpen = false;
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
      // 이 배치의 주소만 본다. 다른 주소(휴면·조회 화면)의 이전 실패가 송금·확정 반영을 막지 않게 한다.
      // 잔액 공개는 지갑 전체 기준으로 큐가 끝날 때 판단한다(runQueued).
      if (_balanceSyncService.hasBalanceFetchFailures(
        walletItem.id,
        addresses: scriptStatuses.map((status) => status.address).toSet(),
      )) {
        throw StateError('Incomplete wallet balance synchronization');
      }
      final balanceEndTime = DateTime.now();
      final balanceDuration = balanceEndTime.difference(balanceStartTime);
      Logger.performance('Balance sync completed in ${balanceDuration.inMilliseconds}ms for ${walletItem.name}');

      // Transaction 병렬 처리
      _stateManager.addWalletSyncState(walletItem.id, UpdateElement.transaction);
      transactionOpen = true;
      _stateManager.addWalletFetchDispatched(walletItem.id, scriptStatuses.length);
      final transactionStartTime = DateTime.now();

      // 한 청크가 실패해도 나머지 청크를 끝까지 조회해 그 거래들이 쓴 코인도 예약한 뒤 첫 실패를 던진다.
      // 실패한 청크도 완료로 세야 거래 목록의 "업데이트 중"이 끝난다.
      const chunkSize = 20;
      AsyncError? chunkError;
      for (int i = 0; i < scriptStatuses.length; i += chunkSize) {
        final endIndex = (i + chunkSize < scriptStatuses.length) ? i + chunkSize : scriptStatuses.length;
        final batch = scriptStatuses.sublist(i, endIndex);
        final transactionFutures = batch.map(
          (status) =>
              _transactionSyncService.fetchScriptTransaction(walletItem, status, inBatchProcess: true, now: now),
        );
        try {
          await Future.wait(transactionFutures);
        } catch (e, stackTrace) {
          chunkError ??= AsyncError(e, stackTrace);
        }
        reportProgress(batch.length);
        _stateManager.addWalletFetchCompleted(walletItem.id, batch.length);

        if (i + chunkSize < scriptStatuses.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      if (chunkError != null) Error.throwWithStackTrace(chunkError.error, chunkError.stackTrace);
      transactionOpen = false;
      _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.transaction);
      await Future.wait(scriptStatuses.map((s) => _unsubscribeIfDormant(walletItem, s.address)));

      final transactionEndTime = DateTime.now();
      final transactionDuration = transactionEndTime.difference(transactionStartTime);

      Logger.performance(
        'Transaction sync completed in ${transactionDuration.inMilliseconds}ms for ${walletItem.name} (${scriptStatuses.length} scripts)',
      );

      // UTXO 병렬 처리
      _stateManager.addWalletSyncState(walletItem.id, UpdateElement.utxo);
      utxoOpen = true;
      final utxoStartTime = DateTime.now();

      final utxosApplied = await Future.wait(
        scriptStatuses.map((status) => _utxoSyncService.fetchScriptUtxo(walletItem, status, inBatchProcess: true)),
      );
      reportProgress(scriptStatuses.length);
      // listunspent를 반영하지 못한 주소가 있으면 아래 정리가 그 주소의 코인을 지울 근거가 없다.
      // 정리하지 않고 이 배치를 실패로 남겨, 스크립트가 실패 목록에 남아 재시도가 다시 조회하게 한다.
      if (utxosApplied.contains(false)) throw StateError('Incomplete UTXO synchronization');

      // 최초 지갑 구독 시 Outgoing Transaction이 있을 경우 UTXO가 생성되지 않을 경우 임의로 UTXO를 생성해야 함
      await _utxoSyncService.createOutgoingUtxos(walletItem);

      // orphaned UTXO가 있으면 정리함
      await _utxoSyncService.cleanupOrphanedUtxos(
        walletItem,
        reconciledAddresses: scriptStatuses.map((status) => status.address).toSet(),
      );

      await _utxoSyncService.restorePendingUtxoLocks(walletItem.id);

      for (final script in scriptStatuses) {
        _failedScriptSyncs.remove((walletItem.id, script.address));
      }
      _failedWalletSyncs.remove(walletItem.id);

      utxoOpen = false;
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
      if (transactionOpen) _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.transaction);
      if (utxoOpen) _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.utxo);
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
