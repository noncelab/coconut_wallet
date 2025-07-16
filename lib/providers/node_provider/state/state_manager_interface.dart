import 'package:coconut_wallet/enums/network_enums.dart';

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

  /// 노드 상태를 syncing으로 변경
  void setNodeSyncStateToSyncing();

  /// 노드 상태를 waiting으로 변경
  void setNodeSyncStateToCompleted();

  /// 노드 상태를 failed으로 변경
  void setNodeSyncStateToFailed();
}
