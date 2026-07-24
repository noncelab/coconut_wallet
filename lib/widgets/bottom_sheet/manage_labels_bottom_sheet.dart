import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_tween_button.dart';
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    t.manage_labels_bottom_sheet.title,
                    style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
                  ),
                  CoconutLayout.spacing_50w,
                  Text(t.manage_labels_bottom_sheet.feature, style: CoconutTypography.body3_12_Bold),
                ],
              ),
              CoconutLayout.spacing_100h,
              Text(
                t.manage_labels_bottom_sheet.description,
                style: CoconutTypography.body3_12.setColor(context.coconutColors.tertiaryText),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: FixedBottomTweenButton(
            leftText: t.wallet_info_screen.import_labels,
            rightText: t.wallet_info_screen.export_labels,
            leftButtonClicked: () {
              Navigator.of(context).pop();
              onImportPressed();
            },
            rightButtonClicked: () {
              Navigator.of(context).pop();
              onExportPressed();
            },
            showSurroundings: true,
          ),
        ),
      ],
    );
  }
}
