import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class CoconutAppBarButton extends StatelessWidget {
  final bool isActive;
  final bool isActivePrimaryColor;
  final VoidCallback? onPressed;
  final String text;

  const CoconutAppBarButton({
    super.key,
    required this.isActive,
    required this.onPressed,
    required this.text,
    this.isActivePrimaryColor = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    final enabled = isActive && onPressed != null;
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(kMinInteractiveDimension, kMinInteractiveDimension),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        backgroundColor: enabled ? (isActivePrimaryColor ? colors.primary : colors.primaryText) : colors.surfaceMuted,
        foregroundColor: colors.background,
        disabledForegroundColor: colors.secondaryText,
        overlayColor: colors.surfacePressOverlay,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: enabled ? Colors.transparent : colors.border),
        textStyle: CoconutTypography.body3_12.copyWith(fontWeight: enabled ? FontWeight.bold : FontWeight.normal),
      ),
      child: Text(text),
    );
  }
}
