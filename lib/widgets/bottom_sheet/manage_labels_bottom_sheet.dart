import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';

class ManageLabelsBottomSheet extends StatelessWidget {
  final VoidCallback onImportPressed;
  final VoidCallback onExportPressed;

  const ManageLabelsBottomSheet({super.key, required this.onImportPressed, required this.onExportPressed});

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onImportPressed,
    required VoidCallback onExportPressed,
  }) {
    return CommonBottomSheets.showBottomSheet(
      context: context,
      title: t.manage_labels_bottom_sheet.title,
      showCloseButton: true,
      child: ManageLabelsBottomSheet(onImportPressed: onImportPressed, onExportPressed: onExportPressed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleButton(
            title: t.wallet_info_screen.import_labels,
            onPressed: () {
              Navigator.of(context).pop();
              onImportPressed();
            },
          ),
          CoconutLayout.spacing_200h,
          SingleButton(
            title: t.wallet_info_screen.export_labels,
            onPressed: () {
              Navigator.of(context).pop();
              onExportPressed();
            },
          ),
        ],
      ),
    );
  }
}
