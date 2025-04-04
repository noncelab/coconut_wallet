import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class CustomExpansionPanel extends StatefulWidget {
  final Widget unExpansionWidget;
  final Widget expansionWidget;
  final bool isExpanded;
  final bool isAssigned;
  final bool isChildPressed;
  final VoidCallback onExpansionChanged;
  final Function(bool) onPannelPressed;
  final EdgeInsets padding;

  const CustomExpansionPanel({
    super.key,
    required this.unExpansionWidget,
    required this.expansionWidget,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onPannelPressed,
    this.isAssigned = false,
    this.isChildPressed = false,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<CustomExpansionPanel> createState() => _CustomExpansionPanelState();
}

class _CustomExpansionPanelState extends State<CustomExpansionPanel> {
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              isPressed = false;
            });
            widget.onPannelPressed(false);
            widget.onExpansionChanged();
          },
          onTapDown: (details) {
            setState(() {
              isPressed = true;
            });
            widget.onPannelPressed(true);
          },
          onTapCancel: () {
            setState(() {
              isPressed = false;
            });
            widget.onPannelPressed(false);
          },
          child: Container(
            color: (isPressed || widget.isChildPressed)
                ? CoconutColors.gray900
                : CoconutColors.gray800,
            padding: widget.padding,
            child: widget.unExpansionWidget,
          ),
        ),
        AnimatedCrossFade(
          firstChild: Container(),
          secondChild: widget.expansionWidget,
          crossFadeState: widget.isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
