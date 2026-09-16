import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:flutter/material.dart';

/// 비트코인 금액과 단위 심볼을 배치하는 공통 위젯
/// BIP-177은 심볼이 금액 앞에, BTC/sats는 금액 뒤에 위치
class BitcoinAmountUnit extends StatelessWidget {
  final BitcoinUnit currentUnit;
  final Widget child;
  final TextStyle unitStyle;
  final CrossAxisAlignment? suffixCrossAxisAlignment;
  final Widget? spacing;
  final MainAxisSize mainAxisSize;

  const BitcoinAmountUnit({
    super.key,
    required this.currentUnit,
    required this.child,
    required this.unitStyle,
    this.suffixCrossAxisAlignment,
    this.spacing,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    final symbolWidget = Text(currentUnit.symbol, style: unitStyle);
    final gap = spacing ?? CoconutLayout.spacing_50w;

    return Row(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment:
          currentUnit.isPrefixSymbol
              ? CrossAxisAlignment.center
              : (suffixCrossAxisAlignment ?? CrossAxisAlignment.baseline),
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (currentUnit.isPrefixSymbol) ...[symbolWidget, gap],
        child,
        if (!currentUnit.isPrefixSymbol) ...[gap, symbolWidget],
      ],
    );
  }
}
