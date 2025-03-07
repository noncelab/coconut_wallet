import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/widgets/dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';

class UtxoOrderDropdown extends StatelessWidget {
  final bool isVisible;
  final double positionTop;
  final UtxoOrder selectedFilter;
  final Function onSelected;
  const UtxoOrderDropdown({
    super.key,
    required this.isVisible,
    required this.positionTop,
    required this.selectedFilter,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return isVisible
        ? Positioned(
            top: positionTop,
            right: 16,
            child: Material(
              borderRadius: BorderRadius.circular(16),
              child: CustomDropdown(
                buttons: [
                  UtxoOrder.byTimestampDesc.text,
                  UtxoOrder.byTimestampAsc.text,
                  UtxoOrder.byAmountDesc.text,
                  UtxoOrder.byAmountAsc.text,
                ],
                dividerColor: Colors.black,
                onTapButton: (index) {
                  switch (index) {
                    case 0: // 큰 금액순
                      if (selectedFilter != UtxoOrder.byTimestampDesc) {
                        onSelected(UtxoOrder.byTimestampDesc);
                      }
                      break;
                    case 1: // 작은 금액순
                      if (selectedFilter != UtxoOrder.byTimestampAsc) {
                        onSelected(UtxoOrder.byTimestampAsc);
                      }
                      break;
                    case 2: // 최신순
                      if (selectedFilter != UtxoOrder.byAmountDesc) {
                        onSelected(UtxoOrder.byAmountDesc);
                      }
                      break;
                    case 3: // 오래된 순
                      if (selectedFilter != UtxoOrder.byAmountAsc) {
                        onSelected(UtxoOrder.byAmountAsc);
                      }
                      break;
                  }
                },
                selectedButton: selectedFilter.text,
              ),
            ),
          )
        : Container();
  }
}
