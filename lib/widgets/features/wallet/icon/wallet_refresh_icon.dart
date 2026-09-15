import 'dart:async';

import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WalletRefreshIndicator extends StatefulWidget {
  const WalletRefreshIndicator({super.key, required this.isRefreshing});

  final bool isRefreshing;

  @override
  State<WalletRefreshIndicator> createState() => _WalletRefreshIndicatorState();
}

class _WalletRefreshIndicatorState extends State<WalletRefreshIndicator> {
  Timer? _hideTimer;
  late bool _isVisible;

  @override
  void initState() {
    super.initState();
    _isVisible = widget.isRefreshing;
  }

  @override
  void didUpdateWidget(covariant WalletRefreshIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRefreshing == widget.isRefreshing) return;
    _hideTimer?.cancel();
    if (widget.isRefreshing) {
      _isVisible = true;
    } else {
      _hideTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _isVisible = false);
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: _isVisible ? 1 : 0),
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeInOut,
    builder:
        (context, value, child) => IgnorePointer(
          child: Align(
            widthFactor: value > 0 ? 1 : 0,
            child: Opacity(opacity: value, child: TickerMode(enabled: value > 0, child: child!)),
          ),
        ),
    child: SizedBox(
      width: 48,
      height: 48,
      child: Center(child: WalletRefreshIcon(isRefreshing: widget.isRefreshing, size: 20)),
    ),
  );
}

class WalletRefreshIcon extends StatefulWidget {
  const WalletRefreshIcon({super.key, required this.isRefreshing, this.size = 18});

  final bool isRefreshing;
  final double size;

  @override
  State<WalletRefreshIcon> createState() => _WalletRefreshIconState();
}

class _WalletRefreshIconState extends State<WalletRefreshIcon> with SingleTickerProviderStateMixin {
  static const _rotationDuration = Duration(milliseconds: 520);
  static const _pauseDuration = Duration(milliseconds: 180);

  late final AnimationController _rotationController;
  int _animationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(vsync: this, duration: _rotationDuration);
    if (widget.isRefreshing) _startRotationLoop();
  }

  @override
  void didUpdateWidget(covariant WalletRefreshIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isRefreshing && widget.isRefreshing) {
      _startRotationLoop();
    } else if (oldWidget.isRefreshing && !widget.isRefreshing) {
      _animationGeneration++;
      _rotationController.stop();
    }
  }

  Future<void> _startRotationLoop() async {
    final generation = ++_animationGeneration;
    try {
      do {
        await _rotationController.forward(from: 0).orCancel;
        if (!mounted || generation != _animationGeneration || !widget.isRefreshing) break;
        await Future<void>.delayed(_pauseDuration);
      } while (mounted && generation == _animationGeneration && widget.isRefreshing);
    } on TickerCanceled {
      return;
    }

    if (mounted && generation == _animationGeneration) {
      _rotationController.value = 0;
    }
  }

  @override
  void dispose() {
    _animationGeneration++;
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 180),
      tween: ColorTween(end: context.coconutColors.primary),
      builder: (context, color, _) {
        return RotationTransition(
          turns: _rotationController,
          child: SvgPicture.asset(
            CommonActionIconPath.rotate,
            width: widget.size,
            height: widget.size,
            colorFilter: ColorFilter.mode(color ?? context.coconutColors.iconPrimary, BlendMode.srcIn),
          ),
        );
      },
    );
  }
}
