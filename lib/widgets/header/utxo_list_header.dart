import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:coconut_wallet/widgets/header/selected_utxo_amount_header.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class UtxoListHeader extends StatefulWidget {
  final GlobalKey headerGlobalKey;
  final GlobalKey dropdownGlobalKey;
  final AnimatedBalanceData animatedBalanceData;
  final String selectedOption;
  final Function onTapDropdown;
  final bool isLoadComplete;
  final void Function() onPressedUnitToggle;
  final BitcoinUnit currentUnit;
  final Widget tagListWidget;
  final bool isBalanceHidden;
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
    required this.selectedOption,
    required this.onTapDropdown,
    required this.isLoadComplete,
    required this.currentUnit,
    required this.onPressedUnitToggle,
    required this.tagListWidget,
    this.isBalanceHidden = false,
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
        widget.isBalanceHidden ? _buildSelectionModeHeader() : _buildHeader(),
        CoconutLayout.spacing_50h,
        widget.tagListWidget,
        CoconutLayout.spacing_300h,
      ],
    );
  }

  // --------------------
  // 일반 모드 헤더
  // --------------------
  Widget _buildHeader() {
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
      padding: const EdgeInsets.only(left: 20, top: 28, right: 20),
      width: MediaQuery.sizeOf(context).width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.utxo_list_screen.total_balance, style: CoconutTypography.body1_16_Bold),
          CoconutLayout.spacing_100h,
          GestureDetector(
            onTap: widget.onPressedUnitToggle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicWidth(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: AnimatedBalance(
                            prevValue: widget.animatedBalanceData.previous,
                            value: widget.animatedBalanceData.current,
                            currentUnit: widget.currentUnit,
                            textStyle: CoconutTypography.heading1_32_NumberBold,
                          ),
                        ),
                      ),
                      CoconutLayout.spacing_200w,
                      Text(widget.currentUnit.symbol, style: CoconutTypography.heading3_21_Number),
                    ],
                  ),
                ),
                CoconutLayout.spacing_50h,
                FiatPrice(satoshiAmount: widget.animatedBalanceData.current),
              ],
            ),
          ),
          CoconutLayout.spacing_400h,
          Row(
            children: [
              const Spacer(),
              if (!widget.isLoadComplete)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 12,
                  height: 12,
                  child: const CircularProgressIndicator(color: CoconutColors.gray400, strokeWidth: 2),
                ),
              CupertinoButton(
                key: widget.dropdownGlobalKey,
                padding: const EdgeInsets.only(top: 7, bottom: 7, left: 8, right: 0),
                minSize: 0,
                onPressed: widget.isLoadComplete ? () => widget.onTapDropdown() : null,
                child: Row(
                  children: [
                    Text(
                      widget.selectedOption,
                      style: CoconutTypography.body3_12.setColor(
                        widget.isLoadComplete ? CoconutColors.white : CoconutColors.gray700,
                      ),
                    ),
                    CoconutLayout.spacing_200w,
                    SvgPicture.asset(
                      'assets/svg/arrow-down.svg',
                      colorFilter:
                          widget.isLoadComplete ? null : const ColorFilter.mode(CoconutColors.gray700, BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------
  // 선택 모드 헤더
  // --------------------
  Widget _buildSelectionModeHeader() {
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
