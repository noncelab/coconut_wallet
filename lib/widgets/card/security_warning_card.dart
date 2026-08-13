import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const securityWarningDismissDuration = Duration(days: 7);

class SecurityWarningCard extends StatefulWidget {
  const SecurityWarningCard({
    super.key,
    required this.showDelay,
    required this.title,
    required this.description,
    required this.useUnbackedWalletGradient,
    required this.onTap,
    required this.onClosed,
    required this.icon,
  });

  final Duration showDelay;
  final String title;
  final String description;
  final Widget icon;
  final bool useUnbackedWalletGradient;
  final VoidCallback onTap;
  final VoidCallback onClosed;

  @override
  State<SecurityWarningCard> createState() => _SecurityWarningCardState();
}

class _SecurityWarningCardState extends State<SecurityWarningCard> with SingleTickerProviderStateMixin {
  static const _animationDuration = Duration(milliseconds: 240);

  late final AnimationController _controller;
  late final Animation<double> _animation;
  Timer? _showDelayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animationDuration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    _showDelayTimer = Timer(widget.showDelay, () {
      if (mounted) _controller.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _showDelayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    _showDelayTimer?.cancel();
    await _controller.reverse();
    if (!mounted) return;
    widget.onClosed();
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        widget.useUnbackedWalletGradient
            ? context.coconutColors.primaryText
            : context.coconutColors.appLockWarningForeground;
    final iconColor =
        widget.useUnbackedWalletGradient
            ? context.coconutColors.iconOnDanger
            : context.coconutColors.appLockWarningForeground;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        return ClipRect(
          child: Align(
            heightFactor: value,
            child: Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 4 * (1 - value)),
                child: Transform.scale(scale: 0.96 + (0.04 * value), child: child),
              ),
            ),
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          decoration: BoxDecoration(
            color: widget.useUnbackedWalletGradient ? null : context.coconutColors.appLockWarningBackground,
            gradient:
                widget.useUnbackedWalletGradient
                    ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [context.coconutColors.danger, const Color(0xFFE18A99)],
                    )
                    : null,
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: widget.icon),
              CoconutLayout.spacing_200w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: CoconutTypography.body1_16_Bold.setColor(textColor)),
                    const SizedBox(height: 10),
                    Text(widget.description, style: CoconutTypography.body3_12_Bold.setColor(textColor)),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: t.close,
                child: InkWell(
                  onTap: _close,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SvgPicture.asset(
                      'assets/svg/close-bold.svg',
                      width: 12,
                      height: 12,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
