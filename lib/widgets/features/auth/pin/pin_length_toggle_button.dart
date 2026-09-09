import 'package:flutter/material.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';

class PinLengthToggleButton extends StatelessWidget {
  final int currentPinLength;
  final VoidCallback onToggle;

  const PinLengthToggleButton({super.key, required this.currentPinLength, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final text = currentPinLength == 4 ? t.pin_setting_screen.set_to_6_digit : t.pin_setting_screen.set_to_4_digit;
    const outerBorderRadius = 8.0;
    const borderWidth = 0.5;
    const innerBorderRadius = outerBorderRadius + borderWidth * 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: ShrinkAnimationButton(
        onPressed: onToggle,
        defaultColor: colors.surfaceButton,
        pressedOverlayColor: colors.surfacePressOverlay,
        borderRadius: outerBorderRadius,
        borderWidth: borderWidth,
        childBuilder:
            (context, isPressed) => Container(
              padding: const EdgeInsets.symmetric(horizontal: Sizes.size12, vertical: Sizes.size8),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(innerBorderRadius),
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: CoconutTypography.body3_12.setColor(colors.secondaryText.withAlpha(isPressed ? 120 : 255)),
              ),
            ),
      ),
    );
  }
}
