import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/repository/converter/transaction.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/widgets/body/wallet_detail_body.dart';
import 'package:coconut_wallet/widgets/card/transaction_item_card.dart';
import 'package:coconut_wallet/widgets/card/utxo_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coconut_wallet/model/app/utxo/utxo.dart' as model;

class FakeTransferDTO extends TransferDTO {
  FakeTransferDTO({
    required String transactionHash,
    required int amount,
    required String transferType,
    String? memo,
    String? note,
    DateTime? createdAt,
  }) : super(transactionHash, DateTime.now(), 0, transferType, memo, amount, 0,
            [], [], note, createdAt);
}

class FakeUTXO extends model.UTXO {
  FakeUTXO({
    required int amount,
    required int index,
  }) : super((DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(), '1',
            amount, 'to', "m/84'/1'/0'/0/6", 'tx_$index', index);
}

void main() {
  group('WalletDetailBody', () {
    List<model.UTXO> mockUtxoList = [];
    List<TransferDTO> mockTxList = [];

    testWidgets('transaction rendering test', (tester) async {
      final txList = [
        FakeTransferDTO(
            transactionHash: 'hash_1',
            amount: 1,
            transferType: 'RECEIVED',
            note: 'Note 1'),
        FakeTransferDTO(
            transactionHash: 'hash_2',
            amount: 2,
            transferType: 'SEND',
            note: 'Note 2'),
        FakeTransferDTO(
            transactionHash: 'hash_3',
            amount: 3,
            transferType: 'SELF',
            note: 'Note 3'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                WalletDetailBody(
                  txSliverListKey: GlobalKey(),
                  utxoSliverListKey: GlobalKey(),
                  walletId: 1,
                  walletType: WalletType.singleSignature,
                  currentUnit: Unit.btc,
                  isTransaction: true,
                  isUtxoListLoadComplete: false,
                  txList: txList,
                  utxoList: mockUtxoList,
                  removePopup: () {},
                  popFromUtxoDetail: (resultUtxo) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(TransactionItemCard), findsWidgets);
    });

    testWidgets('utxo rendering test', (tester) async {
      final utxoList = [
        FakeUTXO(amount: 1, index: 0),
        FakeUTXO(amount: 1, index: 1),
        FakeUTXO(amount: 1, index: 2),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                WalletDetailBody(
                  txSliverListKey: GlobalKey(),
                  utxoSliverListKey: GlobalKey(),
                  walletId: 1,
                  walletType: WalletType.singleSignature,
                  currentUnit: Unit.btc,
                  isTransaction: false,
                  isUtxoListLoadComplete: false,
                  txList: mockTxList,
                  utxoList: utxoList,
                  removePopup: () {},
                  popFromUtxoDetail: (resultUtxo) {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(UTXOItemCard), findsWidgets);
    });
  });
}
