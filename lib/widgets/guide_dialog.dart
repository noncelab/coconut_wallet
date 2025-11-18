import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/button/action_bottom_button.dart';

class GuideDialog extends StatelessWidget {
  final Widget? child;
  final VoidCallback? onPressed;

  const GuideDialog({super.key, this.child, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (child != null) child!,
          ActionBottomButton(
            onPressed:
                onPressed ??
                () {
                  Navigator.pop(context);
                },
            text: "확인",
          ),
        ],
      ),
      backgroundColor: MyColors.grey,
      contentPadding: const EdgeInsets.all(10.0),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20.0))),
    );
  }
}
