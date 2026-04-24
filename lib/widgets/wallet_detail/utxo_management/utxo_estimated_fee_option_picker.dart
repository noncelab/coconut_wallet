import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class UtxoEstimatedFeeOptionPicker extends StatelessWidget {
  final String label;
  final String valueText;
  final String placeholderText;
  final bool hasValue;
  final CoconutOptionStateEnum optionState;
  final String? guideText;
  final VoidCallback onTap;

  const UtxoEstimatedFeeOptionPicker({
    super.key,
    required this.label,
    required this.valueText,
    required this.placeholderText,
    required this.hasValue,
    required this.optionState,
    required this.onTap,
    this.guideText,
  });

  @override
  Widget build(BuildContext context) {
    return CoconutOptionPicker(
      label: label,
      text: hasValue ? valueText : placeholderText,
      textColor: hasValue ? CoconutColors.white : CoconutColors.gray500,
      coconutOptionStateEnum: optionState,
      guideText: guideText,
      onTap: onTap,
    );
  }
}
