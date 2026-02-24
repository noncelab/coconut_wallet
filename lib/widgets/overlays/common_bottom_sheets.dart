import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/selectable_list_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
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
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24.0), topRight: Radius.circular(24.0)),
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
                      onTap:
                          isCloseButton
                              ? () {
                                Navigator.pop(context);
                              }
                              : null,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        color: Colors.transparent,
                        child:
                            isCloseButton
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
                    Container(padding: const EdgeInsets.all(4), child: Container(width: 16)),
                  ],
                ),
              ),
              child,
            ],
          ),
        );
      },
      backgroundColor: CoconutColors.black,
      isDismissible: isDismissible,
      isScrollControlled: true,
      enableDrag: enableDrag,
      useSafeArea: true,
    );
  }

  static Future<T?> showCustomHeightBottomSheet<T>({
    required BuildContext context,
    required Widget child,
    required double heightRatio,
  }) async {
    assert(heightRatio >= 0.4 && heightRatio <= 1.0);
    return showModalBottomSheet<T>(
      context: context,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * heightRatio,
              width: MediaQuery.of(context).size.width,
              child: child,
            ),
          ),
        );
      },
      backgroundColor: CoconutColors.black,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
    );
  }

  static Future<T?> showBottomSheet_100<T>({
    required BuildContext context,
    required Widget child,
    bool enableDrag = true,
    Color backgroundColor = CoconutColors.black,
    bool isDismissible = false,
    bool isScrollControlled = true,
    bool useSafeArea = true,
    AnimationController? animationController,
  }) async {
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
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height),
    );
  }

  /// ScrollController has to be passed to child when child has a scrollView
  /// child builder is a builder for making a widget with ScrollController
  static Future<T?> showDraggableBottomSheet<T>({
    required BuildContext context,
    required Widget Function(ScrollController) childBuilder,
    double minChildSize = 0.5,
    double maxChildSize = 0.9,
    double? initialChildSize,
    bool showDragHandle = true,
    String? title,
    String? subLabel,
  }) async {
    final draggableController = DraggableScrollableController();
    bool isAnimating = false;

    // initialChildSize가 지정되지 않은 경우에만 자동 계산
    final calculatedInitialSize = initialChildSize ?? (minChildSize <= 0.95 ? minChildSize + 0.05 : minChildSize);

    // initialChildSize가 maxChildSize를 초과하지 않도록 보장
    final finalInitialSize = calculatedInitialSize > maxChildSize ? maxChildSize : calculatedInitialSize;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          child: DraggableScrollableSheet(
            controller: draggableController,
            initialChildSize: finalInitialSize,
            minChildSize: minChildSize,
            maxChildSize: maxChildSize,
            expand: false,
            builder: (context, scrollController) {
              void handleDrag() {
                if (isAnimating) return;
                final extent = draggableController.size;
                final targetExtent =
                    (extent - minChildSize).abs() < (extent - maxChildSize).abs() ? minChildSize + 0.01 : maxChildSize;

                isAnimating = true;
                draggableController
                    .animateTo(targetExtent, duration: const Duration(milliseconds: 50), curve: Curves.easeOut)
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
                child: Container(
                  color: CoconutColors.black,
                  child: Column(
                    children: [
                      if (showDragHandle)
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
                            color: CoconutColors.black,
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
                      if (title != null)
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
                          child: CoconutAppBar.build(
                            title: title,
                            context: context,
                            onBackPressed: null,
                            subLabel: Text(
                              subLabel ?? '',
                              style: CoconutTypography.body3_12.setColor(CoconutColors.black),
                            ),
                            showSubLabel: subLabel != null,
                            isBottom: true,
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                          child: childBuilder(scrollController),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// 드래그 가능한 바텀시트 안에 선택 가능한 리스트를 보여줍니다.
  /// 확인 버튼을 누르면 선택된 아이템 T를 반환합니다.
  /// 선택 없이 닫으면 null을 반환합니다.
  static Future<T?> showSelectableDraggableSheet<T>({
    required BuildContext context,
    required String title,
    required List<T> items,
    required Object Function(T item) getItemId,
    required SelectableItemBuilder<T> itemBuilder,
    Object? initiallySelectedId,
    String? confirmText,
    double minChildSize = 0.5,
    double maxChildSize = 0.9,
    double? initialChildSize,
    Color backgroundColor = CoconutColors.gray900,
  }) async {
    return showDraggableBottomSheet<T>(
      context: context,
      title: title,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      initialChildSize: initialChildSize,
      childBuilder: (scrollController) {
        return _SelectableDraggableSheetBody<T>(
          scrollController: scrollController,
          items: items,
          getItemId: getItemId,
          itemBuilder: itemBuilder,
          initiallySelectedId: initiallySelectedId,
          confirmText: confirmText ?? t.select,
          backgroundColor: backgroundColor,
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
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
    );
  }
}

class _SelectableDraggableSheetBody<T> extends StatefulWidget {
  final ScrollController scrollController;
  final List<T> items;
  final Object Function(T item) getItemId;
  final SelectableItemBuilder<T> itemBuilder;
  final Object? initiallySelectedId;
  final String confirmText;
  final Color backgroundColor;

  const _SelectableDraggableSheetBody({
    super.key,
    required this.scrollController,
    required this.items,
    required this.getItemId,
    required this.itemBuilder,
    this.initiallySelectedId,
    required this.confirmText,
    required this.backgroundColor,
  });

  @override
  State<_SelectableDraggableSheetBody<T>> createState() => _SelectableDraggableSheetBodyState<T>();
}

class _SelectableDraggableSheetBodyState<T> extends State<_SelectableDraggableSheetBody<T>> {
  Object? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initiallySelectedId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
              child: ListView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.only(bottom: Sizes.size96),
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final id = widget.getItemId(item);
                  final isSelected = _selectedId == id;

                  void handleTap() {
                    vibrateExtraLight();
                    setState(() {
                      _selectedId = _selectedId == id ? null : id;
                    });
                  }

                  return widget.itemBuilder(context, item, isSelected, handleTap);
                },
              ),
            ),
            FixedBottomButton(
              onButtonClicked: () {
                final selectedItem =
                    _selectedId == null
                        ? null
                        : widget.items.firstWhere((item) => widget.getItemId(item) == _selectedId);
                Navigator.pop(context, selectedItem);
              },
              isActive: _selectedId != null,
              text: widget.confirmText,
              backgroundColor: CoconutColors.white,
            ),
          ],
        ),
      ),
    );
  }
}
