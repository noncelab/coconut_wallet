import 'package:coconut_design_system/coconut_design_system.dart';
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
  final TextStyle? subtitleStyle;
  final Color? backgroundColor;
  final double? betweenGap;

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
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
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
                  Text(title, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: subtitleStyle ??
                            CoconutTypography.body3_12_Number.setColor(CoconutColors.white)),
                ],
              )),
              Container(width: betweenGap),
              rightElement ?? _rightArrow(),
            ],
          ),
        ));
  }

  Widget _rightArrow() =>
      const Icon(Icons.keyboard_arrow_right_rounded, color: CoconutColors.gray600);
}
