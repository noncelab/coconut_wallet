import 'package:coconut_wallet/ui/coconut/coconut_full_screen_dialog.dart';
import 'package:flutter/material.dart';

class CustomDialogs {
  static void showFullScreenDialog(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext context) {
          return CoconutFullScreenDialog(title: title, body: body);
        },
      ),
    );
  }
}
