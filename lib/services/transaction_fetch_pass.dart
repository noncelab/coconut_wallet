import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';

/// One sync pass owns this map; never retain it on a service or across queued passes.
/// Only successful transactions are kept, evicted in LRU order past [maxEntries] or [maxBytes] of raw data.
/// A failure goes to the callers already waiting on it and is dropped, so the next caller asks the server again.
/// In-flight requests are shared and never evicted; when every slot is in flight, new txids wait in FIFO order.
class TransactionFetchPass {
  final Future<String> Function(String, {Duration timeout}) _fetchRaw;
  final int maxEntries;
  final int maxBytes;
  final Stopwatch _clock;
  final _settled = <String, ({Transaction transaction, int bytes})>{};
  final _inFlight = <String, _Request>{};
  final _waiting = <String, _Waiter>{};
  int _settledBytes = 0;

  TransactionFetchPass(this._fetchRaw, {this.maxEntries = 1024, this.maxBytes = 8 << 20, Stopwatch? stopwatch})
    : _clock = (stopwatch ?? Stopwatch())..start() {
    if (maxEntries < 1) throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be positive');
    if (maxBytes < 0) throw ArgumentError.value(maxBytes, 'maxBytes', 'Must not be negative');
  }

  /// [timeout] is this caller's own window. Waiting for a free slot does not use it up, and a shared request
  /// that times out sooner is asked again with what remains of it.
  Future<Transaction> fetch(String txHash, {Duration timeout = const Duration(seconds: 5)}) async {
    var budget = timeout;
    while (true) {
      final settled = _settled.remove(txHash);
      if (settled != null) {
        _settled[txHash] = settled;
        return settled.transaction;
      }
      final now = _clock.elapsed;
      var request = _inFlight[txHash];
      var deadline = now + budget;
      if (request == null && _makeRoom()) {
        request = _start(txHash, budget, now);
      } else if (request == null) {
        request = await (_waiting[txHash] ??= _Waiter(budget)).admitted.future;
        deadline = request.startedAt + budget;
      }
      try {
        return await request.result.future;
      } catch (_) {
        final failedAt = _clock.elapsed;
        // Any failure before the shared request's own deadline would have reached this caller's request too.
        if (failedAt < request.deadline || failedAt >= deadline) rethrow;
        budget = deadline - failedAt;
      }
    }
  }

  bool _makeRoom() {
    if (_settled.length + _inFlight.length < maxEntries) return true;
    if (_settled.isEmpty) return false;
    _evictOldest();
    return true;
  }

  void _evictOldest() => _settledBytes -= _settled.remove(_settled.keys.first)!.bytes;

  _Request _start(String txHash, Duration timeout, Duration startedAt) {
    final request = _inFlight[txHash] = _Request(startedAt, startedAt + timeout);
    unawaited(_load(txHash, timeout, request));
    return request;
  }

  Future<void> _load(String txHash, Duration timeout, _Request request) async {
    try {
      final raw = await _fetchRaw(txHash, timeout: timeout);
      final transaction = Transaction.parse(raw);
      if (transaction.transactionHash != txHash) throw StateError('Server returned a different transaction');
      _inFlight.remove(txHash);
      _settled[txHash] = (transaction: transaction, bytes: raw.length ~/ 2);
      _settledBytes += raw.length ~/ 2;
      while (_settledBytes > maxBytes) {
        _evictOldest();
      }
      request.result.complete(transaction);
    } catch (error, stackTrace) {
      _inFlight.remove(txHash);
      request.result.completeError(error, stackTrace);
    } finally {
      // Each completion frees one slot: admit exactly as many queued txids as fit, oldest first.
      while (_waiting.isNotEmpty && _makeRoom()) {
        final next = _waiting.keys.first;
        final waiter = _waiting.remove(next)!;
        waiter.admitted.complete(_start(next, waiter.timeout, _clock.elapsed));
      }
    }
  }
}

class _Request {
  final Duration startedAt;
  final Duration deadline;
  final result = Completer<Transaction>();

  _Request(this.startedAt, this.deadline);
}

/// Every caller of a queued txid shares this; the first caller's window starts the request.
class _Waiter {
  final Duration timeout;
  final admitted = Completer<_Request>();

  _Waiter(this.timeout);
}
