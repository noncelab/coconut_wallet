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
    final typography = context.coconutTypography;

    return GestureDetector(
      onTap: isActive ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActive ? Colors.transparent : colors.borderSubtle),
          color: isActive ? (isActivePrimaryColor ? colors.primary : colors.primaryText) : colors.surfaceMuted,
        ),
        child: Center(
          child: Text(
            text,
            style: typography.caption.copyWith(
              color: isActive ? colors.background : colors.secondaryText,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
