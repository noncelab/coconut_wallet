import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/utils/derivation_path_util.dart';
import 'package:coconut_wallet/widgets/card/utxo_item_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:provider/provider.dart';

class UtxoListBody extends StatelessWidget {
  final Key utxoSliverListKey;
  final int walletId;
  final WalletType walletType;
  final bool isUtxoListLoadComplete;
  final List<UtxoState> utxoList;
  final Function removePopup;
  const UtxoListBody({
    super.key,
    required this.utxoSliverListKey,
    required this.walletId,
    required this.walletType,
    required this.isUtxoListLoadComplete,
    required this.utxoList,
    required this.removePopup,
  });

  @override
  Widget build(BuildContext context) {
    return utxoList.isNotEmpty
        ? Consumer<UtxoListViewModel>(
            builder: (context, viewModel, child) {
              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final utxoHasSelectedTag = viewModel.selectedUtxoTagName ==
                          t.all ||
                      (utxoList[index].tags != null &&
                          utxoList[index].tags!.any(
                              (e) => e.name == viewModel.selectedUtxoTagName));

                  if (utxoHasSelectedTag) {
                    if (viewModel.selectedUtxoTagName != t.all &&
                        !utxoHasSelectedTag) {
                      return const SizedBox();
                    }
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: UtxoItemCard(
                        key: index == 0 ? utxoSliverListKey : null,
                        onPressed: () async {
                          removePopup();
                          final utxo = utxoList[index];
                          await Navigator.pushNamed(
                            context,
                            '/utxo-detail',
                            arguments: {
                              'utxo': utxo,
                              'id': walletId,
                            },
                          );
                        },
                        utxo: utxoList[index],
                      ),
                    );
                  } else {
                    return const SizedBox();
                  }
                }, childCount: utxoList.length),
              );
            },
          )
        : SliverFillRemaining(
            fillOverscroll: false,
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  isUtxoListLoadComplete ? t.utxo_not_found : t.utxo_loading,
                  style: CoconutTypography.body1_16,
                ),
              ),
            ),
          );
  }
}
