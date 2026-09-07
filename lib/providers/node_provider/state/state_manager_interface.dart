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

  /// 지갑의 트랜잭션 fetch 요청이 몇 건 시작됐는지 보고한다
  /// (총량을 미리 아는 배치든, 건별로 아는 라이브 단일 이벤트든 동일하게 사용)
  /// UI가 "완료 < 시작" 여부로 실제 진행 중인 작업량을 정확히 판단할 수 있도록 하기 위함
  /// syncing/completed 이진 상태만으로는 대량 배치 작업과 순간적인 라이브 재검증 1건을 구분할 수 없음.
  void addWalletFetchDispatched(int walletId, int count);

  /// 지갑의 트랜잭션 fetch 요청이 몇 건 완료됐는지 보고
  void addWalletFetchCompleted(int walletId, int count);
}
