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
        return const BorderRadius.vertical(
          top: Radius.circular(Sizes.size24),
        );
      case SingleButtonPosition.middle:
        return BorderRadius.zero;
      case SingleButtonPosition.bottom:
        return const BorderRadius.vertical(
          bottom: Radius.circular(Sizes.size24),
        );
    }
  }

  EdgeInsets get padding {
    switch (this) {
      case SingleButtonPosition.none:
        return const EdgeInsets.symmetric(horizontal: Sizes.size20, vertical: Sizes.size24);
      case SingleButtonPosition.top:
        return const EdgeInsets.only(
            left: Sizes.size20, right: Sizes.size20, top: Sizes.size24, bottom: Sizes.size20);
      case SingleButtonPosition.middle:
        return const EdgeInsets.all(Sizes.size20);
      case SingleButtonPosition.bottom:
        return const EdgeInsets.only(
            left: Sizes.size20, right: Sizes.size20, top: Sizes.size20, bottom: Sizes.size24);
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
  final bool enableShrinkAnim;
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
    this.enableShrinkAnim = false,
    this.animationEndValue = 0.95,
  });

  @override
  Widget build(BuildContext context) {
    return enableShrinkAnim
        ? ShrinkAnimationButton(
            onPressed: onPressed ?? () {},
            defaultColor: CoconutColors.gray800,
            pressedColor: CoconutColors.gray750,
            borderRadius: 24,
            animationEndValue: animationEndValue,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: buttonPosition.radius,
              ),
              padding: buttonPosition.padding,
              child: Row(
                children: [
                  if (leftElement != null) ...{
                    Container(child: leftElement),
                    CoconutLayout.spacing_400w,
                  },
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: CoconutTypography.body3_12_Number.setColor(CoconutColors.white)),
                    ],
                  )),
                  rightElement ?? _rightArrow(),
                ],
              ),
            ))
        : GestureDetector(
            onTap: onPressed,
            child: Container(
              decoration: BoxDecoration(
                color: CoconutColors.gray800,
                borderRadius: buttonPosition.radius,
              ),
              padding: buttonPosition.padding,
              child: Row(
                children: [
                  if (leftElement != null) ...{
                    Container(child: leftElement),
                    CoconutLayout.spacing_400w,
                  },
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: CoconutTypography.body3_12_Number.setColor(CoconutColors.white)),
                    ],
                  )),
                  rightElement ?? _rightArrow(),
                ],
              ),
            ));
  }

  Widget _rightArrow() =>
      const Icon(Icons.keyboard_arrow_right_rounded, color: CoconutColors.gray600);
}
