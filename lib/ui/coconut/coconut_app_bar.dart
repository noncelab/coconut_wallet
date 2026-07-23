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
    final titleWidget =
        customTitle != null
            ? GestureDetector(onTap: onTitlePressed, child: Padding(padding: titlePadding, child: customTitle))
            : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onTitlePressed == null)
                  Padding(
                    padding: titlePadding,
                    child: Text(title, style: CoconutTypography.body1_16.setColor(colors.primaryText)),
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
      assetName: isBottom && !isBackButton ? CommonActionIconPath.close : CommonNavigationIconPath.arrowBack,
      iconColor: colors.primaryText,
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
    VoidCallback? onBackPressed,
    List<Widget>? actionButtonList,
    EdgeInsets? padding,
  }) {
    final colors = context.coconutColors;
    final brightness = Theme.of(context).brightness;

    return AppBar(
      systemOverlayStyle: _systemOverlayStyle(brightness),
      title: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: Text(title, style: CoconutTypography.heading4_18.setColor(colors.primaryText)),
      ),
      centerTitle: true,
      scrolledUnderElevation: 0,
      toolbarHeight: height ?? (isBottom ? 60 : 56),
      backgroundColor: backgroundColor ?? Colors.transparent,
      leading:
          Navigator.canPop(context)
              ? _AppBarLeading(
                assetName: isBottom ? CommonActionIconPath.close : CommonNavigationIconPath.arrowBack,
                iconColor: colors.primaryText,
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
  const _AppBarLeading({required this.assetName, required this.iconColor, required this.onPressed, this.iconKey});

  final String assetName;
  final Color iconColor;
  final VoidCallback onPressed;
  final Key? iconKey;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: CoconutAppBarActionButton(
          buttonKey: iconKey,
          onPressed: onPressed,
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
