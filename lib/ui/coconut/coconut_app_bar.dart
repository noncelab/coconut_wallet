import 'package:coconut_wallet/app/router/feature_entry_routes.dart';
import 'dart:io';
import 'dart:ui';
import 'package:coconut_wallet/constants/icon_path.dart';

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutUnderlinedButton;
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CoconutAppBar {
  static AppBar build({
    required BuildContext context,
    String title = '',
    EdgeInsets titlePadding = EdgeInsets.zero,
    Key? entireWidgetKey,
    Key? faucetIconKey,
    Color? backgroundColor,
    Color? foregroundColor,
    Color? leadingHighlightColor,
    bool isBottom = false,
    bool isLeadingVisible = true,
    bool showSubLabel = false,
    bool isBackButton = false,
    bool hasBackDropFilter = false,
    double? height,
    VoidCallback? onTitlePressed,
    VoidCallback? onBackPressed,
    Widget? subLabel,
    Widget? customTitle,
    List<Widget>? actionButtonList,
  }) {
    final colors = context.coconutColors;
    final brightness = Theme.of(context).brightness;
    final resolvedForegroundColor = foregroundColor ?? colors.primaryText;
    final titleWidget =
        customTitle != null
            ? GestureDetector(onTap: onTitlePressed, child: Padding(padding: titlePadding, child: customTitle))
            : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onTitlePressed == null)
                  Padding(
                    padding: titlePadding,
                    child: Text(title, style: CoconutTypography.body1_16.setColor(resolvedForegroundColor)),
                  )
                else
                  CoconutUnderlinedButton(
                    text: title,
                    onTap: onTitlePressed,
                    padding: titlePadding,
                    textStyle: CoconutTypography.body1_16,
                  ),
                if (showSubLabel) ...[
                  const SizedBox(height: 3),
                  FittedBox(fit: BoxFit.scaleDown, child: subLabel ?? const SizedBox.shrink()),
                ] else
                  const SizedBox(width: 1),
              ],
            );

    final leading = _AppBarLeading(
      iconKey: faucetIconKey,
      assetName:
          (isBottom && !isBackButton) || FeatureEntryRoutes.instance.contains(ModalRoute.of(context))
              ? CommonActionIconPath.close
              : CommonNavigationIconPath.arrowBack,
      iconColor: resolvedForegroundColor,
      highlightColor: leadingHighlightColor,
      onPressed: () {
        if (onBackPressed != null) {
          onBackPressed();
          return;
        }
        Navigator.pop(context);
      },
    );

    return AppBar(
      key: entireWidgetKey,
      systemOverlayStyle: _systemOverlayStyle(brightness),
      toolbarHeight: height ?? (isBottom ? 60 : 56),
      title: titleWidget,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      backgroundColor: backgroundColor ?? Colors.transparent,
      leading: Visibility(
        visible: isLeadingVisible && Navigator.canPop(context),
        maintainAnimation: true,
        maintainState: true,
        maintainSize: true,
        child: leading,
      ),
      actions: [
        if (actionButtonList != null)
          ...actionButtonList
        else
          Visibility(visible: false, maintainSize: true, maintainState: true, maintainAnimation: true, child: leading),
        CoconutLayout.spacing_300w,
      ],
      flexibleSpace:
          !isBottom && (backgroundColor == null || hasBackDropFilter)
              ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.transparent),
                ),
              )
              : const SizedBox.shrink(),
    );
  }

  static AppBar buildWithNext({
    required String title,
    required BuildContext context,
    required VoidCallback onNextPressed,
    bool isActive = true,
    bool isBottom = false,
    bool usePrimaryActiveColor = false,
    String nextButtonTitle = '다음',
    double? height,
    Color? backgroundColor,
    Color? foregroundColor,
    VoidCallback? onBackPressed,
    List<Widget>? actionButtonList,
    EdgeInsets? padding,
  }) {
    final colors = context.coconutColors;
    final brightness = Theme.of(context).brightness;
    final resolvedForegroundColor = foregroundColor ?? colors.primaryText;

    return AppBar(
      systemOverlayStyle: _systemOverlayStyle(brightness),
      title: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: Text(title, style: CoconutTypography.heading4_18.setColor(resolvedForegroundColor)),
      ),
      centerTitle: true,
      scrolledUnderElevation: 0,
      toolbarHeight: height ?? (isBottom ? 60 : 56),
      backgroundColor: backgroundColor ?? Colors.transparent,
      leading:
          Navigator.canPop(context)
              ? _AppBarLeading(
                assetName:
                    isBottom || FeatureEntryRoutes.instance.contains(ModalRoute.of(context))
                        ? CommonActionIconPath.close
                        : CommonNavigationIconPath.arrowBack,
                iconColor: resolvedForegroundColor,
                onPressed: () {
                  if (onBackPressed != null) {
                    onBackPressed();
                    return;
                  }
                  Navigator.pop(context);
                },
              )
              : null,
      actions: [
        if (actionButtonList != null) ...actionButtonList,
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: CoconutAppBarButton(
            isActive: isActive,
            isActivePrimaryColor: usePrimaryActiveColor,
            text: nextButtonTitle,
            onPressed: onNextPressed,
          ),
        ),
      ],
      flexibleSpace:
          !isBottom && backgroundColor == null
              ? ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.transparent),
                ),
              )
              : const SizedBox.shrink(),
    );
  }

  static SystemUiOverlayStyle _systemOverlayStyle(Brightness brightness) {
    final iconBrightness = brightness == Brightness.light ? Brightness.dark : Brightness.light;

    if (Platform.isIOS) {
      return SystemUiOverlayStyle(statusBarIconBrightness: iconBrightness);
    }

    return SystemUiOverlayStyle(statusBarIconBrightness: iconBrightness);
  }
}

class _AppBarLeading extends StatelessWidget {
  const _AppBarLeading({
    required this.assetName,
    required this.iconColor,
    required this.onPressed,
    this.iconKey,
    this.highlightColor,
  });

  final String assetName;
  final Color iconColor;
  final VoidCallback onPressed;
  final Key? iconKey;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: CoconutAppBarActionButton(
          buttonKey: iconKey,
          onPressed: onPressed,
          highlightColor: highlightColor,
          icon: SvgPicture.asset(
            assetName,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

/// 직접 그린 헤더용 뒤로가기 버튼. All Features·바로가기로 연 화면이면 닫기(X) 버튼으로 보여 준다.
class FeatureAwareBackButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color color;

  const FeatureAwareBackButton({super.key, required this.onPressed, required this.color});

  @override
  Widget build(BuildContext context) {
    if (!FeatureEntryRoutes.instance.contains(ModalRoute.of(context))) {
      return BackButton(onPressed: onPressed, color: color);
    }
    return IconButton(
      key: const Key('feature-aware-close-button'),
      onPressed: onPressed,
      icon: SvgPicture.asset(
        CommonActionIconPath.close,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}
