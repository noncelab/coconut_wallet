import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';

/// One sync pass owns this map; never retain it on a service or across queued passes.
/// Completed entries (including failures) are reused and evicted in LRU order. In-flight
/// entries stay shared: when all slots are busy, new txids wait for a completion.
class TransactionFetchPass {
  final Future<String> Function(String, {Duration timeout}) _fetchRaw;
  final int maxEntries;
  final _transactions = <String, Completer<Transaction>>{};
  Completer<void>? _slotAvailable;

  TransactionFetchPass(this._fetchRaw, {this.maxEntries = 1024}) {
    if (maxEntries < 1) throw ArgumentError.value(maxEntries, 'maxEntries', 'Must be positive');
  }

  Future<Transaction> fetch(String txHash, {Duration timeout = const Duration(seconds: 5)}) {
    final existing = _transactions.remove(txHash);
    if (existing != null) {
      _transactions[txHash] = existing;
      return existing.future;
    }
    if (_transactions.length == maxEntries) {
      String? evict;
      for (final entry in _transactions.entries) {
        if (entry.value.isCompleted) {
          evict = entry.key;
          break;
        }
      }
      if (evict == null) {
        return (_slotAvailable ??= Completer<void>()).future.then((_) => fetch(txHash, timeout: timeout));
      }
      _transactions.remove(evict);
    }
    final result = Completer<Transaction>();
    _transactions[txHash] = result;
    unawaited(_load(txHash, timeout, result));
    return result.future;
  }

  Future<void> _load(String txHash, Duration timeout, Completer<Transaction> result) async {
    try {
      final transaction = Transaction.parse(await _fetchRaw(txHash, timeout: timeout));
      if (transaction.transactionHash != txHash) throw StateError('Server returned a different transaction');
      result.complete(transaction);
    } catch (error, stackTrace) {
      result.completeError(error, stackTrace);
    } finally {
      final waiting = _slotAvailable;
      _slotAvailable = null;
      waiting?.complete();
    }
  }
}
