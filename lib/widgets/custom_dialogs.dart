import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

class CustomDialogs {
  static Future<void> showCustomAlertDialog(BuildContext context,
      {required String title,
      required String message,
      required VoidCallback onConfirm,
      VoidCallback? onCancel,
      String confirmButtonText = '확인',
      String cancelButtonText = '취소',
      Color confirmButtonColor = CoconutColors.white}) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
            title: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(title, style: Styles.body1Bold),
            ),
            content: Text(
              message,
              style: Styles.body2,
              textAlign: TextAlign.center,
            ),
            actions: [
              if (onCancel != null)
                CupertinoDialogAction(
                    isDefaultAction: true,
                    onPressed: onCancel,
                    child: Text(cancelButtonText, style: Styles.label)),
              CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: onConfirm,
                  child: Text(confirmButtonText,
                      style: Styles.label.merge(TextStyle(color: confirmButtonColor)))),
            ]);
      },
    );
  }

  static Future<bool?> showFutureCustomAlertDialog(BuildContext context,
      {required String title,
      required String message,
      required Future<bool> Function() onConfirm,
      required bool Function() onCancel,
      String confirmButtonText = '확인',
      String cancelButtonText = '취소',
      Color confirmButtonColor = CoconutColors.white}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
            title: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(title, style: Styles.body1Bold),
            ),
            content: Text(
              message,
              style: Styles.body2,
              textAlign: TextAlign.center,
            ),
            actions: [
              CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () {
                    bool result = onCancel();
                    Navigator.of(context, rootNavigator: true).pop(result);
                  },
                  child: Text(cancelButtonText, style: Styles.label)),
              CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () async {
                    await onConfirm();
                  },
                  child: Text(confirmButtonText,
                      style: Styles.label.merge(TextStyle(color: confirmButtonColor)))),
            ]);
      },
    );
  }

  static void showFullScreenDialog(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext context) {
        return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
                title: Text(title),
                centerTitle: true,
                backgroundColor: CoconutColors.black,
                titleTextStyle:
                    Styles.h3.merge(const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
                toolbarTextStyle: Styles.h3,
                actions: [
                  IconButton(
                    color: CoconutColors.white,
                    focusColor: MyColors.transparentGrey,
                    icon: const Icon(CupertinoIcons.xmark, size: 18),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  )
                ]),
            body: SafeArea(
                child: SingleChildScrollView(
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                padding: Paddings.container,
                color: CoconutColors.black,
                child: Column(
                  children: [body],
                ),
              ),
            )));
      },
    ));
  }
}
