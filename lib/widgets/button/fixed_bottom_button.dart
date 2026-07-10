import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';

class FixedBottomButton extends StatefulWidget {
  static const fixedBottomButtonDefaultHeight = 50.0;
  static const fixedBottomButtonDefaultBottomPadding = 16.0;

  const FixedBottomButton({
    super.key,
    required this.onButtonClicked,
    required this.text,
    this.isVisibleAboveKeyboard = true,
    this.isActive = true,
    this.buttonHeight,
    this.horizontalPadding = CoconutLayout.defaultPadding,
    this.bottomPadding = FixedBottomButton.fixedBottomButtonDefaultBottomPadding,
    this.subWidget,
    this.backgroundColor,
    this.pressedBackgroundColor,
    this.textColor,
    this.buttonKey,
    this.showSurroundings = true,
    this.surroundingsPadding,
    this.surroundingsColor,
    this.surroundingsKey,
  });

  final Function onButtonClicked;
  final String text;
  final bool showSurroundings;
  final bool isVisibleAboveKeyboard;
  final bool isActive;
  final double? buttonHeight;
  final double horizontalPadding;
  final double bottomPadding;
  final EdgeInsets? surroundingsPadding;
  final Widget? subWidget;
  final Color? backgroundColor;
  final Color? pressedBackgroundColor;
  final Color? textColor;
  final Color? surroundingsColor;
  final Key? surroundingsKey;
  final Key? buttonKey;

  @override
  State<FixedBottomButton> createState() => _FixedBottomButtonState();
}

class _FixedBottomButtonState extends State<FixedBottomButton> {
  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final resolvedBackgroundColor = widget.backgroundColor ?? colors.actionButtonBackground;
    final resolvedTextColor = widget.textColor ?? colors.actionButtonText;
    final resolvedSurroundingsColor = widget.surroundingsColor ?? colors.background;

    final mediaQuery = MediaQuery.of(context);
    final keyboardHeight = widget.isVisibleAboveKeyboard ? mediaQuery.viewInsets.bottom : 0.0;
    final anchoredBottomBase = keyboardHeight > 0 ? keyboardHeight : mediaQuery.padding.bottom;
    final anchoredBottom = anchoredBottomBase + widget.bottomPadding;
    final gradientBottom = keyboardHeight > 0 ? keyboardHeight : 0.0;
    double buttonHeight =
        widget.buttonHeight ??
        (Platform.isAndroid
            ? FixedBottomButton.fixedBottomButtonDefaultHeight
            : FixedBottomButton.fixedBottomButtonDefaultHeight + 3);

    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      child: Stack(
        children: [
          if (widget.showSurroundings)
            Positioned(
              key: widget.surroundingsKey,
              left: 0,
              right: 0,
              bottom: gradientBottom,
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  padding:
                      widget.surroundingsPadding ??
                      EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 40,
                        top: buttonHeight + widget.bottomPadding + (widget.subWidget != null ? 75 : 50),
                      ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [resolvedSurroundingsColor.withValues(alpha: 0.0), resolvedSurroundingsColor],
                      stops: const [0.0, 0.5],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: widget.horizontalPadding,
            right: widget.horizontalPadding,
            bottom: anchoredBottom,
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
                    defaultColor: resolvedBackgroundColor,
                    pressedColor:
                        widget.pressedBackgroundColor ??
                        (resolvedBackgroundColor == colors.actionButtonBackground
                            ? colors.actionButtonPressed
                            : getDarkerColor(resolvedBackgroundColor)),
                    disabledColor: colors.actionButtonDisabled,
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
                            style: CoconutTypography.body2_14_Bold
                                .setColor(widget.isActive ? resolvedTextColor : colors.actionButtonDisabledText)
                                .copyWith(height: 1.0),
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

/// [FixedBottomButton]과 동일한 외형과 색상 토큰을 사용하는 인라인 버튼.
/// [FixedBottomButton]이 Stack + Positioned 구조로 화면에 고정되는 반면,
/// 이 위젯은 일반 레이아웃 흐름 안에 배치되어 intrinsic height 컨텍스트에서도 사용 가능.
class InlineActionButton extends StatelessWidget {
  static const defaultHeight = 50.0;

  const InlineActionButton({
    super.key,
    required this.onPressed,
    this.text,
    this.child,
    this.isActive = true,
    this.buttonHeight,
    this.backgroundColor,
    this.pressedBackgroundColor,
    this.textColor,
  }) : assert(text != null || child != null, 'text 또는 child 중 하나는 반드시 제공해야 합니다.');

  final VoidCallback onPressed;
  final String? text;
  final Widget? child;
  final bool isActive;
  final double? buttonHeight;
  final Color? backgroundColor;
  final Color? pressedBackgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final resolvedBackgroundColor = backgroundColor ?? colors.actionButtonBackground;
    final resolvedTextColor = textColor ?? colors.actionButtonText;
    final resolvedHeight =
        buttonHeight ?? (Platform.isAndroid ? InlineActionButton.defaultHeight : InlineActionButton.defaultHeight + 3);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: ShrinkAnimationButton(
        onPressed: onPressed,
        isActive: isActive,
        defaultColor: resolvedBackgroundColor,
        pressedColor:
            pressedBackgroundColor ??
            (resolvedBackgroundColor == colors.actionButtonBackground
                ? colors.actionButtonPressed
                : getDarkerColor(resolvedBackgroundColor)),
        disabledColor: colors.actionButtonDisabled,
        borderRadius: 12,
        child: SizedBox(
          width: double.infinity,
          height: resolvedHeight,
          child: Center(
            child:
                child ??
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    text!,
                    textAlign: TextAlign.center,
                    style: CoconutTypography.body2_14_Bold
                        .setColor(isActive ? resolvedTextColor : colors.actionButtonDisabledText)
                        .copyWith(height: 1.0),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

Color getDarkerColor(Color color, [double amount = 0.15]) {
  final hsl = HSLColor.fromColor(color);
  final darker = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
  return darker.toColor();
}
