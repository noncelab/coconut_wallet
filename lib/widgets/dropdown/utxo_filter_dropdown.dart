import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:flutter/material.dart';

class UtxoFilterDropdown extends StatelessWidget {
  final bool isVisible;
  final double positionTop;
  final UtxoOrderEnum selectedFilter;
  final Function onSelected;
  const UtxoFilterDropdown({
    super.key,
    required this.isVisible,
    required this.positionTop,
    required this.selectedFilter,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = [
      UtxoOrderEnum.byTimestampDesc.text,
      UtxoOrderEnum.byTimestampAsc.text,
      UtxoOrderEnum.byAmountDesc.text,
      UtxoOrderEnum.byAmountAsc.text,
    ];
    return Visibility(
      visible: isVisible,
      child: Positioned(
        top: positionTop,
        right: 16,
        child: Material(
          borderRadius: BorderRadius.circular(16),
          child: CoconutPulldownMenu(
            brightness: Brightness.dark,
            buttons: buttons,
            dividerColor: Colors.black,
            selectedIndex: buttons.indexOf(selectedFilter.text),
            onTap: (index) {
              switch (index) {
                case 0: // 큰 금액순
                  if (selectedFilter != UtxoOrderEnum.byTimestampDesc) {
                    onSelected(UtxoOrderEnum.byTimestampDesc);
                  }
                  break;
                case 1: // 작은 금액순
                  if (selectedFilter != UtxoOrderEnum.byTimestampAsc) {
                    onSelected(UtxoOrderEnum.byTimestampAsc);
                  }
                  break;
                case 2: // 최신순
                  if (selectedFilter != UtxoOrderEnum.byAmountDesc) {
                    onSelected(UtxoOrderEnum.byAmountDesc);
                  }
                  break;
                case 3: // 오래된 순
                  if (selectedFilter != UtxoOrderEnum.byAmountAsc) {
                    onSelected(UtxoOrderEnum.byAmountAsc);
                  }
                  break;
              }
            },
          ),
        ),
      ),
    );
  }
}
