import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// 멀티시그 지갑 Border gradient 효과는 wallet_icon_small에만 적용
class WalletIcon extends StatelessWidget {
  final WalletImportSource? walletImportSource;
  final int colorIndex;
  final int iconIndex;
  final bool isInnerWallet;
  final bool isHotWallet;
  final String? badgeSvgAssetPath;
  final Color? badgeColor;
  final double badgeSize;
  final double badgeRight;
  final double badgeBottom;

  const WalletIcon({
    super.key,
    this.walletImportSource,
    this.colorIndex = 0,
    this.iconIndex = 0,
    this.isInnerWallet = true,
    this.isHotWallet = false,
    this.badgeSvgAssetPath,
    this.badgeColor,
    this.badgeSize = 18,
    this.badgeRight = -1,
    this.badgeBottom = -0.5,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _buildIcon(context);
    final resolvedBadgeSvgAssetPath = badgeSvgAssetPath ?? (isHotWallet ? 'assets/svg/hot-wallet-fire.svg' : null);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        if (resolvedBadgeSvgAssetPath != null)
          Positioned(right: badgeRight, bottom: badgeBottom, child: _buildBadge(context, resolvedBadgeSvgAssetPath)),
      ],
    );
  }

  Widget _buildIcon(BuildContext context) {
    if (walletImportSource == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: context.coconutColors.iconBackground, borderRadius: BorderRadius.circular(12)),
        child: SvgPicture.asset(
          'assets/svg/puzzle-piece.svg',
          colorFilter: ColorFilter.mode(context.coconutColors.iconSubDefault, BlendMode.srcIn),
          width: 18.0,
        ),
      );
    }
    final isExternalWallet = !isInnerWallet;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isExternalWallet ? context.coconutColors.iconBackground : ColorUtil.getColor(colorIndex).backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child:
          isExternalWallet
              ? SvgPicture.asset(
                walletImportSource!.externalWalletIconPath,
                colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                width: 18.0,
                height: 18.0,
              )
              : SvgPicture.asset(
                CustomIcons.getPathByIndex(iconIndex),
                colorFilter: ColorFilter.mode(ColorUtil.getColor(colorIndex).color, BlendMode.srcIn),
                width: 18.0,
              ),
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
