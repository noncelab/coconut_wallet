import 'dart:ui';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
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
    final isFromCoconutVault = walletImportSource == WalletImportSource.coconutVault;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
      child: ShrinkAnimationButton(
          defaultColor: isFromCoconutVault ? CoconutColors.gray800 : CoconutColors.gray900,
          onPressed: () {
            Navigator.pushNamed(context, '/wallet-detail', arguments: {'id': id});
          },
          // Coconut Vault에서 가져온 멀티시그 지갑 => 테두리 그라디언트 적용
          // External Wallet에서 가져온 싱글시그 지갑 => 테두리 CoconutColors.gray800
          // Coconut Vault에서 가져온 싱글시그 지갑 => 테두리 없음(배경색과 동일)
          borderGradientColors: signers?.isNotEmpty == true
              ? ColorUtil.getGradientColors(signers!)
              : [CoconutColors.gray800, CoconutColors.gray800],
          pressedColor: isFromCoconutVault ? CoconutColors.gray900 : CoconutColors.black,
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(
                    // zpub일 경우에 아이콘 사이즈가 작게 나오기 때문에 minimum 설정
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  decoration: BoxDecoration(
                    color: isFromCoconutVault
                        ? ColorUtil.getColor(colorIndex).backgroundColor
                        : CoconutColors.gray700,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: isFromCoconutVault
                      ? SvgPicture.asset(
                          CustomIcons.getPathByIndex(iconIndex),
                          colorFilter: ColorFilter.mode(
                            ColorUtil.getColor(colorIndex).color,
                            BlendMode.srcIn,
                          ),
                          width: 20.0,
                        )
                      : SvgPicture.asset(
                          _getExternalWalletIconPath(),
                          colorFilter: const ColorFilter.mode(
                            Colors.black,
                            BlendMode.srcIn,
                          ),
                        ),
                ),
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

  String _getExternalWalletIconPath() => walletImportSource == WalletImportSource.keystone
      ? kKeystoneIconPath
      : walletImportSource == WalletImportSource.seedSigner
          ? kSeedSignerIconPath
          : kZpubIconPath;
}
