import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class RippleEffect extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? borderRadius;

  const RippleEffect({super.key, required this.child, this.borderRadius, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius ?? 0),
        highlightColor: colors.surfacePressOverlay.withValues(alpha: colors.surfacePressOverlayOpacity),
        child: child,
      ),
    );
  }
}
