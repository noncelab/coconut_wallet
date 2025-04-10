import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ascendingOrderTimestampForPending = [
    DateTime(2020, 10, 2, 14, 30, 45, 123, 456),
    DateTime(2020, 10, 2, 14, 30, 45, 123, 457),
    DateTime(2020, 10, 12, 14, 30, 45, 123, 456)
  ];

  final ascendingOrderTimestampForConfirmed = [
    DateTime(2020, 10, 2, 14, 30, 45, 123, 456),
    DateTime(2020, 10, 2, 15, 50, 45, 123, 457),
  ];

  group('testing UtxoState.sortUtxo', () {
    final pendingUtxos = [
      UtxoState(
        amount: 3000,
        timestamp: ascendingOrderTimestampForPending[0],
        blockHeight: 0,
        status: UtxoStatus.incoming,
        derivationPath: "m/84'/0'/0'/0/3",
        transactionHash: 'hashC',
        index: 3,
        to: 'addressC',
      ),
      UtxoState(
        amount: 3100,
        timestamp: ascendingOrderTimestampForPending[1],
        blockHeight: 0,
        status: UtxoStatus.incoming,
        derivationPath: "m/84'/0'/0'/0/3",
        transactionHash: 'hashC',
        index: 3,
        to: 'addressC',
      ),
      UtxoState(
        amount: 4000,
        timestamp: ascendingOrderTimestampForPending[2],
        blockHeight: 0,
        status: UtxoStatus.outgoing,
        derivationPath: "m/84'/0'/0'/0/4",
        transactionHash: 'hashD',
        index: 4,
        to: 'addressD',
      ),
    ];
    List<UtxoState> makeTestUtxos() {
      return [
        UtxoState(
          amount: 5000,
          timestamp: ascendingOrderTimestampForConfirmed[0],
          blockHeight: 700000,
          status: UtxoStatus.unspent,
          derivationPath: "m/84'/0'/0'/0/1",
          transactionHash: 'hashA',
          index: 1,
          to: 'addressA',
        ),
        UtxoState(
          amount: 10000,
          timestamp: ascendingOrderTimestampForConfirmed[1],
          blockHeight: 700010,
          status: UtxoStatus.unspent,
          derivationPath: "m/84'/0'/0'/0/2",
          transactionHash: 'hashB',
          index: 2,
          to: 'addressB',
        ),
        ...pendingUtxos,
      ];
    }

    test('sort by amount descending', () {
      final utxos = makeTestUtxos();
      UtxoState.sortUtxo(utxos, UtxoOrder.byAmountDesc);

      expect(utxos[0].isPending, true);
      expect(utxos[1].isPending, true);
      expect(utxos[2].isPending, true);
      expect(utxos[3].isPending, false);
      expect(utxos[4].isPending, false);

      expect(utxos[0].amount, 4000);
      expect(utxos[1].amount, 3100);
      expect(utxos[2].amount, 3000);
      expect(utxos[3].amount, 10000);
      expect(utxos[4].amount, 5000);
    });

    test('sort by amount ascending', () {
      final utxos = makeTestUtxos();
      UtxoState.sortUtxo(utxos, UtxoOrder.byAmountAsc);

      expect(utxos[0].isPending, true);
      expect(utxos[1].isPending, true);
      expect(utxos[2].isPending, true);
      expect(utxos[3].isPending, false);
      expect(utxos[4].isPending, false);

      expect(utxos[0].amount, 3000);
      expect(utxos[1].amount, 3100);
      expect(utxos[2].amount, 4000);
      expect(utxos[3].amount, 5000);
      expect(utxos[4].amount, 10000);
    });

    test('sort by timestamp descending', () {
      final utxos = makeTestUtxos();
      UtxoState.sortUtxo(utxos, UtxoOrder.byTimestampDesc);

      expect(utxos[0].isPending, true);
      expect(utxos[1].isPending, true);
      expect(utxos[2].isPending, true);
      expect(utxos[3].isPending, false);
      expect(utxos[4].isPending, false);

      expect(utxos[0].timestamp, ascendingOrderTimestampForPending[2]);
      expect(utxos[1].timestamp, ascendingOrderTimestampForPending[1]);
      expect(utxos[2].timestamp, ascendingOrderTimestampForPending[0]);
      expect(utxos[3].timestamp, ascendingOrderTimestampForConfirmed[1]);
      expect(utxos[4].timestamp, ascendingOrderTimestampForConfirmed[0]);
    });

    test('sort by timestamp ascending', () {
      final utxos = makeTestUtxos();
      UtxoState.sortUtxo(utxos, UtxoOrder.byTimestampAsc);

      expect(utxos[0].isPending, true);
      expect(utxos[1].isPending, true);
      expect(utxos[2].isPending, true);
      expect(utxos[3].isPending, false);
      expect(utxos[4].isPending, false);

      expect(utxos[0].timestamp, ascendingOrderTimestampForPending[0]);
      expect(utxos[1].timestamp, ascendingOrderTimestampForPending[1]);
      expect(utxos[2].timestamp, ascendingOrderTimestampForPending[2]);
      expect(utxos[3].timestamp, ascendingOrderTimestampForConfirmed[0]);
      expect(utxos[4].timestamp, ascendingOrderTimestampForConfirmed[1]);
    });
  });
}
