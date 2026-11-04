import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/transaction_fetch_pass.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/electrum_transaction_transport.dart';
import '../../../mock/transaction_mock.dart';
import '../../../mock/wallet_mock.dart';

void main() {
  final address = WalletMock.createSingleSigWalletItem().walletBase.getAddress(0);
  final parents = [
    for (var i = 0; i < 3; i++) TransactionMock.createMockTransaction(toAddress: address, amount: 1000 + i),
  ];
  final hashes = parents.map((tx) => tx.transactionHash).toList();
  final raw = {for (final tx in parents) tx.transactionHash: tx.serialize()};

  test('concurrent callers share one future and completed transaction within a pass', () async {
    final reply = Completer<String>();
    final transport = ElectrumTransactionTransport((_) => reply.future);
    final pass = TransactionFetchPass(transport.service.getTransaction);
    final first = pass.fetch(hashes.first);
    final second = pass.fetch(hashes.first);
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(transport.requestedHashes, [hashes.first]);
    reply.complete(raw[hashes.first]);
    expect(identical(await first, await second), isTrue);
    await pass.fetch(hashes.first);
    expect(transport.requestedHashes, [hashes.first]);
    await TransactionFetchPass(transport.service.getTransaction).fetch(hashes.first);
    expect(transport.requestedHashes, [hashes.first, hashes.first]);
  });

  test('capacity waits for a settled entry and never evicts an in-flight request', () async {
    final replies = {for (final hash in hashes.take(2)) hash: Completer<String>()};
    final transport = ElectrumTransactionTransport((hash) => replies[hash]?.future ?? Future.value(raw[hash]!));
    final pass = TransactionFetchPass(transport.service.getTransaction, maxEntries: 2);
    final first = pass.fetch(hashes[0]);
    final second = pass.fetch(hashes[1]);
    final third = pass.fetch(hashes[2]);
    await Future<void>.delayed(Duration.zero);
    expect(transport.requestedHashes, hashes.take(2));
    expect(identical(pass.fetch(hashes[0]), first), isTrue);
    // Even though the first entry is still pending, the second completion frees a slot.
    replies[hashes[1]]!.complete(raw[hashes[1]]);
    await second;
    await third;
    expect(transport.requestedHashes, hashes);
    expect(identical(pass.fetch(hashes[0]), first), isTrue);
    await pass.fetch(hashes[1]);
    expect(transport.requestedHashes, [...hashes, hashes[1]], reason: 'only two entries can be retained');
    replies[hashes[0]]!.complete(raw[hashes[0]]);
    await first;
  });

  test('a wrong txid fails all shared callers and a new pass retries the request', () async {
    var valid = false;
    final transport = ElectrumTransactionTransport((hash) => valid ? raw[hash]! : raw[hashes.last]!);
    final pass = TransactionFetchPass(transport.service.getTransaction);
    final first = pass.fetch(hashes.first);
    final second = pass.fetch(hashes.first);
    await Future.wait([expectLater(first, throwsStateError), expectLater(second, throwsStateError)]);
    await expectLater(pass.fetch(hashes.first), throwsStateError);
    expect(transport.requestedHashes, [hashes.first]);
    valid = true;
    expect(
      (await TransactionFetchPass(transport.service.getTransaction).fetch(hashes.first)).transactionHash,
      hashes.first,
    );
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
}
