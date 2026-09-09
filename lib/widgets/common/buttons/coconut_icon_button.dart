import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

/// Common icon button wrapper for this app.
///
/// Prefer this over raw `IconButton` when the button should follow Coconut
/// theme defaults such as `iconButtonHighlight`.
///
/// Use this for:
/// - generic icon actions outside app bars
/// - close/remove buttons inside overlays, popups, and dialogs
///
/// Use [CoconutAppBarActionButton] instead when the button is an app-bar
/// action and should keep the standard 40x40 action hit area.
class CoconutIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? highlightColor;
  final Color? focusColor;
  final EdgeInsetsGeometry padding;
  final double? iconSize;
  final double? splashRadius;
  final BoxConstraints? constraints;
  final AlignmentGeometry alignment;
  final String? tooltip;

  const CoconutIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.highlightColor,
    this.focusColor,
    this.padding = EdgeInsets.zero,
    this.iconSize,
    this.splashRadius = 20,
    this.constraints,
    this.alignment = Alignment.center,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return IconButton(
      onPressed: onPressed,
      icon: icon,
      color: color,
      highlightColor: highlightColor ?? colors.iconButtonHighlight,
      focusColor: focusColor,
      padding: padding,
      iconSize: iconSize,
      splashRadius: splashRadius,
      constraints: constraints,
      alignment: alignment,
      tooltip: tooltip,
    );
  }
}

/// Standard app-bar action icon button.
///
/// This wraps [CoconutIconButton] and fixes the common 40x40 app-bar action
/// size used across the app.
///
/// Prefer this over raw `IconButton` for:
/// - app bar right-side action icons
/// - top-right action icons in bottom sheets that mimic app-bar actions
///
/// If a screen needs a special interaction model or non-standard hit area,
/// use [CoconutIconButton] directly and document the exception nearby.
class CoconutAppBarActionButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  final Color? color;
  final Color? highlightColor;
  final double size;

  const CoconutAppBarActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.buttonKey,
    this.color,
    this.highlightColor,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: buttonKey,
      width: size,
      height: size,
      child: CoconutIconButton(icon: icon, onPressed: onPressed, color: color, highlightColor: highlightColor),
    );
  }
}
