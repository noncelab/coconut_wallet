import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class PendingTransactionLottieIcon extends StatelessWidget {
  final bool isIncoming;
  final double size;
  final EdgeInsetsGeometry padding;
  final double backgroundAlpha;
  final BoxShape shape;
  final BoxFit fit;
  final bool repeat;

  const PendingTransactionLottieIcon({
    super.key,
    required this.isIncoming,
    this.size = 16,
    this.padding = EdgeInsets.zero,
    this.backgroundAlpha = 0.2,
    this.shape = BoxShape.circle,
    this.fit = BoxFit.none,
    this.repeat = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final iconColor = isIncoming ? colors.receivingColor : colors.sendingColor;

    return Container(
      padding: padding,
      decoration: BoxDecoration(color: iconColor.withValues(alpha: backgroundAlpha), shape: shape),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcATop),
        child: Lottie.asset(
          isIncoming ? TransactionLottiePath.arrowDown : TransactionLottiePath.arrowUp,
          width: size,
          height: size,
          fit: fit,
          repeat: repeat,
        ),
      ),
    );
  }
}
