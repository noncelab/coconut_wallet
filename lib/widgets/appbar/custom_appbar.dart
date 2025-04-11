import 'dart:ui';

import 'package:coconut_wallet/widgets/button/custom_appbar_button.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/label_testnet.dart';

class CustomAppBar {
  static AppBar build({
    required String title,
    required BuildContext context,
    required bool hasRightIcon,
    Key? entireWidgetKey,
    Key? faucetIconKey,
    VoidCallback? onFaucetIconPressed,
    VoidCallback? onTitlePressed,
    Color? backgroundColor,
    IconButton? rightIconButton,
    bool isBottom = false,
    VoidCallback? onBackPressed,
    bool showTestnetLabel = false,
    bool showFaucetIcon = false,
  }) {
    Widget? widget = Column(
      children: [
        if (onTitlePressed == null) ...{
          Text(title)
        } else ...{
          CustomUnderlinedButton(
            text: title,
            onTap: onTitlePressed,
            padding: const EdgeInsets.all(0),
            fontSize: 18,
          )
        },
        showTestnetLabel
            ? const Column(
                children: [
                  SizedBox(
                    height: 3,
                  ),
                  TestnetLabelWidget(),
                ],
              )
            : Container(
                width: 1,
              ),
      ],
    );

    return AppBar(
      key: entireWidgetKey,
      toolbarHeight: 62,
      title: widget,
      scrolledUnderElevation: 0,
      centerTitle: true,
      backgroundColor: backgroundColor ?? Colors.transparent,
      titleTextStyle: Styles.appbarTitle,
      toolbarTextStyle: Styles.h3,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: isBottom
                  ? const Icon(
                      Icons.close_rounded,
                      color: MyColors.white,
                      size: 22,
                    )
                  : SvgPicture.asset('assets/svg/back.svg',
                      width: 24,
                      colorFilter: const ColorFilter.mode(MyColors.white, BlendMode.srcIn)),
              onPressed: () {
                if (onBackPressed != null) {
                  onBackPressed();
                } else {
                  Navigator.pop(context);
                }
              },
            )
          : null,
      actions: [
        if (showFaucetIcon)
          IconButton(
            key: faucetIconKey,
            focusColor: MyColors.transparentGrey,
            icon: SvgPicture.asset(
              'assets/svg/faucet.svg',
              width: 18,
              height: 18,
            ),
            onPressed: () {
              if (onFaucetIconPressed != null) {
                onFaucetIconPressed();
              }
            },
          ),
        if (hasRightIcon && rightIconButton != null) rightIconButton
      ],
      flexibleSpace: backgroundColor == null
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            )
          : null,
    );
  }

  static AppBar buildWithNext({
    required String title,
    required BuildContext context,
    required VoidCallback onNextPressed,
    Color? backgroundColor,
    VoidCallback? onBackPressed,
    bool isActive = true,
    bool isBottom = false,
    String nextButtonTitle = '다음',
  }) {
    return AppBar(
        title: Text(title),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor ?? Colors.transparent,
        titleTextStyle: Styles.navHeader.merge(const TextStyle(color: MyColors.white)),
        toolbarTextStyle: Styles.appbarTitle,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: isBottom
                    ? const Icon(
                        Icons.close,
                        color: MyColors.white,
                        size: 22,
                      )
                    : SvgPicture.asset(
                        'assets/svg/back.svg',
                        colorFilter: const ColorFilter.mode(
                          MyColors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                onPressed: () {
                  if (onBackPressed != null) {
                    onBackPressed();
                  } else {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: CustomAppbarButton(
              isActive: isActive,
              text: nextButtonTitle,
              onPressed: onNextPressed,
            ),
          ),
        ],
        flexibleSpace: ClipRect(
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.transparent,
                ))));
  }
}
