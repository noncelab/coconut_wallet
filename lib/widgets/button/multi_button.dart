import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:flutter/material.dart';

class MultiButton extends StatefulWidget {
  final List<SingleButton> children;
  final int animationDuration;
  final Color backgroundColor;
  final Color dividerColor;

  const MultiButton({
    super.key,
    required this.children,
    this.animationDuration = 100,
    this.backgroundColor = CoconutColors.gray800,
    this.dividerColor = CoconutColors.gray700,
  });

  @override
  State<MultiButton> createState() => _MultiButtonState();
}

class _MultiButtonState extends State<MultiButton> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final BorderRadius topRadius = _getFirstElementRadius();
    final BorderRadius bottomRadius = _getLastElementRadius();

    return AnimatedContainer(
      duration: Duration(milliseconds: widget.animationDuration),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: topRadius.topLeft,
          topRight: topRadius.topRight,
          bottomLeft: bottomRadius.bottomLeft,
          bottomRight: bottomRadius.bottomRight,
        ),
      ),
      curve: Curves.easeInOut,
      child: AnimatedSize(
        duration: Duration(milliseconds: widget.animationDuration),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.children.isNotEmpty) widget.children.first,
            AnimatedOpacity(
              opacity: widget.children.length > 1 ? 1.0 : 0.0,
              duration: Duration(milliseconds: widget.animationDuration),
              curve: Curves.easeInOut,
              child: AnimatedSize(
                duration: Duration(milliseconds: widget.animationDuration + 400),
                curve: Curves.easeInOut,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.children.length > 1
                      ? [
                          Container(
                            height: 1,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              color: widget.dividerColor,
                            ),
                            margin: EdgeInsets.symmetric(
                              horizontal:
                                  widget.children.first.buttonPosition.padding.horizontal / 2,
                            ),
                          ),
                          ...widget.children.sublist(1),
                        ]
                      : [],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BorderRadius _getFirstElementRadius() {
    final firstElement = widget.children.first;
    final radius = firstElement.buttonPosition.radius;
    return BorderRadius.only(
        topLeft: radius.topLeft,
        topRight: radius.topRight,
        bottomLeft: radius.bottomLeft,
        bottomRight: radius.bottomRight);
  }

  BorderRadius _getLastElementRadius() {
    final lastElement = widget.children.last;
    final radius = lastElement.buttonPosition.radius;
    return BorderRadius.only(
        topLeft: radius.topLeft,
        topRight: radius.topRight,
        bottomLeft: radius.bottomLeft,
        bottomRight: radius.bottomRight);
  }
}

class ButtonBorderRadius {
  final double topLeft;
  final double topRight;
  final double bottomLeft;
  final double bottomRight;

  const ButtonBorderRadius({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });
}
