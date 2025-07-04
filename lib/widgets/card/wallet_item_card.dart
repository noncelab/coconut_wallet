import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/screens/home/wallet_item_setting_bottom_sheet.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/icon/wallet_item_icon.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
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
  final int? fakeBalance;
  final List<MultisigSigner>? signers;
  final WalletImportSource walletImportSource;
  final BitcoinUnit currentUnit;
  final Color? backgroundColor;
  final Color? pressedColor;
  final bool? isPrimaryWallet;
  final bool? isExcludeFromTotalAmount;
  final bool isEditMode;
  final bool isStarred;
  final ValueChanged<(bool, int)>? onPrimaryWalletChanged;

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
    this.fakeBalance,
    this.signers,
    this.walletImportSource = WalletImportSource.coconutVault,
    this.backgroundColor,
    this.pressedColor,
    this.isPrimaryWallet,
    this.isExcludeFromTotalAmount,
    this.isEditMode = false,
    this.isStarred = false,
    this.onPrimaryWalletChanged,
  });

  @override
  Widget build(BuildContext context) {
    final displayFakeBalance = fakeBalance != null
        ? currentUnit == BitcoinUnit.btc
            ? satoshiToBitcoinString(fakeBalance!)
            : addCommasToIntegerPart(fakeBalance!.toDouble())
        : '';
    // final isExternalWallet = walletImportSource != WalletImportSource.coconutVault;

    if (isEditMode) {
      return _buildWalletItemContent(displayFakeBalance, isEditMode: true,
          onPrimaryWalletChanged: (pair) {
        if (isPrimaryWallet != null) {
          onPrimaryWalletChanged?.call(pair);
        }
      });
    }
    final row = ShrinkAnimationButton(
      defaultColor: backgroundColor ?? CoconutColors.gray800,
      pressedColor: pressedColor ?? CoconutColors.gray750,
      borderRadius: 12,
      onPressed: () {
        Navigator.pushNamed(context, '/wallet-detail', arguments: {'id': id});
      },
      onLongPressed: () {
        vibrateExtraLight();
        CommonBottomSheets.showBottomSheet(
            title: '',
            titlePadding: EdgeInsets.zero,
            context: context,
            child: const WalletItemSettingBottomSheet());
      },
      // ** gradient 사용안할수도 있음**
      // Coconut Vault에서 가져온 멀티시그 지갑 => 테두리 그라디언트 적용
      // External Wallet에서 가져온 싱글시그 지갑 => 테두리 CoconutColors.gray800
      // Coconut Vault에서 가져온 싱글시그 지갑 => 테두리 없음(배경색과 동일)
      // borderGradientColors: signers?.isNotEmpty == true
      //     ? ColorUtil.getGradientColors(signers!)
      //     : [CoconutColors.gray800, CoconutColors.gray800],
      child: _buildWalletItemContent(displayFakeBalance),
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

  Widget _buildWalletItemContent(String displayFakeBalance,
      {bool isEditMode = false, ValueChanged<(bool, int)>? onPrimaryWalletChanged}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isEditMode ? 8 : 20, vertical: 12),
      child: Row(
        children: [
          if (isEditMode)
            GestureDetector(
              onTap: () => onPrimaryWalletChanged?.call((!isStarred, id)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: SvgPicture.asset(
                  'assets/svg/${isStarred ? 'star-filled' : 'star-outlined'}.svg',
                ),
              ),
            ),
          WalletItemIcon(
              walletImportSource: walletImportSource, iconIndex: iconIndex, colorIndex: colorIndex),
          CoconutLayout.spacing_200w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isBalanceHidden
                    ? fakeBalance != null
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
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
                          ],
                        ),
                      ),
                Row(
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        name,
                        style: CoconutTypography.body3_12.setColor(CoconutColors.gray500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPrimaryWallet == true)
                      Text(
                        ' • ${t.wallet_list.primary_wallet}',
                        style: CoconutTypography.body3_12.setColor(CoconutColors.gray500),
                      ),
                    if (isExcludeFromTotalAmount == true)
                      Text(
                        isPrimaryWallet == true
                            ? ' | ${t.wallet_list.exclude_from_total_amount}'
                            : ' • ${t.wallet_list.exclude_from_total_amount}',
                        style: CoconutTypography.body3_12.setColor(CoconutColors.gray500),
                      ),
                  ],
                ),
              ],
            ),
          ),
          CoconutLayout.spacing_200w,
          isEditMode
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SvgPicture.asset(
                    'assets/svg/hamburger.svg',
                  ),
                )
              : SvgPicture.asset(
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
    );
  }
}
