import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class FloatingWidget extends StatefulWidget {
  final Widget child;
  final int? delayMilliseconds;
  const FloatingWidget({super.key, required this.child, this.delayMilliseconds});

  @override
  _FloatingSvgAnimationState createState() => _FloatingSvgAnimationState();
}

class _FloatingSvgAnimationState extends State<FloatingWidget> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  Key? _previousChildKey;

  @override
  void initState() {
    super.initState();
    _previousChildKey = widget.child.key;
    _setupAnimation();
  }

  void _setupAnimation() {
    _animationController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _animation = Tween<double>(
      begin: -1.0,
      end: 10.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delayMilliseconds ?? 0), () {
      if (mounted) {
        _animationController.repeat(reverse: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant FloatingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child.key != _previousChildKey) {
      _previousChildKey = widget.child.key;
      _animationController.dispose();
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animation.value),
              child: ShaderMask(
                shaderCallback:
                    (bounds) => LinearGradient(
                      colors: [
                        CoconutColors.white.withOpacity(0.7),
                        Colors.transparent,
                        CoconutColors.black.withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                blendMode: BlendMode.srcATop,
                child: widget.child,
              ),
            );
          },
        ),
      ],
    );
  }
}
