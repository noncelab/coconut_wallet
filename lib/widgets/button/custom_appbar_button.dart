import 'package:coconut_wallet/ui/coconut/coconut_app_bar_button.dart';
import 'package:flutter/material.dart';

class CustomAppbarButton extends StatelessWidget {
  final bool isActive;
  final bool isActivePrimaryColor;
  final VoidCallback? onPressed;
  final String text;

  const CustomAppbarButton({
    super.key,
    required this.isActive,
    required this.onPressed,
    required this.text,
    this.isActivePrimaryColor = true,
  });

  @override
  Widget build(BuildContext context) {
    return CoconutAppBarButton(
      isActive: isActive,
      onPressed: onPressed,
      text: text,
      isActivePrimaryColor: isActivePrimaryColor,
    );
  }
}
