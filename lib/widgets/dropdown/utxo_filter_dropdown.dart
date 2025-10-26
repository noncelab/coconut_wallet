import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:flutter/material.dart';

class UtxoOrderDropdown extends StatelessWidget {
  final bool isVisible;
  final double positionTop;
  final UtxoOrder selectedOption;
  final Function onOptionSelected;
  final bool isSelectionMode;
  const UtxoOrderDropdown({
    super.key,
    required this.isVisible,
    required this.positionTop,
    required this.selectedOption,
    required this.onOptionSelected,
    required this.isSelectionMode,
  });

  @override
  Widget build(BuildContext context) {
    return isVisible
        ? Positioned(
          top: isSelectionMode ? positionTop + 10 : positionTop,
          left: isSelectionMode ? 16 : null,
          right: isSelectionMode ? null : 16,
          child: Material(
            borderRadius: BorderRadius.circular(16),
            child: CoconutPulldownMenu(
              entries: [
                CoconutPulldownMenuItem(title: UtxoOrder.byAmountDesc.text),
                CoconutPulldownMenuItem(title: UtxoOrder.byAmountAsc.text),
                CoconutPulldownMenuItem(title: UtxoOrder.byTimestampDesc.text),
                CoconutPulldownMenuItem(title: UtxoOrder.byTimestampAsc.text),
              ],
              dividerColor: CoconutColors.black,
              onSelected: (index, filterName) {
                switch (index) {
                  case 0: // 큰 금액순
                    if (selectedOption != UtxoOrder.byAmountDesc) {
                      onOptionSelected(UtxoOrder.byAmountDesc);
                    }
                    break;
                  case 1: // 작은 금액순
                    if (selectedOption != UtxoOrder.byAmountAsc) {
                      onOptionSelected(UtxoOrder.byAmountAsc);
                    }
                    break;
                  case 2: // 최신순
                    if (selectedOption != UtxoOrder.byTimestampDesc) {
                      onOptionSelected(UtxoOrder.byTimestampDesc);
                    }
                    break;
                  case 3: // 오래된 순
                    if (selectedOption != UtxoOrder.byTimestampAsc) {
                      onOptionSelected(UtxoOrder.byTimestampAsc);
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
      case UtxoOrder.byAmountDesc:
        return 0;
      case UtxoOrder.byAmountAsc:
        return 1;
      case UtxoOrder.byTimestampDesc:
        return 2;
      case UtxoOrder.byTimestampAsc:
        return 3;
    }
  }
}
