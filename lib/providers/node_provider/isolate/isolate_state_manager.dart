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

/// Isolate 스레드에서 메인 스레드로 상태 관리 메시지를 전달하는 클래스
class IsolateStateManager implements StateManagerInterface {
  final SendPort? _isolateToMainSendPort;

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

  @override
  void initWalletUpdateStatus(int walletId) {
    _sendStateUpdateToMain(IsolateStateMessage(
        IsolateStateMethod.initWalletUpdateStatus, [walletId]));
  }

  @override
  void addWalletSyncState(int walletId, UpdateElement updateType) {
    _sendStateUpdateToMain(IsolateStateMessage(
        IsolateStateMethod.addWalletSyncState, [walletId, updateType]));
  }

  @override
  void addWalletCompletedState(int walletId, UpdateElement updateType) {
    _sendStateUpdateToMain(IsolateStateMessage(
        IsolateStateMethod.addWalletCompletedState, [walletId, updateType]));
  }

  @override
  void addWalletCompletedAllStates(int walletId) {
    _sendStateUpdateToMain(IsolateStateMessage(
        IsolateStateMethod.addWalletCompletedAllStates, [walletId]));
  }

  @override
  void setState({
    MainClientState? newConnectionState,
    Map<int, WalletUpdateInfo>? newUpdatedWallets,
    bool notify = true,
  }) {
    _sendStateUpdateToMain(IsolateStateMessage(IsolateStateMethod.setState,
        [newConnectionState, newUpdatedWallets, notify]));
  }
}
