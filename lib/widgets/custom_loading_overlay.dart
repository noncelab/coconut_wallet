import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';

class CustomLoadingOverlay extends StatelessWidget {
  final Widget child;

  const CustomLoadingOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LoaderOverlay(
      overlayColor: CoconutColors.black.withOpacity(0.5),
      overlayWidgetBuilder: (_) {
        return const Stack(
          children: [
            // 🛑 클릭 차단을 위한 ModalBarrier 추가
            ModalBarrier(
              dismissible: false,
              color: Colors.transparent, // 투명하게 유지
            ),
            Center(child: CoconutCircularIndicator()),
          ],
        );
      },
      child: child,
    );
  }
}
