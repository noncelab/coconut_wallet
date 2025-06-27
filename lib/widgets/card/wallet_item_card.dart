import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/icon/wallet_item_icon.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter_svg/svg.dart';

class WalletItemCard extends StatelessWidget {
  /// External Wallet인 경우 iconIndex = colorIndex = null
  final int id;
  final AnimatedBalanceData animatedBalanceData;
  final String name;
  final int iconIndex;
  final int colorIndex;
  final bool isLastItem;
  final bool isBalanceHidden;
  final int? fakeBlance;
  final List<MultisigSigner>? signers;
  final WalletImportSource walletImportSource;
  final BitcoinUnit currentUnit;

  const WalletItemCard({
    super.key,
    required this.id,
    required this.animatedBalanceData,
    required this.name,
    required this.currentUnit,
    this.iconIndex = 0,
    this.colorIndex = 0,
    required this.isLastItem,
    this.isBalanceHidden = false,
    this.fakeBlance,
    this.signers,
    this.walletImportSource = WalletImportSource.coconutVault,
  });

  @override
  Widget build(BuildContext context) {
    final displayFakeBalance = fakeBlance != null
        ? currentUnit == BitcoinUnit.btc
            ? satoshiToBitcoinString(fakeBlance!)
            : addCommasToIntegerPart(fakeBlance!.toDouble())
        : '';
    // final isExternalWallet = walletImportSource != WalletImportSource.coconutVault;
    final row = ShrinkAnimationButton(
      defaultColor: CoconutColors.gray800,
      pressedColor: CoconutColors.gray750,
      borderRadius: 12,
      onPressed: () {
        Navigator.pushNamed(context, '/wallet-detail', arguments: {'id': id});
      },
      // ** gradient 사용안할수도 있음**
      // Coconut Vault에서 가져온 멀티시그 지갑 => 테두리 그라디언트 적용
      // External Wallet에서 가져온 싱글시그 지갑 => 테두리 CoconutColors.gray800
      // Coconut Vault에서 가져온 싱글시그 지갑 => 테두리 없음(배경색과 동일)
      // borderGradientColors: signers?.isNotEmpty == true
      //     ? ColorUtil.getGradientColors(signers!)
      //     : [CoconutColors.gray800, CoconutColors.gray800],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Row(
          children: [
            WalletItemIcon(
                walletImportSource: walletImportSource,
                iconIndex: iconIndex,
                colorIndex: colorIndex),
            CoconutLayout.spacing_200w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isBalanceHidden
                      ? fakeBlance != null
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    displayFakeBalance,
                                    style: CoconutTypography.body2_14_NumberBold
                                        .setColor(CoconutColors.white),
                                  ),
                                  Text(
                                    " ${currentUnit == BitcoinUnit.btc ? t.btc : t.sats}",
                                    style: CoconutTypography.body2_14_NumberBold
                                        .setColor(CoconutColors.white),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              t.view_balance,
                              style: CoconutTypography.body2_14_Bold
                                  .copyWith(color: CoconutColors.gray600),
                            )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                            AnimatedBalance(
                                prevValue: animatedBalanceData.previous,
                                value: animatedBalanceData.current,
                                isBtcUnit: currentUnit == BitcoinUnit.btc,
                                textStyle: CoconutTypography.body2_14_NumberBold
                                    .setColor(CoconutColors.white)),
                            Text(
                              " ${currentUnit == BitcoinUnit.btc ? t.btc : t.sats}",
                              style: CoconutTypography.body2_14_NumberBold
                                  .setColor(CoconutColors.white),
                            ),
                          ]),
                        ),
                  Text(
                    name,
                    style: CoconutTypography.body3_12.setColor(CoconutColors.gray500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            CoconutLayout.spacing_200w,
            SvgPicture.asset(
              'assets/svg/arrow-right.svg',
              width: 6,
              height: 10,
              colorFilter: const ColorFilter.mode(
                CoconutColors.gray400,
                BlendMode.srcIn,
              ),
            )
          ],
        ),
      ),
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
