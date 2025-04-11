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
              signers?.isNotEmpty == true ? ColorUtil.getGradientColors(signers!) : null,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ColorUtil.getColor(colorIndex).backgroundColor,
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: SvgPicture.asset(CustomIcons.getPathByIndex(iconIndex),
                        colorFilter:
                            ColorFilter.mode(ColorUtil.getColor(colorIndex).color, BlendMode.srcIn),
                        width: 20.0)),
                CoconutLayout.spacing_200w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: CoconutTypography.body3_12.setColor(CoconutColors.gray500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      CoconutLayout.spacing_50h,
                      ImageFiltered(
                        imageFilter: isBalanceHidden
                            ? ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0)
                            : ImageFilter.blur(sigmaX: 0),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          AnimatedBalance(
                              prevValue: animatedBalanceData.previous,
                              value: animatedBalanceData.current,
                              isBtcUnit: true,
                              textStyle: CoconutTypography.heading3_21_NumberBold
                                  .setColor(CoconutColors.white)),
                          Text(
                            " BTC",
                            style: CoconutTypography.body3_12_Number.copyWith(
                                color: CoconutColors.gray500, fontWeight: FontWeight.w500),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
                CoconutLayout.spacing_200w,
                // SvgPicture.asset('assets/svg/arrow-right.svg',
                //     width: 24,
                //     colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn))
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
