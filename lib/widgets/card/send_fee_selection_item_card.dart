import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:flutter/cupertino.dart';

class FeeSelectionItemCard extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isSelected;
  final bool isLoading;
  final FeeInfoWithLevel feeInfo;

  const FeeSelectionItemCard({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.isSelected = false,
    required this.feeInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 79,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? MyColors.white : MyColors.grey,
          ),
          borderRadius: MyBorder.defaultRadius,
          color: MyColors.transparentWhite_06),
      child: CupertinoButton(
        padding: Paddings.widgetContainer,
        onPressed: feeInfo.satsPerVb == null || feeInfo.estimatedFee == null
            ? null
            : onPressed,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  feeInfo.level.text,
                  style: feeInfo.estimatedFee == null
                      ? Styles.body1Bold.merge(
                          const TextStyle(color: MyColors.borderLightgrey),
                        )
                      : Styles.body1,
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: Styles.caption, // 동일한 스타일 적용
                        children: [
                          TextSpan(
                            text: feeInfo.level.expectedTime,
                          ),
                          if (feeInfo.satsPerVb != null)
                            TextSpan(
                              text:
                                  " (${feeInfo.satsPerVb} ${feeInfo.satsPerVb == 1 ? 'sat' : 'sats'}/vb)",
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          satoshiToBitcoinString(feeInfo.estimatedFee!),
                          style: Styles.body1Number,
                        ),
                        Text(
                          ' BTC',
                          style: Styles.body2Number.merge(
                            const TextStyle(
                              color: MyColors.transparentWhite_70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    FiatPrice(
                        satoshiAmount: feeInfo.estimatedFee ?? 0,
                        textStyle: CoconutTypography.body3_12_Number
                            .setColor(CoconutColors.gray500)),
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
                      style: Styles.warning,
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
