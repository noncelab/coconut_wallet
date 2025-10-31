import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/cupertino.dart';

// TODO: CoconutButton으로 변경 후 삭제
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
        color: CoconutColors.primary,
        disabledColor: CoconutColors.gray800,
        borderRadius: BorderRadius.circular(24),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Text(text, style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.black)),
      ),
    );
  }
}
