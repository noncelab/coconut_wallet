import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:flutter/cupertino.dart';

class FeeSelectionItemCard extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isSelected;
  final bool isLoading;
  final FeeInfoWithLevel feeInfo;
  final BitcoinUnit currentUnit;

  const FeeSelectionItemCard({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.isSelected = false,
    required this.feeInfo,
    required this.currentUnit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? CoconutColors.white : CoconutColors.gray700,
          ),
          borderRadius: BorderRadius.circular(24),
          color: CoconutColors.gray900),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        onPressed: feeInfo.satsPerVb == null || feeInfo.estimatedFee == null ? null : onPressed,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  feeInfo.level.text,
                  style: feeInfo.estimatedFee == null
                      ? CoconutTypography.body1_16_Bold.setColor(CoconutColors.gray500)
                      : CoconutTypography.body1_16.setColor(CoconutColors.white),
                ),
                CoconutLayout.spacing_50h,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray400),
                        children: [
                          TextSpan(
                            text: feeInfo.level.expectedTime,
                          ),
                          if (feeInfo.satsPerVb != null)
                            TextSpan(
                              text:
                                  " (${feeInfo.satsPerVb?.toInt()} ${feeInfo.satsPerVb == 1 ? 'sat' : 'sats'}/vb)",
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
            if (feeInfo.estimatedFee != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // TODO 수량 위젯
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          currentUnit.displayBitcoinAmount(feeInfo.estimatedFee),
                          style: CoconutTypography.body1_16_Number.setColor(CoconutColors.white),
                        ),
                        Text(" ${currentUnit.symbol}",
                            style:
                                CoconutTypography.body2_14_Number.setColor(CoconutColors.gray400)),
                      ],
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    FiatPrice(
                        satoshiAmount: feeInfo.estimatedFee ?? 0,
                        textStyle:
                            CoconutTypography.body3_12_Number.setColor(CoconutColors.gray400)),
                  ],
                ),
              ),
            if (feeInfo.failedEstimation)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      t.fetch_fee_failed,
                      style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
