import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

class SelectableUtxoItemCard extends StatelessWidget {
  final UtxoState utxo;
  final bool isSelectable;
  final bool isSelected;
  final List<UtxoTag>? utxoTags;
  final Function(UtxoState) onSelected;
  final BitcoinUnit currentUnit;

  const SelectableUtxoItemCard({
    super.key,
    required this.isSelectable,
    required this.utxo,
    required this.isSelected,
    required this.onSelected,
    required this.currentUnit,
    this.utxoTags,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final dateString = DateTimeUtil.formatTimestamp(utxo.timestamp);
    // utxo_item_card.dart의 태그 칩 크기와 통일한다.
    const chipMinWidth = 40.0;
    const chipLabelSize = 10.0;
    final indicatorColor = isSelected ? colors.borderStrong : colors.borderStrong.withAlpha(40);

    return ShrinkAnimationButton(
      isActive: isSelectable,
      onPressed: () => onSelected(utxo),
      defaultColor: colors.surface,
      pressedOverlayColor: colors.surfacePressOverlay,
      pressedOverlayOpacity: colors.surfacePressOverlayOpacity,
      borderRadius: 20,
      borderWidth: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(width: 1, color: indicatorColor),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        currentUnit.displayBitcoinAmount(utxo.amount),
                        style: CoconutTypography.heading4_18_NumberBold.setColor(colors.primaryText),
                      ),
                      CoconutLayout.spacing_100w,
                      if (utxo.status == UtxoStatus.incoming)
                        CoconutChip(
                          color: colors.surfaceInfoChip,
                          label: t.status_receiving,
                          labelColor: colors.receivingColor,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                        ),
                    ],
                  ),
                  CoconutLayout.spacing_100h,
                  Row(
                    children: [
                      Text(dateString[0], style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText)),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        color: colors.secondaryText,
                        width: 1,
                        height: 10,
                      ),
                      Text(dateString[1], style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText)),
                    ],
                  ),
                  Visibility(
                    visible: utxoTags?.isNotEmpty == true,
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: List.generate(utxoTags?.length ?? 0, (index) {
                          Color foregroundColor = tagColorPalette[utxoTags?[index].colorIndex ?? 0];
                          return IntrinsicWidth(
                            child: CoconutChip(
                              minWidth: chipMinWidth,
                              color: CoconutColors.backgroundColorPaletteDark[utxoTags?[index].colorIndex ?? 0],
                              borderColor: foregroundColor,
                              label: '#${utxoTags?[index].name ?? ''}',
                              labelSize: chipLabelSize,
                              labelColor: foregroundColor,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              CommonFormIconPath.circleCheck,
              colorFilter: ColorFilter.mode(indicatorColor, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }
}
