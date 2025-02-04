import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/styles.dart';

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

// void showConfirmDialog(BuildContext context) {
//   showCupertinoModalPopup<void>(
//     context: context,
//     builder: (BuildContext context) => CupertinoAlertDialog(
//       title: const Text('Alert'),
//       content: const Text('Proceed with destructive action?'),
//       actions: <CupertinoDialogAction>[
//         CupertinoDialogAction(
//           /// This parameter indicates this action is the default,
//           /// and turns the action's text to bold text.
//           isDefaultAction: true,
//           onPressed: () {
//             Navigator.pop(context);
//           },
//           child: const Text('No'),
//         ),
//         CupertinoDialogAction(
//           /// This parameter indicates the action would perform
//           /// a destructive action such as deletion, and turns
//           /// the action's text color to red.
//           isDestructiveAction: true,
//           onPressed: () {
//             Navigator.pop(context);
//           },
//           child: const Text('Yes'),
//         ),
//       ],
//     ),
//   );
// }

void showTextFieldDialog(
    {required BuildContext context,
    String? title,
    String? content,
    required TextEditingController controller,
    TextInputType? textInputType,
    required VoidCallback onPressed}) {
  showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) {
      return CupertinoAlertDialog(
        title: title != null ? Text(title, style: Styles.h3) : null,
        content: Column(children: [
          if (content != null) ...[
            Text(content, style: Styles.body2),
            const SizedBox(
              height: 12,
            )
          ],
          CupertinoTextField(
            textAlign: TextAlign.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            controller: controller,
            style: Styles.body1,
            keyboardType: textInputType ??
                const TextInputType.numberWithOptions(decimal: true),
          )
        ]),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            /// This parameter indicates this action is the default,
            /// and turns the action's text to bold text.
            isDefaultAction: false,
            onPressed: () {
              onPressed();
              Navigator.pop(context);
            },
            child: const Text('확인'),
          ),
        ],
      );
    },
  );
}
