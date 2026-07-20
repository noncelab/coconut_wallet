import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class CoconutLoadingOverlay extends StatelessWidget {
  final bool applyFullScreen;
  const CoconutLoadingOverlay({super.key, this.applyFullScreen = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.coconutColors.loadingIndicatorColor.withValues(alpha: 0.4),
      padding:
          applyFullScreen
              ? EdgeInsets.zero
              : EdgeInsets.only(bottom: kToolbarHeight + MediaQuery.of(context).padding.top + kToolbarHeight),
      child: const Center(child: CoconutCircularIndicator()),
    );
  }
}
