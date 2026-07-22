import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FullscreenLoadingIndicator extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double size;
  final int duration;
  final bool loop;
  final bool reverse;

  const FullscreenLoadingIndicator({
    super.key,
    this.padding = EdgeInsets.zero,
    this.color,
    this.size = 200,
    this.duration = 2,
    this.loop = true,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? context.coconutColors.loadingIndicatorColor;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Padding(
        padding: padding,
        child: CoconutCircularIndicator(
          size: size,
          duration: duration,
          loop: loop,
          reverse: reverse,
          colorFilter: resolvedColor,
        ),
      ),
    );
  }
}

class InlineLoadingIndicator extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;

  const InlineLoadingIndicator({
    super.key,
    this.padding = const EdgeInsets.symmetric(vertical: 16.0),
    this.color,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? context.coconutColors.loadingIndicatorColor;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Padding(padding: padding, child: CupertinoActivityIndicator(color: resolvedColor, radius: radius)),
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
          Center(child: indicator ?? const InlineLoadingIndicator()),
        ],
      ],
    );
  }
}
