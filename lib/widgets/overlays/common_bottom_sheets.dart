import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/selectable_list_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:coconut_wallet/styles.dart';

class CommonBottomSheets {
  static Future<T?> showBottomSheet<T>({
    required String title,
    required BuildContext context,
    required Widget child,
    TextStyle titleTextStyle = Styles.body2Bold,
    bool isDismissible = true,
    bool enableDrag = true,
    bool showCloseButton = false,
    bool showDragHandle = false,
    bool adjustForKeyboardInset = true,
    Color backgroundColor = CoconutColors.black,
    EdgeInsetsGeometry titlePadding = const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
  }) {
    return showModalBottomSheet<T>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24.0), topRight: Radius.circular(24.0)),
      ),
      builder: (context) {
        final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: adjustForKeyboardInset ? keyboardInset + 20 : 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (showDragHandle)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Container(
                      width: 55,
                      height: 4,
                      decoration: BoxDecoration(color: CoconutColors.gray400, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              Padding(
                padding: titlePadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap:
                          showCloseButton
                              ? () {
                                Navigator.pop(context);
                              }
                              : null,
                      child:
                          showCloseButton
                              ? const Icon(Icons.close_rounded, size: 24, color: CoconutColors.white)
                              : Container(width: 20),
                    ),
                    Text(
                      title,
                      style: titleTextStyle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(color: Colors.transparent, child: Container(width: 28)),
                  ],
                ),
              ),
              child,
            ],
          ),
        );
      },
      backgroundColor: backgroundColor,
      isDismissible: isDismissible,
      isScrollControlled: true,
      enableDrag: enableDrag,
      useSafeArea: true,
    );
  }

  static Future<T?> showCustomHeightBottomSheet<T>({
    required BuildContext context,
    Widget? child,
    Widget Function(ScrollController scrollController)? childBuilder,
    required double heightRatio,
  }) async {
    assert(heightRatio >= 0.4 && heightRatio <= 1.0);
    assert(child != null || childBuilder != null);
    final draggableController = DraggableScrollableController();
    bool isAnimating = false;

    return showModalBottomSheet<T>(
      context: context,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child:
                childBuilder == null
                    ? SizedBox(
                      height: MediaQuery.of(context).size.height * heightRatio,
                      width: MediaQuery.of(context).size.width,
                      child: child,
                    )
                    : DraggableScrollableSheet(
                      controller: draggableController,
                      expand: false,
                      initialChildSize: heightRatio,
                      minChildSize: 0.01,
                      maxChildSize: heightRatio,
                      shouldCloseOnMinExtent: true,
                      builder: (context, scrollController) {
                        void handleDragEnd() {
                          if (isAnimating || !draggableController.isAttached) return;

                          final extent = draggableController.size;
                          final closeThreshold = heightRatio * 0.7;
                          if ((extent - heightRatio).abs() < 0.001) return;

                          isAnimating = true;
                          final animation =
                              extent <= closeThreshold
                                  ? draggableController.animateTo(
                                    0.01,
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                  )
                                  : draggableController.animateTo(
                                    heightRatio,
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                  );

                          animation.whenComplete(() {
                            if (extent <= closeThreshold && context.mounted) {
                              // Navigator.of(context).pop();
                            }
                            isAnimating = false;
                          });
                        }

                        return NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollEndNotification) {
                              handleDragEnd();
                            }
                            return false;
                          },
                          child: childBuilder(scrollController),
                        );
                      },
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
    Color backgroundColor = CoconutColors.black,
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
                  color: backgroundColor,
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
                            color: backgroundColor,
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
                            backgroundColor: backgroundColor,
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
    Color backgroundColor = CoconutColors.black,
  }) async {
    return showDraggableBottomSheet<T>(
      context: context,
      title: title,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      initialChildSize: initialChildSize,
      backgroundColor: backgroundColor,
      childBuilder: (scrollController) {
        return SelectableBottomSheetBody<T>(
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

class SelectableBottomSheetTextItem extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isDisabled;
  final bool reserveCheckIconSpace;

  const SelectableBottomSheetTextItem({
    super.key,
    required this.child,
    required this.isSelected,
    this.onTap,
    this.isDisabled = false,
    this.reserveCheckIconSpace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: ShrinkAnimationButton(
        onPressed: () {
          if (isDisabled) return;
          if (onTap != null) onTap!();
        },
        defaultColor: CoconutColors.gray900,
        pressedColor: CoconutColors.gray800,
        borderRadius: 8,
        borderWidth: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              Expanded(child: child),
              if (isSelected || reserveCheckIconSpace)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 18,
                  height: 18,
                  child:
                      isSelected
                          ? SvgPicture.asset(
                            'assets/svg/check.svg',
                            width: 16,
                            height: 16,
                            colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                          ).scaleInAnimation(duration: const Duration(milliseconds: 300))
                          : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectableBottomSheetBody<T> extends StatefulWidget {
  final ScrollController? scrollController;
  final List<T> items;
  final Object Function(T item) getItemId;
  final SelectableItemBuilder<T> itemBuilder;
  final Object? initiallySelectedId;
  final String confirmText;
  final Color backgroundColor;
  final bool showGradient;
  final bool showConfirmButton;
  final ValueChanged<T?>? onSelectionChanged;

  const SelectableBottomSheetBody({
    super.key,
    this.scrollController,
    required this.items,
    required this.getItemId,
    required this.itemBuilder,
    this.initiallySelectedId,
    required this.confirmText,
    required this.backgroundColor,
    this.showGradient = true,
    this.showConfirmButton = true,
    this.onSelectionChanged,
  });

  @override
  State<SelectableBottomSheetBody<T>> createState() => _SelectableBottomSheetBodyState<T>();
}

class _SelectableBottomSheetBodyState<T> extends State<SelectableBottomSheetBody<T>> {
  Object? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initiallySelectedId;
  }

  @override
  void didUpdateWidget(covariant SelectableBottomSheetBody<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallySelectedId != widget.initiallySelectedId) {
      _selectedId = widget.initiallySelectedId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final buttonAreaHeight =
        widget.showConfirmButton ? FixedBottomButton.fixedBottomButtonDefaultHeight + bottomSafeArea : 0.0;

    return Container(
      color: widget.backgroundColor,
      child: SafeArea(
        top: false,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
                child: ListView.builder(
                  controller: widget.scrollController,
                  shrinkWrap: true,
                  primary: false,
                  physics:
                      widget.scrollController == null
                          ? const NeverScrollableScrollPhysics()
                          : const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: buttonAreaHeight),
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
                      widget.onSelectionChanged?.call(
                        _selectedId == null
                            ? null
                            : widget.items.firstWhere((candidate) => widget.getItemId(candidate) == _selectedId),
                      );
                    }

                    return widget.itemBuilder(context, item, isSelected, handleTap);
                  },
                ),
              ),
            ),
            if (widget.showConfirmButton)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: buttonAreaHeight,
                  child: FixedBottomButton(
                    showGradient: widget.showGradient,
                    isVisibleAboveKeyboard: false,
                    bottomPadding: 0,
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}
