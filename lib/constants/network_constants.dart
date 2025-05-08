const Duration kHttpReceiveTimeout = Duration(milliseconds: 5000);

const Duration kHttpConnectionTimeout = Duration(milliseconds: 3000);

const int kSocketMaxConnectionAttempts = 30;

const Duration kElectrumResponseTimeout = Duration(seconds: 60);

const Duration kElectrumPingInterval = Duration(seconds: 20);

/// 트랜잭션 처리 중복 방지를 위한 타임아웃 시간
const Duration kTransactionProcessingTimeout = Duration(seconds: 30);
