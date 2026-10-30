import 'dart:async';

import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

/// Reveals a search destination without invoking its action or changing its value.
class FeatureSearchFocus extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const FeatureSearchFocus({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<FeatureSearchFocus> createState() => _FeatureSearchFocusState();
}

class _FeatureSearchFocusState extends State<FeatureSearchFocus> {
  Animation<double>? _routeAnimation;
  Timer? _timer;
  bool _highlighted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _routeAnimation = ModalRoute.of(context)?.animation;
      if (_routeAnimation?.status == AnimationStatus.forward) {
        _routeAnimation!.addStatusListener(_onRouteStatus);
      } else {
        _reveal();
      }
    });
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _reveal();
  }

  Future<void> _reveal() async {
    if (!mounted) return;
    await Scrollable.ensureVisible(
      context,
      alignment: 0.5,
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() => _highlighted = true);
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlighted = false);
    });
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: _highlighted ? 1 : 0,
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.coconutColors.primaryText.withValues(alpha: 0.08),
                borderRadius: widget.borderRadius,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
