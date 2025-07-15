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

  /// ScrollController has to be passed to child when child has a scrollView
  /// child builder is a builder for making a widget with ScrollController
  static Future<T?> showDraggableBottomSheet<T>(
      {required BuildContext context,
      required Widget Function(ScrollController) childBuilder,
      double minChildSize = 0.5,
      double maxChildSize = 0.9}) async {
    final draggableController = DraggableScrollableController();
    bool isAnimating = false;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          controller: draggableController,
          initialChildSize: minChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          expand: false,
          builder: (context, scrollController) {
            void handleDrag() {
              if (isAnimating) return;
              final extent = draggableController.size;
              final targetExtent = (extent - minChildSize).abs() < (extent - maxChildSize).abs()
                  ? minChildSize + 0.01
                  : maxChildSize;

              isAnimating = true;
              draggableController
                  .animateTo(
                targetExtent,
                duration: const Duration(milliseconds: 50),
                curve: Curves.easeOut,
              )
                  .whenComplete(() {
                isAnimating = false;
              });
            }

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification) {
                  handleDrag();
                  return true;
                }
                return false;
              },
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      final delta = -details.primaryDelta! / MediaQuery.of(context).size.height;
                      draggableController.jumpTo(draggableController.size + delta);
                    },
                    onVerticalDragEnd: (details) {
                      handleDrag();
                    },
                    onVerticalDragCancel: () {
                      handleDrag();
                    },
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Container(
                          width: 55,
                          height: 4,
                          decoration: BoxDecoration(
                            color: CoconutColors.gray400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                        child: childBuilder(scrollController)),
                  )
                ],
              ),
            );
          },
        );
      },
    );
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
    double minChildSize = 0.9001,
    double maxHeight = 0.9,
  }) async {
    var adjustedMinChildSize = minChildSize;
    if (maxHeight >= adjustedMinChildSize) adjustedMinChildSize = maxHeight + 0.0001;
    return showModalBottomSheet<T>(
        context: context,
        builder: (context) {
          return DraggableScrollableSheet(
            expand: expand,
            snap: snap,
            initialChildSize: initialChildSize,
            maxChildSize: maxChildSize,
            minChildSize: adjustedMinChildSize,
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
