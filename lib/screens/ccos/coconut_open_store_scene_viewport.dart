import 'package:flutter/material.dart';

/// Scrolls overflowing scenes while preserving their horizontal paint gutter.
class CcosSceneViewport extends StatelessWidget {
  const CcosSceneViewport({super.key, required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Widen the viewport gutter, then restore the content's exact width.
      // SingleChildScrollView clips only when the scene overflows.
      final gutter = MediaQuery.sizeOf(context).width;
      final viewportWidth = constraints.maxWidth + gutter * 2;
      return OverflowBox(
        minWidth: viewportWidth,
        maxWidth: viewportWidth,
        child: SingleChildScrollView(
          primary: false,
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: ConstrainedBox(constraints: BoxConstraints(minHeight: height), child: IntrinsicHeight(child: child)),
          ),
        ),
      );
    },
  );
}
