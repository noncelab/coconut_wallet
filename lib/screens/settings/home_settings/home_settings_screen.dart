import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

class HomeSettingsScreen extends StatelessWidget {
  const HomeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(t.home_screen_settings, style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(context, AppRouteNames.walletHomeEdit),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              t.wallet_home_screen.edit.title,
              style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
            ),
          ),
        ),
      ),
    );
  }
}
