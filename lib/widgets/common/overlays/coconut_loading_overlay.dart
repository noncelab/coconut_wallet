import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:flutter/material.dart';

class CoconutLoadingOverlay extends StatelessWidget {
  final bool applyFullScreen;
  final double indicatorSize;

  const CoconutLoadingOverlay({super.key, this.applyFullScreen = false, this.indicatorSize = 48.0});

  @override
  Widget build(BuildContext context) {
    if (applyFullScreen) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ModalBarrier(dismissible: false, color: context.coconutColors.loadingOverlay),
          Center(child: FullscreenLoadingIndicator(padding: EdgeInsets.zero, size: indicatorSize)),
        ],
      );
    }

    return Container(
      color: context.coconutColors.loadingOverlay,
      padding: EdgeInsets.only(bottom: kToolbarHeight + MediaQuery.of(context).padding.top + kToolbarHeight),
      child: Center(child: FullscreenLoadingIndicator(padding: EdgeInsets.zero, size: indicatorSize)),
    );
  }
}
