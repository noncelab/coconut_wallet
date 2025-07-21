import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:flutter/material.dart';

class ShrinkAnimationButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final VoidCallback? onLongPressed;
  final Color pressedColor;
  final Color defaultColor;
  final double borderRadius;
  final Border? border;
  final double borderWidth;
  final List<Color>? borderGradientColors;
  final double? animationEndValue;

  const ShrinkAnimationButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.onLongPressed,
    this.pressedColor = CoconutColors.gray900,
    this.defaultColor = CoconutColors.gray800,
    this.borderRadius = 24.0,
    this.borderWidth = 2.0,
    this.border,
    this.borderGradientColors,
    this.animationEndValue = 0.97,
  });

  @override
  State<ShrinkAnimationButton> createState() => _ShrinkAnimationButtonState();
}

class _ShrinkAnimationButtonState extends State<ShrinkAnimationButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _animation = Tween<double>(begin: 1.0, end: widget.animationEndValue)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse().then((_) {
      widget.onPressed();
      setState(() {
        _isPressed = false;
      });
    });
  }

  void _onTapCancel() {
    _controller.reverse();
    setState(() {
      _isPressed = false;
    });
  }

  void _onLongPress() {
    if (widget.onLongPressed != null) {
      widget.onLongPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onLongPress: _onLongPress,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: ScaleTransition(
          scale: _animation,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius + 2),
              gradient: widget.borderGradientColors != null
                  ? ColorUtil.getMultisigLinearGradient(widget.borderGradientColors!)
                  : null,
              border: widget.borderGradientColors == null
                  ? Border.all(color: _isPressed ? widget.pressedColor : widget.defaultColor)
                  : null,
            ),
            child: AnimatedContainer(
              margin: EdgeInsets.all(widget.borderGradientColors != null ? widget.borderWidth : 0),
              duration: const Duration(milliseconds: 100),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: _isPressed ? widget.pressedColor : widget.defaultColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
                child: widget.child,
              ),
            ),
          ),
        ));
  }
}
