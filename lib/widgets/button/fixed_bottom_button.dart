import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class FixedBottomButton extends StatefulWidget {
  const FixedBottomButton({
    super.key,
    required this.onButtonClicked,
    required this.text,
    this.showGradient = true,
    this.isActive = true,
    this.buttonHeight,
    this.horizontalPadding = CoconutLayout.defaultPadding,
    this.bottomPadding = Sizes.size30,
    this.gradientPadding,
    this.subWidget,
    this.backgroundColor = CoconutColors.primary,
  });

  final Function onButtonClicked;
  final String text;
  final bool showGradient;
  final bool isActive;
  final double? buttonHeight;
  final double horizontalPadding;
  final double bottomPadding;
  final EdgeInsets? gradientPadding;
  final Widget? subWidget;
  final Color backgroundColor;

  @override
  State<FixedBottomButton> createState() => _FixedBottomButtonState();
}

class _FixedBottomButtonState extends State<FixedBottomButton> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child: Stack(
        children: [
          if (widget.showGradient)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom,
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  padding: widget.gradientPadding ??
                      const EdgeInsets.only(left: 16, right: 16, bottom: 40, top: 150),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        CoconutColors.black,
                      ],
                      stops: [0.0, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: widget.horizontalPadding,
            right: widget.horizontalPadding,
            bottom: MediaQuery.of(context).viewInsets.bottom + widget.bottomPadding,
            child: Column(
              children: [
                widget.subWidget ?? Container(),
                CoconutLayout.spacing_300h,
                CoconutButton(
                  onPressed: () {
                    widget.onButtonClicked();
                  },
                  width: MediaQuery.sizeOf(context).width,
                  disabledBackgroundColor: CoconutColors.gray800,
                  disabledForegroundColor: CoconutColors.gray700,
                  isActive: widget.isActive,
                  height: widget.buttonHeight ?? 50,
                  backgroundColor: widget.backgroundColor,
                  foregroundColor: CoconutColors.black,
                  pressedTextColor: CoconutColors.black,
                  text: widget.text,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
