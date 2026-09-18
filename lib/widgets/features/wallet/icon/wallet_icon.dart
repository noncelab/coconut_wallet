import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:coconut_wallet/utils/custom_wallet_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

/// 멀티시그 지갑 Border gradient 효과는 wallet_icon_small에만 적용
class WalletIcon extends StatelessWidget {
  final WalletImportSource? walletImportSource;
  final int colorIndex;
  final int iconIndex;
  final bool isInnerWallet;

  const WalletIcon({
    super.key,
    this.walletImportSource,
    this.colorIndex = 0,
    this.iconIndex = 0,
    this.isInnerWallet = true,
  });

  @override
  Widget build(BuildContext context) {
    if (walletImportSource == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: context.coconutColors.iconBackground, borderRadius: BorderRadius.circular(12)),
        child: SvgPicture.asset(
          FeatureSettingsIconPath.puzzlePiece,
          colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
          width: 18.0,
        ),
      );
    }
    final isExternalWallet = !isInnerWallet;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            isExternalWallet
                ? context.coconutColors.iconBackground
                : WalletVisualStyleUtil.getColor(colorIndex).backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child:
          isExternalWallet
              ? SvgPicture.asset(
                walletImportSource!.externalWalletIconPath,
                colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                width: 18.0,
                height: 18.0,
              )
              : SvgPicture.asset(
                CustomWalletIcons.getPathByIndex(iconIndex),
                colorFilter: ColorFilter.mode(WalletVisualStyleUtil.getColor(colorIndex).color, BlendMode.srcIn),
                width: 18.0,
              ),
    );
  }
}
