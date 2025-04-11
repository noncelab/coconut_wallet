import 'dart:isolate';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager_interface.dart';
import 'package:coconut_wallet/utils/logger.dart';

class IsolateStateMessage {
  IsolateStateMethod methodName;
  List<dynamic> params;

  IsolateStateMessage(this.methodName, this.params);

  @override
  String toString() {
    return 'IsolateStateMessage{methodName: $methodName, params: $params}';
  }
}

/// 지갑 업데이트 카운터를 관리하는 클래스
class WalletUpdateCounter {
  int balanceCounter;
  int transactionCounter;
  int utxoCounter;

  WalletUpdateCounter({
    this.balanceCounter = 0,
    this.transactionCounter = 0,
    this.utxoCounter = 0,
  });

  /// 초기화된 카운터 생성
  factory WalletUpdateCounter.initial() {
    return WalletUpdateCounter();
  }

  /// 특정 업데이트 요소의 카운터 증가
  void incrementCounter(UpdateElement updateType) {
    switch (updateType) {
      case UpdateElement.balance:
        balanceCounter++;
        break;
      case UpdateElement.transaction:
        transactionCounter++;
        break;
      case UpdateElement.utxo:
        utxoCounter++;
        break;
    }
  }

  /// 특정 업데이트 요소의 카운터 감소
  /// 카운터가 0보다 작아지지 않도록 처리
  /// @return 카운터 값이 0이면 true, 아니면 false
  bool decrementCounter(UpdateElement updateType) {
    switch (updateType) {
      case UpdateElement.balance:
        balanceCounter--;
        if (balanceCounter <= 0) {
          return true;
        }
        break;
      case UpdateElement.transaction:
        transactionCounter--;
        if (transactionCounter <= 0) {
          return true;
        }
        break;
      case UpdateElement.utxo:
        utxoCounter--;
        if (utxoCounter <= 0) {
          return true;
        }
        break;
    }
    return false;
  }
}

/// Isolate 스레드에서 메인 스레드로 상태 관리 메시지를 전달하는 클래스
class IsolateStateManager implements StateManagerInterface {
  final SendPort? _isolateToMainSendPort;

  final Map<int, WalletUpdateInfo> _registeredWallets = <int, WalletUpdateInfo>{};

  /// 지갑 업데이트 카운터 - 각 요소(balance, transaction, utxo)별 카운터를 명시적으로 관리
  final Map<int, WalletUpdateCounter> _walletUpdateCounter = <int, WalletUpdateCounter>{};

  IsolateStateManager(this._isolateToMainSendPort) {
    if (_isolateToMainSendPort == null) {
      Logger.error('IsolateStateManager: SendPort is not initialized');
    }
  }

  /// 현재 SendPort가 설정되어 있는지 확인
  bool get isInitialized => _isolateToMainSendPort != null;

  /// 메인 스레드로 상태 메시지 전송
  void _sendStateUpdateToMain(IsolateStateMessage message) {
    if (!isInitialized) {
      Logger.error('IsolateStateManager: SendPort is not initialized');
      return;
    }

    // updateState 메시지 타입으로 상태 업데이트 데이터 전송
    try {
      // 메시지를 methodName과 params만 포함하는 리스트로 전송
      _isolateToMainSendPort!.send([
        IsolateManagerMessage.updateState,
        [message.methodName, ...message.params]
      ]);
    } catch (e) {
      Logger.error('IsolateStateManager: Failed to send state update: $e');
    }
  }

  /// 지갑 정보 가져오기 (없으면 생성)
  /// @return 지갑 업데이트 정보
  WalletUpdateInfo _getWalletInfo(int walletId) {
    final existingInfo = _registeredWallets[walletId];

    WalletUpdateInfo walletUpdateInfo;

    if (existingInfo == null) {
      walletUpdateInfo = WalletUpdateInfo(walletId);
    } else {
      walletUpdateInfo = WalletUpdateInfo.fromExisting(existingInfo);
    }

    return walletUpdateInfo;
  }

  /// 업데이트 요소에 따른 상태 업데이트 및 상태 변경 여부 반환
  bool _updateElementStatus(
      WalletUpdateInfo walletUpdateInfo, UpdateElement updateType, UpdateStatus newStatus) {
    UpdateStatus prevStatus;

    switch (updateType) {
      case UpdateElement.balance:
        prevStatus = walletUpdateInfo.balance;
        walletUpdateInfo.balance = newStatus;
        return prevStatus != newStatus;
      case UpdateElement.transaction:
        prevStatus = walletUpdateInfo.transaction;
        walletUpdateInfo.transaction = newStatus;
        return prevStatus != newStatus;
      case UpdateElement.utxo:
        prevStatus = walletUpdateInfo.utxo;
        walletUpdateInfo.utxo = newStatus;
        return prevStatus != newStatus;
    }
  }

  @override
  void initWalletUpdateStatus(int walletId) {
    if (_isWalletAnySyncing(walletId)) {
      return;
    }

    _registeredWallets[walletId] = WalletUpdateInfo(walletId);
    _walletUpdateCounter[walletId] = WalletUpdateCounter.initial();
    _sendStateUpdateToMain(
        IsolateStateMessage(IsolateStateMethod.initWalletUpdateStatus, [walletId]));
  }

  @override
  void addWalletSyncState(int walletId, UpdateElement updateType) {
    final walletUpdateInfo = _getWalletInfo(walletId);
    bool isChange = false;

    _walletUpdateCounter[walletId]!.incrementCounter(updateType);

    if (_updateElementStatus(walletUpdateInfo, updateType, UpdateStatus.syncing)) {
      isChange = true;
    }

    _registeredWallets[walletId] = walletUpdateInfo;

    if (isChange) {
      _sendStateUpdateToMain(
          IsolateStateMessage(IsolateStateMethod.addWalletSyncState, [walletId, updateType]));
    }
  }

  @override
  void addWalletCompletedState(int walletId, UpdateElement updateType) {
    final walletUpdateInfo = _getWalletInfo(walletId);
    bool isChange = false;

    bool isCounterZero = _walletUpdateCounter[walletId]!.decrementCounter(updateType);

    if (isCounterZero) {
      // 카운터가 0이면 상태를 completed로 변경
      if (_updateElementStatus(walletUpdateInfo, updateType, UpdateStatus.completed)) {
        isChange = true;
      }
    }

    _registeredWallets[walletId] = walletUpdateInfo;

    if (isChange) {
      _sendStateUpdateToMain(
          IsolateStateMessage(IsolateStateMethod.addWalletCompletedState, [walletId, updateType]));
    }
  }

  @override
  void addWalletCompletedAllStates(int walletId) {
    _sendStateUpdateToMain(
        IsolateStateMessage(IsolateStateMethod.addWalletCompletedAllStates, [walletId]));
  }

  @override
  void setMainClientSyncingState() {
    _sendStateUpdateToMain(IsolateStateMessage(IsolateStateMethod.setMainClientSyncingState, []));
  }

  @override
  void setMainClientWaitingState() {
    _sendStateUpdateToMain(IsolateStateMessage(IsolateStateMethod.setMainClientWaitingState, []));
  }

  bool _isWalletAnySyncing(int walletId) {
    final walletInfo = _registeredWallets[walletId];
    if (walletInfo == null) {
      return false;
    }

    return walletInfo.balance == UpdateStatus.syncing ||
        walletInfo.transaction == UpdateStatus.syncing ||
        walletInfo.utxo == UpdateStatus.syncing;
  }
}
