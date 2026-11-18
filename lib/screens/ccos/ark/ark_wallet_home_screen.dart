import 'package:coconut_wallet/ccos/features/ark/ark_feature_copy.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:flutter/material.dart';

class ArkWalletHomeScreen extends StatelessWidget {
  const ArkWalletHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.coconutColors.homeBackground,
      appBar: CoconutAppBar.build(
        context: context,
        backgroundColor: context.coconutColors.homeBackground,
        title: ArkFeatureCopySource.current.title,
      ),
      body: const SizedBox.shrink(),
    );
  }
}
