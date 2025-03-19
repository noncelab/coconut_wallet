import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';

/// 상태 관리자 인터페이스
abstract class StateManagerInterface {
  /// 지갑 상태 초기화
  void initWalletUpdateStatus(int walletId);

  /// 지갑의 동기화 상태 추가
  void addWalletSyncState(int walletId, UpdateElement updateType);

  /// 지갑의 완료 상태 추가
  void addWalletCompletedState(int walletId, UpdateElement updateType);

  /// 지갑의 모든 상태 완료 처리
  void addWalletCompletedAllStates(int walletId);

  /// 노드 상태 업데이트
  void setState({
    MainClientState? newConnectionState,
    Map<int, WalletUpdateInfo>? newUpdatedWallets,
    bool notify = true,
  });
}
