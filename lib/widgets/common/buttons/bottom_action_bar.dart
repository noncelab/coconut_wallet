import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
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
  static const double _gradientExtensionAboveChild = 48;

  final Widget child;
  final EdgeInsetsGeometry? padding;

  const BottomActionBar({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? EdgeInsets.only(left: 16.0, right: 16.0, bottom: MediaQuery.paddingOf(context).bottom + 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.coconutColors.bottomActionBarBackground.withValues(alpha: 0.0),
            context.coconutColors.bottomActionBarBackground,
          ],
          stops: const [0.0, 0.6],
        ),
      ),
      child: Padding(padding: const EdgeInsets.only(top: _gradientExtensionAboveChild), child: child),
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
  @override
  Widget build(BuildContext context) {
    return ShrinkAnimationButton(
      onPressed: widget.onTap,
      isActive: widget.enabled,
      animationEndValue: 0.94,
      borderRadius: 12,
      defaultColor: Colors.transparent,
      disabledColor: Colors.transparent,
      pressedOverlayOpacity: 0,
      childBuilder: (_, isPressed) {
        final foregroundColor = _foregroundColor(isPressed);
        return SizedBox(
          width: double.infinity,
          height: widget.height ?? _defaultHeight,
          child: Center(
            child:
                widget.buttonLayout == BottomActionButtonLayout.horizontal
                    ? Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildIcon(foregroundColor),
                        SizedBox(width: widget.spacing),
                        _buildLabel(foregroundColor),
                      ],
                    )
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildIcon(foregroundColor),
                        SizedBox(height: widget.spacing),
                        _buildLabel(foregroundColor),
                      ],
                    ),
          ),
        );
      },
    );
  }

  double get _defaultHeight =>
      widget.buttonLayout == BottomActionButtonLayout.horizontal
          ? BottomActionButton.horizontalHeight
          : BottomActionButton.verticalHeight;

  Color _foregroundColor(bool isPressed) {
    if (!widget.enabled) return context.coconutColors.mutedText;
    return isPressed ? context.coconutColors.secondaryText : context.coconutColors.primaryText;
  }

  Widget _buildIcon(Color foregroundColor) {
    return SvgPicture.asset(
      widget.iconPath,
      width: widget.iconSize,
      height: widget.iconSize,
      colorFilter: ColorFilter.mode(foregroundColor, BlendMode.srcIn),
    );
  }

  Widget _buildLabel(Color foregroundColor) {
    return Text(
      widget.label,
      style: widget.textStyle.copyWith(color: foregroundColor),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
