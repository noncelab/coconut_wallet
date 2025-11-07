import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';

enum SingleButtonPosition { none, top, middle, bottom }

extension SingleButtonBorderRadiusExtension on SingleButtonPosition {
  BorderRadius get radius {
    switch (this) {
      case SingleButtonPosition.none:
        return BorderRadius.circular(Sizes.size24);
      case SingleButtonPosition.top:
        return const BorderRadius.vertical(top: Radius.circular(Sizes.size24));
      case SingleButtonPosition.middle:
        return BorderRadius.zero;
      case SingleButtonPosition.bottom:
        return const BorderRadius.vertical(bottom: Radius.circular(Sizes.size24));
    }
  }

  EdgeInsets get padding {
    switch (this) {
      case SingleButtonPosition.none:
        return const EdgeInsets.symmetric(horizontal: Sizes.size20, vertical: Sizes.size24);
      case SingleButtonPosition.top:
        return const EdgeInsets.only(left: Sizes.size20, right: Sizes.size20, top: Sizes.size24, bottom: Sizes.size20);
      case SingleButtonPosition.middle:
        return const EdgeInsets.all(Sizes.size20);
      case SingleButtonPosition.bottom:
        return const EdgeInsets.only(left: Sizes.size20, right: Sizes.size20, top: Sizes.size20, bottom: Sizes.size24);
    }
  }
}

class SingleButton extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? description;
  final VoidCallback? onPressed;
  final Widget? rightElement;
  final Widget? leftElement;
  final SingleButtonPosition buttonPosition;
  final TextStyle? subtitleStyle;
  final Color backgroundColor;
  final double? betweenGap;
  final EdgeInsets? customPadding;
  final bool enableShrinkAnim;
  final bool isVerticalSubtitle;
  final double animationEndValue;

  const SingleButton({
    super.key,
    required this.title,
    this.subtitle,
    this.description,
    this.onPressed,
    this.rightElement,
    this.leftElement,
    this.buttonPosition = SingleButtonPosition.none,
    this.subtitleStyle = CoconutTypography.body3_12,
    this.backgroundColor = CoconutColors.gray800,
    this.betweenGap = 0,
    this.customPadding,
    this.enableShrinkAnim = false,
    this.isVerticalSubtitle = false,
    this.animationEndValue = 0.95,
  });

  @override
  Widget build(BuildContext context) {
    final buttonContent = _buildButtonContent();

    return enableShrinkAnim
        ? ShrinkAnimationButton(
          onPressed: onPressed ?? () {},
          defaultColor: backgroundColor,
          pressedColor: CoconutColors.gray750,
          borderRadius: 24,
          animationEndValue: animationEndValue,
          child: Container(
            decoration: BoxDecoration(borderRadius: buttonPosition.radius),
            padding: getPadding(),
            child: buttonContent,
          ),
        )
        : GestureDetector(
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(color: backgroundColor, borderRadius: buttonPosition.radius),
            padding: getPadding(),
            child: buttonContent,
          ),
        );
  }

  /// padding을 계산하는 메서드 - 하위 클래스에서 오버라이드 가능
  EdgeInsets getPadding() {
    return customPadding ?? buttonPosition.padding;
  }

  Widget _buildButtonContent() {
    return Row(
      children: [
        if (leftElement != null) ...{Container(child: leftElement), CoconutLayout.spacing_400w},
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(title, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
              ),
              if (isVerticalSubtitle) ...{
                CoconutLayout.spacing_100h,
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    subtitle!,
                    style: subtitleStyle ?? CoconutTypography.body3_12_Number.setColor(CoconutColors.gray400),
                  ),
                ),
              },
            ],
          ),
        ),
        if (subtitle != null && !isVerticalSubtitle)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              subtitle!,
              style: subtitleStyle ?? CoconutTypography.body3_12_Number.setColor(CoconutColors.gray400),
            ),
          ),
        rightElement ?? _rightArrow(),
      ],
    );
  }

  Widget _rightArrow() => const Icon(Icons.keyboard_arrow_right_rounded, color: CoconutColors.gray400);
}
