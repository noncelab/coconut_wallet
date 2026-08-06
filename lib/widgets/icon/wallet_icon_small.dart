import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'dart:math' as math;

class WalletIconSmall extends StatelessWidget {
  final WalletImportSource walletImportSource;
  final int colorIndex;
  final int iconIndex;
  final List<Color>? gradientColors;
  final bool isHotWallet;
  final String? badgeSvgAssetPath;
  final Color? badgeColor;
  final double badgeSize;
  final double badgeRight;
  final double badgeBottom;

  const WalletIconSmall({
    super.key,
    required this.walletImportSource,
    this.colorIndex = 0,
    this.iconIndex = 0,
    this.gradientColors,
    this.isHotWallet = false,
    this.badgeSvgAssetPath,
    this.badgeColor,
    this.badgeSize = 18,
    this.badgeRight = -1,
    this.badgeBottom = -0.5,
  });
  @override
  Widget build(BuildContext context) {
    var isExternalWallet = walletImportSource != WalletImportSource.coconutVault;
    final resolvedBadgeSvgAssetPath = badgeSvgAssetPath ?? (isHotWallet ? 'assets/svg/hot-wallet-fire.svg' : null);

    final icon = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient:
            gradientColors != null
                ? LinearGradient(
                  colors: gradientColors!,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  transform: const GradientRotation(math.pi / 10),
                )
                : null,
        border: gradientColors == null ? null : null,
      ),
      child: Container(
        margin: EdgeInsets.all(gradientColors != null ? 1.5 : 0),
        decoration: BoxDecoration(color: context.coconutColors.background, borderRadius: BorderRadius.circular(8)),
        child: Stack(
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                color:
                    isExternalWallet
                        ? context.coconutColors.iconBackground
                        : ColorUtil.getColor(colorIndex).backgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Positioned(
              top: 6,
              left: 6,
              right: 6,
              bottom: 6,
              child:
                  isExternalWallet
                      ? SvgPicture.asset(
                        walletImportSource.externalWalletIconPath,
                        colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                      )
                      : SvgPicture.asset(
                        CustomIcons.getPathByIndex(iconIndex),
                        colorFilter: ColorFilter.mode(ColorUtil.getColor(colorIndex).color, BlendMode.srcIn),
                        //width: 18.0,
                      ),
            ),
          ],
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        if (resolvedBadgeSvgAssetPath != null)
          Positioned(right: badgeRight, bottom: badgeBottom, child: _buildBadge(context, resolvedBadgeSvgAssetPath)),
      ],
    );
  }

  Widget _buildBadge(BuildContext context, String badgeAssetPath) {
    return Container(
      width: badgeSize,
      height: badgeSize,
      padding: EdgeInsets.all(badgeSize * 2 / 9),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.coconutColors.iconBackground,
        border: Border.all(color: context.coconutColors.background),
      ),
      child: SvgPicture.asset(
        badgeAssetPath,
        fit: BoxFit.contain,
        colorFilter: badgeColor == null ? null : ColorFilter.mode(badgeColor!, BlendMode.srcIn),
      ),
    );
  }
}
