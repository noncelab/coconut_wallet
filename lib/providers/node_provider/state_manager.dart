import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';

/// NodeProvider의 상태 관리를 담당하는 매니저 클래스
class NodeStateManager {
  final void Function() _notifyListeners;

  NodeProviderState _state = const NodeProviderState(
    connectionState: MainClientState.waiting,
    updatedWallets: {},
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
    _state = _state.copyWith(
      newConnectionState: newConnectionState,
      newUpdatedWallets: newUpdatedWallets,
    );
    if (notify) {
      _notifyListeners();
    }
  }

  /// 지갑의 업데이트 정보를 추가합니다.
  void addWalletSyncState(int walletId, UpdateElement updateType) {
    final existingInfo = _state.updatedWallets[walletId];

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
        ..._state.updatedWallets,
        walletId: walletUpdateInfo,
      },
    );
  }

  void addWalletCompletedState(int walletId, UpdateElement updateType) {
    final existingInfo = _state.updatedWallets[walletId];

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
        ..._state.updatedWallets,
        walletId: walletUpdateInfo,
      },
    );
  }
}
