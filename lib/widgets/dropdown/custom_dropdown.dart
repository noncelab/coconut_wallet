import 'package:coconut_wallet/ui/coconut/coconut_dropdown.dart';
import 'package:flutter/material.dart';

class CustomDropdown extends StatefulWidget {
  final List<String> buttons;
  final Function onTapButton;
  final int dividerIndex;
  final Color? dividerColor;
  final Color? backgroundColor;
  final EdgeInsets margin;
  final String? selectedButton;

  const CustomDropdown({
    super.key,
    required this.buttons,
    required this.onTapButton,
    this.dividerIndex = 0,
    this.dividerColor,
    this.backgroundColor,
    this.margin = EdgeInsets.zero,
    this.selectedButton,
  });

  @override
  State<CustomDropdown> createState() => _CustomDropdownState();
}

class _CustomDropdownState extends State<CustomDropdown> {
  @override
  Widget build(BuildContext context) {
    return CoconutDropdown(
      buttons: widget.buttons,
      onTapButton: widget.onTapButton,
      dividerIndex: widget.dividerIndex,
      dividerColor: widget.dividerColor,
      backgroundColor: widget.backgroundColor,
      margin: widget.margin,
      selectedButton: widget.selectedButton,
    );
  }
}
