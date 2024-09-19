import 'package:flutter/material.dart';

import '../styles.dart';

class MyToast {
  static Widget getToastWidget(String content) {
    Widget toast = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.0),
        color: MyColors.transparentWhite_20,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(content, style: Styles.body2),
        ],
      ),
    );

    return toast;
  }
}
