import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/utxo_amount_format_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UtxoStickyFilterBarDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final int selectedCount;
  final int selectedTotalSats;
  final BitcoinUnit currentUnit;
  final int viewModeIndex;
  final int lockFilterIndex;
  final bool isSelectionMode;
  final ValueChanged<int> onViewModeSelected;
  final ValueChanged<int> onLockFilterSelected;
  final VoidCallback onExitSelectionMode;

  UtxoStickyFilterBarDelegate({
    required this.height,
    required this.selectedCount,
    required this.selectedTotalSats,
    required this.currentUnit,
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
          key: ValueKey('$isSelectionMode-$selectedCount'),
          selectedCount: selectedCount,
          selectedTotalSats: selectedTotalSats,
          currentUnit: currentUnit,
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
  bool shouldRebuild(covariant UtxoStickyFilterBarDelegate oldDelegate) =>
      height != oldDelegate.height ||
      selectedCount != oldDelegate.selectedCount ||
      selectedTotalSats != oldDelegate.selectedTotalSats ||
      currentUnit != oldDelegate.currentUnit ||
      viewModeIndex != oldDelegate.viewModeIndex ||
      lockFilterIndex != oldDelegate.lockFilterIndex ||
      isSelectionMode != oldDelegate.isSelectionMode;
}

class _StickyFilterBar extends StatelessWidget {
  final int selectedCount;
  final int selectedTotalSats;
  final BitcoinUnit currentUnit;
  final int viewModeIndex;
  final int lockFilterIndex;
  final bool isSelectionMode;
  final ValueChanged<int> onViewModeSelected;
  final ValueChanged<int> onLockFilterSelected;
  final VoidCallback onExitSelectionMode;

  const _StickyFilterBar({
    super.key,
    required this.selectedCount,
    required this.selectedTotalSats,
    required this.currentUnit,
    required this.viewModeIndex,
    required this.lockFilterIndex,
    required this.isSelectionMode,
    required this.onViewModeSelected,
    required this.onLockFilterSelected,
    required this.onExitSelectionMode,
  });

  String _formatSelectedTotal(int sats) => formatUtxoAmountForDisplay(sats, currentUnit);

  @override
  Widget build(BuildContext context) {
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
              if (isSelectionMode)
                _FilterChip(
                  iconPath: 'assets/svg/close.svg',
                  label: t.cancel,
                  isSelected: true,
                  onTap: onExitSelectionMode,
                )
              else ...[
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
            ],
          ),
          if (isSelectionMode) ...[
            const SizedBox(height: 8),
            Row(
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
                  '$selectedCount coins • ${_formatSelectedTotal(selectedTotalSats)}',
                  style: CoconutTypography.body1_16_NumberBold.setColor(CoconutColors.white),
                  textScaler: const TextScaler.linear(1.0),
                ),
              ],
            ),
          ],
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

class _FilterChip extends StatelessWidget {
  final String iconPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.iconPath, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? CoconutColors.gray150 : Colors.transparent;
    final textColor = isSelected ? CoconutColors.black : CoconutColors.gray600;
    final iconColor = isSelected ? CoconutColors.black : CoconutColors.gray600;
    final border = isSelected ? null : Border.all(color: CoconutColors.gray700, width: 1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20), border: border),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                iconPath,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 2),
              Text(
                label,
                style: (isSelected ? CoconutTypography.caption_10_Bold : CoconutTypography.caption_10).setColor(
                  textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 태그 뷰 선택 모드 취소 바 - 도넛 차트 하단, 스크롤 시 앱바에 고정
class UtxoTagSelectionBarDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final int selectedCount;
  final int selectedTotalSats;
  final BitcoinUnit currentUnit;
  final VoidCallback onExitSelectionMode;

  UtxoTagSelectionBarDelegate({
    required this.height,
    required this.selectedCount,
    required this.selectedTotalSats,
    required this.currentUnit,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
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
                    '$selectedCount coins • ${formatUtxoAmountForDisplay(selectedTotalSats, currentUnit)}',
                    style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white),
                    textScaler: const TextScaler.linear(1.0),
                  ),
                ],
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onExitSelectionMode,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: CoconutColors.gray150, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/svg/close.svg',
                          width: 16,
                          height: 16,
                          colorFilter: const ColorFilter.mode(CoconutColors.black, BlendMode.srcIn),
                        ),
                        const SizedBox(width: 2),
                        Text(t.cancel, style: CoconutTypography.caption_10_Bold.setColor(CoconutColors.black)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant UtxoTagSelectionBarDelegate oldDelegate) =>
      height != oldDelegate.height ||
      selectedCount != oldDelegate.selectedCount ||
      selectedTotalSats != oldDelegate.selectedTotalSats ||
      currentUnit != oldDelegate.currentUnit;
}

class UtxoSelectionBarButton extends StatelessWidget {
  static const double height = 36;

  final String iconPath;
  final String label;
  final VoidCallback onTap;

  const UtxoSelectionBarButton({super.key, required this.iconPath, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: height,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                iconPath,
                width: 20,
                height: 20,
                colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
              ),
              const SizedBox(width: 8),
              Text(label, style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
