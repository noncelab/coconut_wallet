import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:flutter/material.dart';

/// 부호가 붙는 큰 금액. 0이면 부호 없음. 부호는 늘 맨 앞(₿처럼 앞에 붙는 단위보다도 앞), 최근 거래 줄의 "- ₿ 5,020"과 같은 순서
class ArkSignedAmount extends StatelessWidget {
  const ArkSignedAmount({super.key, required this.unit, required this.sats, this.struck = false});

  final BitcoinUnit unit;

  /// 음수면 보낸 금액
  final int sats;
  final bool struck;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final amountStyle = CoconutTypography.heading2_28_NumberBold
        .setColor(colors.primaryText)
        .copyWith(decoration: struck ? TextDecoration.lineThrough : null);
    final unitStyle = CoconutTypography.heading4_18_Number.setColor(colors.primaryText);
    final sign =
        sats < 0
            ? '-'
            : sats > 0
            ? '+'
            : '';
    final amount = unit.displayBitcoinAmount(sats.abs());
    if (!unit.isPrefixSymbol) {
      return BitcoinAmountUnit(
        currentUnit: unit,
        unitStyle: unitStyle,
        spacing: CoconutLayout.spacing_100w,
        child: Text('$sign$amount', style: amountStyle),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sign.isNotEmpty) ...[Text(sign, style: amountStyle), CoconutLayout.spacing_100w],
        BitcoinAmountUnit(
          currentUnit: unit,
          unitStyle: unitStyle,
          spacing: CoconutLayout.spacing_100w,
          child: Text(amount, style: amountStyle),
        ),
      ],
    );
  }
}
