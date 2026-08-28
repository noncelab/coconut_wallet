import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  const LoadingIndicator({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 16.0),
    this.color,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Container(
        padding: padding,
        child: CupertinoActivityIndicator(
          color: color ?? context.coconutColors.loadingIndicatorColor.withValues(alpha: 0.4),
          radius: radius,
        ),
      ),
    );
  }
}

// 임시
class CircularLoadingSpinner extends StatelessWidget {
  final double size;
  final double scale;
  final double strokeWidth;
  final Color? color;

  const CircularLoadingSpinner({super.key, this.size = 48, this.scale = 0.8, this.strokeWidth = 6, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Transform.scale(
        scale: scale,
        child: CircularProgressIndicator(
          color: color ?? context.coconutColors.loadingIndicatorColor,
          strokeWidth: strokeWidth,
          strokeCap: StrokeCap.round,
        ),
      ),
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
