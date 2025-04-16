import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/styles.dart';

// TODO: cds로 교체 후 삭제
class CustomDialog extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback? onConfirmPressed;

  const CustomDialog(
      {required this.title, required this.content, this.onConfirmPressed, super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(title),
      content: Text(content),
      actions: <CupertinoDialogAction>[
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () {
            Navigator.of(context).pop;
          },
          child:
              Text('아니요', style: Styles.label.merge(const TextStyle(color: MyColors.defaultIcon))),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: onConfirmPressed,
          child: Text('네',
              style: Styles.subLabel.merge(const TextStyle(color: CoconutColors.primary))),
        ),
      ],
    );
  }
}
