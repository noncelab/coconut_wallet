import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_icon_small.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter_svg/svg.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_caution_widgets.dart';

class WalletItemCard extends StatelessWidget {
  final WalletItemBase walletItem;
  final AnimatedBalanceData animatedBalanceData;
  final bool isLastItem;
  final bool shrinkContentOnly;
  final bool isBalanceHidden;
  final int? fakeBalance;
  final BitcoinUnit currentUnit;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? contentPadding;
  final Color? pressedOverlayColor;
  final double? pressedOverlayOpacity;
  final bool? isExcludeFromTotalBalance;
  final bool shouldWarnUnbackedHotWallet;
  final bool isEditMode;
  final bool isFavorite;
  final bool isStarVisible;
  final ValueChanged<(bool, int)>? onTapStar;
  final int? index;
  final VoidCallback? onLongPressed;
  final Widget rightWidget;

  /// Lays [rightWidget] under the identity row at the full content width.
  /// Default keeps the trailing slot on the identity row.
  final bool placeTrailingBelow;
  final VoidCallback onPressed;
  final int? watchedAddressCount;

  const WalletItemCard({
    super.key,
    required this.walletItem,
    required this.animatedBalanceData,
    required this.currentUnit,
    required this.isLastItem,
    this.isBalanceHidden = false,
    this.shrinkContentOnly = false,
    this.fakeBalance,
    this.backgroundColor,
    this.contentPadding,
    this.pressedOverlayColor,
    this.pressedOverlayOpacity,
    this.shouldWarnUnbackedHotWallet = false,
    this.isExcludeFromTotalBalance,
    this.isEditMode = false,
    this.isFavorite = false,
    this.isStarVisible = true,
    this.onTapStar,
    this.index,
    this.onLongPressed,
    required this.rightWidget,
    this.placeTrailingBelow = false,
    required this.onPressed,
    this.watchedAddressCount,
  });

  @override
  Widget build(BuildContext context) {
    List<Color>? iconGradientColors;
    if (walletItem.walletType == WalletType.multiSignature) {
      final signers = (walletItem as MultisigWalletItem).signers;
      iconGradientColors = WalletVisualStyleUtil.getGradientColors(signers);
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
          onTapStar?.call(pair);
        },
        index: index,
        iconGradientColors: iconGradientColors,
      );
    }
    final row = ShrinkAnimationButton(
      shrinkContentOnly: shrinkContentOnly,
      defaultColor: backgroundColor ?? colors.surface,
      pressedOverlayColor: pressedOverlayColor ?? colors.surfacePressOverlay,
      pressedOverlayOpacity: pressedOverlayOpacity ?? colors.surfacePressOverlayOpacity,
      borderRadius: 12,
      onPressed: onPressed,
      onLongPress: onLongPressed,
      child: _buildWalletItemContent(
        context,
        displayedFakeBalance,
        onTapStar: onTapStar,
        iconGradientColors: iconGradientColors,
      ),
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
      if (isExcludeFromTotalBalance == true) t.wallet_list.exclude_from_total_amount,
    ];
    final hasStarButton = isStarVisible && onTapStar != null;

    final row = Row(
      children: [
        if (hasStarButton)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              onTapStar((!isFavorite, walletItem.id));
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SvgPicture.asset(
                isFavorite ? CommonStateIconPath.starFilled : CommonStateIconPath.starOutlined,
                colorFilter: ColorFilter.mode(context.coconutColors.primary, BlendMode.srcIn),
              ),
            ),
          ),
        WalletIconSmall(
          walletImportSource: walletItem.walletImportSource,
          iconIndex: walletItem.iconIndex,
          colorIndex: walletItem.colorIndex,
          gradientColors: iconGradientColors,
          isHotWallet: walletItem.hasLocalKey,
          badgeBorderColor: backgroundColor,
        ),
        CoconutLayout.spacing_200w,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (placeTrailingBelow)
                _readableBalance(context, displayFakeBalance)
              else
                isBalanceHidden
                    ? Text(
                      t.view_balance,
                      style: CoconutTypography.body2_14_Bold.copyWith(color: context.coconutColors.mutedText),
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
                              style: CoconutTypography.body2_14_NumberBold.setColor(
                                shouldWarnUnbackedHotWallet
                                    ? context.coconutColors.danger
                                    : context.coconutColors.primaryText,
                              ),
                            ),
                            CoconutLayout.spacing_50w,
                          ],
                          Text(
                            displayFakeBalance,
                            style: CoconutTypography.body2_14_NumberBold.setColor(
                              shouldWarnUnbackedHotWallet
                                  ? context.coconutColors.danger
                                  : context.coconutColors.primaryText,
                            ),
                          ),
                          if (!currentUnit.isPrefixSymbol) ...[
                            Text(
                              " ${currentUnit.symbol}",
                              style: CoconutTypography.body2_14_NumberBold.setColor(
                                shouldWarnUnbackedHotWallet
                                    ? context.coconutColors.danger
                                    : context.coconutColors.primaryText,
                              ),
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
                              style: CoconutTypography.body2_14_NumberBold.setColor(
                                shouldWarnUnbackedHotWallet
                                    ? context.coconutColors.danger
                                    : context.coconutColors.primaryText,
                              ),
                            ),
                            CoconutLayout.spacing_50w,
                          ],
                          AnimatedBalance(
                            prevValue: animatedBalanceData.previous,
                            value: animatedBalanceData.current,
                            currentUnit: currentUnit,
                            textStyle: CoconutTypography.body2_14_NumberBold.setColor(
                              shouldWarnUnbackedHotWallet
                                  ? context.coconutColors.danger
                                  : context.coconutColors.primaryText,
                            ),
                          ),
                          if (!currentUnit.isPrefixSymbol) ...[
                            CoconutLayout.spacing_50w,
                            Text(
                              currentUnit.symbol,
                              style: CoconutTypography.body2_14_NumberBold.setColor(
                                shouldWarnUnbackedHotWallet
                                    ? context.coconutColors.danger
                                    : context.coconutColors.primaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
              if (placeTrailingBelow)
                Text(
                  walletDescriptionParts.join(' • '),
                  style: CoconutTypography.body3_12.setColor(
                    shouldWarnUnbackedHotWallet == true
                        ? context.coconutColors.danger
                        : context.coconutColors.secondaryText,
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          walletDescriptionParts.join(' • '),
                          style: CoconutTypography.body3_12.setColor(
                            shouldWarnUnbackedHotWallet == true
                                ? context.coconutColors.danger
                                : context.coconutColors.secondaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              SafetyCautionBadge(walletId: walletItem.id, margin: const EdgeInsets.only(top: 4)),
            ],
          ),
        ),
        if (!placeTrailingBelow) ...[
          CoconutLayout.spacing_200w,
          isEditMode
              ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (shouldWarnUnbackedHotWallet) ...[
                    SvgPicture.asset(
                      CommonStateIconPath.triangleWarning,
                      colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
                    ),
                    CoconutLayout.spacing_200w,
                  ],
                  ReorderableDragStartListener(
                    index: index!,
                    child: GestureDetector(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SvgPicture.asset(
                          CommonMenuIconPath.hamburger,
                          colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ],
              )
              : shouldWarnUnbackedHotWallet
              ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    CommonStateIconPath.triangleWarning,
                    colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
                  ),
                  CoconutLayout.spacing_200w,
                  rightWidget,
                ],
              )
              : rightWidget,
        ],
      ],
    );
    return Container(
      padding: contentPadding ?? EdgeInsets.fromLTRB(hasStarButton ? 0 : 20, 12, isEditMode ? 8 : 20, 12),
      child:
          placeTrailingBelow
              ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [row, const SizedBox(height: 8), _belowCues(context, editing: isEditMode, index: index)],
              )
              : row,
    );
  }

  /// Full-size balance. Used only when the trailing slot moves below, so a long
  /// amount wraps instead of scaling down inside a few pixels.
  Widget _readableBalance(BuildContext context, String displayFakeBalance) {
    if (isBalanceHidden) {
      return Text(
        t.view_balance,
        style: CoconutTypography.body2_14_Bold.copyWith(color: context.coconutColors.mutedText),
      );
    }
    final style = CoconutTypography.body2_14_NumberBold.setColor(
      shouldWarnUnbackedHotWallet ? context.coconutColors.danger : context.coconutColors.primaryText,
    );
    if (fakeBalance != null) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (currentUnit.isPrefixSymbol) ...[Text(currentUnit.symbol, style: style), CoconutLayout.spacing_50w],
          Text(displayFakeBalance, style: style),
          if (!currentUnit.isPrefixSymbol) ...[Text(' ${currentUnit.symbol}', style: style), CoconutLayout.spacing_50w],
        ],
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (currentUnit.isPrefixSymbol) ...[Text(currentUnit.symbol, style: style), CoconutLayout.spacing_50w],
        AnimatedBalance(
          prevValue: animatedBalanceData.previous,
          value: animatedBalanceData.current,
          currentUnit: currentUnit,
          textStyle: style,
        ),
        if (!currentUnit.isPrefixSymbol) ...[CoconutLayout.spacing_50w, Text(currentUnit.symbol, style: style)],
      ],
    );
  }

  Widget _belowCues(BuildContext context, {required bool editing, required int? index}) {
    final warning = SvgPicture.asset(
      CommonStateIconPath.triangleWarning,
      colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
    );
    if (editing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (shouldWarnUnbackedHotWallet) ...[warning, CoconutLayout.spacing_200w],
          ReorderableDragStartListener(
            index: index!,
            child: GestureDetector(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SvgPicture.asset(
                  CommonMenuIconPath.hamburger,
                  colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (shouldWarnUnbackedHotWallet) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [warning, CoconutLayout.spacing_200w, Expanded(child: rightWidget)],
      );
    }
    return rightWidget;
  }
}
