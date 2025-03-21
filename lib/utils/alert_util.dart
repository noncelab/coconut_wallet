import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
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
    builder: (BuildContext context) => CoconutPopup(
        title: title ?? '',
        description: content ?? '',
        backgroundColor: CoconutColors.gray800,
        rightButtonText: t.confirm,
        rightButtonTextStyle: CoconutTypography.body1_16,
        rightButtonColor: CoconutColors.white,
        onTapRight: () {
          if (onClosed != null) onClosed();
          Navigator.pop(context);
        }),
  );
}

// todo : cds에 맞게 수정 후 삭제 예정
// send_fee_selection_screen.dart > showModalBottomSheet 부분 확인
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
            child: Text(t.confirm),
          ),
        ],
      );
    },
  );
}
