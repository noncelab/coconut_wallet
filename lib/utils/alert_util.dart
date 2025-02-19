import 'package:flutter/cupertino.dart';

void showAlertDialog(
    {required BuildContext context,
    String? title,
    String? content,
    bool dismissible = true,
    VoidCallback? onClosed}) {
  showCupertinoModalPopup<void>(
    context: context,
    barrierDismissible: dismissible,
    builder: (BuildContext context) => CupertinoAlertDialog(
      title: title != null ? Text(title) : null,
      content: content != null ? Text(content) : null,
      actions: <CupertinoDialogAction>[
        CupertinoDialogAction(
          /// This parameter indicates this action is the default,
          /// and turns the action's text to bold text.
          isDefaultAction: true,
          onPressed: () {
            if (onClosed != null) onClosed();
            Navigator.pop(context);
          },
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
