const Duration kIsolateInitTimeout = Duration(seconds: 4);
const Duration kIsolateInitTimeoutForOnion = Duration(seconds: 90);
const Duration kIsolateSocketCheckTimeout = Duration(milliseconds: 300);
const Duration kIsolateResponseTimeout = Duration(seconds: 180);
const Duration kIsolateSimpleResponseTimeout = Duration(seconds: 3);
const Duration kIsolateSimpleResponseTimeoutForOnion = Duration(seconds: 75);

/// 0부터 전체 gap-limit 스캔 + 데이터 fetch를 수행하므로 이미 인덱싱된 구간만
/// 스캔하는 kIsolateResponseTimeout보다 훨씬 길게 잡음.
const Duration kIsolateResyncTimeout = Duration(minutes: 10);
