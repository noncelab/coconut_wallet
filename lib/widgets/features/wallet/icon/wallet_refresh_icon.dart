import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
      tween: ColorTween(
        end: widget.isRefreshing ? context.coconutColors.iconSecondary : context.coconutColors.iconPrimary,
      ),
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
