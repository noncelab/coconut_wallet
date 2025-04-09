import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('testing UtxoState.sortUtxo', () {
    final pendingUtxos = [
      UtxoState(
        amount: 3000,
        timestamp: DateTime(2020, 10, 2),
        blockHeight: 0,
        status: UtxoStatus.incoming,
        derivationPath: "m/84'/0'/0'/0/3",
        transactionHash: 'hashC',
        index: 3,
        to: 'addressC',
      ),
      UtxoState(
        amount: 3100,
        timestamp: DateTime(2021, 10, 2),
        blockHeight: 0,
        status: UtxoStatus.incoming,
        derivationPath: "m/84'/0'/0'/0/3",
        transactionHash: 'hashC',
        index: 3,
        to: 'addressC',
      ),
      UtxoState(
        amount: 4000,
        timestamp: DateTime(2022, 10, 2),
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
          timestamp: DateTime(2009, 10, 1),
          blockHeight: 700000,
          status: UtxoStatus.unspent,
          derivationPath: "m/84'/0'/0'/0/1",
          transactionHash: 'hashA',
          index: 1,
          to: 'addressA',
        ),
        UtxoState(
          amount: 10000,
          timestamp: DateTime(2009, 10, 2),
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

      expect(utxos[0].status, anyOf([UtxoStatus.incoming, UtxoStatus.outgoing]));
      expect(utxos[1].status, anyOf([UtxoStatus.incoming, UtxoStatus.outgoing]));
      expect(utxos[2].status, anyOf([UtxoStatus.incoming, UtxoStatus.outgoing]));
      expect(utxos[3].amount, 10000);
      expect(utxos[4].amount, 5000);
    });

    test('sort by amount ascending', () {
      final utxos = makeTestUtxos();
      UtxoState.sortUtxo(utxos, UtxoOrder.byAmountAsc);

      expect(utxos[0].status, anyOf([UtxoStatus.incoming, UtxoStatus.outgoing]));
      expect(utxos[1].status, anyOf([UtxoStatus.incoming, UtxoStatus.outgoing]));
      expect(utxos[2].status, anyOf([UtxoStatus.incoming, UtxoStatus.outgoing]));
      expect(utxos[3].amount, 5000);
      expect(utxos[4].amount, 10000);
    });

    test('sort by timestamp descending', () {
      final utxos = makeTestUtxos();
      UtxoState.sortUtxo(utxos, UtxoOrder.byTimestampDesc);

      expect(utxos[0].status, anyOf([UtxoStatus.incoming, UtxoStatus.outgoing]));
      expect(utxos[1].status, anyOf([UtxoStatus.incoming, UtxoStatus.outgoing]));
      expect(utxos[2].status, anyOf([UtxoStatus.incoming, UtxoStatus.outgoing]));
      expect(utxos[3].timestamp, DateTime(2009, 10, 2));
      expect(utxos[4].timestamp, DateTime(2009, 10, 1));
    });

    test('sort by timestamp ascending', () {
      final utxos = makeTestUtxos();
      UtxoState.sortUtxo(utxos, UtxoOrder.byTimestampAsc);

      expect(utxos[0].status, anyOf([UtxoStatus.incoming, UtxoStatus.outgoing]));
      expect(utxos[1].status, anyOf([UtxoStatus.incoming, UtxoStatus.outgoing]));
      expect(utxos[2].status, anyOf([UtxoStatus.incoming, UtxoStatus.outgoing]));
      expect(utxos[3].timestamp, DateTime(2009, 10, 1));
      expect(utxos[4].timestamp, DateTime(2009, 10, 2));
    });
  });
}
