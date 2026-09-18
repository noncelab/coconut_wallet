import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:flutter/material.dart';

class SendAmountHeader extends StatelessWidget {
  final String amountText;
  final BitcoinUnit unit;
  final int satoshiAmount;
  final VoidCallback? onTap;
  final TextStyle? fiatTextStyle;
  final double topMargin;
  final TextAlign textAlign;
  final String totalCostAmountText;

  const SendAmountHeader({
    super.key,
    required this.amountText,
    required this.unit,
    required this.satoshiAmount,
    required this.totalCostAmountText,
    this.onTap,
    this.fiatTextStyle,
    this.topMargin = 40,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Container(
          margin: EdgeInsets.only(top: topMargin),
          child: Center(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: BitcoinAmountUnit(
                  currentUnit: unit,
                  unitStyle: CoconutTypography.heading4_18_Number.setColor(context.coconutColors.primaryText),
                  child: Text(
                    amountText,
                    style: CoconutTypography.heading1_32_NumberBold.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: context.coconutColors.primaryText,
                    ),
                    textAlign: textAlign,
                  ),
                ),
              ),
            ),
          ),
        ),
        FiatPrice(
          satoshiAmount: satoshiAmount,
          textStyle: fiatTextStyle,
          textColor: context.coconutColors.secondaryText,
        ),
        CoconutLayout.spacing_1000h,
        Text(
          t.send_confirm_screen.total_required_amount(
            n: '${unit.isPrefixSymbol ? unit.symbol : ''} $totalCostAmountText ${unit.isPrefixSymbol ? '' : unit.symbol}',
          ),
          style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.secondaryText),
          textScaler: const TextScaler.linear(1.0),
        ),
      ],
    );

    if (onTap == null) {
      return content;
    }
    return GestureDetector(onTap: onTap, child: content);
  }
}
