import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

/// 트랜잭션 수, UTXO 수, 목표 수량 통계 카드
class WalletInfoStatsSection extends StatelessWidget {
  final int walletId;
  final int transactionCount;
  final int utxoCount;
  final int balanceSats;
  final BitcoinUnit currentUnit;
  final int? targetSats;
  final VoidCallback onEditTargetTap;

  const WalletInfoStatsSection({
    super.key,
    required this.walletId,
    required this.transactionCount,
    required this.utxoCount,
    required this.balanceSats,
    required this.currentUnit,
    this.targetSats,
    required this.onEditTargetTap,
  });

  static const int _maxBtcSats = 2100000000000000; // 21M BTC

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(label: t.wallet_info_screen.transaction, value: '$transactionCount')),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: t.wallet_info_screen.utxo,
                  value: '$utxoCount',
                  onPressed: () => Navigator.pushNamed(context, '/utxo-overview', arguments: {'id': walletId}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TargetQuantityCard(
            balanceSats: balanceSats,
            currentUnit: currentUnit,
            targetSats: targetSats,
            maxSats: _maxBtcSats,
            onPressed: onEditTargetTap,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onPressed;

  const _StatCard({required this.label, required this.value, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final cardContent = Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: BoxDecoration(
        color: onPressed == null ? colors.surfaceCard : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: CoconutTypography.body2_14_Bold.setColor(colors.secondaryText)),
              const SizedBox(width: 4),
              if (onPressed != null)
                Icon(Icons.keyboard_arrow_right_rounded, size: 20, color: colors.iconSubDefault)
              else
                const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(value, style: CoconutTypography.heading3_21_NumberBold.setColor(colors.primaryText)),
          ),
        ],
      ),
    );

    if (onPressed == null) {
      return cardContent;
    }

    return ShrinkAnimationButton(
      onPressed: onPressed!,
      defaultColor: colors.surfaceCard,
      pressedColor: colors.surfacePressed,
      borderRadius: 24,
      child: cardContent,
    );
  }
}

class _TargetQuantityCard extends StatelessWidget {
  final int balanceSats;
  final BitcoinUnit currentUnit;
  final int? targetSats;
  final int maxSats;
  final VoidCallback onPressed;

  const _TargetQuantityCard({
    required this.balanceSats,
    required this.currentUnit,
    this.targetSats,
    required this.maxSats,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTarget = targetSats ?? maxSats;
    final progress = effectiveTarget > 0 ? (balanceSats / effectiveTarget).clamp(0.0, 1.0) : 0.0;
    final percent = _formatProgressPercent(progress);
    final isTargetReached = targetSats != null && progress >= 1.0;

    return ShrinkAnimationButton(
      onPressed: onPressed,
      defaultColor: context.coconutColors.surfaceCard,
      pressedColor: context.coconutColors.surfacePressed,
      borderRadius: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      t.wallet_info_screen.target_quantity,
                      style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.secondaryText),
                    ),
                    const SizedBox(width: 4),
                    SvgPicture.asset(
                      'assets/svg/edit-outlined.svg',
                      width: 12,
                      height: 12,
                      colorFilter: ColorFilter.mode(context.coconutColors.secondaryText, BlendMode.srcIn),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                targetSats == null
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stay humble, stack sats!',
                          style: CoconutTypography.heading4_18_NumberBold.setColor(context.coconutColors.secondaryText),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.wallet_info_screen.target_not_set_secondary,
                          style: CoconutTypography.body3_12.setColor(context.coconutColors.tertiaryText),
                        ),
                      ],
                    )
                    : _buildTargetProgressText(
                      context: context,
                      percent: percent,
                      amountText: currentUnit.displayBitcoinAmount(effectiveTarget, withUnit: false),
                      unitSymbol: currentUnit.symbol,
                      isPrefixUnit: currentUnit.isPrefixSymbol,
                    ),
                if (targetSats != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: context.coconutColors.pageIndicatorActive,
                        inactiveTrackColor: context.coconutColors.pageIndicatorInactive,
                        overlayShape: SliderComponentShape.noOverlay,
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                      ),
                      child: IgnorePointer(child: Slider(value: progress, onChanged: (_) {})),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          if (isTargetReached)
            Positioned(
              top: -10,
              right: 10,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(24)),
                  child: Lottie.asset(
                    'assets/lottie/fireworks.json',
                    width: 140,
                    height: 120,
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTargetProgressText({
    required BuildContext context,
    required String percent,
    required String amountText,
    required String unitSymbol,
    required bool isPrefixUnit,
  }) {
    final whiteStyle = CoconutTypography.heading3_21_Number.setColor(context.coconutColors.primaryText);
    final grayStyle = CoconutTypography.body1_16_Number.setColor(context.coconutColors.secondaryText);

    return RichText(
      text: TextSpan(
        style: whiteStyle,
        children: [
          TextSpan(text: percent, style: whiteStyle),
          TextSpan(text: '%', style: grayStyle),
          TextSpan(text: ' / ', style: whiteStyle),
          if (isPrefixUnit) ...[
            TextSpan(text: '$unitSymbol ', style: grayStyle),
            TextSpan(text: amountText, style: whiteStyle),
          ] else ...[
            TextSpan(text: amountText, style: whiteStyle),
            TextSpan(text: ' $unitSymbol', style: grayStyle),
          ],
        ],
      ),
    );
  }

  String _formatProgressPercent(double progress) {
    final percentValue = progress * 100;
    if (percentValue == percentValue.truncateToDouble()) {
      return percentValue.toStringAsFixed(0);
    }

    var decimalPlaces = 1;
    var formatted = percentValue.toStringAsFixed(decimalPlaces);

    while (decimalPlaces < 16 && _countNonZeroFractionDigits(formatted) < 2) {
      decimalPlaces++;
      formatted = percentValue.toStringAsFixed(decimalPlaces);
    }

    return formatted;
  }

  int _countNonZeroFractionDigits(String value) {
    final dotIndex = value.indexOf('.');
    if (dotIndex < 0 || dotIndex == value.length - 1) {
      return 0;
    }

    var count = 0;
    for (final char in value.substring(dotIndex + 1).split('')) {
      if (char != '0') {
        count++;
      }
    }

    return count;
  }
}
