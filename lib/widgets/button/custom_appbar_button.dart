import 'package:coconut_wallet/styles.dart';
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
    return GestureDetector(
      onTap: isActive ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: isActive ? Colors.transparent : MyColors.transparentWhite_20,
          ),
          color: isActive
              ? (isActivePrimaryColor ? MyColors.primary : MyColors.white)
              : MyColors.grey,
        ),
        child: Center(
          child: Text(
            text,
            style: Styles.label2.merge(
              TextStyle(
                color: isActive ? Colors.black : MyColors.transparentWhite_70,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
