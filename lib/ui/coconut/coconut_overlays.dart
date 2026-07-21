import 'dart:async';
import 'dart:math' show pi;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum CoconutToastLevel {
  info,
  warning,
  error,
  success;

  Color borderColor(BuildContext context) {
    final colors = context.coconutColors;
    switch (this) {
      case CoconutToastLevel.info:
        return colors.borderStrong;
      case CoconutToastLevel.warning:
        return colors.warning;
      case CoconutToastLevel.error:
        return colors.danger;
      case CoconutToastLevel.success:
        return colors.success;
    }
  }

  Gradient borderGradient(BuildContext context) {
    final colors = context.coconutColors;
    return LinearGradient(
      colors: [borderColor(context), colors.popupBackground],
      transform: const GradientRotation(pi / 6),
    );
  }
}

class CoconutToast {
  static OverlayEntry? _currentToastOverlay;
  static bool _isToastVisible = false;

  static void showBottomToast({
    required BuildContext context,
    required String text,
    Color? backgroundColor,
    Color? borderColor,
    Color? textColor,
    int seconds = 2,
  }) {
    if (_isToastVisible) return;
    _isToastVisible = true;

    final colors = context.coconutColors;
    final fadeController = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 300),
    );

    final fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: fadeController, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)));

    late OverlayEntry overlayEntry;

    Future<void> dismiss({bool isDelay = false}) async {
      try {
        final limitSeconds = seconds <= 3 ? seconds : 3;
        if (isDelay) await Future.delayed(Duration(seconds: limitSeconds));
        await fadeController.forward();
        overlayEntry.remove();
        fadeController.dispose();
      } catch (_) {
      } finally {
        _isToastVisible = false;
      }
    }

    overlayEntry = OverlayEntry(
      builder:
          (overlayContext) => Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: FadeTransition(
                opacity: fadeAnimation,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      if ((details.primaryDelta ?? 0) > 5) {
                        dismiss();
                      }
                    },
                    child: MediaQuery(
                      data: MediaQuery.of(overlayContext).copyWith(textScaler: TextScaler.noScaling),
                      child: Container(
                        margin: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: MediaQuery.sizeOf(overlayContext).height / 13,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: backgroundColor ?? colors.primaryText,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor ?? colors.border, width: 0.5),
                        ),
                        child: Text(
                          text,
                          overflow: TextOverflow.ellipsis,
                          style: CoconutTypography.body2_14.copyWith(
                            decoration: TextDecoration.none,
                            color: textColor ?? colors.background,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
    );

    Overlay.of(context).insert(overlayEntry);
    unawaited(dismiss(isDelay: true));
  }

  static void showToast({
    required BuildContext context,
    required String text,
    bool isVisibleIcon = false,
    bool removePrevToast = true,
    int seconds = 3,
    double iconSize = 16,
    double iconRightPadding = 4,
    double textPadding = 3.5,
    TextStyle textStyle = CoconutTypography.body2_14,
    Color? backgroundColor,
    Color? borderColor,
    Color? textColor,
    String? iconPath,
    CoconutToastLevel level = CoconutToastLevel.info,
  }) {
    if (removePrevToast && _currentToastOverlay != null) {
      try {
        _currentToastOverlay?.remove();
      } catch (_) {}
      _currentToastOverlay = null;
      _isToastVisible = false;
    } else if (_isToastVisible) {
      return;
    }

    _isToastVisible = true;
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder:
          (overlayContext) => Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: _CoconutToastWidget(
                  context: overlayContext,
                  text: text,
                  isVisibleIcon: isVisibleIcon,
                  backgroundColor: backgroundColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  iconColor:
                      borderColor ??
                      (level == CoconutToastLevel.info
                          ? textColor ?? overlayContext.coconutColors.primaryText
                          : level.borderColor(overlayContext)),
                  iconPath: iconPath,
                  iconSize: iconSize,
                  iconRightPadding: iconRightPadding,
                  textStyle: textStyle,
                  textPadding: textPadding,
                  level: level,
                  onDismiss: () {
                    overlayEntry.remove();
                    _currentToastOverlay = null;
                  },
                  duration: seconds <= 5 ? seconds : 5,
                ),
              ),
            ),
          ),
    );

    Overlay.of(context, rootOverlay: true).insert(overlayEntry);
    _currentToastOverlay = overlayEntry;
  }

  @Deprecated('Use showToast() with level: CoconutToastLevel.warning instead.')
  static void showWarningToast({
    required BuildContext context,
    required String text,
    bool removePrevToast = true,
    int seconds = 5,
    double iconSize = 16,
    double iconRightPadding = 4,
    double textPadding = 3.5,
    Color? backgroundColor,
    Color? borderColor,
    TextStyle textStyle = CoconutTypography.body2_14,
  }) {
    showToast(
      context: context,
      text: text,
      isVisibleIcon: true,
      removePrevToast: removePrevToast,
      seconds: seconds,
      iconSize: iconSize,
      iconRightPadding: iconRightPadding,
      textPadding: textPadding,
      textStyle: textStyle,
      backgroundColor: backgroundColor ?? context.coconutColors.tooltipBackground,
      borderColor: borderColor ?? context.coconutColors.warning,
      textColor: context.coconutColors.primaryText,
      iconPath: 'packages/coconut_design_system/assets/svg/triangle_warning.svg',
      level: CoconutToastLevel.warning,
    );
  }
}

class _CoconutToastWidget extends StatefulWidget {
  const _CoconutToastWidget({
    required this.context,
    required this.text,
    required this.isVisibleIcon,
    required this.duration,
    required this.onDismiss,
    required this.iconColor,
    required this.level,
    this.iconSize = 16,
    this.iconRightPadding = 4,
    this.textPadding = 3.5,
    this.textStyle = CoconutTypography.body2_14,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.iconPath,
  });

  final BuildContext context;
  final String text;
  final bool isVisibleIcon;
  final int duration;
  final VoidCallback onDismiss;
  final double iconSize;
  final double iconRightPadding;
  final double textPadding;
  final TextStyle textStyle;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final Color iconColor;
  final String? iconPath;
  final CoconutToastLevel level;

  @override
  State<_CoconutToastWidget> createState() => _CoconutToastWidgetState();
}

class _CoconutToastWidgetState extends State<_CoconutToastWidget> with SingleTickerProviderStateMixin {
  static const double _initialOffsetY = 12.0;
  static const double _dismissOffsetY = -80.0;

  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _slideAnimation = Tween<double>(
      begin: _initialOffsetY,
      end: _dismissOffsetY,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.4,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(Duration(seconds: widget.duration), () {
      if (mounted) {
        _startFadeOut();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startFadeOut() {
    _controller.forward().then((_) {
      CoconutToast._isToastVisible = false;
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.context.coconutColors;

    return AnimatedBuilder(
      animation: _controller,
      builder:
          (context, child) => Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(opacity: _fadeAnimation.value, child: child),
          ),
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if ((details.primaryDelta ?? 0) < -5) {
            _startFadeOut();
          }
        },
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 24, 12, 12),
              width: double.maxFinite,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: widget.borderColor != null ? null : widget.level.borderGradient(widget.context),
                color: widget.borderColor,
                boxShadow: [
                  BoxShadow(
                    color: colors.shadowDefault.withValues(alpha: 0.18),
                    blurRadius: 16,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(0.5),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 13),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? colors.popupBackground,
                  borderRadius: BorderRadius.circular(11.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isVisibleIcon)
                      Container(
                        height: (widget.textStyle.fontSize ?? 14) * (widget.textStyle.height ?? 1.4),
                        padding: EdgeInsets.only(right: widget.iconRightPadding),
                        child: Center(
                          child: SvgPicture.asset(
                            widget.iconPath ?? 'packages/coconut_design_system/assets/svg/circle_info.svg',
                            height: widget.iconSize,
                            colorFilter: ColorFilter.mode(widget.iconColor, BlendMode.srcIn),
                          ),
                        ),
                      )
                    else
                      SizedBox(height: widget.iconSize),
                    Flexible(
                      child: Text(
                        widget.text,
                        style: widget.textStyle.copyWith(
                          decoration: TextDecoration.none,
                          color: widget.textColor ?? colors.primaryText,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum CoconutTooltipState {
  info('info', 'packages/coconut_design_system/assets/svg/tooltip/info.svg'),
  normal('normal', 'packages/coconut_design_system/assets/svg/tooltip/normal.svg'),
  success('success', 'packages/coconut_design_system/assets/svg/tooltip/success.svg'),
  warning('warning', 'packages/coconut_design_system/assets/svg/tooltip/warning.svg'),
  error('error', 'packages/coconut_design_system/assets/svg/tooltip/error.svg');

  final String code;
  final String svgPath;
  const CoconutTooltipState(this.code, this.svgPath);
}

enum CoconutTooltipType { placement, fixed, fixedClosable }

class CoconutToolTip extends StatefulWidget {
  const CoconutToolTip({
    super.key,
    required this.tooltipType,
    required this.richText,
    this.tooltipState = CoconutTooltipState.info,
    this.isAvailableTapToClose = true,
    this.showIcon = true,
    this.icon,
    this.baseBackgroundColor = Colors.transparent,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.onTapRemove,
    this.padding,
    this.isBubbleClipperSideLeft = true,
    this.isPlacementTooltipVisible = false,
    this.animateOnBuild = false,
    this.width,
    this.iconPosition = Offset.zero,
    this.iconSize = Size.zero,
    this.titleStyle = CoconutTypography.caption_10,
  }) : assert(
         tooltipType != CoconutTooltipType.placement || (width != null && onTapRemove != null),
         'When using CoconutTooltipType.placement, width and onTapRemove must not be null.',
       );

  final CoconutTooltipType tooltipType;
  final CoconutTooltipState tooltipState;
  final RichText richText;
  final bool showIcon;
  final Widget? icon;
  final Color? baseBackgroundColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderRadius;
  final VoidCallback? onTapRemove;
  final EdgeInsets? padding;
  final double? width;
  final Offset iconPosition;
  final Size iconSize;
  final bool? isAvailableTapToClose;
  final bool isBubbleClipperSideLeft;
  final bool isPlacementTooltipVisible;
  final bool animateOnBuild;
  final TextStyle titleStyle;

  @override
  State<CoconutToolTip> createState() => _CoconutToolTipState();
}

class _CoconutToolTipState extends State<CoconutToolTip> {
  bool _isVisibleAnimated = false;
  late Color _borderColor;
  late Color _backgroundColor;
  late EdgeInsets _padding;
  SvgPicture? _icon;
  late Color _accentColor;

  @override
  void initState() {
    super.initState();
    if (widget.tooltipType == CoconutTooltipType.fixed) {
      _padding = widget.padding ?? const EdgeInsets.all(CoconutLayout.defaultPadding);
    } else if (widget.tooltipType == CoconutTooltipType.fixedClosable) {
      _padding = widget.padding ?? const EdgeInsets.all(Sizes.size12);
    } else {
      _padding = widget.padding ?? const EdgeInsets.only(top: 25, left: 18, right: 18, bottom: 10);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.isPlacementTooltipVisible) {
          _showTooltip();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initColors();
    if (widget.tooltipType == CoconutTooltipType.fixed) {
      _icon = SvgPicture.asset(
        widget.tooltipState.svgPath,
        colorFilter: ColorFilter.mode(_accentColor, BlendMode.srcIn),
        width: 18,
      );
    }
  }

  @override
  void didUpdateWidget(covariant CoconutToolTip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initColors();

    if (widget.isPlacementTooltipVisible != oldWidget.isPlacementTooltipVisible) {
      widget.isPlacementTooltipVisible ? _showTooltip() : _hideTooltip();
    }
  }

  void _initColors() {
    final colors = context.coconutColors;
    _accentColor = _resolveTooltipAccentColor(colors);

    if (widget.tooltipType == CoconutTooltipType.fixed) {
      _borderColor = widget.borderColor ?? _accentColor.withValues(alpha: 0.7);
      _backgroundColor = widget.backgroundColor ?? _resolveTooltipFillColor(colors).withValues(alpha: 0.22);
      return;
    }

    _borderColor = widget.borderColor ?? colors.popoverBackground;
    _backgroundColor = widget.backgroundColor ?? colors.popoverBackground;
  }

  Color _resolveTooltipAccentColor(dynamic colors) {
    switch (widget.tooltipState) {
      case CoconutTooltipState.info:
        return colors.primary;
      case CoconutTooltipState.normal:
        return colors.secondaryText;
      case CoconutTooltipState.success:
        return colors.success;
      case CoconutTooltipState.warning:
        return colors.warning;
      case CoconutTooltipState.error:
        return colors.danger;
    }
  }

  Color _resolveTooltipFillColor(dynamic colors) {
    switch (widget.tooltipState) {
      case CoconutTooltipState.info:
        return colors.infoChipBackground;
      case CoconutTooltipState.normal:
        return colors.surfaceMuted;
      case CoconutTooltipState.success:
        return colors.success;
      case CoconutTooltipState.warning:
        return colors.warning;
      case CoconutTooltipState.error:
        return colors.danger;
    }
  }

  void _showTooltip() => setState(() => _isVisibleAnimated = true);
  void _hideTooltip() => setState(() => _isVisibleAnimated = false);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    switch (widget.tooltipType) {
      case CoconutTooltipType.placement:
        return Visibility(
          visible: widget.isPlacementTooltipVisible,
          child: AnimatedOpacity(
            opacity: widget.animateOnBuild ? (_isVisibleAnimated ? 1.0 : 0.0) : 1.0,
            duration: const Duration(milliseconds: 1000),
            child: GestureDetector(
              onTap: widget.onTapRemove,
              child: ClipPath(
                clipper: widget.isBubbleClipperSideLeft ? LeftTriangleBubbleClipper() : RightTriangleBubbleClipper(),
                child: Container(
                  padding: _padding,
                  color: _backgroundColor,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: widget.richText)]),
                ),
              ),
            ),
          ),
        );
      case CoconutTooltipType.fixed:
        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: widget.baseBackgroundColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius ?? CoconutStyles.radius_250),
                ),
              ),
            ),
            Container(
              padding: _padding,
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(widget.borderRadius ?? CoconutStyles.radius_250),
                border: Border.all(width: 1, color: _borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showIcon)
                    if (widget.icon != null)
                      Padding(padding: const EdgeInsets.only(right: 8), child: widget.icon)
                    else
                      Padding(padding: const EdgeInsets.only(right: 8), child: _icon),
                  Expanded(child: widget.richText),
                ],
              ),
            ),
          ],
        );
      case CoconutTooltipType.fixedClosable:
        return LayoutBuilder(
          builder:
              (context, constraints) => Container(
                constraints: BoxConstraints(minHeight: Sizes.size60, minWidth: widget.width ?? constraints.maxWidth),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius ?? CoconutStyles.radius_250),
                  border: Border.all(width: 1, color: _borderColor),
                ),
                child: Stack(
                  children: [
                    Padding(padding: _padding, child: widget.richText),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton(
                        iconSize: 16,
                        onPressed: widget.onTapRemove,
                        icon: SvgPicture.asset(
                          'packages/coconut_design_system/assets/svg/close.svg',
                          colorFilter: ColorFilter.mode(colors.popoverText, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        );
    }
  }
}

class CoconutPopup extends StatefulWidget {
  const CoconutPopup({
    super.key,
    required this.title,
    required this.description,
    required this.onTapRight,
    required this.languageCode,
    this.leftButtonText,
    this.rightButtonText,
    this.centerTitle = true,
    this.centerDescription = true,
    this.useFixedFontSize = true,
    this.onTapLeft,
    this.backgroundColor,
    this.titleColor,
    this.descriptionColor,
    this.leftButtonColor,
    this.rightButtonColor,
    this.titleTextStyle,
    this.descriptionTextStyle,
    this.leftButtonTextStyle,
    this.rightButtonTextStyle,
    this.titlePadding,
    this.descriptionPadding,
    this.insetPadding,
  });

  final String title;
  final Function onTapRight;
  final String description;
  final Function? onTapLeft;
  final String? leftButtonText;
  final String? rightButtonText;
  final bool centerTitle;
  final bool centerDescription;
  final bool useFixedFontSize;
  final Color? backgroundColor;
  final Color? titleColor;
  final Color? descriptionColor;
  final Color? leftButtonColor;
  final Color? rightButtonColor;
  final TextStyle? titleTextStyle;
  final TextStyle? descriptionTextStyle;
  final TextStyle? leftButtonTextStyle;
  final TextStyle? rightButtonTextStyle;
  final EdgeInsets? titlePadding;
  final EdgeInsets? descriptionPadding;
  final EdgeInsets? insetPadding;
  final String languageCode;

  @override
  State<CoconutPopup> createState() => _CoconutPopupState();
}

class _CoconutPopupState extends State<CoconutPopup> {
  bool _isLeftButtonPressing = false;
  bool _isRightButtonPressing = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    final content = Container(
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? colors.popupBackground,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: IntrinsicHeight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: widget.titlePadding ?? const EdgeInsets.only(top: 24, bottom: 12),
              child: Text(
                widget.title,
                style:
                    widget.titleTextStyle?.setColor(widget.titleColor ?? colors.primaryText) ??
                    CoconutTypography.heading4_18_Bold.setColor(widget.titleColor ?? colors.primaryText),
                textAlign: widget.centerTitle ? TextAlign.center : null,
              ),
            ),
            Container(
              alignment: Alignment.topCenter,
              padding: widget.descriptionPadding ?? const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 12),
              constraints: const BoxConstraints(minHeight: 66),
              child: Text(
                widget.description,
                textAlign: widget.centerDescription ? TextAlign.center : null,
                style:
                    widget.descriptionTextStyle?.setColor(widget.descriptionColor ?? colors.secondaryText) ??
                    CoconutTypography.heading4_18.setColor(widget.descriptionColor ?? colors.secondaryText),
              ),
            ),
            Row(
              children: [
                if (widget.onTapLeft != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _isLeftButtonPressing = false);
                        widget.onTapLeft?.call();
                      },
                      onTapCancel: () => setState(() => _isLeftButtonPressing = false),
                      onTapDown: (_) => setState(() => _isLeftButtonPressing = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: _isLeftButtonPressing ? colors.surfacePressed : Colors.transparent,
                        alignment: Alignment.center,
                        child: Text(
                          widget.leftButtonText ?? _getLeftButtonText(),
                          style:
                              widget.leftButtonTextStyle?.setColor(widget.leftButtonColor ?? colors.primaryText) ??
                              CoconutTypography.body1_16_Bold.setColor(widget.leftButtonColor ?? colors.primaryText),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _isRightButtonPressing = false);
                      widget.onTapRight.call();
                    },
                    onTapCancel: () => setState(() => _isRightButtonPressing = false),
                    onTapDown: (_) => setState(() => _isRightButtonPressing = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: _isRightButtonPressing ? colors.surfacePressed : Colors.transparent,
                      alignment: Alignment.center,
                      child: Text(
                        widget.rightButtonText ?? _getRightButtonText(),
                        style:
                            widget.rightButtonTextStyle?.setColor(widget.rightButtonColor ?? colors.primaryText) ??
                            CoconutTypography.body1_16_Bold.setColor(widget.rightButtonColor ?? colors.primaryText),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Dialog(
      insetPadding: widget.insetPadding,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child:
            widget.useFixedFontSize
                ? MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
                  child: content,
                )
                : content,
      ),
    );
  }

  String _getLeftButtonText() {
    switch (widget.languageCode) {
      case 'ko':
      case 'kr':
        return '취소';
      case 'jp':
        return 'キャンセル';
      case 'es':
        return 'Cancelar';
      case 'en':
      default:
        return 'Cancel';
    }
  }

  String _getRightButtonText() {
    switch (widget.languageCode) {
      case 'ko':
      case 'kr':
        return '확인';
      case 'jp':
        return '確認';
      case 'es':
        return 'Aceptar';
      case 'en':
      default:
        return 'OK';
    }
  }
}
