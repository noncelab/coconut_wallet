import 'package:flutter/cupertino.dart';

import '../../styles.dart';

class ActionBottomButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;

  const ActionBottomButton({super.key, this.onPressed, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: MediaQuery.of(context).size.width * 0.95,
        height: 64,
        child: CupertinoButton(
          color: MyColors.primary,
          disabledColor: MyColors.transparentWhite_15,
          borderRadius: MyBorder.defaultRadius,
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Text(text, style: Styles.CTAButtonTitle),
        ));
  }
}
