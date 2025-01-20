import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/repository/converter/transaction.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/derivation_path_util.dart';
import 'package:coconut_wallet/widgets/card/transaction_item_card.dart';
import 'package:coconut_wallet/widgets/card/utxo_item_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/model/app/utxo/utxo.dart' as model;

class WalletDetailBody extends StatelessWidget {
  final Key txSliverListKey;
  final Key utxoSliverListKey;
  final int walletId;
  final WalletType walletType;
  final Unit currentUnit;
  final bool isTransaction;
  final bool isUtxoListLoadComplete;
  final List<TransferDTO> txList;
  final List<model.UTXO> utxoList;
  final Function(model.UTXO)? popFromUtxoDetail;
  const WalletDetailBody({
    super.key,
    required this.txSliverListKey,
    required this.utxoSliverListKey,
    required this.walletId,
    required this.walletType,
    required this.currentUnit,
    required this.isTransaction,
    required this.isUtxoListLoadComplete,
    required this.txList,
    required this.utxoList,
    this.popFromUtxoDetail,
  });

  @override
  Widget build(BuildContext context) {
    return isTransaction && txList.isNotEmpty ||
            !isTransaction && utxoList.isNotEmpty
        ? SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index.isOdd) return const SizedBox(height: 8);
                if (isTransaction) {
                  final tx = txList[index];
                  return TransactionItemCard(
                    key: index == 0 ? txSliverListKey : null,
                    tx: tx,
                    currentUnit: currentUnit,
                    id: walletId,
                    onPressed: () {
                      Navigator.pushNamed(context, '/transaction-detail',
                          arguments: {
                            'id': walletId,
                            'txHash': tx.transactionHash
                          });
                    },
                  );
                } else {
                  final itemIndex = index ~/ 2;
                  return UTXOItemCard(
                    key: index == 0 ? utxoSliverListKey : null,
                    currentUnit: currentUnit,
                    onPressed: () async {
                      final utxo = utxoList[itemIndex];
                      await Navigator.pushNamed(
                        context,
                        '/utxo-detail',
                        arguments: {
                          'utxo': utxo,
                          'id': walletId,
                          'isChange': DerivationPathUtil.getChangeElement(
                                walletType,
                                utxo.derivationPath,
                              ) ==
                              1,
                        },
                      );
                      popFromUtxoDetail?.call(utxo);
                    },
                    utxo: utxoList[itemIndex],
                  );
                }
              },
              childCount: isTransaction
                  ? txList.length
                  : utxoList.length * 2 - 1, // 항목 개수 지정
            ),
          )
        : SliverFillRemaining(
            fillOverscroll: isTransaction,
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  isTransaction
                      ? '거래 내역이 없어요'
                      : isUtxoListLoadComplete
                          ? 'UTXO가 없어요'
                          : 'UTXO를 확인하는 중이에요',
                  style: Styles.body1,
                ),
              ),
            ),
          );
  }
}
