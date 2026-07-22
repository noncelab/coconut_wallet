import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';

class CustomLoadingOverlay extends StatelessWidget {
  final Widget child;

  const CustomLoadingOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LoaderOverlay(
      overlayColor: context.coconutColors.loadingOverlay,
      overlayWidgetBuilder: (_) {
        return const Stack(
          children: [
            // 🛑 클릭 차단을 위한 ModalBarrier 추가
            ModalBarrier(
              dismissible: false,
              color: Colors.transparent, // 투명하게 유지
            ),
            Center(
              child: FullscreenLoadingIndicator(padding: EdgeInsets.zero),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
