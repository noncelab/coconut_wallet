import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/previous_transactions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/transaction_mock.dart';
import '../../../mock/electrum_transaction_transport.dart';
import '../../../mock/wallet_mock.dart';
import 'electrum_service_test.mocks.dart';

void main() {
  final wallet = WalletMock.createSingleSigWalletItem();
  final owned = wallet.walletBase.getAddress(0);
  final foreign = wallet.walletBase.getAddress(999);
  late List<_CountingTransaction> parents;
  late Transaction spending;

  setUp(() {
    parents = [
      for (var i = 0; i < 30; i++)
        _CountingTransaction(
          TransactionMock.createMockTransaction(
            toAddress: foreign,
            amount: 1000 + i,
            change: (amount: 2000 + i, address: foreign),
          ),
        ),
    ];
    spending = Transaction.withInputsAndOutputs(
      [
        for (final parent in parents)
          for (var i = 0; i < 2; i++) TransactionInput.forPayment(parent.transactionHash, i),
      ],
      [TransactionOutput.forPayment(500, owned)],
      AddressType.p2wpkh,
    );
    for (final parent in parents) {
      parent.hashReads = 0;
    }
  });

  test('supplied parents are indexed once and reused for repeated inputs without network requests', () async {
    final socket = MockSocketManager();
    final service = ElectrumService(socketManager: socket);

    final loaded = await service.getPreviousTransactions(spending, existingTxList: [...parents, parents.first]);

    expect(loaded.toSet(), parents.toSet());
    expect(loaded.length, parents.length, reason: 'one parent per txid, even when several outputs are spent');
    expect(parents.map((tx) => tx.hashReads), everyElement(1));
    verifyNever(socket.send(any));
  });

  test('record details hash each parent once while preserving every input amount and direction', () {
    final service = TransactionRecordService(ElectrumService(), _OwnedAddressRepository(owned));

    final details = service.processTransactionDetails(spending, [...parents, parents.first], 1);

    expect(details.inputAddressList.length, 60);
    expect(details.fee, 30 * 3000 + 2 * (29 * 30 ~/ 2) - 500);
    expect(details.amount, 500);
    expect(details.txType, TransactionType.received);
    expect(parents.map((tx) => tx.hashReads), everyElement(1));
  });

  test('fetches each missing parent once and reuses a supplied parent', () async {
    final raw = {for (final tx in parents) tx.transactionHash: tx.serialize()};
    final transport = ElectrumTransactionTransport((hash) => raw[hash]!);
    final loaded = await transport.service.getPreviousTransactions(spending, existingTxList: [parents.first]);
    expect(loaded.length, parents.length);
    expect(loaded.map((tx) => tx.transactionHash).toSet(), raw.keys.toSet());
    expect(transport.requestedHashes.length, parents.length - 1);
    expect(transport.requestedHashes.toSet().length, transport.requestedHashes.length);
    expect(transport.requestedHashes, isNot(contains(parents.first.transactionHash)));
  });

  for (final failure in ['one fetch', 'all fetches', 'parse']) {
    test('$failure fails the entire parent lookup instead of returning partial data', () async {
      final raw = {for (final tx in parents) tx.transactionHash: tx.serialize()};
      final failedHash = raw.keys.first;
      final transport = ElectrumTransactionTransport((hash) {
        if (failure == 'all fetches' || hash == failedHash) {
          if (failure == 'parse') return '00';
          throw StateError('parent unavailable');
        }
        return raw[hash]!;
      });
      await expectLater(transport.service.getPreviousTransactions(spending), throwsA(anything));
      expect(transport.requestedHashes.length, parents.length);
    });
  }

  test('requested parent identity survives record construction and reuse without recomputing its hash', () async {
    final parent = parents.first;
    final requestedHash = parent.transactionHash;
    final tx = Transaction.withInputsAndOutputs(
      [TransactionInput.forPayment(requestedHash, 0)],
      spending.outputs,
      AddressType.p2wpkh,
    );
    final transport = ElectrumTransactionTransport((hash) {
      expect(hash, requestedHash);
      return parent.serialize();
    });
    final loaded = await transport.service.getPreviousTransactions(tx);
    expect(loaded, isA<PreviousTransactions>());
    expect((loaded as PreviousTransactions).byHash.keys, [requestedHash]);
    final records = TransactionRecordService(transport.service, _OwnedAddressRepository(owned));
    final record = await records.createTransactionRecord(1, tx, previousTxs: loaded);
    expect(record.amount, 500);
    expect(record.fee, parent.outputs.first.amount - 500);
    expect(record.transactionType, TransactionType.received);
    expect(record.inputAddressList.single.amount, parent.outputs.first.amount);
    expect(transport.requestedHashes, [requestedHash], reason: 'reuse keeps the original txid without another request');

    parent.hashReads = 0;
    records.processTransactionDetails(tx, PreviousTransactions({requestedHash: parent}), 1);
    expect(parent.hashReads, 0, reason: 'fetched parents already carry their requested txid');
    expect(() => loaded.clear(), throwsUnsupportedError);
    expect(() => loaded.byHash.clear(), throwsUnsupportedError);
  });

  test('a wrong parent response is rejected before constructing a record', () async {
    final raw = {for (final parent in parents) parent.transactionHash: parent.serialize()};
    final requested = raw.keys.first;
    final transport = ElectrumTransactionTransport((hash) => hash == requested ? raw.values.last : raw[hash]!);
    final records = TransactionRecordService(transport.service, _OwnedAddressRepository(owned));
    await expectLater(
      records.createTransactionRecord(1, spending),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains(requested))),
    );
    expect(transport.requestedHashes.length, parents.length);
  });

  test('a failed lookup drains already submitted parent futures before escaping', () async {
    final raw = {for (final tx in parents) tx.transactionHash: tx.serialize()};
    final delayed = Completer<String>();
    final transport = ElectrumTransactionTransport((hash) {
      if (hash == raw.keys.first) throw StateError('parent unavailable');
      if (hash == raw.keys.last) return delayed.future;
      return raw[hash]!;
    });
    var completed = false;
    final result = transport.service.getPreviousTransactions(spending);
    final checked = expectLater(result, throwsA(anything)).whenComplete(() => completed = true);
    await Future<void>.delayed(Duration.zero);
    expect(transport.requestedHashes.length, parents.length);
    expect(completed, isFalse);
    delayed.complete(raw.values.last);
    await checked;
  });

  for (final index in [-1, 2]) {
    test('invalid prevout index $index cannot produce a record', () async {
      final tx = Transaction.withInputsAndOutputs(
        [_Input(parents.first.transactionHash, index)],
        spending.outputs,
        AddressType.p2wpkh,
      );
      final service = ElectrumService();
      await expectLater(service.getPreviousTransactions(tx, existingTxList: parents), throwsA(isA<StateError>()));
      final records = TransactionRecordService(service, _OwnedAddressRepository(owned));
      expect(() => records.processTransactionDetails(tx, parents, 1), throwsA(isA<StateError>()));
    });
  }

  test('record construction also rejects a missing parent from another caller', () {
    final records = TransactionRecordService(ElectrumService(), _OwnedAddressRepository(owned));
    expect(() => records.processTransactionDetails(spending, parents.skip(1).toList(), 1), throwsA(isA<StateError>()));
  });

  test('coinbase and empty inputs require no parents or network calls', () async {
    final transport = ElectrumTransactionTransport((_) => throw StateError('must not fetch'));
    final coinbase = TransactionMock.createMockTransaction(toAddress: owned, amount: 1000, isCoinbase: true);
    final empty = Transaction.withInputsAndOutputs([], spending.outputs, AddressType.p2wpkh);
    expect(await transport.service.getPreviousTransactions(coinbase), isEmpty);
    expect(await transport.service.getPreviousTransactions(empty), isEmpty);
    expect(transport.requestedHashes, isEmpty);
  });
}

class _Input extends Fake implements TransactionInput {
  @override
  final String transactionHash;
  @override
  final int index;
  _Input(this.transactionHash, this.index);
}

class _CountingTransaction extends Transaction {
  int hashReads = 0;
  _CountingTransaction(Transaction tx)
    : super(Codec.decodeHex(tx.version), tx.inputs, tx.outputs, Codec.decodeHex(tx.lockTime), true);

  @override
  String get transactionHash {
    hashReads++;
    return super.transactionHash;
  }
}

class _OwnedAddressRepository extends Fake implements AddressRepository {
  final String owned;
  _OwnedAddressRepository(this.owned);

  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => address == owned;
}
