import 'package:coconut_wallet/widgets/overlays/error_tooltip.dart';
import 'package:flutter/material.dart';

class UtxoUnexpectedErrorTooltip extends StatelessWidget {
  final bool isShown;
  final String errorMessage;
  final bool animated;

  const UtxoUnexpectedErrorTooltip({
    super.key,
    required this.isShown,
    required this.errorMessage,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    final tooltip =
        isShown
            ? ErrorTooltip(
              key: const ValueKey('unexpected-error-tooltip'),
              isShown: true,
              errorMessage: errorMessage,
            )
            : const SizedBox.shrink(key: ValueKey('unexpected-error-tooltip-empty'));

    if (!animated) return tooltip;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: tooltip,
    );
  }
}
