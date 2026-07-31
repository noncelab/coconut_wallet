import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/cupertino.dart';

// todo : cds에 맞게 수정 후 삭제 예정
// send_fee_selection_screen.dart > showModalBottomSheet 부분 확인
void showTextFieldDialog({
  required BuildContext context,
  String? title,
  String? content,
  required TextEditingController controller,
  TextInputType? textInputType,
  required VoidCallback onPressed,
}) {
  showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) {
      return CupertinoAlertDialog(
        title: title != null ? Text(title, style: CoconutTypography.heading4_18_Bold) : null,
        content: Column(
          children: [
            if (content != null) ...[Text(content, style: CoconutTypography.body2_14), const SizedBox(height: 12)],
            CupertinoTextField(
              textAlign: TextAlign.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              controller: controller,
              style: CoconutTypography.body1_16,
              keyboardType: textInputType ?? const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
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
