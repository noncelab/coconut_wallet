/// 일렉트럼 서버 연결 상태. 서버 설정 화면과 지갑 재동기화 확인 화면에서 공유해서 사용한다.
enum NodeConnectionStatus {
  connecting, // 연결 중입니다
  connected, // 연결되었습니다
  failed, // 연결할 수 없습니다!
  networkMismatch, // 네트워크가 달라 연결할 수 없어요
  waiting, // 대기중
}
