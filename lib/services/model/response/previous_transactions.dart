import 'dart:collection';

import 'package:coconut_lib/coconut_lib.dart';

/// Parents keyed by the requested outpoint txid, which can differ from the library's re-serialized hash.
/// The list interface keeps existing consumers compatible; no transaction data is copied or cached across calls.
class PreviousTransactions extends UnmodifiableListView<Transaction> {
  final Map<String, Transaction> byHash;

  factory PreviousTransactions(Map<String, Transaction> byHash) =>
      PreviousTransactions._(Map<String, Transaction>.unmodifiable(byHash));

  PreviousTransactions._(this.byHash) : super(byHash.values.toList(growable: false));
}
