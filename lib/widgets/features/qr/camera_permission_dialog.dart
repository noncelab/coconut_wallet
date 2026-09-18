import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/utils/app_settings_util.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> showCameraPermissionDialog(BuildContext context) async {
  await showConfirmDialog(
    context,
    context.read<PreferenceProvider>().language,
    t.coconut_qr_scanner.camera_error.title,
    t.coconut_qr_scanner.camera_error.need_camera_permission,
    rightButtonText: t.go_to_settings,
    onTapRight: () {
      openAppSettings();
    },
  );
}
