import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';

/// NodeProvider 상태 정보를 담는 클래스
class NodeProviderState {
  final MainClientState connectionState;
  final Map<int, WalletUpdateInfo> registeredWallets;

  const NodeProviderState({
    required this.connectionState,
    required this.registeredWallets,
  });

  NodeProviderState copyWith({
    MainClientState? newConnectionState,
    Map<int, WalletUpdateInfo>? newUpdatedWallets,
  }) {
    return NodeProviderState(
      connectionState: newConnectionState ?? connectionState,
      registeredWallets: newUpdatedWallets ?? registeredWallets,
    );
  }
}
