import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

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
              const SizedBox(width: 12),
            },
            Expanded(child: Text(title, style: Styles.body2Bold)),
            rightElement ?? _rightArrow(),
          ],
        ));
  }

  Widget _rightArrow() => const Icon(Icons.keyboard_arrow_right_rounded,
      color: MyColors.transparentWhite_40);
}
