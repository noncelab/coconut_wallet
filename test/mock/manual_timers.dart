import 'dart:async';

/// A clock the test advances by hand: callbacks of timers created through [create] run only in [elapse].
/// Timers that are never elapsed simply never fire, so nothing leaks into later tests.
class ManualTimers {
  final List<_ManualTimer> _pending = [];

  Timer create(Duration delay, void Function() callback) {
    final timer = _ManualTimer(delay, callback, _pending);
    _pending.add(timer);
    return timer;
  }

  /// Delays of the timers that have not fired or been cancelled.
  List<Duration> get pendingDelays => [for (final timer in _pending) timer.delay];

  /// Fires every pending timer (timers they create wait for the next call). Returns how many fired.
  int elapse() {
    final due = List.of(_pending);
    _pending.clear();
    for (final timer in due) {
      timer._fire();
    }
    return due.length;
  }
}

class _ManualTimer implements Timer {
  final Duration delay;
  final void Function() _callback;
  final List<_ManualTimer> _pending;
  bool _active = true;

  _ManualTimer(this.delay, this._callback, this._pending);

  void _fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() {
    _active = false;
    _pending.remove(this);
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}
