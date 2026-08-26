import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class OptionCard extends StatefulWidget {
  final String title;
  final List<TextSpan> subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showBorder;
  final bool isEnabled;

  const OptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.showBorder = false,
    this.isEnabled = true,
  });

  @override
  State<OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<OptionCard> {
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
        !widget.isEnabled
            ? context.coconutColors.iconDisabled
            : (widget.isSelected || _isPressed)
            ? context.coconutColors.primaryText
            : context.coconutColors.border;
    final titleColor = widget.isEnabled ? context.coconutColors.primaryText : context.coconutColors.mutedText;
    final subtitleColor = widget.isEnabled ? context.coconutColors.secondaryText : context.coconutColors.mutedText;

    final double scale = (_isPressed && widget.isEnabled) ? 0.96 : 1.0;

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration:
              widget.showBorder
                  ? BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1),
                  )
                  : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: CoconutCheckbox(
                  isSelected: widget.isSelected || _isPressed,
                  onChanged: (_) => widget.onTap(),
                  width: 20,
                  color: context.coconutColors.iconDefault,
                  unSelectedColor: context.coconutColors.iconSubDefault,
                  inactiveColor: context.coconutColors.iconDisabled,
                  isDisabled: !widget.isEnabled,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: CoconutTypography.body2_14.setColor(titleColor)),
                    if (widget.subtitle.isNotEmpty) ...[
                      CoconutLayout.spacing_50h,
                      Text.rich(
                        TextSpan(style: CoconutTypography.body3_12.setColor(subtitleColor), children: widget.subtitle),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
