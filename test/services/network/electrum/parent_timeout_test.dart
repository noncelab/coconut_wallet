import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/electrum_transaction_transport.dart';
import '../../../mock/transaction_mock.dart';
import '../../../mock/wallet_mock.dart';

void main() {
  final wallet = WalletMock.createSingleSigWalletItem();
  final owned = wallet.walletBase.getAddress(0);
  final foreign = wallet.walletBase.getAddress(999);
  List<Transaction> parents(int count) => [
    for (var i = 0; i < count; i++) TransactionMock.createMockTransaction(toAddress: foreign, amount: 1000 + i),
  ];
  Transaction spend(List<Transaction> parents) => Transaction.withInputsAndOutputs(
    [for (final parent in parents) TransactionInput.forPayment(parent.transactionHash, 0)],
    [TransactionOutput.forPayment(500, owned)],
    AddressType.p2wpkh,
  );

  for (final (count, reused, timeoutMs) in [(1, 0, 5300), (30, 29, 5300), (60, 0, 23000), (600, 0, 60000)]) {
    testWidgets('parent timeout uses only missing parents and caps at 60 s ($count total, $reused reused)', (
      tester,
    ) async {
      final previous = parents(count);
      final tx = spend(previous);
      final transport = ElectrumTransactionTransport((_) => Completer<String>().future);
      var failed = false;
      transport.service
          .getPreviousTransactions(tx, existingTxList: previous.take(reused).toList())
          .then<void>((_) => fail('an unanswered request must time out'), onError: (Object _) => failed = true);
      await tester.pump();
      expect(transport.requestedHashes.length, count - reused);
      await tester.pump(Duration(milliseconds: timeoutMs - 1));
      expect(failed, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(failed, isTrue);
    });
  }

  for (final delayMs in [100, 200]) {
    test(
      '[P5-slow-link][codex-r2-slow-link] a serial $delayMs ms parent stream records on its first attempt',
      () async {
        final previous = parents(60);
        final raw = {for (final parent in previous) parent.transactionHash: parent.serialize()};
        var position = 0;
        final transport = ElectrumTransactionTransport(
          (hash) => Future.delayed(Duration(milliseconds: delayMs * ++position), () => raw[hash]!),
        );
        final records = TransactionRecordService(transport.service, _OwnedAddress(owned));
        final record = await records.createTransactionRecord(1, spend(previous));
        expect(record.amount, 500);
        expect(record.fee, 60 * 1000 + 59 * 60 ~/ 2 - 500);
        expect(record.transactionType, TransactionType.received);
        expect(record.inputAddressList.length, 60);
        expect(transport.requestedHashes.length, 60, reason: 'no retry or re-fetch was needed');
      },
    );
  }
}

class _OwnedAddress extends Fake implements AddressRepository {
  _OwnedAddress(this.address);
  final String address;
  @override
  bool containsAddress(int walletId, String candidate, {bool? isChange}) => candidate == address;
}
