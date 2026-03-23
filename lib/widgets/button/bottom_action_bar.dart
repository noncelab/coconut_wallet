import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// utxo list screen, utxo overview screen, wallet detail screen에서 사용
enum BottomActionButtonLayout { horizontal, vertical }

class BottomActionBarSlide extends StatelessWidget {
  final bool isVisible;
  final Widget child;
  final Duration duration;
  final Curve curve;

  const BottomActionBarSlide({
    super.key,
    required this.isVisible,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: IgnorePointer(
          ignoring: !isVisible,
          child: AnimatedSlide(
            duration: duration,
            curve: curve,
            offset: isVisible ? Offset.zero : const Offset(0, 1),
            child: child,
          ),
        ),
      ),
    );
  }
}

class BottomActionBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const BottomActionBar({super.key, required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xFF1D1D1D), Color(0xFF1D1D1D)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}

class BottomActionButton extends StatefulWidget {
  static const double horizontalHeight = 44;
  static const double verticalHeight = 64;

  final String iconPath;
  final String label;
  final VoidCallback onTap;
  final BottomActionButtonLayout buttonLayout;
  final bool enabled;
  final double? height;
  final double iconSize;
  final double spacing;
  final TextStyle textStyle;

  const BottomActionButton({
    super.key,
    required this.iconPath,
    required this.label,
    required this.onTap,
    required this.buttonLayout,
    required this.textStyle,
    this.enabled = true,
    this.height,
    this.iconSize = 20,
    this.spacing = 8,
  });

  @override
  State<BottomActionButton> createState() => _BottomActionButtonState();
}

class _BottomActionButtonState extends State<BottomActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (isPressed) {
          if (!widget.enabled || _isPressed == isPressed) return;
          setState(() => _isPressed = isPressed);
        },
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: SizedBox(
          width: double.infinity,
          height: widget.height ?? _defaultHeight,
          child: AnimatedScale(
            scale: _isPressed && widget.enabled ? 0.94 : 1,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
            child: Center(
              child:
                  widget.buttonLayout == BottomActionButtonLayout.horizontal
                      ? Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [_buildIcon(), SizedBox(width: widget.spacing), _buildLabel()],
                      )
                      : Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [_buildIcon(), SizedBox(height: widget.spacing), _buildLabel()],
                      ),
            ),
          ),
        ),
      ),
    );
  }

  double get _defaultHeight =>
      widget.buttonLayout == BottomActionButtonLayout.horizontal
          ? BottomActionButton.horizontalHeight
          : BottomActionButton.verticalHeight;

  Color get _foregroundColor {
    if (!widget.enabled) return CoconutColors.gray600;
    return _isPressed ? CoconutColors.gray400 : CoconutColors.white;
  }

  Widget _buildIcon() {
    return SvgPicture.asset(
      widget.iconPath,
      width: widget.iconSize,
      height: widget.iconSize,
      colorFilter: ColorFilter.mode(_foregroundColor, BlendMode.srcIn),
    );
  }

  Widget _buildLabel() {
    return Text(
      widget.label,
      style: widget.textStyle.copyWith(color: _foregroundColor),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
