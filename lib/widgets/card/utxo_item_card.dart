import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/custom_chip.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class UtxoItemCard extends StatelessWidget {
  final UtxoState utxo;
  final Function onPressed;

  const UtxoItemCard({
    super.key,
    required this.utxo,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dateString = DateTimeUtil.formatTimestamp(utxo.timestamp);
    const borderRadius = CoconutStyles.radius_300;

    return ShrinkAnimationButton(
      pressedColor: CoconutColors.gray900,
      borderWidth: 0,
      borderRadius: borderRadius,
      onPressed: () {
        onPressed();
      },
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius), color: CoconutColors.gray800),
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
                        style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray300),
                      ),
                      CoconutLayout.spacing_200w,
                      Text(
                        '|',
                        style: CoconutTypography.caption_10.setColor(CoconutColors.gray400),
                      ),
                      CoconutLayout.spacing_200w,
                      Text(
                        dateString[1],
                        style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray300),
                      ),
                    ],
                  ),
                  // amount
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (utxo.isChange)
                          CustomChip(
                            text: t.change,
                            backgroundColor: CoconutColors.gray500,
                            borderColor: CoconutColors.gray500,
                            textStyle:
                                CoconutTypography.caption_10_Bold.setColor(CoconutColors.black),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          ),
                        CoconutLayout.spacing_100w,
                        if (utxo.isPending) _buildPendingStatus(utxo.status),
                        Text(
                          satoshiToBitcoinString(utxo.amount),
                          style: CoconutTypography.heading4_18_NumberBold
                              .setColor(CoconutColors.gray200),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              CoconutLayout.spacing_100h,
              // address
              Text(utxo.to,
                  style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray400)),
              Column(
                children: [
                  if ((utxo.tags?.isNotEmpty ?? false))
                    CoconutLayout.spacing_100h, // utxo.tags가 있을 때만 마진 추가
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: List.generate(
                      utxo.tags?.length ?? 0,
                      (index) => IntrinsicWidth(
                        child: CoconutChip(
                          minWidth: 40,
                          color: CoconutColors
                              .backgroundColorPaletteDark[utxo.tags?[index].colorIndex ?? 0],
                          borderColor:
                              CoconutColors.colorPalette[utxo.tags?[index].colorIndex ?? 0],
                          label: '#${utxo.tags?[index].name ?? ''}',
                          labelSize: 12,
                          labelColor: CoconutColors.colorPalette[utxo.tags?[index].colorIndex ?? 0],
                        ),
                      ),
                    ),
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
