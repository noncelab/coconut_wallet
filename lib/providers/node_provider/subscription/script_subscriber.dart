import 'dart:async';
import 'dart:math';

import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/subscribe_wallet_response.dart';
import 'package:coconut_wallet/utils/logger.dart';

import '../../../utils/electrum_utils.dart';

/// 스크립트 구독 처리를 담당하는 클래스
class ScriptSubscriber {
  final ElectrumService _electrumService;
  final StreamController<SubscribeScriptStreamDto> _scriptStatusController;
  final SubscriptionRepository _subscriptionRepository;
  final AddressRepository _addressRepository;
  final int _gapLimit = 20; // 기본 gap limit 설정

  ScriptSubscriber(
    this._electrumService,
    this._scriptStatusController,
    this._subscriptionRepository,
    this._addressRepository,
  );

  /// 지갑의 스크립트 구독
  Future<SubscribeWalletResponse> subscribeWallet(
    WalletListItemBase walletItem,
    WalletProvider walletProvider,
  ) async {
    final receiveFutures = _subscribeWallet(
        walletItem, false, _scriptStatusController, walletProvider);
    final changeFutures = _subscribeWallet(
        walletItem, true, _scriptStatusController, walletProvider);

    final [receiveResult, changeResult] =
        await Future.wait([receiveFutures, changeFutures]);

    walletItem.receiveUsedIndex = receiveResult.lastUsedIndex;
    walletItem.changeUsedIndex = changeResult.lastUsedIndex;

    List<ScriptStatus> allScriptStatuses = [...receiveResult.scriptStatuses];
    allScriptStatuses.addAll(changeResult.scriptStatuses);

    // 구독 응답 객체 생성
    SubscribeWalletResponse subscribeResponse = SubscribeWalletResponse(
      scriptStatuses: allScriptStatuses,
      usedReceiveIndex: receiveResult.lastUsedIndex,
      usedChangeIndex: changeResult.lastUsedIndex,
    );

    if (subscribeResponse.scriptStatuses.isEmpty) {
      Logger.log('SubscribeWallet: ${walletItem.name} - no script statuses');
      return subscribeResponse;
    }

    final changedScriptStatuses = subscribeResponse.scriptStatuses
        .where((status) => status.status != null)
        .toList();

    // 지갑 인덱스 업데이트
    _addressRepository.updateWalletUsedIndex(walletItem,
        subscribeResponse.usedReceiveIndex, subscribeResponse.usedChangeIndex);

    // 변경된 상태만 DB에 저장
    _subscriptionRepository.batchUpdateScriptStatuses(
        changedScriptStatuses, walletItem.id);

    Logger.log(
        'SubscribeWallet: ${walletItem.name} - finished / subscribedScriptMap.length: ${walletItem.subscribedScriptMap.length}');

    return subscribeResponse;
  }

  /// 지갑의 스크립트 구독 해제
  Future<void> unsubscribeWallet(WalletListItemBase walletItem) async {
    await Future.wait([
      _unsubscribeScript(walletItem, false),
      _unsubscribeScript(walletItem, true)
    ]);
    walletItem.subscribedScriptMap.clear();
    Logger.log('UnsubscribeWallet: ${walletItem.name} - finished');
  }

  /// 특정 유형(receive/change)의 주소에 대한 구독 처리
  Future<({List<ScriptStatus> scriptStatuses, int lastUsedIndex})>
      _subscribeWallet(
          WalletListItemBase walletItem,
          bool isChange,
          StreamController<SubscribeScriptStreamDto> scriptStatusController,
          WalletProvider walletProvider) async {
    int currentAddressIndex = 0;
    int addressScanLimit = _gapLimit;
    int lastUsedIndex =
        isChange ? walletItem.changeUsedIndex : walletItem.receiveUsedIndex;
    List<ScriptStatus> scriptStatuses = [];

    while (currentAddressIndex < addressScanLimit) {
      Logger.log(
          'currentAddressIndex: $currentAddressIndex, addressScanLimit: $addressScanLimit, lastUsedIndex: $lastUsedIndex');

      // 주소 범위에 대한 구독 처리
      final result = await _subscribeAddressRange(
        walletItem,
        currentAddressIndex,
        addressScanLimit,
        isChange,
        scriptStatusController,
        walletProvider,
      );

      // 새로 구독된 스크립트 상태 추가
      scriptStatuses.addAll(result.newScriptStatuses);

      // 마지막 사용된 인덱스 업데이트
      if (result.maxUsedIndex > lastUsedIndex) {
        lastUsedIndex = result.maxUsedIndex;

        // 즉시 walletItem의 인덱스 업데이트 (중요)
        if (isChange) {
          walletItem.changeUsedIndex = lastUsedIndex;
        } else {
          walletItem.receiveUsedIndex = lastUsedIndex;
        }

        Logger.log(
            'Updated ${isChange ? "change" : "receive"} lastUsedIndex to $lastUsedIndex');
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
  Future<
      ({
        List<ScriptStatus> newScriptStatuses,
        int maxUsedIndex,
        int nextIndex
      })> _subscribeAddressRange(
    WalletListItemBase walletItem,
    int startIndex,
    int endIndex,
    bool isChange,
    StreamController<SubscribeScriptStreamDto> scriptStatusController,
    WalletProvider walletProvider,
  ) async {
    Map<int, String> addresses = ElectrumUtil.prepareAddressesMap(
      walletItem.walletBase,
      startIndex,
      endIndex,
      isChange,
    );

    if (addresses.isEmpty) {
      return (
        newScriptStatuses: <ScriptStatus>[],
        maxUsedIndex: -1,
        nextIndex: startIndex
      );
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
            walletProvider,
          )),
    );

    Logger.log('Subscribed addresses count: ${results.length}');

    for (var result in results) {
      final (:scriptStatus, :isSubscribed) = result;

      if (scriptStatus.status != null) {
        maxUsedIndex = max(maxUsedIndex, scriptStatus.index);

        // 즉시 walletItem의 인덱스 업데이트
        if (isChange && scriptStatus.index > walletItem.changeUsedIndex) {
          walletItem.changeUsedIndex = scriptStatus.index;
        } else if (!isChange &&
            scriptStatus.index > walletItem.receiveUsedIndex) {
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
    WalletProvider walletProvider,
  ) async {
    final script = ElectrumUtil.getScriptForAddress(
        walletItem.walletBase.addressType, address);
    final derivationPath =
        '${walletItem.walletBase.derivationPath}/${isChange ? 1 : 0}/$derivationIndex';

    // 이미 구독 중인 스크립트인지 확인
    final existingStatus = walletItem.subscribedScriptMap[script];

    if (existingStatus != null) {
      // 이미 구독 중인 스크립트는 기존 상태를 재사용하고 새 구독 요청을 보내지 않음
      return (
        scriptStatus: ScriptStatus(
          derivationPath: derivationPath,
          address: address,
          index: derivationIndex,
          isChange: isChange,
          scriptPubKey: script,
          status: existingStatus.status,
          timestamp: existingStatus.timestamp,
        ),
        isSubscribed: true,
      );
    }

    final status = await _electrumService
        .subscribeScript(walletItem.walletBase.addressType, address,
            onUpdate: (reversedScriptHash, newStatus) {
      // ---------- 콜백 함수 시작 ----------
      final now = DateTime.now();
      final scriptStatus = ScriptStatus(
        scriptPubKey: script,
        status: newStatus,
        timestamp: now,
        derivationPath: derivationPath,
        address: address,
        index: derivationIndex,
        isChange: isChange,
      );

      // 상태 변경 시 사용된 인덱스 업데이트 및 스캔 범위 확장
      if (newStatus != null) {
        // 현재 상태와 기존 상태를 비교하여 변경 여부 확인
        final currentStatus = walletItem.subscribedScriptMap[script]?.status;
        final bool statusChanged = currentStatus != newStatus;

        // 중요: 상태가 변경되었거나 인덱스가 현재 최대값인 경우 확장 수행
        bool needsExtension = false;

        if (isChange) {
          // 안전하게 현재 최신 상태의 인덱스와 비교
          int currentChangeIndex = walletItem.changeUsedIndex;

          // 인덱스가 더 크거나, 상태가 변경되었고 현재 인덱스와 같은 경우
          if (derivationIndex > currentChangeIndex ||
              (statusChanged && derivationIndex >= currentChangeIndex)) {
            walletItem.changeUsedIndex =
                max(walletItem.changeUsedIndex, derivationIndex);

            needsExtension = true;
            Logger.log(
                'Status changed for change address at index $derivationIndex: "$currentStatus" -> "$newStatus"');
          }
        } else {
          // 안전하게 현재 최신 상태의 인덱스와 비교
          int currentReceiveIndex = walletItem.receiveUsedIndex;

          // 인덱스가 더 크거나, 상태가 변경되었고 현재 인덱스와 같은 경우
          if (derivationIndex > currentReceiveIndex ||
              (statusChanged && derivationIndex >= currentReceiveIndex)) {
            walletItem.receiveUsedIndex =
                max(walletItem.receiveUsedIndex, derivationIndex);

            needsExtension = true;
            Logger.log(
                'Status changed for receive address at index $derivationIndex: "$currentStatus" -> "$newStatus"');
          }
        }

        // 확장 조건이 충족되면 스캔 범위 확장
        if (needsExtension) {
          Logger.log(
              'Triggering extension from onUpdate callback for ${isChange ? "change" : "receive"} index $derivationIndex');
          // 추가 주소 구독이 필요한 경우 비동기로 처리
          _extendSubscription(
              walletItem, isChange, scriptStatusController, walletProvider);
        }
      }

      // 상태 업데이트 반영
      walletItem.subscribedScriptMap[script] = UnaddressedScriptStatus(
        scriptPubKey: script,
        status: newStatus,
        timestamp: now,
      );

      scriptStatusController.add(SubscribeScriptStreamDto(
        scriptStatus: scriptStatus,
        walletItem: walletItem,
        walletProvider: walletProvider,
      ));
      // ---------- 콜백 함수 끝 ----------
    });

    walletItem.subscribedScriptMap[script] = UnaddressedScriptStatus(
      scriptPubKey: script,
      status: status,
      timestamp: DateTime.now(),
    );

    return (
      scriptStatus: ScriptStatus(
        scriptPubKey: script,
        status: status,
        timestamp: DateTime.now(),
        derivationPath: derivationPath,
        address: address,
        index: derivationIndex,
        isChange: isChange,
      ),
      isSubscribed: false,
    );
  }

  /// 스캔 범위 확장을 위한 메서드
  Future<void> _extendSubscription(
      WalletListItemBase walletItem,
      bool isChange,
      StreamController<SubscribeScriptStreamDto> scriptStatusController,
      WalletProvider walletProvider) async {
    final usedIndex =
        isChange ? walletItem.changeUsedIndex : walletItem.receiveUsedIndex;
    final startIndex = usedIndex + 1;
    final endIndex = usedIndex + _gapLimit + 1;

    Logger.log(
        'Extending subscription: isChange=$isChange, startIndex=$startIndex, endIndex=$endIndex, usedIndex=$usedIndex');

    // 범위가 유효한지 확인
    if (startIndex >= endIndex || usedIndex < 0) {
      Logger.log(
          'Invalid extension range: skipping (startIndex=$startIndex, endIndex=$endIndex)');
      return;
    }

    // 주소 범위에 대한 구독 처리 (기존 _subscribeAddressRange 메서드 재사용)
    await _subscribeAddressRange(
      walletItem,
      startIndex,
      endIndex,
      isChange,
      scriptStatusController,
      walletProvider,
    );
  }

  /// 특정 유형(receive/change)의 스크립트 구독 해제
  Future<void> _unsubscribeScript(
      WalletListItemBase walletItem, bool isChange) async {
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
      return _electrumService.unsubscribeScript(
          walletItem.walletBase.addressType, address);
    }));
  }
}
