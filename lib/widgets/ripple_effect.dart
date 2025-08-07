import 'package:flutter/material.dart';

class RippleEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? borderRadius;

  const RippleEffect({super.key, required this.child, this.borderRadius, this.onTap});

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect> {
  double _opacity = 1.0;

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _opacity = 0.5;
    });
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _opacity = 1.0;
    });
  }

  void _handleTapCancel() {
    setState(() {
      _opacity = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 0),
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: _opacity,
          child: widget.child,
        ),
      ),
    );
  }
}
