import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

class CustomDialogs {
  static void showFullScreenDialog(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext context) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: Text(title),
              centerTitle: true,
              backgroundColor: CoconutColors.black,
              titleTextStyle: Styles.h3.merge(const TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
              toolbarTextStyle: Styles.h3,
              actions: [
                IconButton(
                  color: CoconutColors.white,
                  focusColor: MyColors.transparentGrey,
                  icon: const Icon(CupertinoIcons.xmark, size: 18),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  padding: Paddings.container,
                  color: CoconutColors.black,
                  child: Column(children: [body]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
