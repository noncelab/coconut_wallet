import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class TrezorDigitBox extends StatelessWidget {
  final String digit;
  final bool hasError;
  final bool isVerifying;

  const TrezorDigitBox({super.key, required this.digit, required this.hasError, this.isVerifying = false});

  @override
  Widget build(BuildContext context) {
    final filled = digit.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: context.coconutColors.inputPlaceholder,
          border: hasError && filled ? Border.all(color: context.coconutColors.danger, width: 1.5) : null,
        ),
        alignment: Alignment.center,
        child:
            filled
                ? Text(
                  digit,
                  style: CoconutTypography.heading3_21_Number.copyWith(
                    fontWeight: FontWeight.w700,
                    color:
                        hasError
                            ? context.coconutColors.danger
                            : isVerifying
                            ? context.coconutColors.mutedText
                            : context.coconutColors.primaryText,
                  ),
                )
                : null,
      ),
    );
  }
}
