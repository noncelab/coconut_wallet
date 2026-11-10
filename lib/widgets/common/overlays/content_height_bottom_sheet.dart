import 'dart:math' as math;

import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

/// 자식이 보고하는 전체 시트 높이. 드래그 핸들·앱바 등 고정 영역도 포함한다.
/// 최초 값만 최대 높이로 사용하고, 이후 콘텐츠 변화는 내부 스크롤로 처리한다.
class ContentHeightSheetNotification extends Notification {
  final double height;
  ContentHeightSheetNotification(this.height);
}

/// 콘텐츠로 정한 최초 높이와 내부 목록의 드래그를 하나의 시트에서 관리한다.
class ContentHeightBottomSheet extends StatefulWidget {
  final Widget child;
  final Key? dragAreaKey;
  const ContentHeightBottomSheet({super.key, this.dragAreaKey, required this.child});

  static Future<T?> show<T>({
    required BuildContext context,
    required String screenName,
    required Widget child,
    Key? dragAreaKey,
  }) => showModalBottomSheet<T>(
    context: context,
    routeSettings: RouteSettings(name: screenName),
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    enableDrag: false,
    backgroundColor: context.coconutColors.surfaceBottomSheet,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    clipBehavior: Clip.antiAlias,
    builder:
        (context) => AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ContentHeightBottomSheet(dragAreaKey: dragAreaKey, child: child),
        ),
  );

  @override
  State<ContentHeightBottomSheet> createState() => _ContentHeightBottomSheetState();
}

class _ContentHeightBottomSheetState extends State<ContentHeightBottomSheet> {
  final _controller = DraggableScrollableController();
  double? _naturalHeight;
  double _viewportHeight = 0;
  double _maxExtent = 0.6;
  double get _minExtent => _viewportHeight <= 0 ? 0.1 : math.min(80 / _viewportHeight, _maxExtent / 2);

  void _fitContent() {
    if (!mounted || _naturalHeight == null || _viewportHeight <= 0) return;
    final target = (_naturalHeight! / _viewportHeight).clamp(0.1, 0.95);
    if ((_maxExtent - target).abs() < 0.0001) return;
    setState(() => _maxExtent = target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.isAttached) _controller.jumpTo(_maxExtent);
    });
  }

  void _dragHeader(DragUpdateDetails details) {
    if (!_controller.isAttached || _viewportHeight <= 0) return;
    _controller.jumpTo((_controller.size - details.delta.dy / _viewportHeight).clamp(_minExtent, _maxExtent));
  }

  void _settleHeader([double velocity = 0]) {
    // 최소 높이에서 시트가 이미 닫히기 시작했다면 뒤 화면을 다시 pop하지 않는다.
    if (!_controller.isAttached || ModalRoute.of(context)?.isCurrent != true) return;
    final dismiss = velocity > 600 || (velocity >= -600 && _controller.size < (_minExtent + _maxExtent) / 2);
    if (dismiss) {
      Navigator.of(context).pop();
    } else {
      _controller.animateTo(_maxExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (_viewportHeight != constraints.maxHeight) {
        _viewportHeight = constraints.maxHeight;
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitContent());
      }
      return NotificationListener<ContentHeightSheetNotification>(
        onNotification: (notification) {
          // 최초 콘텐츠 높이만 기준으로 삼고, 이후 정보 변화는 내부 스크롤로 처리한다.
          _naturalHeight ??= notification.height;
          _fitContent();
          return true;
        },
        child: DraggableScrollableSheet(
          controller: _controller,
          initialChildSize: _maxExtent,
          minChildSize: _minExtent,
          maxChildSize: _maxExtent,
          snap: true,
          expand: false,
          builder:
              (context, scrollController) => GestureDetector(
                key: widget.dragAreaKey,
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _dragHeader,
                onVerticalDragEnd: (details) => _settleHeader(details.primaryVelocity ?? 0),
                onVerticalDragCancel: _settleHeader,
                child: Column(
                  children: [
                    SizedBox(
                      height: 20,
                      child: Center(
                        child: Container(
                          width: 55,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.coconutColors.bottomSheetHandle,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: PrimaryScrollController(
                        controller: scrollController,
                        child: MediaQuery.removePadding(context: context, removeTop: true, child: widget.child),
                      ),
                    ),
                  ],
                ),
              ),
        ),
      );
    },
  );
}
