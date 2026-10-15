import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class CoconutFullScreenDialog extends StatelessWidget {
  final String title;
  final Widget body;

  const CoconutFullScreenDialog({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: colors.background,
        titleTextStyle: CoconutTypography.body1_16.setColor(colors.primaryText),
        toolbarTextStyle: CoconutTypography.body1_16.setColor(colors.primaryText),
        actions: [
          CoconutIconButton(
            color: colors.primaryText,
            focusColor: colors.surface,
            icon: const Icon(CupertinoIcons.xmark, size: 18),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            color: colors.background,
            child: Column(children: [body]),
          ),
        ),
      ),
    );
  }
}
