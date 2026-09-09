import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class CheckboxCard extends StatefulWidget {
  final String title;
  final List<TextSpan> subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showBorder;
  final bool isEnabled;

  const CheckboxCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.showBorder = false,
    this.isEnabled = true,
  });

  @override
  State<CheckboxCard> createState() => _CheckboxCardState();
}

class _CheckboxCardState extends State<CheckboxCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!widget.isEnabled) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        widget.isSelected ? context.coconutColors.primaryText : context.coconutColors.border.withValues(alpha: 0.7);
    final titleColor = widget.isEnabled ? context.coconutColors.primaryText : context.coconutColors.mutedText;
    final subtitleColor = widget.isEnabled ? context.coconutColors.secondaryText : context.coconutColors.mutedText;

    final double scale = (_isPressed && widget.isEnabled) ? 0.96 : 1.0;

    final clampedTextScaler = TextScaler.linear(MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.2));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.isEnabled ? _handleTapDown : null,
      onTapUp: widget.isEnabled ? _handleTapUp : null,
      onTapCancel: widget.isEnabled ? _handleTapCancel : null,
      onTap: widget.isEnabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration:
              widget.showBorder
                  ? BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1),
                  )
                  : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CoconutCheckbox(
                    isSelected: widget.isSelected,
                    onChanged: (_) => widget.onTap(),
                    width: 16,
                    color: context.coconutColors.iconPrimary,
                    unSelectedColor: context.coconutColors.iconPrimary,
                    inactiveColor: context.coconutColors.iconDisabled,
                    isDisabled: !widget.isEnabled,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: CoconutTypography.body2_14.setColor(titleColor),
                      textScaler: clampedTextScaler,
                    ),
                  ),
                ],
              ),
              if (widget.subtitle.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text.rich(
                    TextSpan(style: CoconutTypography.body3_12.setColor(subtitleColor), children: widget.subtitle),
                    textScaler: clampedTextScaler,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
