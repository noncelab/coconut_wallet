import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<bool> confirmArkAction(
  BuildContext context, {
  required String title,
  required String description,
  String? confirmText,
}) async {
  var confirmed = false;
  await showConfirmDialog(
    context,
    context.read<PreferenceProvider>().language,
    title,
    description,
    leftButtonText: t.cancel,
    rightButtonText: confirmText ?? t.confirm,
    onTapRight: () {
      confirmed = true;
      Navigator.pop(context);
    },
  );
  return confirmed;
}
