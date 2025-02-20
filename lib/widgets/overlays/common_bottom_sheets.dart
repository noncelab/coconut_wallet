import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

class CommonBottomSheets {
  static Future<T?> showCustomBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = true,
    bool useSafeArea = true,
    bool enableDrag = true,
    bool isDismissible = true,
    AnimationController? animationController,
  }) async {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      enableDrag: enableDrag,
      isDismissible: isDismissible,
      transitionAnimationController: animationController,
      builder: (context) => child,
    );
  }

  static Future<T?> showBottomSheetWithScreen<T>(
      {required BuildContext context, required Widget child}) async {
    return showModalBottomSheet<T>(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 54),
          child: child,
        );
      },
      backgroundColor: MyColors.black,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(32),
        ),
      ),
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
    );
  }

  static Future<T?> showDraggableBottomSheet<T>(
      {required BuildContext context, required Widget child}) async {
    return showModalBottomSheet(
      context: context,
      backgroundColor: CoconutColors.gray800,
      enableDrag: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: true,
          snap: true,
          initialChildSize: 1,
          maxChildSize: 1,
          minChildSize: 0.9,
          builder: (_, controller) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              controller: controller,
              child: child,
            );
          },
        );
      },
    );
  }
}
