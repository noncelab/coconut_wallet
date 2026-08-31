import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class ShrinkAnimationButton extends StatefulWidget {
  final Widget? child;
  final Widget Function(BuildContext context, bool isPressed)? childBuilder;
  final VoidCallback onPressed;
  final VoidCallback? onLongPress;
  final Color? pressedColor;
  final Color? pressedOverlayColor;
  final double? pressedOverlayOpacity;
  final Color? defaultColor;
  final Color? disabledColor;
  final double borderRadius;
  final Border? border;
  final double borderWidth;
  final Gradient? borderGradient;
  final double? animationEndValue;
  final bool isActive;

  const ShrinkAnimationButton({
    super.key,
    this.child,
    this.childBuilder,
    required this.onPressed,
    this.onLongPress,
    this.pressedColor,
    this.pressedOverlayColor,
    this.pressedOverlayOpacity,
    this.defaultColor,
    this.disabledColor,
    this.borderRadius = 24.0,
    this.borderWidth = 2.0,
    this.border,
    this.borderGradient,
    this.animationEndValue = 0.97,
    this.isActive = true,
  }) : assert(child != null || childBuilder != null, 'Either child or childBuilder must be provided.');

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

  double _clampOpacity(double value) => value.clamp(0.0, 1.0);

  double _resolveOverlayOpacity(Color color) {
    if (widget.pressedOverlayOpacity != null) {
      return _clampOpacity(widget.pressedOverlayOpacity!);
    }
    if (color.a > 0 && color.a < 1) {
      return color.a;
    }
    return 0.12;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final overlayColor = (widget.pressedOverlayColor ?? colors.surfacePressOverlay).withValues(alpha: 1.0);
    final overlayOpacity =
        widget.pressedOverlayOpacity ??
        ((widget.pressedOverlayColor == null || widget.pressedOverlayColor == colors.surfacePressOverlay)
            ? colors.surfacePressOverlayOpacity
            : _resolveOverlayOpacity(widget.pressedOverlayColor!));
    final pressedColor = widget.pressedColor ?? colors.surfacePressOverlay;
    final defaultColor = widget.defaultColor ?? colors.surface;
    final disabledColor = widget.disabledColor ?? colors.surface;

    final Color solidColor = widget.isActive ? (_isPressed ? pressedColor : defaultColor) : disabledColor;
    final Color baseColor = widget.isActive ? defaultColor : disabledColor;
    final bool useGradientBorder = widget.borderGradient != null;
    final child = widget.childBuilder != null ? widget.childBuilder!(context, _isPressed) : widget.child!;

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
            border: useGradientBorder ? null : widget.border ?? Border.all(color: Colors.transparent),
          ),
          child: AnimatedContainer(
            margin: EdgeInsets.all(useGradientBorder ? widget.borderWidth : 0),
            duration: const Duration(milliseconds: 100),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color:
                  widget.isActive && _isPressed
                      ? Color.alphaBlend(overlayColor.withValues(alpha: overlayOpacity), baseColor)
                      : baseColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
