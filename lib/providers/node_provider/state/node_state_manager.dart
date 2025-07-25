import 'dart:async';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/providers/node_provider/state/state_manager_interface.dart';
import 'package:coconut_wallet/utils/logger.dart';

/// NodeProvider의 상태 관리를 담당하는 매니저 클래스
class NodeStateManager implements StateManagerInterface {
  final void Function() _notifyListeners;
  final StreamController<NodeSyncState> _syncStateController;
  final StreamController<Map<int, WalletUpdateInfo>> _walletStateController;

  NodeProviderState _state = const NodeProviderState(
    nodeSyncState: NodeSyncState.init,
    registeredWallets: {},
  );
  NodeProviderState get state => _state;

  NodeStateManager(
    this._notifyListeners,
    this._syncStateController,
    this._walletStateController,
  );

  /// 노드 상태 업데이트
  /// [newConnectionState] 노드 상태
  /// [newUpdatedWallets] 지갑 업데이트 정보
  /// [notify] 상태 변경 시 리스너에게 알림 여부 (default: true)
  void _setState({
    NodeSyncState? newConnectionState,
    Map<int, WalletUpdateInfo>? newUpdatedWallets,
    bool notify = true,
  }) {
    final prevState = _state;

    // 새 상태 생성
    final newState = _state.copyWith(
      newConnectionState: newConnectionState,
      newUpdatedWallets: newUpdatedWallets,
    );

    // 상태 업데이트
    _state = newState;

    // notify가 true이고 상태가 변경된 경우에만 리스너에게 알림
    if (notify && _isStateChanged(prevState, newState)) {
      newState.printStatus();

      // Stream을 통해 상태 변경 알림
      if (prevState.nodeSyncState != newState.nodeSyncState) {
        _syncStateController.add(newState.nodeSyncState);
      }

      if (newUpdatedWallets != null) {
        _walletStateController.add(newState.registeredWallets);
      }

      _notifyListeners();
    }
  }

  /// 이전 상태와 새 상태를 비교하여 변경 여부를 확인
  bool _isStateChanged(NodeProviderState prevState, NodeProviderState newState) {
    // ConnectionState 비교
    if (prevState.nodeSyncState != newState.nodeSyncState) {
      return true;
    }

    // 등록된 지갑 수 비교
    if (prevState.registeredWallets.length != newState.registeredWallets.length) {
      return true;
    }

    // 각 지갑별 상태 비교
    for (final walletId in newState.registeredWallets.keys) {
      // 이전 상태에 없는 지갑이 새로 추가된 경우
      if (!prevState.registeredWallets.containsKey(walletId)) {
        return true;
      }

      final prevWalletInfo = prevState.registeredWallets[walletId]!;
      final newWalletInfo = newState.registeredWallets[walletId]!;

      // 지갑 상세 상태 비교 (subscription, balance, transaction, utxo)
      if (prevWalletInfo.subscription != newWalletInfo.subscription ||
          prevWalletInfo.balance != newWalletInfo.balance ||
          prevWalletInfo.transaction != newWalletInfo.transaction ||
          prevWalletInfo.utxo != newWalletInfo.utxo) {
        return true;
      }
    }

    // 모든 비교에서 변경이 없으면 false 반환
    return false;
  }

  @override
  void initWalletUpdateStatus(int walletId) {
    _setState(
      newUpdatedWallets: {
        ..._state.registeredWallets,
        walletId: WalletUpdateInfo(walletId),
      },
      notify: false,
    );
  }

  /// 지갑의 동기화 상태 증가 및 상태 업데이트
  @override
  void addWalletSyncState(int walletId, UpdateElement updateType) {
    final existingInfo = _state.registeredWallets[walletId];

    WalletUpdateInfo walletUpdateInfo;

    if (existingInfo == null) {
      walletUpdateInfo = WalletUpdateInfo(walletId);
    } else {
      walletUpdateInfo = WalletUpdateInfo.fromExisting(existingInfo);
    }

    switch (updateType) {
      case UpdateElement.subscription:
        walletUpdateInfo.subscription = WalletSyncState.syncing;
        break;
      case UpdateElement.balance:
        walletUpdateInfo.balance = WalletSyncState.syncing;
        break;
      case UpdateElement.transaction:
        walletUpdateInfo.transaction = WalletSyncState.syncing;
        break;
      case UpdateElement.utxo:
        walletUpdateInfo.utxo = WalletSyncState.syncing;
        break;
    }

    // 상태 업데이트
    _setState(
      newConnectionState: NodeSyncState.syncing,
      newUpdatedWallets: {
        ..._state.registeredWallets,
        walletId: walletUpdateInfo,
      },
    );
  }

  /// 지갑의 동기화 상태 감소 및 완료 여부 업데이트
  @override
  void addWalletCompletedState(int walletId, UpdateElement updateType) {
    final existingInfo = _state.registeredWallets[walletId];

    if (existingInfo == null) {
      Logger.error('지갑 ID $walletId에 대한 정보가 없어 완료 상태로 변경할 수 없습니다.');
      return;
    }

    WalletUpdateInfo walletUpdateInfo = WalletUpdateInfo.fromExisting(existingInfo);
    NodeSyncState? newConnectionState;

    switch (updateType) {
      case UpdateElement.subscription:
        walletUpdateInfo.subscription = WalletSyncState.completed;
        break;
      case UpdateElement.balance:
        walletUpdateInfo.balance = WalletSyncState.completed;
        break;
      case UpdateElement.transaction:
        walletUpdateInfo.transaction = WalletSyncState.completed;
        break;
      case UpdateElement.utxo:
        walletUpdateInfo.utxo = WalletSyncState.completed;
        break;
    }

    final Map<int, WalletUpdateInfo> newUpdatedWallets = {
      ..._state.registeredWallets,
      walletId: walletUpdateInfo,
    };

    if (isAllWalletsCompleted(updatedWallets: newUpdatedWallets)) {
      newConnectionState = NodeSyncState.completed;
    }

    _setState(
      newConnectionState: newConnectionState,
      newUpdatedWallets: newUpdatedWallets,
    );
  }

  @override
  void addWalletCompletedAllStates(int walletId) {
    final existingInfo = _state.registeredWallets[walletId];
    NodeSyncState? newConnectionState;
    WalletUpdateInfo updateInfo;

    // 기존 정보가 없으면 새 정보 생성
    if (existingInfo == null) {
      updateInfo = WalletUpdateInfo(
        walletId,
        subscription: WalletSyncState.completed,
        balance: WalletSyncState.completed,
        transaction: WalletSyncState.completed,
        utxo: WalletSyncState.completed,
      );
    } else {
      // 기존 정보가 있는 경우 모든 카운터를 0으로 설정하고 상태를 완료로 변경
      updateInfo = WalletUpdateInfo.fromExisting(
        existingInfo,
        subscription: WalletSyncState.completed,
        balance: WalletSyncState.completed,
        transaction: WalletSyncState.completed,
        utxo: WalletSyncState.completed,
      );
    }

    final Map<int, WalletUpdateInfo> newUpdatedWallets = {
      ..._state.registeredWallets,
      walletId: updateInfo,
    };

    if (isAllWalletsCompleted(updatedWallets: newUpdatedWallets)) {
      newConnectionState = NodeSyncState.completed;
    }

    _setState(
      newConnectionState: newConnectionState,
      newUpdatedWallets: newUpdatedWallets,
    );
  }

  void handleIsolateStateMessage(IsolateStateMessage message) {
    final methodName = message.methodName;
    final params = message.params;

    try {
      switch (methodName) {
        case IsolateStateMethod.initWalletUpdateStatus:
          initWalletUpdateStatus(params[0]);
          break;
        case IsolateStateMethod.addWalletSyncState:
          addWalletSyncState(params[0], params[1]);
          break;
        case IsolateStateMethod.addWalletCompletedState:
          addWalletCompletedState(params[0], params[1]);
          break;
        case IsolateStateMethod.addWalletCompletedAllStates:
          addWalletCompletedAllStates(params[0]);
          break;
        case IsolateStateMethod.setNodeSyncStateToSyncing:
          setNodeSyncStateToSyncing();
          break;
        case IsolateStateMethod.setNodeSyncStateToCompleted:
          setNodeSyncStateToCompleted();
          break;
        case IsolateStateMethod.setNodeSyncStateToFailed:
          setNodeSyncStateToFailed();
          break;
      }
    } catch (e) {
      Logger.error('handleIsolateStateMessage 처리 중 에러 발생: $e');
    }
  }

  void unregisterWalletUpdateState(int walletId) {
    final updatedWallets = Map<int, WalletUpdateInfo>.from(_state.registeredWallets);
    updatedWallets.remove(walletId);

    _setState(
      newUpdatedWallets: updatedWallets,
      notify: true,
    );
  }

  @override
  void setNodeSyncStateToSyncing() {
    _setState(
      newConnectionState: NodeSyncState.syncing,
      newUpdatedWallets: null,
      notify: true,
    );
  }

  @override
  void setNodeSyncStateToCompleted() {
    // 등록된 지갑 중 하나라도 syncing 상태인지 확인
    if (!isAllWalletsCompleted()) {
      return;
    }

    _setState(
      newConnectionState: NodeSyncState.completed,
      newUpdatedWallets: null,
      notify: true,
    );
  }

  @override
  void setNodeSyncStateToFailed() {
    _setState(
      newConnectionState: NodeSyncState.failed,
      newUpdatedWallets: null,
      notify: true,
    );
  }

  bool isAllWalletsCompleted({Map<int, WalletUpdateInfo>? updatedWallets}) {
    final registeredWallets = updatedWallets ?? _state.registeredWallets;

    for (final walletInfo in registeredWallets.values) {
      if (walletInfo.subscription != WalletSyncState.completed ||
          walletInfo.balance != WalletSyncState.completed ||
          walletInfo.transaction != WalletSyncState.completed ||
          walletInfo.utxo != WalletSyncState.completed) {
        return false;
      }
    }
    return true;
  }
}
