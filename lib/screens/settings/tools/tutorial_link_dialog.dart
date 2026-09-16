import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class TutorialLinkDialog extends StatelessWidget {
  final String title;
  final String description;
  final String confirmLabel;
  final VoidCallback onConfirm;

  const TutorialLinkDialog({
    super.key,
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(title, style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText)),
      content: Text(description, style: CoconutTypography.body1_16.setColor(colors.secondaryText)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
