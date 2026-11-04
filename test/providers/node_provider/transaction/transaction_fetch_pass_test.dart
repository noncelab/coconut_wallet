import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/transaction_fetch_pass.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/electrum_transaction_transport.dart';
import '../../../mock/transaction_mock.dart';
import '../../../mock/wallet_mock.dart';

class _CountingPass extends TransactionFetchPass {
  int fetchEntries = 0;

  _CountingPass(super.fetchRaw);

  @override
  Future<Transaction> fetch(String txHash, {Duration timeout = const Duration(seconds: 5)}) {
    fetchEntries++;
    return super.fetch(txHash, timeout: timeout);
  }
}

void main() {
  final address = WalletMock.createSingleSigWalletItem().walletBase.getAddress(0);
  final parents = [
    for (var i = 0; i < 3; i++) TransactionMock.createMockTransaction(toAddress: address, amount: 1000 + i),
  ];
  final hashes = parents.map((tx) => tx.transactionHash).toList();
  final raw = {for (final tx in parents) tx.transactionHash: tx.serialize()};

  test('concurrent callers share one request and the completed transaction within a pass', () async {
    final reply = Completer<String>();
    final transport = ElectrumTransactionTransport((_) => reply.future);
    final pass = TransactionFetchPass(transport.service.getTransaction);
    final first = pass.fetch(hashes.first);
    final second = pass.fetch(hashes.first);
    await Future<void>.delayed(Duration.zero);
    expect(transport.requestedHashes, [hashes.first]);
    reply.complete(raw[hashes.first]);
    expect(identical(await first, await second), isTrue);
    expect(identical(await pass.fetch(hashes.first), await first), isTrue);
    expect(transport.requestedHashes, [hashes.first]);
    await TransactionFetchPass(transport.service.getTransaction).fetch(hashes.first);
    expect(transport.requestedHashes, [hashes.first, hashes.first]);
  });

  test('capacity waits for a settled entry, never evicts an in-flight request and shares queued txids', () async {
    final replies = {for (final hash in hashes.take(2)) hash: Completer<String>()};
    final transport = ElectrumTransactionTransport((hash) => replies[hash]?.future ?? Future.value(raw[hash]!));
    final pass = TransactionFetchPass(transport.service.getTransaction, maxEntries: 2);
    final first = pass.fetch(hashes[0]);
    final second = pass.fetch(hashes[1]);
    final third = pass.fetch(hashes[2]);
    final thirdAgain = pass.fetch(hashes[2]);
    await Future<void>.delayed(Duration.zero);
    expect(transport.requestedHashes, hashes.take(2));
    final firstAgain = pass.fetch(hashes[0]);
    // Even though the first entry is still pending, the second completion frees a slot.
    replies[hashes[1]]!.complete(raw[hashes[1]]);
    await second;
    expect(identical(await third, await thirdAgain), isTrue);
    expect(transport.requestedHashes, hashes);
    await pass.fetch(hashes[1]);
    expect(transport.requestedHashes, [...hashes, hashes[1]], reason: 'only two entries can be retained');
    replies[hashes[0]]!.complete(raw[hashes[0]]);
    expect(identical(await first, await firstAgain), isTrue);
    expect(transport.requestedHashes, [...hashes, hashes[1]]);
  });

  test('a failure reaches every waiting caller and the next caller in the same pass asks again', () async {
    var valid = false;
    final transport = ElectrumTransactionTransport((hash) => valid ? raw[hash]! : raw[hashes.last]!);
    final pass = TransactionFetchPass(transport.service.getTransaction);
    final first = pass.fetch(hashes.first);
    final second = pass.fetch(hashes.first);
    await Future.wait([expectLater(first, throwsStateError), expectLater(second, throwsStateError)]);
    expect(transport.requestedHashes, [hashes.first]);
    valid = true;
    expect((await pass.fetch(hashes.first)).transactionHash, hashes.first);
    expect(transport.requestedHashes, [hashes.first, hashes.first]);
  });

  test('shared parent failure drains all parents and never returns a partial list', () async {
    final delayed = Completer<String>();
    final transport = ElectrumTransactionTransport((hash) => hash == hashes.first ? '00' : delayed.future);
    final pass = TransactionFetchPass(transport.service.getTransaction);
    final children = [
      for (var i = 0; i < 2; i++)
        Transaction.withInputsAndOutputs(
          [for (final hash in hashes.take(2)) TransactionInput.forPayment(hash, 0)],
          [TransactionOutput.forPayment(1500 + i, address)],
          AddressType.p2wpkh,
        ),
    ];
    var completed = 0;
    final checks = [
      for (final tx in children)
        expectLater(
          transport.service.getPreviousTransactions(tx, transactionFetch: pass),
          throwsA(anything),
        ).whenComplete(() => completed++),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(completed, 0);
    expect(transport.requestedHashes, hashes.take(2));
    delayed.complete(raw[hashes[1]]);
    await Future.wait(checks);
    expect(completed, 2);
    expect(transport.requestedHashes, hashes.take(2));
    final recovered = ElectrumTransactionTransport((hash) => raw[hash]!);
    final loaded = await recovered.service.getPreviousTransactions(
      children.first,
      transactionFetch: TransactionFetchPass(recovered.service.getTransaction),
    );
    expect(loaded.map((tx) => tx.transactionHash), hashes.take(2));
  });

  testWidgets('a 60-second parent load outlives the 5.3-second request it shares and still needs every parent', (
    tester,
  ) async {
    final shared = [
      for (var i = 0; i < 200; i++)
        TransactionMock.createMockTransaction(
          toAddress: address,
          amount: 1000 + i,
          change: (amount: 2500, address: address),
        ),
    ];
    final rawShared = {for (final tx in shared) tx.transactionHash: tx.serialize()};
    final slow = shared.first.transactionHash;
    Transaction child(Iterable<Transaction> inputs, {int outputIndex = 0}) => Transaction.withInputsAndOutputs(
      [for (final parent in inputs) TransactionInput.forPayment(parent.transactionHash, outputIndex)],
      [TransactionOutput.forPayment(500, address)],
      AddressType.p2wpkh,
    );
    // Every request for the shared parent is answered after 8 seconds; the HTTP fallback is offline.
    final transport = ElectrumTransactionTransport(
      (hash) => hash == slow ? Future.delayed(const Duration(seconds: 8), () => rawShared[hash]!) : rawShared[hash]!,
    );
    final pass = TransactionFetchPass(transport.service.getTransaction, stopwatch: tester.binding.clock.stopwatch());
    Object? smallError;
    List<Transaction>? largeResult;
    final smallDone = transport.service
        .getPreviousTransactions(child(shared.take(1), outputIndex: 1), transactionFetch: pass)
        .then<void>((_) {}, onError: (Object e) => smallError = e);
    final largeDone = transport.service
        .getPreviousTransactions(child(shared), transactionFetch: pass)
        .then<void>((txs) => largeResult = txs);
    await tester.pump();
    expect(transport.requestedHashes.length, 200, reason: 'the large load joins the small load\'s request');
    await tester.pump(const Duration(milliseconds: 5300));
    expect(smallError, isNotNull, reason: 'the small load has no window left');
    expect(transport.requestedHashes.where((hash) => hash == slow).length, 2);
    await tester.pump(const Duration(seconds: 8));
    await Future.wait([smallDone, largeDone]);
    expect(largeResult?.map((tx) => tx.transactionHash), shared.map((tx) => tx.transactionHash));
    expect(transport.requestedHashes.length, 201);
  });

  test('staggered completions past the cap admit one queued txid per freed slot with linear work', () async {
    const cap = 1024;
    const overflow = 1024;
    final txs = [
      for (var i = 0; i < cap + overflow; i++) TransactionMock.createMockTransaction(toAddress: address, amount: i + 1),
    ];
    final txids = txs.map((tx) => tx.transactionHash).toList();
    final rawTxs = {for (final tx in txs) tx.transactionHash: tx.serialize()};
    final replies = <String, Completer<String>>{};
    var inFlight = 0;
    var maxInFlight = 0;
    final pass = _CountingPass((String hash, {Duration timeout = const Duration(seconds: 5)}) {
      final reply = replies[hash] = Completer<String>();
      if (++inFlight > maxInFlight) maxInFlight = inFlight;
      return reply.future.whenComplete(() => inFlight--);
    });
    // Every queued txid is asked for twice; the duplicates must share one queued request.
    final results = [for (final txid in txids) pass.fetch(txid), for (final txid in txids.skip(cap)) pass.fetch(txid)];
    await Future<void>.delayed(Duration.zero);
    expect(replies.length, cap);
    // Keep 1023 requests open while the last slot completes queued txids one at a time.
    for (var i = cap - 1; i < txids.length; i++) {
      replies[txids[i]]!.complete(rawTxs[txids[i]]);
      await Future<void>.delayed(Duration.zero);
      expect(replies.length, i + 2 < txids.length ? i + 2 : txids.length);
    }
    for (var i = 0; i < cap - 1; i++) {
      replies[txids[i]]!.complete(rawTxs[txids[i]]);
    }
    final fetched = await Future.wait(results);
    expect(fetched.map((tx) => tx.transactionHash), [...txids, ...txids.skip(cap)]);
    expect(maxInFlight, cap);
    expect(replies.length, txids.length);
    expect(pass.fetchEntries, txids.length + overflow, reason: 'a completion never re-enters waiting callers');
  });

  test('settled transactions stay within 8 MiB of raw data however large each one is', () async {
    // Before this bound, 1,024 parsed copies of a 44 KB transaction kept about 367 MB alive in one pass.
    String txid(String prefix, int i) => prefix + i.toRadixString(16).padLeft(63, '0');
    final inputs = [for (var i = 1; i < 50; i++) TransactionInput.forPayment(txid('2', i), 0)];
    final outputs = [for (var i = 0; i < 1000; i++) TransactionOutput.forPayment(1000 + i, address)];
    final large = [
      for (var i = 0; i < 300; i++)
        Transaction.withInputsAndOutputs(
          [TransactionInput.forPayment(txid('1', i), 0), ...inputs],
          outputs,
          AddressType.p2wpkh,
        ),
    ];
    final rawLarge = {for (final tx in large) tx.transactionHash: tx.serialize()};
    final txids = rawLarge.keys.toList();
    final kept = (8 << 20) ~/ (rawLarge.values.first.length ~/ 2);
    expect(txids.length, greaterThan(kept));
    final requests = <String>[];
    final pass = TransactionFetchPass((String hash, {Duration timeout = const Duration(seconds: 5)}) async {
      requests.add(hash);
      return rawLarge[hash]!;
    });
    for (final txid in txids) {
      await pass.fetch(txid);
    }
    expect(requests, txids);
    requests.clear();
    // Newest first: exactly the transactions that fit in 8 MiB are answered from the pass.
    for (final txid in txids.reversed.take(kept + 1)) {
      await pass.fetch(txid);
    }
    expect(requests, [txids[txids.length - kept - 1]]);
  });
}
