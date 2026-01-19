import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

Future<void> showInfoDialog(
  BuildContext context,
  String languageCode,
  String title,
  String description, {
  String? buttonText,
  Function? onTapButton,
  bool barrierDismissible = true,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext context) {
      return CoconutPopup(
        languageCode: languageCode,
        title: title,
        backgroundColor: CoconutColors.black.withOpacity(0.7),
        description: description,
        descriptionPadding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
        insetPadding: const EdgeInsets.symmetric(horizontal: 50),
        rightButtonText: buttonText ?? t.OK,
        rightButtonColor: CoconutColors.white,
        onTapRight:
            onTapButton ??
            () {
              Navigator.pop(context);
            },
      );
    },
  );
}

Future<void> showConfirmDialog(
  BuildContext context,
  String languageCode,
  String title,
  String description, {
  String? leftButtonText,
  String? rightButtonText,
  Function? onTapLeft,
  Function? onTapRight,
  bool barrierDismissible = true,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext context) {
      return CoconutPopup(
        languageCode: languageCode,
        title: title,
        backgroundColor: CoconutColors.black.withOpacity(0.7),
        description: description,
        descriptionPadding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
        insetPadding: const EdgeInsets.symmetric(horizontal: 50),
        leftButtonText: leftButtonText ?? t.cancel,
        leftButtonColor: CoconutColors.white,
        rightButtonText: rightButtonText ?? t.OK,
        rightButtonColor: CoconutColors.white,
        onTapLeft:
            onTapLeft ??
            () {
              Navigator.pop(context);
            },
        onTapRight:
            onTapRight ??
            () {
              Navigator.pop(context);
            },
      );
    },
  );
}
