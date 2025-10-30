import 'package:flutter/material.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

class PinLengthToggleButton extends StatelessWidget {
  final int currentPinLength;
  final VoidCallback onToggle;

  const PinLengthToggleButton({super.key, required this.currentPinLength, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: CoconutButton(
        width: 180,
        padding: const EdgeInsets.symmetric(horizontal: Sizes.size12, vertical: Sizes.size8),
        onPressed: onToggle,
        text: currentPinLength == 4 ? t.pin_setting_screen.set_to_6_digit : t.pin_setting_screen.set_to_4_digit,
        pressedBackgroundColor: CoconutColors.gray800,
        backgroundColor: CoconutColors.gray600,
        buttonType: CoconutButtonType.outlined,
        textStyle: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
      ),
    );
  }
}
