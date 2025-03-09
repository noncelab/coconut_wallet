import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';

/// NodeProvider의 상태 관리를 담당하는 매니저 클래스
class NodeStateManager {
  final void Function() _notifyListeners;

  NodeProviderState _state = const NodeProviderState(
    connectionState: MainClientState.waiting,
    registeredWallets: {},
  );

  NodeProviderState get state => _state;

  NodeStateManager(this._notifyListeners);

  /// 노드 상태 업데이트
  /// [newConnectionState] 노드 상태
  /// [newUpdatedWallets] 지갑 업데이트 정보
  /// [notify] 상태 변경 시 리스너에게 알림 여부 (default: true)
  void setState({
    MainClientState? newConnectionState,
    Map<int, WalletUpdateInfo>? newUpdatedWallets,
    bool notify = true,
  }) {
    // 상태 변경 전 이전 상태 저장
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
      _notifyListeners();
    }
  }

  /// 이전 상태와 새 상태를 비교하여 변경 여부를 확인
  bool _isStateChanged(
      NodeProviderState prevState, NodeProviderState newState) {
    // ConnectionState 비교
    if (prevState.connectionState != newState.connectionState) {
      return true;
    }

    // 등록된 지갑 수 비교
    if (prevState.registeredWallets.length !=
        newState.registeredWallets.length) {
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

      // 지갑 상세 상태 비교 (balance, transaction, utxo)
      if (prevWalletInfo.balance != newWalletInfo.balance ||
          prevWalletInfo.transaction != newWalletInfo.transaction ||
          prevWalletInfo.utxo != newWalletInfo.utxo) {
        return true;
      }
    }

    // 모든 비교에서 변경이 없으면 false 반환
    return false;
  }

  void initWalletUpdateStatus(int walletId) {
    setState(
      newUpdatedWallets: {
        ..._state.registeredWallets,
        walletId: WalletUpdateInfo(walletId),
      },
      notify: false,
    );
  }

  /// 지갑의 업데이트 정보를 추가합니다.
  void addWalletSyncState(int walletId, UpdateElement updateType) {
    final existingInfo = _state.registeredWallets[walletId];

    WalletUpdateInfo walletUpdateInfo;

    if (existingInfo == null) {
      walletUpdateInfo = WalletUpdateInfo(walletId);
    } else {
      walletUpdateInfo = WalletUpdateInfo.fromExisting(existingInfo);
    }

    switch (updateType) {
      case UpdateElement.balance:
        walletUpdateInfo.balance = UpdateStatus.syncing;
        break;
      case UpdateElement.transaction:
        walletUpdateInfo.transaction = UpdateStatus.syncing;
        break;
      case UpdateElement.utxo:
        walletUpdateInfo.utxo = UpdateStatus.syncing;
        break;
    }

    // 상태 업데이트
    setState(
      newConnectionState: MainClientState.syncing,
      newUpdatedWallets: {
        ..._state.registeredWallets,
        walletId: walletUpdateInfo,
      },
    );
  }

  void addWalletCompletedState(int walletId, UpdateElement updateType) {
    final existingInfo = _state.registeredWallets[walletId];

    WalletUpdateInfo walletUpdateInfo;

    if (existingInfo == null) {
      walletUpdateInfo = WalletUpdateInfo(walletId);
    } else {
      walletUpdateInfo = WalletUpdateInfo.fromExisting(existingInfo);
    }

    switch (updateType) {
      case UpdateElement.balance:
        walletUpdateInfo.balance = UpdateStatus.completed;
        break;
      case UpdateElement.transaction:
        walletUpdateInfo.transaction = UpdateStatus.completed;
        break;
      case UpdateElement.utxo:
        walletUpdateInfo.utxo = UpdateStatus.completed;
        break;
    }

    setState(
      newUpdatedWallets: {
        ..._state.registeredWallets,
        walletId: walletUpdateInfo,
      },
    );
  }
}
