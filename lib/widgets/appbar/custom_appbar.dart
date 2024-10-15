import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/label_testnet.dart';

class CustomAppBar {
  static AppBar build({
    required String title,
    required BuildContext context,
    required bool hasRightIcon,
    Key? faucetIconKey,
    VoidCallback? onFaucetIconPressed,
    VoidCallback? onRightIconPressed,
    Color? backgroundColor,
    bool hasWalletIcon = false,
    IconButton? rightIconButton,
    bool isBottom = false,
    VoidCallback? onBackPressed,
    bool showTestnetLabel = true,
    bool showFaucetIcon = false,
  }) {
    Widget? widget = Column(
      children: [
        Text(title),
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

    // 현재 사용하지 않고 있음
    if (hasWalletIcon) {
      int colorIndex = CustomColorHelper.getIntFromColor(CustomColor.apricot);
      widget = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: BackgroundColorPalette[colorIndex]),
            // ignore: deprecated_member_use
            child: SvgPicture.asset(CustomIcons.carrot,
                color: ColorPalette[colorIndex], width: 16)),
        Text(title)
      ]);
    }

    return AppBar(
      toolbarHeight: 62,
      title: widget,
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
                      colorFilter: const ColorFilter.mode(
                          MyColors.white, BlendMode.srcIn)),
              onPressed: () {
                if (onBackPressed != null) {
                  onBackPressed();
                }
                Navigator.pop(context);
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
        if (hasRightIcon && rightIconButton == null)
          IconButton(
            color: MyColors.white,
            focusColor: MyColors.transparentGrey,
            icon: SvgPicture.asset(
              'assets/svg/wallet-info.svg',
              width: 18,
              height: 18,
            ),
            onPressed: () {
              if (onRightIconPressed != null) {
                onRightIconPressed();
              }
            },
          )
        else if (hasRightIcon && rightIconButton != null)
          rightIconButton
      ],
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            color: Colors.transparent,
          ),
        ),
      ),
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
  }) {
    return AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: backgroundColor ?? Colors.transparent,
        titleTextStyle:
            Styles.navHeader.merge(const TextStyle(color: MyColors.white)),
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
              child: GestureDetector(
                  onTap: isActive ? onNextPressed : null,
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14.0),
                        border: Border.all(
                            color: isActive
                                ? Colors.transparent
                                : MyColors.transparentWhite_20),
                        color: isActive ? MyColors.primary : MyColors.grey,
                      ),
                      child: Center(
                          child: Text('다음',
                              style: Styles.label2.merge(TextStyle(
                                color: isActive
                                    ? Colors.black
                                    : MyColors.transparentWhite_70,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              )))))))
        ],
        flexibleSpace: ClipRect(
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.transparent,
                ))));
  }
}
