import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:flutter/material.dart';

class UtxoOrderDropdown extends StatelessWidget {
  final bool isVisible;
  final double positionTop;
  final UtxoOrder selectedOption;
  final Function onOptionSelected;
  const UtxoOrderDropdown({
    super.key,
    required this.isVisible,
    required this.positionTop,
    required this.selectedOption,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return isVisible
        ? Positioned(
            top: positionTop,
            right: 16,
            child: Material(
              borderRadius: BorderRadius.circular(16),
              child: CoconutPulldownMenu(
                entries: [
                  CoconutPulldownMenuItem(title: UtxoOrder.byTimestampDesc.text),
                  CoconutPulldownMenuItem(title: UtxoOrder.byTimestampAsc.text),
                  CoconutPulldownMenuItem(title: UtxoOrder.byAmountDesc.text),
                  CoconutPulldownMenuItem(title: UtxoOrder.byAmountAsc.text),
                ],
                dividerColor: Colors.black,
                onSelected: (index, filterName) {
                  switch (index) {
                    case 0: // 최신순
                      if (selectedOption != UtxoOrder.byTimestampDesc) {
                        onOptionSelected(UtxoOrder.byTimestampDesc);
                      }
                      break;
                    case 1: // 오래된 순
                      if (selectedOption != UtxoOrder.byTimestampAsc) {
                        onOptionSelected(UtxoOrder.byTimestampAsc);
                      }
                      break;
                    case 2: // 큰 금액순
                      if (selectedOption != UtxoOrder.byAmountDesc) {
                        onOptionSelected(UtxoOrder.byAmountDesc);
                      }
                      break;
                    case 3: // 작은 금액순
                      if (selectedOption != UtxoOrder.byAmountAsc) {
                        onOptionSelected(UtxoOrder.byAmountAsc);
                      }
                      break;
                  }
                },
                selectedIndex: _getIndexBySelectedFilter(),
              ),
            ),
          )
        : Container();
  }

  int _getIndexBySelectedFilter() {
    switch (selectedOption) {
      case UtxoOrder.byTimestampDesc:
        return 0;
      case UtxoOrder.byTimestampAsc:
        return 1;
      case UtxoOrder.byAmountDesc:
        return 2;
      case UtxoOrder.byAmountAsc:
        return 3;
    }
  }
}
