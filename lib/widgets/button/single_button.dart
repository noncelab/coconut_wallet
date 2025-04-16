import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class SingleButton extends StatelessWidget {
  final String title;
  final String? description;
  final VoidCallback? onPressed;
  final Widget? rightElement;
  final Widget? leftElement;

  const SingleButton({
    super.key,
    required this.title,
    this.description,
    this.onPressed,
    this.rightElement,
    this.leftElement,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onPressed,
        child: Row(
          children: [
            if (leftElement != null) ...{
              Container(child: leftElement),
              CoconutLayout.spacing_400w,
            },
            Expanded(
                child: Text(title,
                    style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white))),
            rightElement ?? _rightArrow(),
          ],
        ));
  }

  Widget _rightArrow() =>
      const Icon(Icons.keyboard_arrow_right_rounded, color: CoconutColors.gray600);
}
