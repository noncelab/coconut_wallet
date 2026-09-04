import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/renewal_utxo_list_view_model.dart';
import 'package:coconut_wallet/widgets/features/utxo/header/utxo_list_dropdown_button.dart';
import 'package:flutter/material.dart';

class RenewalUtxoListFilterHeader extends StatelessWidget {
  const RenewalUtxoListFilterHeader({
    super.key,
    required this.viewModel,
    required this.dropdownKey,
    required this.onTapDropdown,
  });

  final RenewalUtxoListViewModel viewModel;
  final GlobalKey dropdownKey;
  final VoidCallback onTapDropdown;

  @override
  Widget build(BuildContext context) {
    final activeTagName = viewModel.activeUtxoTagName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Stack(
                children: [
                  _buildChipRow(activeTagName, foreground: false),
                  IgnorePointer(child: _buildChipRow(activeTagName, foreground: true)),
                ],
              ),
            ),
          ),
          CoconutLayout.spacing_200w,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: context.coconutColors.borderStrong),
              borderRadius: BorderRadius.circular(18),
            ),
            child: UtxoListDropdownButton(
              dropdownGlobalKey: dropdownKey,
              activeOption: viewModel.activeUtxoOrder.text,
              isEnabled: viewModel.isUtxoListLoadComplete,
              alignRight: false,
              onTapDropdown: onTapDropdown,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipRow(String activeTagName, {required bool foreground}) {
    final filters = <({String label, int count})>[
      (label: t.all, count: viewModel.utxoList.length),
      (label: t.utxo_detail_screen.utxo_locked, count: viewModel.utxoList.where((utxo) => utxo.isLocked).length),
      (label: t.change, count: viewModel.utxoList.where((utxo) => utxo.isChange).length),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, filter) in filters.indexed) ...[
          if (index > 0) CoconutLayout.spacing_100w,
          Opacity(
            opacity: (filter.label == activeTagName) == foreground ? 1 : 0,
            child: AnimatedUtxoFilterChip(
              label: filter.label,
              count: filter.count,
              isSelected: filter.label == activeTagName,
              onTap: () => viewModel.setActiveUtxoTagName(filter.label),
            ),
          ),
        ],
      ],
    );
  }
}

class RenewalUtxoGroupingTabBar extends StatelessWidget {
  const RenewalUtxoGroupingTabBar({super.key, required this.isByAmount, required this.onSelected});

  final bool isByAmount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: context.coconutColors.background,
            padding: const EdgeInsets.fromLTRB(4, 12, 0, 0),
            child: SizedBox(
              width: 132,
              height: 40,
              child: Stack(
                children: [
                  Row(
                    children: [
                      UtxoGroupingTab(
                        label: t.utxo_overview_screen.by_amount,
                        isSelected: isByAmount,
                        onTap: () => onSelected(0),
                      ),
                      UtxoGroupingTab(
                        label: t.utxo_overview_screen.by_tag,
                        isSelected: !isByAmount,
                        onTap: () => onSelected(1),
                      ),
                    ],
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: isByAmount ? 0 : 66,
                    bottom: 0,
                    child: Container(
                      width: 66,
                      height: 2,
                      decoration: BoxDecoration(
                        color: context.coconutColors.primaryText,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: MediaQuery.sizeOf(context).width, height: 1, color: context.coconutColors.divider),
        ],
      ),
    );
  }
}

class AnimatedUtxoFilterChip extends StatelessWidget {
  const AnimatedUtxoFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.none,
      child: CoconutChip(
        color: isSelected ? colors.chipSelectedBackground : colors.chipUnselectedBackground,
        label: isSelected ? '$label $count' : label,
        labelColor: isSelected ? colors.chipSelectedText : colors.chipUnselectedText,
        labelSize: 12,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minWidth: 0,
        isSelected: isSelected ? true : null,
        borderWidth: 0,
        selectedBorderWidth: 0,
        onTap: onTap,
      ),
    );
  }
}

class UtxoGroupingTab extends StatelessWidget {
  const UtxoGroupingTab({super.key, required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            style: CoconutTypography.body1_16_Bold.setColor(
              isSelected
                  ? context.coconutColors.segmentedControlSelectedText
                  : context.coconutColors.segmentedControlUnselectedText,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
