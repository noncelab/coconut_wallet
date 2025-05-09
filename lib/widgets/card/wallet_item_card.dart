import 'dart:ui';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/icon/wallet_item_icon.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';

class WalletItemCard extends StatelessWidget {
  /// External Wallet인 경우 iconIndex = colorIndex = null
  final int id;
  final AnimatedBalanceData animatedBalanceData;
  final String name;
  final int iconIndex;
  final int colorIndex;
  final bool isLastItem;
  final bool isBalanceHidden;
  final List<MultisigSigner>? signers;
  final WalletImportSource walletImportSource;

  const WalletItemCard({
    super.key,
    required this.id,
    required this.animatedBalanceData,
    required this.name,
    this.iconIndex = 0,
    this.colorIndex = 0,
    required this.isLastItem,
    this.isBalanceHidden = false,
    this.signers,
    this.walletImportSource = WalletImportSource.coconutVault,
  });

  @override
  Widget build(BuildContext context) {
    final isExternalWawllet = walletImportSource != WalletImportSource.coconutVault;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
      child: ShrinkAnimationButton(
          defaultColor: isExternalWawllet ? CoconutColors.gray900 : CoconutColors.gray800,
          onPressed: () {
            Navigator.pushNamed(context, '/wallet-detail', arguments: {'id': id});
          },
          // Coconut Vault에서 가져온 멀티시그 지갑 => 테두리 그라디언트 적용
          // External Wallet에서 가져온 싱글시그 지갑 => 테두리 CoconutColors.gray800
          // Coconut Vault에서 가져온 싱글시그 지갑 => 테두리 없음(배경색과 동일)
          borderGradientColors: signers?.isNotEmpty == true
              ? ColorUtil.getGradientColors(signers!)
              : [CoconutColors.gray800, CoconutColors.gray800],
          pressedColor: isExternalWawllet ? CoconutColors.black : CoconutColors.gray900,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Row(children: [
                WalletItemIcon(
                    walletImportSource: walletImportSource,
                    iconIndex: iconIndex,
                    colorIndex: colorIndex),
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
