import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FullscreenLoadingIndicator extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double? size;
  final double? strokeWidth;

  const FullscreenLoadingIndicator({
    super.key,
    this.padding = EdgeInsets.zero,
    this.color,
    this.size,
    this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? context.coconutColors.loadingIndicatorColor;
    final resolvedSize = size ?? MediaQuery.of(context).size.width * 0.15;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Padding(
        padding: padding,
        // coconut_design_system의 CoconutCircularIndicator(Lottie 기반)는
        // 로티 패키지 자체의 resolveKeyPath null-check 버그로 인해
        // 앱 진입 시 크래시가 발생해서, 네이티브 CircularProgressIndicator로 대체함.
        child: SizedBox(
          width: resolvedSize,
          height: resolvedSize,
          child: CircularProgressIndicator(
            color: resolvedColor,
            backgroundColor: resolvedColor.withValues(alpha: 0.15),
            strokeWidth: strokeWidth ?? resolvedSize / 5.5,
            strokeCap: StrokeCap.round,
          ),
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
