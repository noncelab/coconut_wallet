import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/utxo_amount_format_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class _SelectionSummaryBar extends StatelessWidget {
  final int selectedCount;
  final int selectedTotalSats;
  final BitcoinUnit currentUnit;
  final int dustThreshold;
  final VoidCallback onCancel;

  const _SelectionSummaryBar({
    required this.selectedCount,
    required this.selectedTotalSats,
    required this.currentUnit,
    required this.dustThreshold,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: CoconutColors.white, shape: BoxShape.circle),
                child: SvgPicture.asset(
                  'assets/svg/check.svg',
                  width: 8,
                  height: 8,
                  colorFilter: const ColorFilter.mode(CoconutColors.black, BlendMode.srcIn),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$selectedCount coins • ${formatUtxoAmountForDisplay(selectedTotalSats, currentUnit, dustThreshold: dustThreshold)}',
                style: CoconutTypography.body1_16_NumberBold.setColor(CoconutColors.white),
                textScaler: const TextScaler.linear(1.0),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _FilterChip(iconPath: 'assets/svg/close.svg', label: t.cancel, isSelected: true, onTap: onCancel),
      ],
    );
  }
}

/// 금액별 필터 바 - 바 차트 하단, 스크롤 시 앱바에 고정, 선택 모드 시 요약 요소 하단에 추가 표시
class UtxoAmountStickyFilterBarDelegate extends SliverPersistentHeaderDelegate {
  static const Duration _transitionDuration = Duration(milliseconds: 220);

  final double height;
  final int selectedCount;
  final int selectedTotalSats;
  final BitcoinUnit currentUnit;
  final int dustThreshold;
  final int viewModeIndex;
  final int lockFilterIndex;
  final bool isSelectionMode;
  final ValueChanged<int> onViewModeSelected;
  final ValueChanged<int> onLockFilterSelected;
  final VoidCallback onExitSelectionMode;

  UtxoAmountStickyFilterBarDelegate({
    required this.height,
    required this.selectedCount,
    required this.selectedTotalSats,
    required this.currentUnit,
    required this.dustThreshold,
    required this.viewModeIndex,
    required this.lockFilterIndex,
    required this.isSelectionMode,
    required this.onViewModeSelected,
    required this.onLockFilterSelected,
    required this.onExitSelectionMode,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: Material(
        color: CoconutColors.black,
        elevation: overlapsContent ? 4 : 0,
        child: _StickyFilterBar(
          selectedCount: selectedCount,
          selectedTotalSats: selectedTotalSats,
          currentUnit: currentUnit,
          dustThreshold: dustThreshold,
          viewModeIndex: viewModeIndex,
          lockFilterIndex: lockFilterIndex,
          isSelectionMode: isSelectionMode,
          onViewModeSelected: onViewModeSelected,
          onLockFilterSelected: onLockFilterSelected,
          onExitSelectionMode: onExitSelectionMode,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant UtxoAmountStickyFilterBarDelegate oldDelegate) =>
      height != oldDelegate.height ||
      selectedCount != oldDelegate.selectedCount ||
      selectedTotalSats != oldDelegate.selectedTotalSats ||
      currentUnit != oldDelegate.currentUnit ||
      dustThreshold != oldDelegate.dustThreshold ||
      viewModeIndex != oldDelegate.viewModeIndex ||
      lockFilterIndex != oldDelegate.lockFilterIndex ||
      isSelectionMode != oldDelegate.isSelectionMode;
}

class _StickyFilterBar extends StatelessWidget {
  static const Duration _transitionDuration = UtxoAmountStickyFilterBarDelegate._transitionDuration;

  final int selectedCount;
  final int selectedTotalSats;
  final BitcoinUnit currentUnit;
  final int dustThreshold;
  final int viewModeIndex;
  final int lockFilterIndex;
  final bool isSelectionMode;
  final ValueChanged<int> onViewModeSelected;
  final ValueChanged<int> onLockFilterSelected;
  final VoidCallback onExitSelectionMode;

  const _StickyFilterBar({
    required this.selectedCount,
    required this.selectedTotalSats,
    required this.currentUnit,
    required this.dustThreshold,
    required this.viewModeIndex,
    required this.lockFilterIndex,
    required this.isSelectionMode,
    required this.onViewModeSelected,
    required this.onLockFilterSelected,
    required this.onExitSelectionMode,
  });

  @override
  Widget build(BuildContext context) {
    final showSelectionSummary = isSelectionMode && viewModeIndex == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _ViewModeChip(
                icon: Icons.view_list_rounded,
                isSelected: viewModeIndex == 0,
                onTap: () => onViewModeSelected(0),
                semanticLabel: t.utxo_overview_screen.view_mode_list,
                isLeftChunk: true,
              ),
              _ViewModeChip(
                icon: Icons.grid_view_rounded,
                isSelected: viewModeIndex == 1,
                onTap: () => onViewModeSelected(1),
                semanticLabel: t.utxo_overview_screen.view_mode_grid,
                isRightChunk: true,
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: _transitionDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.centerRight,
                    children: [...previousChildren, if (currentChild != null) currentChild],
                  );
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child:
                    showSelectionSummary
                        ? const SizedBox(key: ValueKey('selection-empty-space'))
                        : _buildLockFilterChips(),
              ),
            ],
          ),
          if (showSelectionSummary)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _SelectionSummaryBar(
                selectedCount: selectedCount,
                selectedTotalSats: selectedTotalSats,
                currentUnit: currentUnit,
                dustThreshold: dustThreshold,
                onCancel: onExitSelectionMode,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLockFilterChips() {
    return KeyedSubtree(
      key: const ValueKey('lock-filter-chips'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterChip(
            iconPath: 'assets/svg/unlock_simple.svg',
            label: t.utxo_detail_screen.utxo_unlocked,
            isSelected: lockFilterIndex == 0,
            onTap: () => onLockFilterSelected(0),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            iconPath: 'assets/svg/lock_simple.svg',
            label: t.utxo_detail_screen.utxo_locked,
            isSelected: lockFilterIndex == 1,
            onTap: () => onLockFilterSelected(1),
          ),
        ],
      ),
    );
  }
}

class _ViewModeChip extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool isLeftChunk;
  final bool isRightChunk;

  const _ViewModeChip({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.semanticLabel,
    this.isLeftChunk = false,
    this.isRightChunk = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? CoconutColors.gray150 : Colors.transparent;
    final iconColor = isSelected ? CoconutColors.black : CoconutColors.gray700;
    final borderColor = isSelected ? CoconutColors.gray150 : CoconutColors.gray700;
    final borderRadius = BorderRadius.only(
      topLeft: isRightChunk ? Radius.zero : const Radius.circular(8),
      topRight: isLeftChunk ? Radius.zero : const Radius.circular(8),
      bottomLeft: isRightChunk ? Radius.zero : const Radius.circular(8),
      bottomRight: isLeftChunk ? Radius.zero : const Radius.circular(8),
    );
    final border = Border(
      top: BorderSide(color: borderColor, width: 1),
      bottom: BorderSide(color: borderColor, width: 1),
      left: isRightChunk ? BorderSide.none : BorderSide(color: borderColor, width: 1),
      right: isLeftChunk ? BorderSide.none : BorderSide(color: borderColor, width: 1),
    );

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: bgColor, borderRadius: borderRadius, border: border),
            child: Icon(icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String iconPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.iconPath, required this.label, required this.isSelected, required this.onTap});

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isSelected ? CoconutColors.gray150 : Colors.transparent;
    final textColor = widget.isSelected ? CoconutColors.black : CoconutColors.gray600;
    final iconColor = widget.isSelected ? CoconutColors.black : CoconutColors.gray600;
    final border = widget.isSelected ? null : Border.all(color: CoconutColors.gray700, width: 1);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        scale: _isPressed ? 0.96 : 1,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          opacity: _isPressed ? 0.72 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20), border: border),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  widget.iconPath,
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
                const SizedBox(width: 2),
                Text(
                  widget.label,
                  style: (widget.isSelected ? CoconutTypography.caption_10_Bold : CoconutTypography.caption_10)
                      .setColor(textColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 태그별 선택 모드에서 나타남 - 도넛 차트 하단, 스크롤 시 앱바에 고정
class UtxoTagSelectionBarDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final int selectedCount;
  final int selectedTotalSats;
  final BitcoinUnit currentUnit;
  final int dustThreshold;
  final bool isSelectionMode;
  final VoidCallback onExitSelectionMode;

  UtxoTagSelectionBarDelegate({
    required this.height,
    required this.selectedCount,
    required this.selectedTotalSats,
    required this.currentUnit,
    required this.dustThreshold,
    required this.isSelectionMode,
    required this.onExitSelectionMode,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: Material(
        color: CoconutColors.black,
        elevation: overlapsContent ? 4 : 0,
        child:
            isSelectionMode
                ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _SelectionSummaryBar(
                    selectedCount: selectedCount,
                    selectedTotalSats: selectedTotalSats,
                    currentUnit: currentUnit,
                    dustThreshold: dustThreshold,
                    onCancel: onExitSelectionMode,
                  ),
                )
                : const SizedBox.shrink(),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant UtxoTagSelectionBarDelegate oldDelegate) =>
      height != oldDelegate.height ||
      selectedCount != oldDelegate.selectedCount ||
      selectedTotalSats != oldDelegate.selectedTotalSats ||
      currentUnit != oldDelegate.currentUnit ||
      dustThreshold != oldDelegate.dustThreshold ||
      isSelectionMode != oldDelegate.isSelectionMode;
}
