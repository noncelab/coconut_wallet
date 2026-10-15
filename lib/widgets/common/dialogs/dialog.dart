import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
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
        description: description,
        descriptionPadding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
        insetPadding: const EdgeInsets.symmetric(horizontal: 50),
        rightButtonText: buttonText ?? t.OK,
        rightButtonColor: context.coconutColors.primaryText,
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
        description: description,
        descriptionPadding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
        insetPadding: const EdgeInsets.symmetric(horizontal: 50),
        leftButtonText: leftButtonText ?? t.cancel,
        leftButtonColor: context.coconutColors.primaryText,
        rightButtonText: rightButtonText ?? t.OK,
        rightButtonColor: context.coconutColors.primaryText,
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
