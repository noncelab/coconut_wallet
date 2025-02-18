import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

class CustomToast {
  static void showToast({
    required BuildContext context,
    required String text,
    int seconds = 5,
    bool visibleIcon = true,
  }) {
    CoconutToast.showToast(
      brightness: Brightness.dark,
      context: context,
      text: text,
      seconds: seconds,
      isVisibleIcon: visibleIcon,
      iconPath: 'assets/svg/tooltip/info.svg',
      iconSize: 20,
      iconRightPadding: 6,
      fontSize: 12,
      textPadding: 3,
    );
  }

  static void showWarningToast({
    required BuildContext context,
    required String text,
    int seconds = 5,
  }) {
    CoconutToast.showToast(
      brightness: Brightness.dark,
      context: context,
      text: text,
      seconds: seconds,
      borderColor: MyColors.warningYellow,
      backgroundColor: MyColors.warningYellowBackground,
      textColor: MyColors.darkgrey,
      isVisibleIcon: true,
      iconPath: 'assets/svg/tooltip/triangle-warning.svg',
      iconSize: 20,
      iconRightPadding: 6,
      fontSize: 12,
      textPadding: 3,
    );
  }
}
