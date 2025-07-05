import 'package:flutter/material.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

class PinLengthToggleButton extends StatelessWidget {
  final int currentPinLength;
  final VoidCallback onToggle;

  const PinLengthToggleButton({
    super.key,
    required this.currentPinLength,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: OutlinedButton(
        onPressed: onToggle,
        style: OutlinedButton.styleFrom(
          foregroundColor: CoconutColors.gray600,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: CoconutColors.gray400, width: 1.0),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(8),
            ),
          ),
        ),
        child: Text(
          currentPinLength == 4
              ? t.pin_setting_screen.set_to_6_digit
              : t.pin_setting_screen.set_to_4_digit,
          style: CoconutTypography.body2_14.setColor(CoconutColors.gray400),
        ),
      ),
    );
  }
}
