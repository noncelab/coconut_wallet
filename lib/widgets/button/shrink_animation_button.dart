import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

class ShrinkAnimationButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final Color? pressedColor;
  final Color? defaultColor;
  final double borderRadius;
  final Border? border;
  final double borderWidth;
  final List<Color>? borderGradientColors;

  const ShrinkAnimationButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.pressedColor = MyColors.darkgrey,
    this.defaultColor = MyColors.defaultBackground,
    this.borderRadius = 28.0,
    this.borderWidth = 2.0,
    this.border,
    this.borderGradientColors,
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
    _animation = Tween<double>(begin: 1.0, end: 0.97)
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: ScaleTransition(
          scale: _animation,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius + 2),
              gradient: widget.borderGradientColors != null
                  ? BoxDecorations.getMultisigLinearGradient(
                      widget.borderGradientColors!)
                  : null,
            ),
            child: AnimatedContainer(
              margin: EdgeInsets.all(widget.borderWidth),
              duration: const Duration(milliseconds: 100),
              decoration: BoxDecoration(
                color: MyColors.black,
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
