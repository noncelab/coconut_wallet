import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:flutter/material.dart';

class AllFeaturesScreen extends StatelessWidget {
  final VoidCallback onBack;

  const AllFeaturesScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(
        context: context,
        backgroundColor: colors.background,
        title: t.all_features.title,
        onBackPressed: onBack,
      ),
      body: const SafeArea(child: SizedBox.expand(key: Key('all-features-body'))),
    );
  }
}
