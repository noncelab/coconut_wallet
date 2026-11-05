const Duration kHttpReceiveTimeout = Duration(milliseconds: 5000);

const Duration kHttpConnectionTimeout = Duration(milliseconds: 3000);

const Duration kElectrumConnectionTimeout = Duration(milliseconds: 3000);

const int kSocketMaxConnectionAttempts = 30;

const Duration kElectrumResponseTimeout = Duration(seconds: 60);

const Duration kElectrumPingInterval = Duration(seconds: 20);

const Duration kNodeRefreshWaitTimeout = Duration(seconds: 30);

/// 브로트캐스팅 전 서버 연결 대기 상한
const Duration kBroadcastConnectionWaitTimeout = Duration(seconds: 15);
const Duration kBroadcastConnectionWaitTimeoutForOnion = Duration(seconds: 120);
