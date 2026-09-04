import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

class RenewalUtxoHeaderDelegate extends SliverPersistentHeaderDelegate {
  const RenewalUtxoHeaderDelegate({
    required this.topPadding,
    required this.totalBalance,
    required this.fiatPrice,
    required this.bottomBar,
    required this.isOverviewSelected,
    required this.onBackPressed,
    required this.onTabChanged,
    required this.refreshButton,
  });

  final double topPadding;
  final String totalBalance;
  final String fiatPrice;
  final Widget bottomBar;
  final bool isOverviewSelected;
  final VoidCallback onBackPressed;
  final ValueChanged<int> onTabChanged;
  final Widget refreshButton;

  @override
  double get minExtent => topPadding + 165;

  @override
  double get maxExtent => topPadding + 273;

  double _lerp(double begin, double end, double progress) => begin + (end - begin) * progress;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = context.coconutColors;
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(progress);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final segmentWidth = _lerp(screenWidth / 2, screenWidth - 32, eased);
    final segmentTop = _lerp(topPadding + 160, topPadding + 60, eased);
    final lastSpace = totalBalance.lastIndexOf(' ');
    final amount = lastSpace < 0 ? totalBalance : totalBalance.substring(0, lastSpace);
    final unit = lastSpace < 0 ? '' : totalBalance.substring(lastSpace + 1);

    return Material(
      color: colors.background,
      elevation: overlapsContent && progress > 0.95 ? 1 : 0,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: topPadding + 4,
            child: BackButton(onPressed: onBackPressed, color: colors.primaryText),
          ),
          Positioned(right: 4, top: topPadding + 4, child: refreshButton),
          Positioned(
            left: 16,
            top: topPadding + 58,
            child: Opacity(
              opacity: 1 - eased,
              child: Transform.translate(
                offset: Offset(0, -8 * eased),
                child: Text(
                  t.utxo_list_screen.total_balance,
                  style: CoconutTypography.body2_14_Bold.setColor(colors.secondaryText),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _lerp(topPadding + 77, topPadding + 17, eased),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment(_lerp(-1, 0, eased), 0),
                child: _SuctionAmountText(amount: amount, unit: unit, progress: progress),
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: topPadding + 116,
            child: Opacity(
              opacity: (1 - progress * 1.8).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -6 * eased),
                child: Text(fiatPrice, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
              ),
            ),
          ),
          Positioned(
            top: segmentTop,
            left: (screenWidth - segmentWidth) / 2,
            width: segmentWidth,
            child: _MorphingSegmentedControl(
              isFirstSelected: isOverviewSelected,
              onPressed: onTabChanged,
              horizontalLabelPadding: _lerp(8, 16, eased),
              firstLabel: t.utxo_overview_screen.overview,
              secondLabel: t.utxo_overview_screen.list,
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: bottomBar),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant RenewalUtxoHeaderDelegate oldDelegate) =>
      totalBalance != oldDelegate.totalBalance ||
      fiatPrice != oldDelegate.fiatPrice ||
      bottomBar != oldDelegate.bottomBar ||
      refreshButton != oldDelegate.refreshButton ||
      isOverviewSelected != oldDelegate.isOverviewSelected ||
      topPadding != oldDelegate.topPadding;
}

class _MorphingSegmentedControl extends StatelessWidget {
  const _MorphingSegmentedControl({
    required this.isFirstSelected,
    required this.onPressed,
    required this.horizontalLabelPadding,
    required this.firstLabel,
    required this.secondLabel,
  });

  final bool isFirstSelected;
  final ValueChanged<int> onPressed;
  final double horizontalLabelPadding;
  final String firstLabel;
  final String secondLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.segmentedControlBackground,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              alignment: isFirstSelected ? Alignment.centerLeft : Alignment.centerRight,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.segmentedControlSelected,
                      borderRadius: BorderRadius.circular(CoconutStyles.radius_150),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _buildSegment(context, label: firstLabel, index: 0, isSelected: isFirstSelected),
              _buildSegment(context, label: secondLabel, index: 1, isSelected: !isFirstSelected),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(BuildContext context, {required String label, required int index, required bool isSelected}) {
    final colors = context.coconutColors;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(CoconutStyles.radius_150),
            splashColor: colors.segmentedControlSelected.withValues(alpha: 0.2),
            highlightColor: colors.segmentedControlSelected.withValues(alpha: 0.4),
            onTap: () => onPressed(index),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalLabelPadding, vertical: 10),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: (isSelected ? CoconutTypography.body3_12_Bold : CoconutTypography.body3_12).setColor(
                  isSelected ? colors.segmentedControlSelectedText : colors.segmentedControlUnselectedText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuctionAmountText extends StatelessWidget {
  const _SuctionAmountText({required this.amount, required this.unit, required this.progress});

  final String amount;
  final String unit;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final characters = amount.characters.toList();
    final unitCharacters = unit.characters.toList();
    final totalCharacterCount = characters.length + unitCharacters.length;
    final eased = Curves.easeInOutCubic.transform(progress);

    double characterProgress(int index) {
      if (totalCharacterCount <= 1) return progress;
      final delay = index / (totalCharacterCount - 1) * 0.5;
      return ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ...List.generate(characters.length, (index) {
          final localEased = Curves.easeInOutCubic.transform(characterProgress(index));
          return Transform.translate(
            offset: Offset(0, (eased - localEased) * 36),
            child: Text(
              characters[index],
              style: CoconutTypography.heading2_28_NumberBold
                  .setColor(colors.primaryText)
                  .copyWith(fontSize: 28 - 12 * eased),
            ),
          );
        }),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 1),
          ...List.generate(unitCharacters.length, (index) {
            final localEased = Curves.easeInOutCubic.transform(characterProgress(characters.length + index));
            return Transform.translate(
              offset: Offset(0, (eased - localEased) * 36),
              child: Text(
                unitCharacters[index],
                style: CoconutTypography.heading4_18_Number
                    .setColor(colors.primaryText)
                    .copyWith(fontSize: 18 - 4 * eased, height: 1.6 - 0.2 * eased),
              ),
            );
          }),
        ],
      ],
    );
  }
}
