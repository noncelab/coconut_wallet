import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_overview_view_model.dart';
import 'package:coconut_wallet/widgets/features/utxo/header/utxo_list_dropdown_button.dart';
import 'package:flutter/material.dart';

class UtxoListFilterHeader extends StatelessWidget {
  const UtxoListFilterHeader({
    super.key,
    required this.viewModel,
    required this.dropdownKey,
    required this.onTapDropdown,
  });

  final UtxoOverviewViewModel viewModel;
  final GlobalKey dropdownKey;
  final VoidCallback onTapDropdown;

  @override
  Widget build(BuildContext context) {
    final activeTagName = viewModel.activeUtxoTagName;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16, right: 24),
                  child: Stack(
                    children: [
                      _buildChipRow(activeTagName, foreground: false),
                      IgnorePointer(child: _buildChipRow(activeTagName, foreground: true)),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            context.coconutColors.background.withValues(alpha: 0),
                            context.coconutColors.background,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          CoconutLayout.spacing_200w,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: context.coconutColors.border),
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
    final filters = <({String label, String text, int count})>[
      (label: t.all, text: t.all, count: viewModel.utxoList.length),
      (
        label: t.utxo_detail_screen.utxo_locked,
        text: t.utxo_detail_screen.utxo_locked,
        count: viewModel.utxoList.where((utxo) => utxo.isLocked).length,
      ),
      (label: t.change, text: t.change, count: viewModel.utxoList.where((utxo) => utxo.isChange).length),
      for (final tag in viewModel.utxoTagList)
        (
          label: tag.name,
          text: '#${tag.name}',
          count: viewModel.utxoList.where((utxo) => utxo.tags?.any((e) => e.name == tag.name) ?? false).length,
        ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, filter) in filters.indexed) ...[
          if (index > 0) CoconutLayout.spacing_100w,
          Opacity(
            opacity: (filter.label == activeTagName) == foreground ? 1 : 0,
            child: AnimatedUtxoFilterChip(
              label: filter.text,
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

class UtxoGroupingTabBar extends StatelessWidget {
  const UtxoGroupingTabBar({super.key, required this.isByAmount, required this.onSelected});

  static const double _tabWidth = 96;

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
            padding: const EdgeInsets.only(left: 4),
            child: SizedBox(
              width: _tabWidth * 2,
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
                    left: isByAmount ? 0 : _tabWidth,
                    bottom: 0,
                    child: Container(
                      width: _tabWidth,
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
          const SizedBox(height: 8),
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
        minWidth: 48,
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
                  ? context.coconutColors.utxoOverviewGroupingTabSelectedText
                  : context.coconutColors.utxoOverviewGroupingTabUnselectedText,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
