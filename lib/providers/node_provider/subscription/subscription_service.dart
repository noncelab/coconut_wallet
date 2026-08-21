import 'dart:async';
import 'dart:math';

import 'package:coconut_wallet/constants/address.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/state/state_manager_interface.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

import '../../../utils/electrum_utils.dart';

/// 스크립트 구독 처리를 담당하는 클래스
class SubscriptionService {
  final ElectrumService _electrumService;
  final StateManagerInterface _stateManager;
  final AddressRepository _addressRepository;
  final SubscriptionRepository _subscriptionRepository;
  final ScriptSyncService _scriptSyncService;

  final StreamController<SubscribeScriptStreamDto> _scriptStatusController;

  // 중복 구독 방지를 위한 상태 관리
  final Set<int> _subscribingWallets = {};
  final Map<int, Completer<Result<bool>>> _subscriptionCompleters = {};

  SubscriptionService(
    this._electrumService,
    this._stateManager,
    this._addressRepository,
    this._subscriptionRepository,
    this._scriptSyncService,
  ) : _scriptStatusController = StreamController<SubscribeScriptStreamDto>.broadcast() {
    _scriptStatusController.stream.listen(_scriptSyncService.syncScriptStatus);
    // ScriptSyncService 내부(_processScriptStatus)에서 gap-limit 확장을 위해 호출하는 경로
    // 이미 그 지갑의 큐 슬롯을 점유한 상태에서 호출되므로, 큐를 타는 subscribeWallet이 아니라
    // 큐를 거치지 않는 _subscribeWalletGuarded를 직접 연결해야 데드락이 나지 않는다.
    _scriptSyncService.subscribeWallet = _subscribeWalletGuarded;
    _scriptSyncService.unsubscribeAddress = unsubscribeAddress;
    _scriptSyncService.subscribeAddress = subscribeAddress;
  }

  /// 지갑의 스크립트 구독 (외부 진입점)
  /// 라이브 구독 이벤트(syncScriptStatus)와 같은 지갑에 대해 동시에 잔액/UTXO를 쓰지 않도록
  /// ScriptSyncService의 지갑별 큐를 거쳐서 실행한다.
  /// [onProgress]는 재동기화 화면 진행률 표시 등 선택적 용도로만 사용한다(기본 null, 일반 흐름에는 영향 없음).
  Future<Result<bool>> subscribeWallet(
    WalletItemBase walletItem, {
    void Function(int completed, int total)? onProgress,
  }) {
    return _scriptSyncService.runQueued(
      walletItem.id,
      () => _subscribeWalletGuarded(walletItem, onProgress: onProgress),
    );
  }

  /// 지갑별 큐를 공유해서 [task] (subscribeWallet/스크립트 상태 처리)를 실행한다.
  /// 재동기화처럼 subscribeWallet을 거치지 않고 직접 Realm을 쓰는 작업이, 백그라운드에서 도는
  /// 지갑의 일반 구독과 순서 없이 경합하지 않도록 도착 순서대로 직렬화한다.
  Future<T> runExclusive<T>(int walletId, Future<T> Function() task) {
    return _scriptSyncService.runQueued(walletId, task);
  }

  /// dormant 주소들의 잔액을 재검증한다 (외부 진입점, 지갑별 큐를 거쳐서 실행한다)
  Future<Result<bool>> syncDormantAddresses(WalletItemBase walletItem) {
    return _scriptSyncService.runQueued(walletItem.id, () async {
      await _scriptSyncService.syncDormantAddresses(walletItem);
      return Result.success(true);
    });
  }

  /// 화면에서 실제로 보고 있는 주소들의 잔액을 온디맨드로 확인한다 (외부 진입점, 지갑별 큐를 거쳐서 실행한다)
  /// 반환값은 이번 호출로 새로 사용됨이 발견된 주소 목록이다.
  Future<Result<List<WalletAddress>>> syncViewedAddresses(WalletItemBase walletItem, List<WalletAddress> addresses) {
    return _scriptSyncService.runQueued(walletItem.id, () async {
      final discovered = await _scriptSyncService.syncViewedAddresses(walletItem, addresses);
      return Result.success(discovered);
    });
  }

  /// 지갑의 스크립트 구독 (중복 방지 가드 포함). 큐를 거치지 않으므로,
  /// 이미 그 지갑의 큐 안에서 실행 중인 코드에서만 직접 호출해야 한다.
  Future<Result<bool>> _subscribeWalletGuarded(
    WalletItemBase walletItem, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final walletId = walletItem.id;

    // 이미 구독 중이면 기존 작업 완료 대기
    if (_subscribingWallets.contains(walletId)) {
      Logger.log('SubscribeWallet: ${walletItem.name} - 이미 구독 중, 기존 작업 대기');
      return await _subscriptionCompleters[walletId]?.future ?? Result.success(true);
    }

    // 새로운 구독 시작
    _subscribingWallets.add(walletId);
    final completer = Completer<Result<bool>>();
    _subscriptionCompleters[walletId] = completer;

    try {
      Logger.log('SubscribeWallet: ${walletItem.name} - 구독 시작');
      final result = await _performSubscribeWallet(walletItem, onProgress: onProgress);
      completer.complete(result);
      return result;
    } catch (e, stackTrace) {
      Logger.error('SubscribeWallet: ${walletItem.name} - 구독 중 에러 발생: $e');
      Logger.error('Stack trace: $stackTrace');
      final errorResult = Result<bool>.failure(ErrorCodes.nodeUnknown);
      completer.complete(errorResult);
      return errorResult;
    } finally {
      // 상태 정리
      _subscribingWallets.remove(walletId);
      _subscriptionCompleters.remove(walletId);
    }
  }

  /// 지갑의 스크립트 구독 실제 구현부
  Future<Result<bool>> _performSubscribeWallet(
    WalletItemBase walletItem, {
    void Function(int completed, int total)? onProgress,
  }) async {
    _stateManager.addWalletSyncState(walletItem.id, UpdateElement.subscription);
    final [receiveResult, changeResult] = await Future.wait([
      _subscribeWallet(walletItem, false, _scriptStatusController),
      _subscribeWallet(walletItem, true, _scriptStatusController),
    ]);

    List<ScriptStatus> fetchedScriptStatuses = [...receiveResult.scriptStatuses, ...changeResult.scriptStatuses];

    // 지갑 최신화
    await _addressRepository.syncWalletWithSubscriptionData(
      walletItem,
      fetchedScriptStatuses,
      receiveResult.lastUsedIndex,
      changeResult.lastUsedIndex,
    );

    Logger.log(
      'SubscribeWallet: ${walletItem.name} - finished / subscribedScriptMap.length: ${walletItem.subscribedScriptMap.length}',
    );

    // 사용 이력이 없는 지갑
    if (fetchedScriptStatuses.isEmpty) {
      _stateManager.addWalletCompletedAllStates(walletItem.id);
      return Result.success(true);
    }

    final updatedScriptStatuses = _subscriptionRepository.getUpdatedScriptStatuses(
      fetchedScriptStatuses,
      walletItem.id,
    );

    if (updatedScriptStatuses.isEmpty) {
      _stateManager.addWalletCompletedAllStates(walletItem.id);
      return Result.success(true);
    }

    _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.subscription);

    // 변경 이력이 있는 지갑에 대해서만 balance, transaction, utxo 업데이트
    await _scriptSyncService.syncBatchScriptStatusList(
      walletItem: walletItem,
      scriptStatuses: updatedScriptStatuses,
      onProgress: onProgress,
    );

    // 변경된 ScriptStatus DB에 저장
    _subscriptionRepository.updateScriptStatusList(walletItem.id, updatedScriptStatuses);
    return Result.success(true);
  }

  /// 지갑의 스크립트 구독 해제
  Future<Result<bool>> unsubscribeWallet(WalletItemBase walletItem) async {
    await Future.wait([_unsubscribeScript(walletItem, false), _unsubscribeScript(walletItem, true)]);
    walletItem.subscribedScriptMap.clear();
    Logger.log('UnsubscribeWallet: ${walletItem.name} - finished');
    return Result.success(true);
  }

  /// 단일 주소의 스크립트 구독을 해제합니다.
  /// 잔액이 소진되어 더 이상 감시할 필요가 없어진(dormant) 주소를 구독에서 제외할 때 사용
  Future<void> unsubscribeAddress(WalletItemBase walletItem, String address) async {
    final script = ElectrumUtil.getScriptForAddress(walletItem.walletBase.addressType, address);
    if (!walletItem.subscribedScriptMap.containsKey(script)) {
      return;
    }

    await _electrumService.unsubscribeScript(walletItem.walletBase.addressType, address);
    walletItem.subscribedScriptMap.remove(script);
    Logger.log('UnsubscribeAddress: ${walletItem.name} - $address dormant, unsubscribed');
  }

  /// 단일 주소를 실시간 구독합니다. dormant였던 주소가 재검증으로 다시 활성화됐을 때 사용
  Future<void> subscribeAddress(WalletItemBase walletItem, int index, String address, bool isChange) async {
    await _subscribeAddress(walletItem, index, address, isChange, _scriptStatusController);
  }

  /// 특정 유형(receive/change)의 주소에 대한 구독 처리
  /// 이미 사용 이력이 알려진 지갑(lastUsedIndex >= 0)이면, DB에 남아있는 잔액/미확정 트랜잭션이 있는
  /// 주소만 재구독하고, gap limit 트레일링 윈도우만 새로 스캔한다(0부터 재스캔하지 않음).
  /// 사용 이력이 전혀 없는 지갑(최초 구독)은 0부터 전체를 스캔해서 사용 여부를 새로 발견해야 한다.
  Future<({List<ScriptStatus> scriptStatuses, int lastUsedIndex})> _subscribeWallet(
    WalletItemBase walletItem,
    bool isChange,
    StreamController<SubscribeScriptStreamDto> scriptStatusController,
  ) async {
    final lastUsedIndex = isChange ? walletItem.changeUsedIndex : walletItem.receiveUsedIndex;

    if (lastUsedIndex < 0) {
      return _scanAndSubscribeRange(walletItem, isChange, 0, -1, scriptStatusController);
    }

    List<ScriptStatus> scriptStatuses = [];
    final activeAddresses = _addressRepository.getActiveUsedAddresses(walletItem.id, isChange);
    for (final activeAddress in activeAddresses) {
      final result = await _subscribeAddress(
        walletItem,
        activeAddress.index,
        activeAddress.address,
        isChange,
        scriptStatusController,
      );
      if (!result.isSubscribed) {
        scriptStatuses.add(result.scriptStatus);
      }
    }

    final scanResult = await _scanAndSubscribeRange(
      walletItem,
      isChange,
      lastUsedIndex + 1,
      lastUsedIndex,
      scriptStatusController,
    );
    scriptStatuses.addAll(scanResult.scriptStatuses);

    return (scriptStatuses: scriptStatuses, lastUsedIndex: scanResult.lastUsedIndex);
  }

  /// [startIndex]부터 시작해서, 사용된 주소가 발견될 때마다 gap limit만큼 범위를 확장하며 구독한다.
  Future<({List<ScriptStatus> scriptStatuses, int lastUsedIndex})> _scanAndSubscribeRange(
    WalletItemBase walletItem,
    bool isChange,
    int startIndex,
    int knownLastUsedIndex,
    StreamController<SubscribeScriptStreamDto> scriptStatusController,
  ) async {
    int currentAddressIndex = startIndex;
    int lastUsedIndex = knownLastUsedIndex;
    int addressScanLimit = lastUsedIndex + kSubscriptionGapLimit + 1;
    List<ScriptStatus> scriptStatuses = [];

    while (currentAddressIndex < addressScanLimit) {
      final result = await _subscribeAddressRange(
        walletItem,
        currentAddressIndex,
        addressScanLimit,
        isChange,
        scriptStatusController,
      );

      scriptStatuses.addAll(result.newScriptStatuses);

      if (result.maxUsedIndex > lastUsedIndex) {
        lastUsedIndex = result.maxUsedIndex;

        if (isChange) {
          walletItem.changeUsedIndex = lastUsedIndex;
        } else {
          walletItem.receiveUsedIndex = lastUsedIndex;
        }
      }

      if (lastUsedIndex >= currentAddressIndex) {
        addressScanLimit = lastUsedIndex + kSubscriptionGapLimit + 1;
      }

      currentAddressIndex = result.nextIndex;
    }

    return (scriptStatuses: scriptStatuses, lastUsedIndex: lastUsedIndex);
  }

  /// 주소 범위에 대한 구독 처리를 수행하는 공통 메서드
  Future<({List<ScriptStatus> newScriptStatuses, int maxUsedIndex, int nextIndex})> _subscribeAddressRange(
    WalletItemBase walletItem,
    int startIndex,
    int endIndex,
    bool isChange,
    StreamController<SubscribeScriptStreamDto> scriptStatusController,
  ) async {
    Map<int, String> addresses = ElectrumUtil.prepareAddressesMap(
      walletItem.walletBase,
      startIndex,
      endIndex,
      isChange,
    );

    if (addresses.isEmpty) {
      return (newScriptStatuses: <ScriptStatus>[], maxUsedIndex: -1, nextIndex: startIndex);
    }

    List<ScriptStatus> newScriptStatuses = <ScriptStatus>[];
    int maxUsedIndex = -1;

    final results = await Future.wait(
      addresses.entries.map(
        (entry) => _subscribeAddress(walletItem, entry.key, entry.value, isChange, scriptStatusController),
      ),
    );

    for (var result in results) {
      final (:scriptStatus, :isSubscribed) = result;

      if (scriptStatus.status != null) {
        maxUsedIndex = max(maxUsedIndex, scriptStatus.index);

        // 즉시 walletItem의 인덱스 업데이트
        if (isChange && scriptStatus.index > walletItem.changeUsedIndex) {
          walletItem.changeUsedIndex = scriptStatus.index;
        } else if (!isChange && scriptStatus.index > walletItem.receiveUsedIndex) {
          walletItem.receiveUsedIndex = scriptStatus.index;
        }
      }

      // 이미 구독 중인 스크립트는 반환하지 않음
      if (!isSubscribed) {
        newScriptStatuses.add(scriptStatus);
      }
    }

    return (newScriptStatuses: newScriptStatuses, maxUsedIndex: maxUsedIndex, nextIndex: startIndex + addresses.length);
  }

  /// 단일 주소에 대한 구독 처리를 수행하는 메서드
  Future<({ScriptStatus scriptStatus, bool isSubscribed})> _subscribeAddress(
    WalletItemBase walletItem,
    int derivationIndex,
    String address,
    bool isChange,
    StreamController<SubscribeScriptStreamDto> scriptStatusController,
  ) async {
    final script = ElectrumUtil.getScriptForAddress(walletItem.walletBase.addressType, address);
    final derivationPath = '${walletItem.walletBase.derivationPath}/${isChange ? 1 : 0}/$derivationIndex';

    // 이미 구독 중인 스크립트인지 확인
    final existingStatus = walletItem.subscribedScriptMap[script];

    ScriptStatus scriptStatus = ScriptStatus(
      derivationPath: derivationPath,
      address: address,
      index: derivationIndex,
      isChange: isChange,
      scriptPubKey: script,
      status: null,
      timestamp: DateTime.now(),
    );

    if (existingStatus != null) {
      // 이미 구독 중인 스크립트는 기존 상태를 재사용하고 새 구독 요청을 보내지 않음
      scriptStatus.status = existingStatus.status;
      return (scriptStatus: scriptStatus, isSubscribed: true);
    }

    /// 구독중인 스크립트의 상태 변경 이벤트 처리
    void onUpdate(String reversedScriptHash, String? newStatus) {
      // 새 상태 업데이트
      scriptStatus.status = newStatus;
      scriptStatus.timestamp = DateTime.now();
      _handleScriptUpdate(reversedScriptHash, scriptStatus, walletItem, scriptStatusController);
    }

    final status = await _electrumService.subscribeScript(
      walletItem.walletBase.addressType,
      address,
      onUpdate: onUpdate,
    );

    scriptStatus.status = status;
    scriptStatus.timestamp = DateTime.now();

    walletItem.subscribedScriptMap[script] = scriptStatus.toUnaddressedScriptStatus();

    return (scriptStatus: scriptStatus, isSubscribed: false);
  }

  /// 스크립트 변경사항이 있는 경우 처리
  ///
  /// 1. 사용한 인덱스 갱신
  /// 2. 인덱스가 확장된 경우 스캔 범위 확장
  /// 3. 지갑별 스크립트 상태 업데이트
  /// 4. 스크립트 상태
  void _handleScriptUpdate(
    String reversedScriptHash,
    ScriptStatus scriptStatus,
    WalletItemBase walletItem,
    StreamController<SubscribeScriptStreamDto> scriptStatusController,
  ) {
    // 상태 변경 시 사용된 인덱스 업데이트 및 스캔 범위 확장
    if (scriptStatus.status == null) {
      return;
    }

    // 현재 상태와 기존 상태를 비교하여 변경 여부 확인
    final currentStatus = walletItem.subscribedScriptMap[scriptStatus.scriptPubKey]?.status;
    final bool statusChanged = currentStatus != scriptStatus.status;

    // 중요: 상태가 변경되었거나 인덱스가 현재 최대값인 경우 확장 수행
    bool needsExtension = false;
    int currentIndex;

    if (scriptStatus.isChange) {
      currentIndex = walletItem.changeUsedIndex;
    } else {
      currentIndex = walletItem.receiveUsedIndex;
    }

    // gap window 밖에서 발견한 이벤트는 usedIndex에 영향을 주면 안됨
    final withinGapReach = scriptStatus.index <= currentIndex + kSubscriptionGapLimit;

    // 인덱스가 더 크거나, 상태가 변경되었고 현재 인덱스와 같은 경우
    if (withinGapReach &&
        (scriptStatus.index > currentIndex || (statusChanged && scriptStatus.index >= currentIndex))) {
      currentIndex = max(currentIndex, scriptStatus.index);

      if (scriptStatus.isChange) {
        walletItem.changeUsedIndex = currentIndex;
      } else {
        walletItem.receiveUsedIndex = currentIndex;
      }

      needsExtension = true;
      // Logger.log(
      //     'Status changed for address at index $derivationIndex: "$currentStatus" -> "$newStatus"');
    }

    // 확장 조건이 충족되면 스캔 범위 확장
    if (needsExtension) {
      // Logger.log(
      //     'Triggering extension from onUpdate callback for ${isChange ? "change" : "receive"} index $derivationIndex');
      // 추가 주소 구독이 필요한 경우 비동기로 처리
      _extendSubscription(walletItem, scriptStatus.isChange, scriptStatusController);
    }

    // 상태 업데이트 반영
    walletItem.subscribedScriptMap[scriptStatus.scriptPubKey] = UnaddressedScriptStatus(
      scriptPubKey: scriptStatus.scriptPubKey,
      status: scriptStatus.status,
      timestamp: scriptStatus.timestamp,
    );

    scriptStatusController.add(
      SubscribeScriptStreamDto(scriptStatus: scriptStatus, walletItem: walletItem, updateUsedIndex: withinGapReach),
    );
  }

  /// 스캔 범위 확장을 위한 메서드
  Future<void> _extendSubscription(
    WalletItemBase walletItem,
    bool isChange,
    StreamController<SubscribeScriptStreamDto> scriptStatusController,
  ) async {
    final usedIndex = isChange ? walletItem.changeUsedIndex : walletItem.receiveUsedIndex;
    final startIndex = usedIndex + 1;
    final endIndex = usedIndex + kSubscriptionGapLimit + 1;

    Logger.log(
      'Extending subscription: isChange=$isChange, startIndex=$startIndex, endIndex=$endIndex, usedIndex=$usedIndex',
    );

    // 범위가 유효한지 확인
    if (startIndex >= endIndex || usedIndex < 0) {
      Logger.log('Invalid extension range: skipping (startIndex=$startIndex, endIndex=$endIndex)');
      return;
    }

    // 주소 범위에 대한 구독 처리 (기존 _subscribeAddressRange 메서드 재사용)
    await _subscribeAddressRange(walletItem, startIndex, endIndex, isChange, scriptStatusController);
  }

  /// 특정 유형(receive/change)의 스크립트 구독 해제
  /// 실제로 구독 중일 수 있는 범위(활성 사용 주소 + gap limit 트레일링 윈도우)만 대상으로 한다.
  Future<void> _unsubscribeScript(WalletItemBase walletItem, bool isChange) async {
    final lastUsedIndex = isChange ? walletItem.changeUsedIndex : walletItem.receiveUsedIndex;

    final activeAddresses = _addressRepository.getActiveUsedAddresses(walletItem.id, isChange);
    final gapWindowAddresses =
        ElectrumUtil.prepareAddressesMap(
          walletItem.walletBase,
          lastUsedIndex + 1,
          lastUsedIndex + kSubscriptionGapLimit + 1,
          isChange,
        ).values;

    final addressesToUnsubscribe = [...activeAddresses.map((a) => a.address), ...gapWindowAddresses];

    await Future.wait(
      addressesToUnsubscribe.map((address) {
        return _electrumService.unsubscribeScript(walletItem.walletBase.addressType, address);
      }),
    );
  }
}
