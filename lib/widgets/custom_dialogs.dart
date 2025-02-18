import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class CustomDialogs {
  static Future<bool?> showCustomDialog(
    BuildContext context, {
    required String title,
    required String description,
    required Function onTapRight,
    String rightButtonText = '확인',
    String leftButtonText = '취소',
    Color? backgroundColor,
    Color? titleColor,
    Color? descriptionColor,
    Color? rightButtonColor,
    Color? leftButtonColor,
    EdgeInsets? padding,
    Function? onTapLeft,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          title: title,
          description: description,
          onTapRight: onTapRight,
          rightButtonText: rightButtonText,
          leftButtonText: leftButtonText,
          backgroundColor: backgroundColor,
          titleColor: titleColor,
          descriptionColor: descriptionColor,
          rightButtonColor: rightButtonColor,
          leftButtonColor: leftButtonColor,
          padding: padding,
          onTapLeft: onTapLeft,
        );
      },
    );
  }
}
