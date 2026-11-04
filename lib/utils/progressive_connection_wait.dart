import 'dart:async';

/// Notify the caller of the next [totalLimit]. Returning true extends the wait.
/// [finished] clears delay indicators when recovery finishes or waiting stops.
typedef ConnectionWaitExtension = Future<bool> Function(Duration totalLimit, Future<void> finished);

Future<T> waitForConnection<T>(
  Future<T> operation, {
  required List<Duration> limits,
  ConnectionWaitExtension? onExtend,
}) async {
  final finished = Completer<void>();
  void finish() {
    if (!finished.isCompleted) finished.complete();
  }

  unawaited(operation.then<void>((_) => finish(), onError: (Object _, StackTrace __) => finish()));
  final expired = Object();
  final alarms = <Completer<Object>>[];
  final timers = <Timer>[];
  // Start all deadlines together so stage transitions never reset the budget.
  for (final limit in limits) {
    final alarm = Completer<Object>();
    alarms.add(alarm);
    timers.add(Timer(limit, () => alarm.complete(expired)));
  }
  try {
    for (var index = 0; index < limits.length; index++) {
      final outcome = await Future.any<Object?>([operation, alarms[index].future]);
      if (!identical(outcome, expired)) return outcome as T;
      if (index == limits.length - 1 || onExtend == null) break;
      final extend = await Future.any<bool>([
        onExtend(limits[index + 1], finished.future),
        alarms.last.future.then((_) => false),
      ]);
      if (!extend) break;
    }
    throw TimeoutException('Connection preparation wait ended', limits.last);
  } finally {
    for (final timer in timers) {
      timer.cancel();
    }
    finish();
  }
}
