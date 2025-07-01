import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FiatPrice extends StatefulWidget {
  const FiatPrice({
    super.key,
    required this.satoshiAmount,
    this.textStyle,
    this.textColor,
  });

  final int satoshiAmount;
  final TextStyle? textStyle;
  final Color? textColor;

  @override
  State<FiatPrice> createState() => _FiatPriceState();
}

class _FiatPriceState extends State<FiatPrice> {
  @override
  Widget build(BuildContext context) {
    return Consumer<PriceProvider>(builder: (context, viewModel, child) {
      final defaultStyle = CoconutTypography.body2_14_Number.copyWith(color: CoconutColors.gray500);
      final appliedStyle =
          widget.textStyle?.copyWith(color: widget.textColor ?? defaultStyle.color) ??
              defaultStyle.copyWith(color: widget.textColor ?? defaultStyle.color);

      return Text(
        viewModel.getFiatPrice(widget.satoshiAmount),
        style: appliedStyle,
      );
    });
  }
}
