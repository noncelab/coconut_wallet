import 'dart:async';

/// 핫월렛의 secret과 Realm metadata를 함께 변경하는 작업을 직렬화한다.
///
/// 같은 작업 안에서 다시 잠금을 요청하는 경우에는 현재 잠금을 재사용한다.
class HotWalletLifecycleLock {
  final Object _zoneKey = Object();
  Future<void> _pending = Future<void>.value();

  Future<T> synchronized<T>(Future<T> Function() operation) async {
    if (Zone.current[_zoneKey] == this) {
      return operation();
    }

    final previous = _pending;
    final release = Completer<void>();
    _pending = previous.then((_) => release.future, onError: (_) => release.future);

    try {
      await previous;
    } catch (_) {
      // 앞선 작업의 실패는 다음 작업의 실행을 막지 않는다.
    }

    try {
      return await runZoned(operation, zoneValues: {_zoneKey: this});
    } finally {
      release.complete();
    }
  }
}
