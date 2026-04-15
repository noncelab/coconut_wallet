import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;

  const LoadingIndicator({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 16.0),
    this.color = CoconutColors.white,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Container(padding: padding, child: CupertinoActivityIndicator(color: color, radius: radius)),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final Widget? indicator;
  final Color barrierColor;
  final bool dismissible;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.indicator,
    this.barrierColor = Colors.transparent,
    this.dismissible = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) ...[
          ModalBarrier(dismissible: dismissible, color: barrierColor),
          Center(child: indicator ?? const LoadingIndicator()),
        ],
      ],
    );
  }
}
