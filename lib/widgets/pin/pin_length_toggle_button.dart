import 'package:flutter/material.dart';
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
          foregroundColor: const Color(0xFF9CA3AF), // gray600 equivalent
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.0), // gray300 equivalent
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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD1D5DB), // gray300 equivalent
          ),
        ),
      ),
    );
  }
}
