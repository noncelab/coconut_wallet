import 'package:flutter/material.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

class PinLengthToggleButton extends StatelessWidget {
  final int currentPinLength;
  final VoidCallback onToggle;

  const PinLengthToggleButton({super.key, required this.currentPinLength, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: CoconutButton(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: Sizes.size12, vertical: Sizes.size8),
        onPressed: onToggle,
        text: currentPinLength == 4 ? t.pin_setting_screen.set_to_6_digit : t.pin_setting_screen.set_to_4_digit,
        pressedBackgroundColor: colors.surfacePressed,
        backgroundColor: colors.surfaceButton,
        buttonType: CoconutButtonType.outlined,
        textStyle: CoconutTypography.body3_12.setColor(colors.secondaryText),
      ),
    );
  }
}
