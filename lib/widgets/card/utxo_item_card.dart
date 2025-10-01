import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';

class UtxoItemCard extends StatelessWidget {
  final UtxoState utxo;
  final Function onPressed;
  final BitcoinUnit currentUnit;
  final bool isSelected;
  final bool settingLock;

  const UtxoItemCard({
    super.key,
    required this.utxo,
    required this.onPressed,
    required this.currentUnit,
    this.isSelected = false,
    this.settingLock = false
  });

  @override
  Widget build(BuildContext context) {
    final dateString = DateTimeUtil.formatTimestamp(utxo.timestamp);

    return ShrinkAnimationButton(
      defaultColor: CoconutColors.gray900,
      pressedColor: CoconutColors.gray800,
      borderRadius: CoconutStyles.radius_300,
      borderWidth: 0,
      onPressed: () {
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // data string
                Row(
                  children: [
                    Text(
                      dateString[0],
                      style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray350),
                    ),
                    CoconutLayout.spacing_200w,
                    Text(
                      '|',
                      style: CoconutTypography.caption_10.setColor(CoconutColors.gray350),
                    ),
                    CoconutLayout.spacing_200w,
                    Text(
                      dateString[1],
                      style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray350),
                    ),
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
                          _buildPendingStatus(utxo.status),
                          SizedBox(width: 4),
                        ] else if (utxo.status == UtxoStatus.locked) ...[
                          SvgPicture.asset('assets/svg/lock.svg'),
                          SizedBox(width: 4),
                        ],
                        Text(
                          currentUnit.displayBitcoinAmount(utxo.amount),
                          style: CoconutTypography.heading4_18_NumberBold
                              .setColor(CoconutColors.white),
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
                    style: CoconutTypography.body2_14_Number
                        .setColor(CoconutColors.gray350)
                        .copyWith(height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                if ((utxo.tags?.isNotEmpty ?? false) || utxo.isChange)
                  CoconutLayout.spacing_100h, // utxo.tags가 있거나 잔돈일때만 마진 추가
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: List.generate(
                          (utxo.tags?.length ?? 0) + 1,
                          (index) {
                            if (index == 0) {
                              if (utxo.isChange) {
                                return IntrinsicWidth(
                                  child: CoconutChip(
                                    minWidth: 40,
                                    color: CoconutColors.gray800,
                                    borderColor: CoconutColors.gray800,
                                    label: t.change,
                                    labelSize: 12,
                                    labelColor: CoconutColors.white,
                                  ),
                                );
                              } else {
                                return Container();
                              }
                            }
                            Color foregroundColor =
                                tagColorPalette[utxo.tags?[index - 1].colorIndex ?? 0];
                            return IntrinsicWidth(
                              child: CoconutChip(
                                minWidth: 40,
                                color: CoconutColors
                                    .backgroundColorPaletteDark[utxo.tags?[index - 1].colorIndex ?? 0],
                                borderColor: foregroundColor,
                                label: '#${utxo.tags?[index - 1].name ?? ''}',
                                labelSize: 12,
                                labelColor: foregroundColor,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // 체크 아이콘
                    if (settingLock)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: SvgPicture.asset(
                          'assets/svg/circle-check.svg',
                          colorFilter: ColorFilter.mode(
                              isSelected ? CoconutColors.primary : MyColors.transparentWhite_40,
                              BlendMode.srcIn),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        )),
    );
  }

  Widget _buildPendingStatus(UtxoStatus status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: status == UtxoStatus.incoming
                ? CoconutColors.cyan.withOpacity(0.2)
                : CoconutColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Lottie.asset(
            status == UtxoStatus.incoming
                ? 'assets/lottie/arrow-down.json'
                : 'assets/lottie/arrow-up.json',
            width: 16,
            height: 16,
          ),
        ),
        CoconutLayout.spacing_100w,
      ],
    );
  }
}
