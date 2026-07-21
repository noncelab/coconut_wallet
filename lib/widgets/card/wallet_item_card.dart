import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/icon/wallet_icon_small.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter_svg/svg.dart';

class WalletItemCard extends StatelessWidget {
  final WalletItemBase walletItem;
  final AnimatedBalanceData animatedBalanceData;
  final bool isLastItem;
  final bool isBalanceHidden;
  final int? fakeBalance;
  final BitcoinUnit currentUnit;
  final Color? backgroundColor;
  final Color? pressedColor;
  final bool? isPrimaryWallet;
  final bool? isExcludeFromTotalBalance;
  final bool isEditMode;
  final bool isFavorite;
  final bool isStarVisible;
  final ValueChanged<(bool, int)>? onTapStar;
  final int? index;
  final VoidCallback? onLongPressed;
  final Widget rightWidget;
  final VoidCallback onPressed;

  const WalletItemCard({
    super.key,
    required this.walletItem,
    required this.animatedBalanceData,
    required this.currentUnit,
    required this.isLastItem,
    this.isBalanceHidden = false,
    this.fakeBalance,
    this.backgroundColor,
    this.pressedColor,
    this.isPrimaryWallet,
    this.isExcludeFromTotalBalance,
    this.isEditMode = false,
    this.isFavorite = false,
    this.isStarVisible = true,
    this.onTapStar,
    this.index,
    this.onLongPressed,
    required this.rightWidget,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    List<Color>? iconGradientColors;
    if (walletItem.walletType == WalletType.multiSignature) {
      final signers = (walletItem as MultisigWalletItem).signers;
      iconGradientColors = ColorUtil.getGradientColors(signers);
    } else if (walletItem.walletType == WalletType.taproot) {
      final taprootStyle = TaprootCardStyle.from(walletItem);
      iconGradientColors = taprootStyle?.iconGradientColors;
    }
    final colors = context.coconutColors;
    final displayedFakeBalance = currentUnit.displayBitcoinAmount(fakeBalance);
    if (isEditMode) {
      return _buildWalletItemContent(
        context,
        displayedFakeBalance,
        isEditMode: true,
        onTapStar: (pair) {
          if (isPrimaryWallet != null) {
            onTapStar?.call(pair);
          }
        },
        index: index,
        iconGradientColors: iconGradientColors,
      );
    }
    final row = ShrinkAnimationButton(
      defaultColor: backgroundColor ?? colors.surfaceCard,
      pressedColor: pressedColor ?? colors.surfacePressed,
      borderRadius: 12,
      onPressed: onPressed,
      onLongPress: onLongPressed,
      child: _buildWalletItemContent(context, displayedFakeBalance, iconGradientColors: iconGradientColors),
    );

    if (isLastItem) {
      return row;
    }

    return Column(children: [row]);
  }

  Widget _buildWalletItemContent(
    BuildContext context,
    String displayFakeBalance, {
    bool isEditMode = false,
    ValueChanged<(bool, int)>? onTapStar,
    List<Color>? iconGradientColors,
    int? index,
  }) {
    final walletDescriptionParts = <String>[
      walletItem.name,
      if (isPrimaryWallet == true) t.wallet_list.primary_wallet,
      if (isExcludeFromTotalBalance == true) t.wallet_list.exclude_from_total_amount,
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isEditMode ? 8 : 20, vertical: 12),
      child: Row(
        children: [
          if (isEditMode)
            Opacity(
              opacity: isStarVisible ? 1 : 0,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (!isStarVisible) return;
                  onTapStar?.call((!isFavorite, walletItem.id));
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SvgPicture.asset(
                    'assets/svg/${isFavorite ? 'star-filled' : 'star-outlined'}.svg',
                    colorFilter: ColorFilter.mode(context.coconutColors.primary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          WalletIconSmall(
            walletImportSource: walletItem.walletImportSource,
            iconIndex: walletItem.iconIndex,
            colorIndex: walletItem.colorIndex,
            gradientColors: iconGradientColors,
          ),
          CoconutLayout.spacing_200w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isBalanceHidden
                    ? Text(
                      t.view_balance,
                      style: CoconutTypography.body2_14_Bold.copyWith(color: context.coconutColors.tertiaryText),
                    )
                    : fakeBalance != null
                    ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (currentUnit.isPrefixSymbol) ...[
                            Text(
                              currentUnit.symbol,
                              style: CoconutTypography.body2_14_NumberBold.setColor(context.coconutColors.primaryText),
                            ),
                            CoconutLayout.spacing_50w,
                          ],
                          Text(
                            displayFakeBalance,
                            style: CoconutTypography.body2_14_NumberBold.setColor(context.coconutColors.primaryText),
                          ),
                          if (!currentUnit.isPrefixSymbol) ...[
                            Text(
                              " ${currentUnit.symbol}",
                              style: CoconutTypography.body2_14_NumberBold.setColor(context.coconutColors.primaryText),
                            ),
                            CoconutLayout.spacing_50w,
                          ],
                        ],
                      ),
                    )
                    : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (currentUnit.isPrefixSymbol) ...[
                            Text(
                              currentUnit.symbol,
                              style: CoconutTypography.body2_14_NumberBold.setColor(context.coconutColors.primaryText),
                            ),
                            CoconutLayout.spacing_50w,
                          ],
                          AnimatedBalance(
                            prevValue: animatedBalanceData.previous,
                            value: animatedBalanceData.current,
                            currentUnit: currentUnit,
                            textStyle: CoconutTypography.body2_14_NumberBold.setColor(
                              context.coconutColors.primaryText,
                            ),
                          ),
                          if (!currentUnit.isPrefixSymbol) ...[
                            CoconutLayout.spacing_50w,
                            Text(
                              currentUnit.symbol,
                              style: CoconutTypography.body2_14_NumberBold.setColor(context.coconutColors.primaryText),
                            ),
                          ],
                        ],
                      ),
                    ),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          walletDescriptionParts.join(' • '),
                          style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          CoconutLayout.spacing_200w,
          isEditMode
              ? ReorderableDragStartListener(
                index: index!,
                child: GestureDetector(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SvgPicture.asset(
                      'assets/svg/hamburger.svg',
                      colorFilter: ColorFilter.mode(context.coconutColors.iconSubDefault, BlendMode.srcIn),
                    ),
                  ),
                ),
              )
              : rightWidget,
        ],
      ),
    );
  }
}
