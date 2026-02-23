import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FiatPrice extends StatefulWidget {
  const FiatPrice({super.key, required this.satoshiAmount, this.textStyle, this.textColor});

  final int satoshiAmount;
  final TextStyle? textStyle;
  final Color? textColor;

  @override
  State<FiatPrice> createState() => _FiatPriceState();
}

class _FiatPriceState extends State<FiatPrice> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<PriceProvider, ConnectivityProvider>(
      builder: (context, priceProvider, connectivityProvider, child) {
        // 네트워크 연결이 없으면 가격 정보를 표시하지 않음
        if (!connectivityProvider.isInternetOn) {
          return const SizedBox.shrink();
        }

        final defaultStyle = CoconutTypography.body2_14_Number.copyWith(color: CoconutColors.gray500);
        final appliedStyle =
            widget.textStyle?.copyWith(color: widget.textColor ?? defaultStyle.color) ??
            defaultStyle.copyWith(color: widget.textColor ?? defaultStyle.color);

        try {
          final priceText = priceProvider.getFiatPrice(widget.satoshiAmount);

          // 가격 정보가 없으면 빈 공간으로 표시
          if (priceText.isEmpty) {
            return const SizedBox.shrink();
          }

          return FittedBox(fit: BoxFit.scaleDown, child: Text(priceText, style: appliedStyle));
        } catch (e) {
          // 오류 발생 시 빈 공간으로 표시
          return const SizedBox.shrink();
        }
      },
    );
  }
}
