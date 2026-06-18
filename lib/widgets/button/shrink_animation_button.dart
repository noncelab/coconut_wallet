import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class ShrinkAnimationButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final Color pressedColor;
  final Color defaultColor;
  final Color disabledColor;
  final double borderRadius;
  final Border? border;
  final double borderWidth;
  final Gradient? borderGradient;
  final double? animationEndValue;
  final bool isActive;

  const ShrinkAnimationButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.onLongPress,
    this.pressedColor = CoconutColors.gray900,
    this.defaultColor = CoconutColors.gray800,
    this.disabledColor = CoconutColors.gray800,
    this.borderRadius = 24.0,
    this.borderWidth = 2.0,
    this.border,
    this.borderGradient,
    this.animationEndValue = 0.97,
    this.isActive = true,
  });

  @override
  State<ShrinkAnimationButton> createState() => _ShrinkAnimationButtonState();
}

class _ShrinkAnimationButtonState extends State<ShrinkAnimationButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _animation = Tween<double>(
      begin: 1.0,
      end: widget.animationEndValue,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!widget.isActive) return;

    setState(() {
      _isPressed = true;
    });
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.isActive) return;

    _controller.reverse().then((_) {
      widget.onPressed();
      setState(() {
        _isPressed = false;
      });
    });
  }

  void _onTapCancel() {
    if (!widget.isActive) return;

    _controller.reverse();
    setState(() {
      _isPressed = false;
    });
  }

  void _onLongPress() {
    if (!widget.isActive || widget.onLongPress == null) return;

    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    final Color solidColor =
        widget.isActive ? (_isPressed ? widget.pressedColor : widget.defaultColor) : widget.disabledColor;
    final bool useGradientBorder = widget.borderGradient != null;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.onLongPress != null ? _onLongPress : null,
      child: ScaleTransition(
        scale: _animation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius + 2),
            gradient: useGradientBorder ? widget.borderGradient : null,
            border: useGradientBorder ? null : Border.all(color: solidColor),
          ),
          child: AnimatedContainer(
            margin: EdgeInsets.all(useGradientBorder ? widget.borderWidth : 0),
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.borderRadius)),
            child: Container(
              decoration: BoxDecoration(color: solidColor, borderRadius: BorderRadius.circular(widget.borderRadius)),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
