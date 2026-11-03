const Duration kHttpReceiveTimeout = Duration(milliseconds: 5000);

const Duration kHttpConnectionTimeout = Duration(milliseconds: 3000);

const Duration kElectrumConnectionTimeout = Duration(milliseconds: 3000);

const int kSocketMaxConnectionAttempts = 30;

const Duration kElectrumResponseTimeout = Duration(seconds: 60);

const Duration kElectrumPingInterval = Duration(seconds: 20);

const Duration kNodeRefreshWaitTimeout = Duration(seconds: 30);

/// Sending waits for recovery for a bounded time; the shared recovery continues.
const Duration kSendReconnectTimeout = Duration(seconds: 15);
const Duration kSendReconnectTimeoutForOnion = Duration(seconds: 120);

/// Local post-send work must not indefinitely block the completion screen.
const Duration kSendLocalProcessingTimeout = Duration(seconds: 5);
