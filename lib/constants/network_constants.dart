const Duration kHttpReceiveTimeout = Duration(milliseconds: 5000);

const Duration kHttpConnectionTimeout = Duration(milliseconds: 3000);

const Duration kElectrumConnectionTimeout = Duration(milliseconds: 3000);

const int kSocketMaxConnectionAttempts = 30;

const Duration kElectrumResponseTimeout = Duration(seconds: 60);

/// 일반 노드에서 브로드캐스트 응답을 기다리는 시간. 넘기면 서버에 거래가 들어갔는지 확인한다.
const Duration kBroadcastReplyTimeout = Duration(seconds: 8);

/// 응답을 못 받은 브로드캐스트가 서버에 들어갔는지 확인하는 시간.
const Duration kBroadcastCheckTimeout = Duration(seconds: 4);
const Duration kBroadcastCheckTimeoutForOnion = Duration(seconds: 12);

/// 결과를 모르는 전송을 같은 거래로 다시 보내는 횟수. 매번 기다림을 두 배로 늘린다.
/// 최대 대기는 일반 노드 약 2분, Tor 약 11분이다(응답·확인 대기 + 다시 보내기 전 연결 확인·재연결).
const int kBroadcastRetries = 2;

/// 다시 보내기 전 재연결을 기다리는 상한. 지갑 구독까지 기다리지 않는다(재연결은 뒤에서 계속된다).
const Duration kBroadcastReconnectWait = Duration(seconds: 10);

const Duration kElectrumPingInterval = Duration(seconds: 20);

const Duration kNodeRefreshWaitTimeout = Duration(seconds: 30);
