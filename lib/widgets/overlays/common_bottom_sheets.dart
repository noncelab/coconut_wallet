import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

class CommonBottomSheets {
  static void showBottomSheet({
    required String title,
    required BuildContext context,
    required Widget child,
    TextStyle titleTextStyle = Styles.body2Bold,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isCloseButton = false,
    EdgeInsetsGeometry titlePadding = const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.0),
          topRight: Radius.circular(24.0),
        ),
      ),
      builder: (context) {
        return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Wrap(
              children: <Widget>[
                Padding(
                  padding: titlePadding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: isCloseButton
                            ? () {
                                Navigator.pop(context);
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          color: Colors.transparent,
                          child: isCloseButton
                              ? const Icon(Icons.close_rounded, color: CoconutColors.white)
                              : Container(width: 16),
                        ),
                      ),
                      Text(
                        title,
                        style: titleTextStyle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        child: Container(width: 16),
                      ),
                    ],
                  ),
                ),
                child
              ],
            ));
      },
      backgroundColor: CoconutColors.black,
      isDismissible: isDismissible,
      isScrollControlled: true,
      enableDrag: enableDrag,
      useSafeArea: true,
    );
  }

  static Future<T?> showBottomSheet_50<T>(
      {required BuildContext context, required Widget child}) async {
    return showModalBottomSheet<T>(
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            width: MediaQuery.of(context).size.width,
            child: child,
          ),
        );
      },
      backgroundColor: CoconutColors.black,
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
        backgroundColor: CoconutColors.black,
        //isDismissible: false,
        isScrollControlled: true,
        enableDrag: true,
        useSafeArea: true,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9));
  }

  static Future<T?> showBottomSheet_95<T>(
      {required BuildContext context, required Widget child}) async {
    return showModalBottomSheet<T>(
        context: context,
        builder: (context) {
          return child; // child screen에서 type <T>를 반환하면 반환됩니다.
        },
        backgroundColor: CoconutColors.black,
        //isDismissible: false,
        isScrollControlled: true,
        enableDrag: true,
        useSafeArea: true,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.95));
  }

  static Future<T?> showBottomSheet_100<T>(
      {required BuildContext context,
      required Widget child,
      bool enableDrag = true,
      Color backgroundColor = CoconutColors.black,
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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height));
  }

  static Future<T?> showDraggableScrollableSheet<T>({
    required BuildContext context,
    required Widget child,
    bool enableDrag = true,
    Color backgroundColor = CoconutColors.black,
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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8));
  }
}
