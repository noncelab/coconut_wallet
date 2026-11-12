import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/common/amount/suction_amount_text.dart';
import 'package:flutter/material.dart';

class VtxoListHeaderDelegate extends SliverPersistentHeaderDelegate {
  const VtxoListHeaderDelegate({
    required this.topPadding,
    required this.totalSats,
    required this.unit,
    required this.onBackPressed,
    required this.onUnitPressed,
    required this.infoButton,
    required this.refreshButton,
    required this.filterBar,
  });

  final double topPadding;
  final int totalSats;
  final BitcoinUnit unit;
  final VoidCallback onBackPressed;
  final VoidCallback onUnitPressed;
  final Widget infoButton;
  final Widget refreshButton;
  final Widget filterBar;

  @override
  double get minExtent => topPadding + 114;

  @override
  double get maxExtent => topPadding + 208;

  double _lerp(double begin, double end, double progress) => begin + (end - begin) * progress;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = context.coconutColors;
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(progress);
    final totalBalance = unit.displayBitcoinAmount(totalSats, withUnit: true);
    final lastSpace = totalBalance.lastIndexOf(' ');
    final amount = lastSpace < 0 ? totalBalance : totalBalance.substring(0, lastSpace);
    final unitText = lastSpace < 0 ? '' : totalBalance.substring(lastSpace + 1);
    final detailOpacity = (1 - progress * 1.8).clamp(0.0, 1.0);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Material(
        color: colors.background,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: topPadding + 4,
              child: FeatureAwareBackButton(onPressed: onBackPressed, color: colors.primaryText),
            ),
            Positioned(right: 4, top: topPadding + 4, child: infoButton),
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
                child: GestureDetector(
                  onTap: onUnitPressed,
                  child: Align(
                    alignment: Alignment(_lerp(-1, 0, eased), 0),
                    child: SuctionAmountText(amount: amount, unit: unitText, progress: progress),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: topPadding + 108,
              child: IgnorePointer(
                ignoring: detailOpacity == 0,
                child: Opacity(
                  opacity: detailOpacity,
                  child: Transform.translate(
                    offset: Offset(0, -6 * eased),
                    child: GestureDetector(onTap: onUnitPressed, child: FiatPrice(satoshiAmount: totalSats)),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: topPadding + 101,
              child: IgnorePointer(
                ignoring: detailOpacity == 0,
                child: Opacity(opacity: detailOpacity, child: refreshButton),
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: filterBar),
            Positioned(
              left: 0,
              right: 0,
              bottom: -24,
              height: 24,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: shrinkOffset >= maxExtent - minExtent - 0.5 ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [colors.background, colors.background.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant VtxoListHeaderDelegate oldDelegate) =>
      totalSats != oldDelegate.totalSats ||
      unit != oldDelegate.unit ||
      topPadding != oldDelegate.topPadding ||
      infoButton != oldDelegate.infoButton ||
      refreshButton != oldDelegate.refreshButton ||
      filterBar != oldDelegate.filterBar;
}
