import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class TransactionStatusGradientMask extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const TransactionStatusGradientMask({super.key, this.enabled = true, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback:
          (bounds) => LinearGradient(
            colors: [context.coconutColors.sendingColor, context.coconutColors.receivingColor],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(bounds),
      child: child,
    );
  }
}
