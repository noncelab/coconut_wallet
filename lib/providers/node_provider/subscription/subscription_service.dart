import 'dart:async';
import 'dart:math';

import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
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
  final int _gapLimit = 20; // 기본 gap limit 설정

  SubscriptionService(this._electrumService, this._stateManager, this._addressRepository,
      this._subscriptionRepository, this._scriptSyncService)
      : _scriptStatusController = StreamController<SubscribeScriptStreamDto>.broadcast() {
    _scriptStatusController.stream.listen(_scriptSyncService.syncScriptStatus);
    _scriptSyncService.subscribeWallet = subscribeWallet;
  }

  /// 지갑의 스크립트 구독
  Future<Result<bool>> subscribeWallet(
    WalletListItemBase walletItem,
  ) async {
    final [receiveResult, changeResult] = await Future.wait([
      _subscribeWallet(walletItem, false, _scriptStatusController),
      _subscribeWallet(walletItem, true, _scriptStatusController),
    ]);

    List<ScriptStatus> fetchedScriptStatuses = [
      ...receiveResult.scriptStatuses,
      ...changeResult.scriptStatuses,
    ];

    // 지갑 최신화
    await _addressRepository.syncWalletWithSubscriptionData(
      walletItem,
      fetchedScriptStatuses,
      receiveResult.lastUsedIndex,
      changeResult.lastUsedIndex,
    );

    Logger.log(
        'SubscribeWallet: ${walletItem.name} - finished / subscribedScriptMap.length: ${walletItem.subscribedScriptMap.length}');

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

    // 변경 이력이 있는 지갑에 대해서만 balance, transaction, utxo 업데이트
    await _scriptSyncService.syncBatchScriptStatusList(
      walletItem: walletItem,
      scriptStatuses: updatedScriptStatuses,
    );

    // 변경된 ScriptStatus DB에 저장
    _subscriptionRepository.updateScriptStatusList(walletItem.id, updatedScriptStatuses);
    return Result.success(true);
  }

  /// 지갑의 스크립트 구독 해제
  Future<Result<bool>> unsubscribeWallet(WalletListItemBase walletItem) async {
    await Future.wait([
      _unsubscribeScript(walletItem, false),
      _unsubscribeScript(walletItem, true),
    ]);
    walletItem.subscribedScriptMap.clear();
    Logger.log('UnsubscribeWallet: ${walletItem.name} - finished');
    return Result.success(true);
  }

  /// 특정 유형(receive/change)의 주소에 대한 구독 처리
  Future<({List<ScriptStatus> scriptStatuses, int lastUsedIndex})> _subscribeWallet(
    WalletListItemBase walletItem,
    bool isChange,
    StreamController<SubscribeScriptStreamDto> scriptStatusController,
  ) async {
    int currentAddressIndex = 0;
    int addressScanLimit = _gapLimit;
    int lastUsedIndex = isChange ? walletItem.changeUsedIndex : walletItem.receiveUsedIndex;
    List<ScriptStatus> scriptStatuses = [];

    while (currentAddressIndex < addressScanLimit) {
      // 주소 범위에 대한 구독 처리
      final result = await _subscribeAddressRange(
        walletItem,
        currentAddressIndex,
        addressScanLimit,
        isChange,
        scriptStatusController,
      );

      // 새로 구독된 스크립트 상태 추가
      scriptStatuses.addAll(result.newScriptStatuses);

      // 마지막 사용된 인덱스 업데이트
      if (result.maxUsedIndex > lastUsedIndex) {
        lastUsedIndex = result.maxUsedIndex;

        if (isChange) {
          walletItem.changeUsedIndex = lastUsedIndex;
        } else {
          walletItem.receiveUsedIndex = lastUsedIndex;
        }

        // Logger.log('Updated ${isChange ? "change" : "receive"} lastUsedIndex to $lastUsedIndex');
      }

      // 사용된 주소가 발견된 경우 스캔 범위 확장
      if (lastUsedIndex >= currentAddressIndex) {
        addressScanLimit = lastUsedIndex + _gapLimit + 1;
      }

      currentAddressIndex = result.nextIndex;
    }

    return (scriptStatuses: scriptStatuses, lastUsedIndex: lastUsedIndex);
  }

  /// 주소 범위에 대한 구독 처리를 수행하는 공통 메서드
  Future<({List<ScriptStatus> newScriptStatuses, int maxUsedIndex, int nextIndex})>
      _subscribeAddressRange(
    WalletListItemBase walletItem,
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
      addresses.entries.map((entry) => _subscribeAddress(
            walletItem,
            entry.key,
            entry.value,
            isChange,
            scriptStatusController,
          )),
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

    return (
      newScriptStatuses: newScriptStatuses,
      maxUsedIndex: maxUsedIndex,
      nextIndex: startIndex + addresses.length,
    );
  }

  /// 단일 주소에 대한 구독 처리를 수행하는 메서드
  Future<({ScriptStatus scriptStatus, bool isSubscribed})> _subscribeAddress(
    WalletListItemBase walletItem,
    int derivationIndex,
    String address,
    bool isChange,
    StreamController<SubscribeScriptStreamDto> scriptStatusController,
  ) async {
    final script = ElectrumUtil.getScriptForAddress(walletItem.walletBase.addressType, address);
    final derivationPath =
        '${walletItem.walletBase.derivationPath}/${isChange ? 1 : 0}/$derivationIndex';

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
      return (
        scriptStatus: scriptStatus,
        isSubscribed: true,
      );
    }

    /// 구독중인 스크립트의 상태 변경 이벤트 처리
    void onUpdate(String reversedScriptHash, String? newStatus) {
      // 새 상태 업데이트
      scriptStatus.status = newStatus;
      scriptStatus.timestamp = DateTime.now();
      _handleScriptUpdate(
        reversedScriptHash,
        scriptStatus,
        walletItem,
        scriptStatusController,
      );
    }

    final status = await _electrumService
        .subscribeScript(walletItem.walletBase.addressType, address, onUpdate: onUpdate);

    scriptStatus.status = status;
    scriptStatus.timestamp = DateTime.now();

    walletItem.subscribedScriptMap[script] = scriptStatus.toUnaddressedScriptStatus();

    return (
      scriptStatus: scriptStatus,
      isSubscribed: false,
    );
  }

  /// 스크립트 변경사항이 있는경우 처리
  ///
  /// 1. 사용한 인덱스 갱신
  /// 2. 인덱스가 확장된 경우 스캔 범위 확장
  /// 3. 지갑별 스크립트 상태 업데이트
  /// 4. 스크립트 상태
  void _handleScriptUpdate(
    String reversedScriptHash,
    ScriptStatus scriptStatus,
    WalletListItemBase walletItem,
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

    // 인덱스가 더 크거나, 상태가 변경되었고 현재 인덱스와 같은 경우
    if (scriptStatus.index > currentIndex ||
        (statusChanged && scriptStatus.index >= currentIndex)) {
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

    scriptStatusController.add(SubscribeScriptStreamDto(
      scriptStatus: scriptStatus,
      walletItem: walletItem,
    ));
  }

  /// 스캔 범위 확장을 위한 메서드
  Future<void> _extendSubscription(
    WalletListItemBase walletItem,
    bool isChange,
    StreamController<SubscribeScriptStreamDto> scriptStatusController,
  ) async {
    final usedIndex = isChange ? walletItem.changeUsedIndex : walletItem.receiveUsedIndex;
    final startIndex = usedIndex + 1;
    final endIndex = usedIndex + _gapLimit + 1;

    Logger.log(
        'Extending subscription: isChange=$isChange, startIndex=$startIndex, endIndex=$endIndex, usedIndex=$usedIndex');

    // 범위가 유효한지 확인
    if (startIndex >= endIndex || usedIndex < 0) {
      Logger.log('Invalid extension range: skipping (startIndex=$startIndex, endIndex=$endIndex)');
      return;
    }

    // 주소 범위에 대한 구독 처리 (기존 _subscribeAddressRange 메서드 재사용)
    await _subscribeAddressRange(
      walletItem,
      startIndex,
      endIndex,
      isChange,
      scriptStatusController,
    );
  }

  /// 특정 유형(receive/change)의 스크립트 구독 해제
  Future<void> _unsubscribeScript(WalletListItemBase walletItem, bool isChange) async {
    final addressScanLimit = isChange
        ? walletItem.changeUsedIndex + _gapLimit + 1
        : walletItem.receiveUsedIndex + _gapLimit + 1;

    Map<int, String> addresses = ElectrumUtil.prepareAddressesMap(
      walletItem.walletBase,
      0,
      addressScanLimit,
      isChange,
    );

    await Future.wait(addresses.values.map((address) {
      return _electrumService.unsubscribeScript(walletItem.walletBase.addressType, address);
    }));
  }
}
