import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:coconut_wallet/widgets/features/transaction/icon/pending_transaction_lottie_icon.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

/// utxo_list_screen에서 사용
/// [isSelectionMode]가 true면 체크 아이콘이 나타남
class UtxoListItemCard extends StatelessWidget {
  final UtxoState utxo;
  final Function onPressed;
  final VoidCallback? onLongPress;
  final BitcoinUnit currentUnit;
  final bool isSelected;
  final bool isSelectionMode;

  const UtxoListItemCard({
    super.key,
    required this.utxo,
    required this.onPressed,
    this.onLongPress,
    required this.currentUnit,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final dateString = DateTimeUtil.formatTimestamp(utxo.timestamp);
    final colors = context.coconutColors;
    const chipMinWidth = 40.0;
    const chipLabelSize = 10.0;

    return ShrinkAnimationButton(
      borderWidth: 0,
      borderRadius: CoconutStyles.radius_300,
      defaultColor: colors.surface,
      pressedOverlayColor: colors.surfacePressOverlay,
      pressedOverlayOpacity: colors.surfacePressOverlayOpacity,
      onPressed: () {
        onPressed();
      },
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color:
                isSelectionMode
                    ? (isSelected ? colors.borderStrong : colors.borderStrong.withAlpha(40))
                    : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(CoconutStyles.radius_300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: Alignment.centerLeft,
                  child:
                      isSelectionMode
                          ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: SvgPicture.asset(
                                  CommonFormIconPath.circleCheck,
                                  width: 20,
                                  height: 20,
                                  colorFilter: ColorFilter.mode(
                                    isSelected
                                        ? context.coconutColors.borderStrong
                                        : context.coconutColors.borderStrong.withAlpha(40),
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                              CoconutLayout.spacing_100w,
                            ],
                          )
                          : const SizedBox.shrink(),
                ),
                // data string
                Row(
                  children: [
                    Text(dateString[0], style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText)),
                    CoconutLayout.spacing_200w,
                    Text('|', style: CoconutTypography.caption_10.setColor(colors.secondaryText)),
                    CoconutLayout.spacing_200w,
                    Text(dateString[1], style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText)),
                  ],
                ),
                CoconutLayout.spacing_200w,
                // amount
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (utxo.isPending) ...[
                          _buildPendingStatus(context, utxo.status),
                          const SizedBox(width: 4),
                        ] else if (utxo.status == UtxoStatus.locked) ...[
                          SvgPicture.asset(
                            CommonSecurityIconPath.lock,
                            width: 16,
                            height: 16,
                            colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          currentUnit.displayBitcoinAmount(utxo.amount),
                          style: CoconutTypography.heading4_18_NumberBold.setColor(context.coconutColors.primaryText),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            CoconutLayout.spacing_100h,
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // address
                Expanded(
                  child: Text(
                    utxo.to,
                    style: CoconutTypography.body2_14_Number.setColor(colors.secondaryText).copyWith(height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                if ((utxo.tags?.isNotEmpty ?? false) || utxo.isChange)
                  CoconutLayout.spacing_150h, // utxo.tags가 있거나 잔돈일때만 마진 추가
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: List.generate((utxo.tags?.length ?? 0) + 1, (index) {
                          if (index == 0) {
                            if (utxo.isChange) {
                              return IntrinsicWidth(
                                child: CoconutChip(
                                  minWidth: chipMinWidth,
                                  color: colors.surfaceInfoChip,
                                  borderColor: colors.surfaceInfoChip,
                                  label: t.change,
                                  labelSize: chipLabelSize,
                                  labelColor: colors.primaryText,
                                ),
                              );
                            } else {
                              return Container();
                            }
                          }
                          final colorIndex = WalletVisualStyleUtil.normalizePaletteIndex(
                            utxo.tags?[index - 1].colorIndex ?? 0,
                          );
                          Color foregroundColor = tagColorPalette[colorIndex];
                          return IntrinsicWidth(
                            child: CoconutChip(
                              minWidth: chipMinWidth,
                              color: CoconutColors.backgroundColorPaletteDark[utxo.tags?[index - 1].colorIndex ?? 0],
                              borderColor: foregroundColor,
                              label: '#${utxo.tags?[index - 1].name ?? ''}',
                              labelSize: chipLabelSize,
                              labelColor: foregroundColor,
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingStatus(BuildContext context, UtxoStatus status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PendingTransactionLottieIcon(isIncoming: status == UtxoStatus.incoming, size: 16, fit: BoxFit.none),
        CoconutLayout.spacing_100w,
      ],
    );
  }
}
