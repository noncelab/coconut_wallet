import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FiatPrice extends StatefulWidget {
  const FiatPrice({super.key, required this.satoshiAmount, this.textStyle, this.textColor, this.sign});

  final int satoshiAmount;

  /// 금액 앞에 붙일 부호(+, -), 거래 금액처럼 방향이 있을 때
  final String? sign;
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

        final defaultStyle = CoconutTypography.body2_14_Number.copyWith(
          color: context.coconutColors.secondaryTextStrong,
        );
        final appliedStyle = (widget.textStyle ?? defaultStyle).copyWith(
          color: widget.textColor ?? widget.textStyle?.color ?? defaultStyle.color,
        );

        try {
          final priceText = priceProvider.getFiatPrice(widget.satoshiAmount);

          // 가격 정보가 없으면 빈 공간으로 표시
          if (priceText.isEmpty) {
            return const SizedBox.shrink();
          }

          final sign = widget.sign;
          return FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(sign == null ? priceText : '$sign $priceText', style: appliedStyle),
          );
        } catch (e) {
          // 오류 발생 시 빈 공간으로 표시
          return const SizedBox.shrink();
        }
      },
    );
  }
}
