import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

class MyToast {
  static Widget getToastWidget(String content) {
    Widget toast = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: CoconutColors.white,
        border: Border.all(color: CoconutColors.gray300, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Text(content, style: CoconutTypography.body2_14.setColor(CoconutColors.gray900))],
      ),
    );

    return toast;
  }
}
