const Duration kHttpReceiveTimeout = Duration(milliseconds: 5000);

const Duration kHttpConnectionTimeout = Duration(milliseconds: 3000);

const Duration kElectrumConnectionTimeout = Duration(milliseconds: 3000);

const int kSocketMaxConnectionAttempts = 30;

const Duration kElectrumResponseTimeout = Duration(seconds: 60);

const Duration kElectrumPingInterval = Duration(seconds: 20);

const Duration kNodeRefreshWaitTimeout = Duration(seconds: 30);

/// Absolute connection-preparation deadlines, including the initial probe.
const List<Duration> kSendConnectionWaitLimits = [Duration(seconds: 15), Duration(seconds: 30), Duration(seconds: 60)];
const List<Duration> kSendConnectionWaitLimitsForOnion = [
  Duration(seconds: 90),
  Duration(seconds: 120),
  Duration(seconds: 180),
];

/// Local post-send work must not indefinitely block the completion screen.
const Duration kSendLocalProcessingTimeout = Duration(seconds: 5);

/// Includes socket checks and isolate readiness before the connection probe.
const Duration kSendConnectionCheckTimeout = Duration(seconds: 3);
const Duration kSendConnectionCheckTimeoutForOnion = Duration(seconds: 10);

/// Delay after an explicitly failed pre-send recovery; reuse the last delay afterwards.
const List<Duration> kSendRecoveryRetryDelays = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
];
const List<Duration> kSendRecoveryRetryDelaysForOnion = [
  Duration(seconds: 3),
  Duration(seconds: 6),
  Duration(seconds: 12),
  Duration(seconds: 24),
];
