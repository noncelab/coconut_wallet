import 'package:coconut_design_system/coconut_design_system.dart';
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

  const WalletIconSmall({
    super.key,
    required this.walletImportSource,
    this.colorIndex = 0,
    this.iconIndex = 0,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    var isExternalWallet = walletImportSource != WalletImportSource.coconutVault;

    return Container(
      width: 30,
      height: 30,
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
        decoration: BoxDecoration(color: CoconutColors.gray800, borderRadius: BorderRadius.circular(8)),
        child: Stack(
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              decoration: BoxDecoration(
                color: isExternalWallet ? CoconutColors.gray700 : CoconutColors.backgroundColorPaletteLight[colorIndex],
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
                        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                      )
                      : SvgPicture.asset(
                        CustomIcons.getPathByIndex(iconIndex),
                        colorFilter: ColorFilter.mode(ColorUtil.getColor(colorIndex).color, BlendMode.srcIn),
                        width: 18.0,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
