import 'dart:ui';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';

class WalletItemCard extends StatelessWidget {
  final int id;
  final AnimatedBalanceData animatedBalanceData;
  final String name;
  final int iconIndex;
  final int colorIndex;
  final bool isLastItem;
  final bool isBalanceHidden;
  final List<MultisigSigner>? signers;

  const WalletItemCard({
    super.key,
    required this.id,
    required this.animatedBalanceData,
    required this.name,
    required this.iconIndex,
    required this.colorIndex,
    required this.isLastItem,
    this.isBalanceHidden = false,
    this.signers,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
      child: ShrinkAnimationButton(
          onPressed: () {
            Navigator.pushNamed(context, '/wallet-detail', arguments: {'id': id});
          },
          borderGradientColors:
              signers?.isNotEmpty == true ? CustomColorHelper.getGradientColors(signers!) : null,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: CoconutColors.backgroundColorPaletteDark[colorIndex],
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: SvgPicture.asset(CustomIcons.getPathByIndex(iconIndex),
                        colorFilter: ColorFilter.mode(
                            CoconutColors.colorPalette[colorIndex], BlendMode.srcIn),
                        width: 20.0)),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: CoconutTypography.body3_12.merge(TextStyle(
                            color: CoconutColors.white.withOpacity(0.7), letterSpacing: 0.2)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Padding(
                          padding: const EdgeInsets.only(top: 0),
                          child: ImageFiltered(
                            imageFilter: isBalanceHidden
                                ? ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0)
                                : ImageFilter.blur(sigmaX: 0),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                              AnimatedBalance(
                                prevValue: animatedBalanceData.previous,
                                value: animatedBalanceData.current,
                                isBtcUnit: true,
                                textStyle: CoconutTypography.heading3_21_NumberBold.merge(
                                  const TextStyle(
                                    fontSize: 22,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              Text(
                                " BTC",
                                style: CoconutTypography.body3_12_Number.merge(
                                  TextStyle(
                                      fontSize: 13,
                                      color: CoconutColors.white.withOpacity(0.7),
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ]),
                          )),
                    ],
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                SvgPicture.asset('assets/svg/arrow-right.svg',
                    width: 24,
                    colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn))
              ]))),
    );

    if (isLastItem) {
      return row;
    }

    return Column(
      children: [
        row,
      ],
    );
  }
}
