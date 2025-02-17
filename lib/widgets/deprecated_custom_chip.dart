import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';

@Deprecated("CustomChip")
class CustomChip extends StatelessWidget {
  final String text;
  final Color? borderColor;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final double? borderRadius;
  final double? borderWidth;
  final EdgeInsets? padding;

  const CustomChip({
    super.key,
    required this.text,
    this.borderColor,
    this.backgroundColor,
    this.textStyle,
    this.borderRadius,
    this.borderWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius ?? 100),
        border: Border.all(
          color: borderColor ?? MyColors.white,
          width: borderWidth ?? 0.5,
        ),
      ),
      child: Text(
        text,
        style: textStyle ??
            Styles.caption2.copyWith(
              color: MyColors.white,
              height: 1.0,
            ),
      ),
    );
  }
}
