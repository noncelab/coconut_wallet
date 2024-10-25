import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

class MyBottomSheet {
  static Future<T?> showBottomSheet_50<T>(
      {required BuildContext context, required Widget child}) async {
    return showModalBottomSheet<T>(
      context: context,
      builder: (context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            width: MediaQuery.of(context).size.width,
            child: child,
          ),
        );
      },
      backgroundColor: MyColors.black,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
    );
  }

  static Future<T?> showBottomSheet_90<T>(
      {required BuildContext context, required Widget child}) async {
    return showModalBottomSheet<T>(
        context: context,
        builder: (context) {
          return child; // child screen에서 type <T>를 반환하면 반환됩니다.
        },
        backgroundColor: MyColors.black,
        //isDismissible: false,
        isScrollControlled: true,
        enableDrag: true,
        useSafeArea: true,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9));
  }

  static Future<T?> showBottomSheet_95<T>(
      {required BuildContext context, required Widget child}) async {
    return showModalBottomSheet<T>(
        context: context,
        builder: (context) {
          return child; // child screen에서 type <T>를 반환하면 반환됩니다.
        },
        backgroundColor: MyColors.black,
        //isDismissible: false,
        isScrollControlled: true,
        enableDrag: true,
        useSafeArea: true,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.95));
  }

  static Future<T?> showBottomSheet_100<T>(
      {required BuildContext context,
      required Widget child,
      bool enableDrag = true,
      Color backgroundColor = MyColors.black,
      bool isDismissible = false,
      bool isScrollControlled = true,
      bool useSafeArea = true,
      AnimationController? animationController}) async {
    return showModalBottomSheet<T>(
        context: context,
        builder: (context) {
          return child; // child screen에서 type <T>를 반환하면 반환됩니다.
        },
        transitionAnimationController: animationController,
        backgroundColor: backgroundColor,
        isDismissible: isDismissible,
        isScrollControlled: isScrollControlled,
        enableDrag: enableDrag,
        useSafeArea: useSafeArea,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height));
  }

  static Future<T?> showDraggableScrollableSheet<T>({
    required BuildContext context,
    required Widget child,
    bool enableDrag = true,
    Color backgroundColor = MyColors.black,
    bool isDismissible = true,
    bool isScrollControlled = true,
    bool useSafeArea = true,
    bool expand = true,
    bool snap = true,
    double initialChildSize = 1,
    double maxChildSize = 1,
    double minChildSize = 0.9,
    double maxHeight = 0.9,
  }) async {
    return showModalBottomSheet<T>(
        context: context,
        builder: (context) {
          return DraggableScrollableSheet(
            expand: expand,
            snap: snap,
            initialChildSize: initialChildSize,
            maxChildSize: maxChildSize,
            minChildSize: minChildSize,
            builder: (_, controller) {
              return SingleChildScrollView(
                // physics: const ClampingScrollPhysics(),
                controller: controller,
                child: child,
              );
            },
          );
        },
        backgroundColor: backgroundColor,
        isDismissible: isDismissible,
        isScrollControlled: isScrollControlled,
        enableDrag: enableDrag,
        useSafeArea: useSafeArea,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5));
  }
}
