import 'package:flutter/material.dart';

class ShimmerText extends StatefulWidget {
  final String text;
  final Color color;
  final TextStyle textStyle;
  const ShimmerText({super.key, required this.text, required this.color, required this.textStyle});

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: false);

    _animation = Tween<double>(begin: -5.0, end: 5.0).animate(_controller);
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
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              colors: [widget.color.withOpacity(0.8), widget.color, widget.color.withOpacity(0.8)],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + _animation.value, 0),
              end: Alignment(1.0 + _animation.value, 0),
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: widget.textStyle,
          ),
        );
      },
    );
  }
}
