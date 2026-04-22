import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';

class FixedBottomTweenButton extends StatefulWidget {
  static const fixedBottomButtonDefaultHeight = 55.0;
  static const fixedBottomButtonDefaultBottomPadding = 22.0;

  const FixedBottomTweenButton({
    super.key,
    required this.leftButtonClicked,
    required this.rightButtonClicked,
    required this.leftText,
    required this.rightText,
    this.leftButtonRatio = 0.5, // 왼쪽 버튼이 차지하는 비율 (0.0 ~ 1.0)
    this.showGradient = true,
    this.isVisibleAboveKeyboard = true,
    this.isLeftButtonActive = true,
    this.isRightButtonActive = true,
    this.buttonHeight,
    this.horizontalPadding = CoconutLayout.defaultPadding,
    this.bottomPadding = FixedBottomTweenButton.fixedBottomButtonDefaultBottomPadding,
    this.gradientPadding,
    this.subWidget,
    this.leftButtonBackgroundColor = CoconutColors.gray200,
    this.rightButtonBackgroundColor = CoconutColors.primary,
    this.leftButtonTextColor = CoconutColors.black,
    this.rightButtonTextColor = CoconutColors.black,
    this.buttonSpacing = 8.0, // 두 버튼 사이의 간격
  });

  final Function leftButtonClicked;
  final Function rightButtonClicked;
  final String leftText;
  final String rightText;
  final double leftButtonRatio;
  final bool showGradient;
  final bool isVisibleAboveKeyboard;
  final bool isLeftButtonActive;
  final bool isRightButtonActive;
  final double? buttonHeight;
  final double horizontalPadding;
  final double bottomPadding;
  final EdgeInsets? gradientPadding;
  final Widget? subWidget;
  final Color leftButtonBackgroundColor;
  final Color rightButtonBackgroundColor;
  final Color leftButtonTextColor;
  final Color rightButtonTextColor;
  final double buttonSpacing;

  @override
  State<FixedBottomTweenButton> createState() => _FixedBottomTweenButtonState();
}

class _FixedBottomTweenButtonState extends State<FixedBottomTweenButton> {
  @override
  Widget build(BuildContext context) {
    double keyboardHeight = (widget.isVisibleAboveKeyboard ? MediaQuery.of(context).viewInsets.bottom : 0);
    double bottomInset = MediaQuery.of(context).padding.bottom;

    // 전체 너비에서 패딩과 버튼 간격을 제외한 실제 버튼 영역
    final totalWidth = MediaQuery.sizeOf(context).width - (widget.horizontalPadding * 2) - widget.buttonSpacing;
    final leftButtonWidth = totalWidth * widget.leftButtonRatio;
    final rightButtonWidth = totalWidth * (1 - widget.leftButtonRatio);

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
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  padding:
                      widget.gradientPadding ??
                      EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 40,
                        top: buttonHeight + bottomInset + (widget.subWidget != null ? 75 : 50),
                      ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        CoconutColors.black.withValues(alpha: 0.1),
                        CoconutColors.black.withValues(alpha: 0.4),
                        CoconutColors.black.withValues(alpha: 0.8),
                        CoconutColors.black,
                        CoconutColors.black,
                      ],
                      stops: const [0.0, 0.1, 0.2, 0.35, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: widget.horizontalPadding,
            right: widget.horizontalPadding,
            bottom: keyboardHeight + widget.bottomPadding + bottomInset,
            child: Column(
              children: [
                widget.subWidget ?? Container(),
                CoconutLayout.spacing_300h,
                Row(
                  children: [
                    // 왼쪽 버튼
                    SizedBox(
                      width: leftButtonWidth,
                      child: ShrinkAnimationButton(
                        onPressed: () {
                          widget.leftButtonClicked();
                        },
                        defaultColor: widget.leftButtonBackgroundColor,
                        pressedColor: getDarkerColor(widget.leftButtonBackgroundColor),
                        disabledColor: CoconutColors.gray800,
                        borderRadius: 12,
                        child: SizedBox(
                          width: leftButtonWidth,
                          height: buttonHeight,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.leftText,
                                style: CoconutTypography.body1_16_Bold.setColor(
                                  widget.isLeftButtonActive ? widget.leftButtonTextColor : CoconutColors.gray700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: widget.buttonSpacing),
                    // 오른쪽 버튼
                    SizedBox(
                      width: rightButtonWidth,
                      child: ShrinkAnimationButton(
                        onPressed: () {
                          widget.rightButtonClicked();
                        },
                        defaultColor: widget.rightButtonBackgroundColor,
                        pressedColor: getDarkerColor(widget.rightButtonBackgroundColor),
                        disabledColor: CoconutColors.gray800,
                        borderRadius: 12,
                        child: SizedBox(
                          width: rightButtonWidth,
                          height: buttonHeight,
                          child: Center(
                            child: Text(
                              widget.rightText,
                              style: CoconutTypography.body1_16_Bold.setColor(
                                widget.isRightButtonActive ? widget.rightButtonTextColor : CoconutColors.gray700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
