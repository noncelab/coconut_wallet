import 'package:flutter/material.dart';

class AnimatedDotsText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const AnimatedDotsText({super.key, required this.text, required this.style});

  @override
  State<AnimatedDotsText> createState() => _AnimatedDotsTextState();
}

class _AnimatedDotsTextState extends State<AnimatedDotsText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  }

  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) {
      _controller.reset();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dotsCount = _reduceMotion ? 3 : ((_controller.value * 4) % 4).floor();
        final dots = '.' * dotsCount;
        return Text('${widget.text}$dots', style: widget.style);
      },
    );
  }
}
