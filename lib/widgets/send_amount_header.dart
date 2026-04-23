import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
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
                  unitStyle: Styles.unit,
                  child: Text(amountText, style: Styles.balance1, textAlign: textAlign),
                ),
              ),
            ),
          ),
        ),
        FiatPrice(satoshiAmount: satoshiAmount, textStyle: fiatTextStyle),
        CoconutLayout.spacing_1000h,
        Text(
          t.send_confirm_screen.total_required_amount(
            n: '${unit.isPrefixSymbol ? unit.symbol : ''} $totalCostAmountText ${unit.isPrefixSymbol ? '' : unit.symbol}',
          ),
          style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray400),
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
