import 'dart:ui';

import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';

class WalletItemCard extends StatelessWidget {
  final int id;
  final int? balance;
  final String name;
  final int iconIndex;
  final int colorIndex;
  final bool isLastItem;
  final bool isBalanceHidden;
  final List<MultisigSigner>? signers;

  const WalletItemCard({
    super.key,
    required this.id,
    required this.balance,
    required this.name,
    required this.iconIndex,
    required this.colorIndex,
    required this.isLastItem,
    this.isBalanceHidden = false,
    this.signers,
  });

  @override
  Widget build(BuildContext context) {
    final row = ShrinkAnimationButton(
        onPressed: () {
          Navigator.pushNamed(context, '/wallet-detail', arguments: {'id': id});
        },
        borderGradientColors: signers?.isNotEmpty == true
            ? CustomColorHelper.getGradientColors(signers!)
            : null,
        child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BackgroundColorPalette[colorIndex],
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: SvgPicture.asset(CustomIcons.getPathByIndex(iconIndex),
                      colorFilter: ColorFilter.mode(
                          ColorPalette[colorIndex], BlendMode.srcIn),
                      width: 20.0)),
              const SizedBox(width: 8.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12.0,
                          fontWeight: FontWeight.w400,
                          color: MyColors.transparentWhite_70,
                          letterSpacing: 0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Padding(
                        padding: const EdgeInsets.only(top: 0),
                        child: ImageFiltered(
                          imageFilter: isBalanceHidden
                              ? ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0)
                              : ImageFilter.blur(sigmaX: 0),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  balance != null
                                      ? satoshiToBitcoinString(balance!)
                                      : '0',
                                  style: Styles.h3Number,
                                ),
                                const Text(" BTC", style: Styles.unitSmall),
                              ]),
                        )),
                  ],
                ),
              ),
            ])));

    if (isLastItem) {
      return row;
    }

    return Column(
      children: [
        row,
        const SizedBox(
          height: 10,
        )
      ],
    );
  }
}
