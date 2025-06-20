import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';

/// NodeProvider 상태 정보를 담는 클래스
class NodeProviderState {
  final NodeSyncState nodeSyncState;
  final Map<int, WalletUpdateInfo> registeredWallets;

  const NodeProviderState({
    required this.nodeSyncState,
    required this.registeredWallets,
  });

  // 초기 상태를 생성하는 팩토리 생성자 추가
  factory NodeProviderState.initial() {
    return const NodeProviderState(
      nodeSyncState: NodeSyncState.completed,
      registeredWallets: {},
    );
  }

  NodeProviderState copyWith({
    NodeSyncState? newConnectionState,
    Map<int, WalletUpdateInfo>? newUpdatedWallets,
  }) {
    return NodeProviderState(
      nodeSyncState: newConnectionState ?? nodeSyncState,
      registeredWallets: newUpdatedWallets ?? registeredWallets,
    );
  }
}
