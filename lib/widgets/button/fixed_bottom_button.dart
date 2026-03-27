import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';

class FixedBottomButton extends StatefulWidget {
  static const fixedBottomButtonDefaultHeight = 55.0;
  static const fixedBottomButtonDefaultBottomPadding = 22.0;

  const FixedBottomButton({
    super.key,
    required this.onButtonClicked,
    required this.text,
    this.showGradient = true,
    this.isVisibleAboveKeyboard = true,
    this.isActive = true,
    this.buttonHeight,
    this.horizontalPadding = CoconutLayout.defaultPadding,
    this.bottomPadding = FixedBottomButton.fixedBottomButtonDefaultBottomPadding,
    this.gradientPadding,
    this.subWidget,
    this.backgroundColor = CoconutColors.primary,
    this.pressedBackgroundColor,
    this.textColor = CoconutColors.black,
    this.gradientKey,
    this.buttonKey,
  });

  final Function onButtonClicked;
  final String text;
  final bool showGradient;
  final bool isVisibleAboveKeyboard;
  final bool isActive;
  final double? buttonHeight;
  final double horizontalPadding;
  final double bottomPadding;
  final EdgeInsets? gradientPadding;
  final Widget? subWidget;
  final Color backgroundColor;
  final Color? pressedBackgroundColor;
  final Color textColor;
  final Key? gradientKey;
  final Key? buttonKey;

  @override
  State<FixedBottomButton> createState() => _FixedBottomButtonState();
}

class _FixedBottomButtonState extends State<FixedBottomButton> {
  @override
  Widget build(BuildContext context) {
    double keyboardHeight = (widget.isVisibleAboveKeyboard ? MediaQuery.of(context).viewInsets.bottom : 0);
    double buttonHeight =
        widget.buttonHeight ??
        (Platform.isAndroid
            ? FixedBottomButton.fixedBottomButtonDefaultHeight
            : FixedBottomButton.fixedBottomButtonDefaultHeight + 3);
    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child: Stack(
        children: [
          if (widget.showGradient)
            Positioned(
              key: widget.gradientKey,
              left: 0,
              right: 0,
              bottom: keyboardHeight,
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  padding:
                      widget.gradientPadding ??
                      EdgeInsets.only(left: 16, right: 16, bottom: 40, top: buttonHeight + 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        CoconutColors.black.withValues(alpha: 0.1),
                        CoconutColors.black.withValues(alpha: 0.4),
                        CoconutColors.black.withValues(alpha: 0.7),
                        CoconutColors.black,
                      ],
                      stops: const [0.0, 0.03, 0.07, 0.15, 0.23],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: widget.horizontalPadding,
            right: widget.horizontalPadding,
            bottom: keyboardHeight + widget.bottomPadding + MediaQuery.of(context).padding.bottom,
            child: Column(
              key: widget.buttonKey,
              children: [
                widget.subWidget ?? Container(),
                CoconutLayout.spacing_300h,
                MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
                  child: ShrinkAnimationButton(
                    onPressed: () {
                      widget.onButtonClicked();
                    },
                    isActive: widget.isActive,
                    defaultColor: widget.backgroundColor,
                    pressedColor: widget.pressedBackgroundColor ?? getDarkerColor(widget.backgroundColor),
                    disabledColor: CoconutColors.gray800,
                    borderRadius: 12,
                    child: SizedBox(
                      width: MediaQuery.sizeOf(context).width,
                      height: buttonHeight,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.text,
                            textAlign: TextAlign.center,
                            style: CoconutTypography.heading4_18_Bold.setColor(
                              widget.isActive ? widget.textColor : CoconutColors.gray700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color getDarkerColor(Color color, [double amount = 0.15]) {
  final hsl = HSLColor.fromColor(color);
  final darker = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return darker.toColor();
}
