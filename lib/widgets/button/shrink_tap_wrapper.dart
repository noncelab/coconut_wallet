import 'package:flutter/material.dart';

/// 자식 위젯을 감싸서 탭 시 shrink 애니메이션을 적용하는 래퍼
///
/// [ShrinkAnimationButton]과 달리 배경색/테두리 스타일 없이
/// 순수하게 scale 애니메이션만 제공
class ShrinkTapWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double shrinkScale;
  final Duration duration;

  const ShrinkTapWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.shrinkScale = 0.90,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<ShrinkTapWrapper> createState() => _ShrinkTapWrapperState();
}

class _ShrinkTapWrapperState extends State<ShrinkTapWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.shrinkScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse().then((_) => widget.onTap?.call());
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}
