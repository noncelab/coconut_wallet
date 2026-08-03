import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:flutter/material.dart';

class CoconutLoadingOverlay extends StatelessWidget {
  final bool applyFullScreen;
  final bool barrier;
  const CoconutLoadingOverlay({super.key, this.applyFullScreen = true, this.barrier = true});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (barrier) const ModalBarrier(dismissible: false),
        Container(
          color: context.coconutColors.loadingOverlay,
          padding:
              applyFullScreen
                  ? EdgeInsets.zero
                  : EdgeInsets.only(bottom: kToolbarHeight + MediaQuery.of(context).padding.top + kToolbarHeight),
          child: const Center(child: OverlayLoadingIndicator(padding: EdgeInsets.zero)),
        ),
      ],
    );
  }
}
