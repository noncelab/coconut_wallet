import 'dart:async';
import 'dart:math';

import 'package:coconut_lib/coconut_lib.dart';
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
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/subscribe_wallet_response.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

/// NodeProvider의 스크립트 구독 관련 기능을 담당하는 매니저 클래스
class SubscriptionManager {
  final ElectrumService _electrumService;
  final NodeStateManager _stateManager;
  final BalanceManager _balanceManager;
  final TransactionManager _transactionManager;
  final UtxoManager _utxoManager;
  final AddressRepository _addressRepository;
  final SubscriptionRepository _subscriptionRepository;
  final int _gapLimit = 20; // 기본 gap limit 설정

  // 구독중인 스크립트 상태 변경을 인지하는 컨트롤러
  late StreamController<SubscribeScriptStreamDto> _scriptStatusController;

  Stream<SubscribeScriptStreamDto> get scriptStatusStream =>
      _scriptStatusController.stream;

  SubscriptionManager(
    this._electrumService,
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
    Map<int, String> addresses = _prepareAddressesMap(
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
    final script =
        _getScriptForAddress(walletItem.walletBase.addressType, address);
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

    final status = await _electrumService.subscribeScript(script,
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

  /// 스크립트 구독 해제
  /// [walletItem] 지갑 아이템
  Future<Result<bool>> unsubscribeWallet(WalletListItemBase walletItem) async {
    try {
      await Future.wait([
        _unsubscribeScript(walletItem, false),
        _unsubscribeScript(walletItem, true)
      ]);
      walletItem.subscribedScriptMap.clear();
      Logger.log('UnsubscribeWallet: ${walletItem.name} - finished');
      return Result.success(true);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 특정 유형(receive/change)의 스크립트 구독 해제
  Future<void> _unsubscribeScript(
      WalletListItemBase walletItem, bool isChange) async {
    final addressScanLimit = isChange
        ? walletItem.changeUsedIndex + _gapLimit + 1
        : walletItem.receiveUsedIndex + _gapLimit + 1;

    Map<int, String> addresses = _prepareAddressesMap(
      walletItem.walletBase,
      0,
      addressScanLimit,
      isChange,
    );

    await Future.wait(addresses.values.map((address) {
      final script =
          _getScriptForAddress(walletItem.walletBase.addressType, address);
      return _electrumService.unsubscribeScript(script);
    }));
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

  /// 지갑으로부터 주소 목록을 가져옵니다.
  Map<int, String> _prepareAddressesMap(
    WalletBase wallet,
    int startIndex,
    int endIndex,
    bool isChange,
  ) {
    Map<int, String> scripts = {};

    try {
      for (int derivationIndex = startIndex;
          derivationIndex < endIndex;
          derivationIndex++) {
        String address = wallet.getAddress(derivationIndex, isChange: isChange);
        scripts[derivationIndex] = address;
      }
      return scripts;
    } catch (e) {
      Logger.error('Error preparing addresses map: $e');
      return {};
    }
  }

  /// 주소 유형에 따른 스크립트를 생성합니다.
  String _getScriptForAddress(AddressType addressType, String address) {
    if (addressType == AddressType.p2wpkh) {
      return ScriptPublicKey.p2wpkh(address).serialize().substring(2);
    } else if (addressType == AddressType.p2wsh) {
      return ScriptPublicKey.p2wsh(address).serialize().substring(2);
    }
    throw 'Unsupported address type: $addressType';
  }

  /// 리소스 해제
  void dispose() {
    _scriptStatusController.close();
  }
}
