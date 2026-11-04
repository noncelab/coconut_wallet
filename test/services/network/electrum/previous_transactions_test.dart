import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/transaction_mock.dart';
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
