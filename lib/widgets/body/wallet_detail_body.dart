import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/card/transaction_item_card.dart';
import 'package:flutter/cupertino.dart';

class WalletDetailBody extends StatelessWidget {
  final Key txSliverListKey;
  final int walletId;
  final WalletType walletType;
  final Unit currentUnit;
  final List<TransactionRecord> txList;
  final Function removePopup;
  const WalletDetailBody({
    super.key,
    required this.txSliverListKey,
    required this.walletId,
    required this.walletType,
    required this.currentUnit,
    required this.txList,
    required this.removePopup,
  });

  @override
  Widget build(BuildContext context) {
    return txList.isNotEmpty
        ? SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final tx = txList[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: TransactionItemCard(
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
                ),
              );
            }, childCount: txList.length),
          )
        : SliverFillRemaining(
            fillOverscroll: true,
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  t.tx_not_found,
                  style: Styles.body1,
                ),
              ),
            ),
          );
  }
}
