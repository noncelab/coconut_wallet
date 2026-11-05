import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/features/utxo/header/selected_utxo_amount_header.dart';
import 'package:coconut_wallet/widgets/features/utxo/header/utxo_list_dropdown_button.dart';
import 'package:flutter/cupertino.dart';

class UtxoListHeader extends StatefulWidget {
  final GlobalKey headerGlobalKey;
  final GlobalKey dropdownGlobalKey;
  final AnimatedBalanceData animatedBalanceData;
  final String activeOption;
  final Function onTapDropdown;
  final bool isLoadComplete;
  final void Function() onPressedUnitToggle;
  final BitcoinUnit currentUnit;
  final Widget tagListWidget;
  final GlobalKey orderDropdownButtonKey;
  final String orderText;
  final int selectedUtxoCount;
  final int selectedUtxoAmountSum;
  final VoidCallback onSelectAll;
  final VoidCallback onUnselectAll;
  final bool isSelectionMode;
  final ValueNotifier<bool> dropdownVisibleNotifier;

  const UtxoListHeader({
    super.key,
    required this.headerGlobalKey,
    required this.dropdownGlobalKey,
    required this.animatedBalanceData,
    required this.activeOption,
    required this.onTapDropdown,
    required this.isLoadComplete,
    required this.currentUnit,
    required this.onPressedUnitToggle,
    required this.tagListWidget,
    required this.orderDropdownButtonKey,
    required this.orderText,
    required this.selectedUtxoCount,
    required this.selectedUtxoAmountSum,
    required this.onSelectAll,
    required this.onUnselectAll,
    required this.isSelectionMode,
    required this.dropdownVisibleNotifier,
  });

  @override
  State<UtxoListHeader> createState() => _UtxoListHeaderState();
}

class _UtxoListHeaderState extends State<UtxoListHeader> {
  @override
  Widget build(BuildContext context) {
    return Column(
      key: widget.headerGlobalKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.isSelectionMode ? _buildSelectionModeHeader(context) : _buildHeader(context),
        CoconutLayout.spacing_50h,
        widget.tagListWidget,
        CoconutLayout.spacing_300h,
      ],
    );
  }

  // --------------------
  // 일반 모드 헤더
  // --------------------
  Widget _buildHeader(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
      padding: const EdgeInsets.only(left: 20, top: 28, right: 20),
      width: MediaQuery.sizeOf(context).width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.utxo_list_screen.total_balance,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
          ),
          CoconutLayout.spacing_100h,
          GestureDetector(
            onTap: widget.onPressedUnitToggle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicWidth(
                  child: BitcoinAmountUnit(
                    currentUnit: widget.currentUnit,
                    unitStyle: CoconutTypography.heading4_18_Number.setColor(context.coconutColors.primaryText),
                    child: Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: AnimatedBalance(
                          prevValue: widget.animatedBalanceData.previous,
                          value: widget.animatedBalanceData.current,
                          currentUnit: widget.currentUnit,
                          textStyle: CoconutTypography.heading2_28_NumberBold.setColor(
                            context.coconutColors.primaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                CoconutLayout.spacing_50h,
                FiatPrice(satoshiAmount: widget.animatedBalanceData.current),
              ],
            ),
          ),
          CoconutLayout.spacing_400h,
          UtxoListDropdownButton(
            dropdownGlobalKey: widget.dropdownGlobalKey,
            activeOption: widget.activeOption,
            isEnabled: widget.isLoadComplete,
            onTapDropdown: () => widget.onTapDropdown(),
          ),
        ],
      ),
    );
  }

  // --------------------
  // 선택 모드 헤더
  // --------------------
  Widget _buildSelectionModeHeader(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
      width: MediaQuery.sizeOf(context).width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          SelectedUtxoAmountHeader(
            orderDropdownButtonKey: widget.orderDropdownButtonKey,
            orderText: widget.orderText,
            selectedUtxoCount: widget.selectedUtxoCount,
            selectedUtxoAmountSum: widget.selectedUtxoAmountSum,
            currentUnit: widget.currentUnit,
            onSelectAll: widget.onSelectAll,
            onUnselectAll: widget.onUnselectAll,
            onToggleOrderDropdown: () {
              if (widget.isLoadComplete) widget.onTapDropdown();
            },
          ),
        ],
      ),
    );
  }
}
