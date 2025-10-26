import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:coconut_wallet/widgets/header/selected_utxo_amount_header.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class UtxoListStickyHeader extends StatelessWidget {
  final GlobalKey stickyHeaderGlobalKey;
  final GlobalKey dropdownGlobalKey;
  final GlobalKey orderDropdownButtonKey;

  final double height;
  final bool isVisible;
  final bool isLoadComplete;
  final bool enableDropdown;

  final AnimatedBalanceData animatedBalanceData;
  final int? totalCount;
  final String selectedOption;
  final Function onTapDropdown;
  final Function removePopup;
  final BitcoinUnit currentUnit;

  final bool isSelectionMode;
  final int selectedUtxoCount;
  final int selectedUtxoAmountSum;
  final String orderText;
  final VoidCallback onSelectAll;
  final VoidCallback onUnselectAll;
  final VoidCallback onToggleOrderDropdown;

  const UtxoListStickyHeader({
    super.key,
    required this.stickyHeaderGlobalKey,
    required this.dropdownGlobalKey,
    required this.orderDropdownButtonKey,
    required this.height,
    required this.isVisible,
    required this.isLoadComplete,
    required this.enableDropdown,
    required this.animatedBalanceData,
    required this.totalCount,
    required this.selectedOption,
    required this.onTapDropdown,
    required this.removePopup,
    required this.currentUnit,
    required this.isSelectionMode,
    required this.selectedUtxoCount,
    required this.selectedUtxoAmountSum,
    required this.orderText,
    required this.onSelectAll,
    required this.onUnselectAll,
    required this.onToggleOrderDropdown,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('build sticky!!!!!!!!!!!!!!!!!!!!');
    final totalCount = this.totalCount ?? 0;

    return Consumer<UtxoListViewModel>(
      builder: (context, viewModel, _) {
        return Positioned(
          top: height,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: !isVisible,
            child: AnimatedOpacity(
              key: stickyHeaderGlobalKey,
              opacity: isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: MediaQuery.sizeOf(context).width,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: CoconutColors.black,
                        boxShadow: [
                          BoxShadow(color: Color.fromRGBO(255, 255, 255, 0.2), offset: Offset(0, 3), blurRadius: 4),
                        ],
                      ),
                    ),
                  ),

                  // 본문 영역
                  Container(
                    color: CoconutColors.black,
                    child: Column(
                      children: [
                        if (!isSelectionMode)
                          _buildStickyHeader(context, totalCount)
                        else
                          _buildSelectionModeStickyHeader(),

                        CoconutLayout.spacing_50h,
                        _buildTagSelector(viewModel),
                        CoconutLayout.spacing_300h,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 일반 모드 헤더 (잔액 + 드롭다운)
  Widget _buildStickyHeader(BuildContext context, int totalCount) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 16, top: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBalance(
                prevValue: animatedBalanceData.previous,
                value: animatedBalanceData.current,
                currentUnit: currentUnit,
                textStyle: CoconutTypography.heading4_18_NumberBold,
              ),
              CoconutLayout.spacing_100w,
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text(currentUnit.symbol, style: CoconutTypography.body2_14_Number),
                      CoconutLayout.spacing_100w,
                      Text(
                        t.total_item_count(count: totalCount),
                        style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 드롭다운 행
        Row(
          children: [
            const Spacer(),
            if (!isLoadComplete)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(color: CoconutColors.gray400, strokeWidth: 2),
                ),
              ),
            CupertinoButton(
              key: dropdownGlobalKey,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8).copyWith(right: 26),
              minSize: 0,
              onPressed: enableDropdown ? () => onTapDropdown() : null,
              child: Row(
                children: [
                  Text(
                    selectedOption,
                    style: CoconutTypography.body3_12.setColor(
                      enableDropdown ? CoconutColors.white : CoconutColors.gray700,
                    ),
                  ),
                  CoconutLayout.spacing_200w,
                  SvgPicture.asset(
                    'assets/svg/arrow-down.svg',
                    colorFilter: enableDropdown ? null : const ColorFilter.mode(CoconutColors.gray700, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 선택 모드 헤더 (SelectedUtxoAmountHeader)
  Widget _buildSelectionModeStickyHeader() {
    debugPrint('selectedUtxoCount: $selectedUtxoCount');
    return SelectedUtxoAmountHeader(
      orderDropdownButtonKey: orderDropdownButtonKey,
      orderText: orderText,
      selectedUtxoCount: selectedUtxoCount,
      selectedUtxoAmountSum: selectedUtxoAmountSum,
      currentUnit: currentUnit,
      onSelectAll: onSelectAll,
      onUnselectAll: onUnselectAll,
      onToggleOrderDropdown: onToggleOrderDropdown,
    );
  }

  /// 태그 선택 바
  Widget _buildTagSelector(UtxoListViewModel viewModel) {
    return CustomTagHorizontalSelector(
      tags: viewModel.utxoTagList.map((e) => e.name).toList(),
      selectedName: viewModel.selectedUtxoTagName,
      onSelectedTag: (tagName) => viewModel.setSelectedUtxoTagName(tagName),
      settingLock: isSelectionMode,
      scrollPhysics: const AlwaysScrollableScrollPhysics(),
    );
  }
}
