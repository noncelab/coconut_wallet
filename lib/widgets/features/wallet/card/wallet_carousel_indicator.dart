import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';

/// 홈 지갑 카드와 지갑 선택 캐러셀에서 공유하는 드래그 인디케이터.
class WalletCarouselIndicator extends StatefulWidget {
  final PageController controller;
  final int count;
  final String keyPrefix;
  final ValueChanged<bool>? onInteraction;
  final bool hapticOnChange;
  const WalletCarouselIndicator({
    super.key,
    required this.controller,
    required this.count,
    required this.keyPrefix,
    this.onInteraction,
    this.hapticOnChange = true,
  });
  @override
  State<WalletCarouselIndicator> createState() => _WalletCarouselIndicatorState();
}

class _WalletCarouselIndicatorState extends State<WalletCarouselIndicator> {
  PageController get _controller => widget.controller;
  int get _pageCount => widget.count;
  double? _indicatorDragDistance;
  Offset? _indicatorPointerDown;
  Timer? _indicatorRepeat;
  int _indicatorDragDirection = 0;
  bool _indicatorAutoMode = false;
  static const _indicatorPageDistance = 18.0;
  static const _indicatorRepeatInterval = Duration(milliseconds: 500);
  @override
  void dispose() {
    _indicatorRepeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_pageCount < 1) return const SizedBox.shrink();
    return GestureDetector(
      key: Key('${widget.keyPrefix}-indicator-scrubber'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.onInteraction?.call(true);
        widget.onInteraction?.call(false);
      },
      onHorizontalDragDown: (details) => _indicatorPointerDown = details.globalPosition,
      onHorizontalDragStart: _startIndicatorDrag,
      onHorizontalDragUpdate: _updateIndicatorDrag,
      onHorizontalDragEnd: (_) => _endIndicatorDrag(),
      onHorizontalDragCancel: _endIndicatorDrag,
      child: SizedBox(
        height: 32,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(padding: const EdgeInsets.only(bottom: 8), child: _indicator(context)),
        ),
      ),
    );
  }

  void _startIndicatorDrag(DragStartDetails details) {
    if (!_controller.hasClients) return;
    _indicatorRepeat?.cancel();
    _indicatorDragDistance = 0;
    _indicatorDragDirection = 0;
    _indicatorAutoMode = false;
    widget.onInteraction?.call(true);
    _controller.jumpToPage(_page.round().clamp(0, _pageCount - 1));
    // 제스처 인식에 쓰인 첫 이동도 포함해, 한 번 민 뒤 멈춰도 반복을 시작한다.
    if (_pageCount > 5 && _indicatorPointerDown != null) {
      final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
      _moveIndicator((details.globalPosition.dx - _indicatorPointerDown!.dx) * direction);
    }
  }

  void _updateIndicatorDrag(DragUpdateDetails details) {
    final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    _moveIndicator((details.primaryDelta ?? 0) * direction);
  }

  bool get _canRepeatIndicator {
    if (!_controller.hasClients || _pageCount <= 5) return false;
    final current = _page.round();
    return current >= 2 && current <= _pageCount - 3;
  }

  void _stopIndicatorRepeat() {
    _indicatorRepeat?.cancel();
    _indicatorRepeat = null;
    _indicatorDragDirection = 0;
  }

  void _repeatIndicator(int direction) {
    _stopIndicatorRepeat();
    if (!_indicatorAutoMode && !_canRepeatIndicator) return;
    // 같은 드래그에서 시작한 자동 전환은 양 끝 두 페이지에 들어가도 유지한다.
    _indicatorAutoMode = true;
    _indicatorDragDirection = direction;
    _indicatorDragDistance = 0;
    if ((direction < 0 && _page <= 0) || (direction > 0 && _page >= _pageCount - 1)) return;
    _indicatorRepeat = Timer.periodic(_indicatorRepeatInterval, (_) {
      if (!mounted || _indicatorDragDistance == null || !_controller.hasClients || _pageCount <= 5) {
        _stopIndicatorRepeat();
        return;
      }
      _stepIndicator(_indicatorDragDirection);
      if ((_indicatorDragDirection < 0 && _page <= 0) || (_indicatorDragDirection > 0 && _page >= _pageCount - 1)) {
        _indicatorDragDistance = 0;
        _stopIndicatorRepeat();
      }
    });
  }

  void _moveIndicator(double movement) {
    if (_indicatorDragDistance == null || !_controller.hasClients || movement == 0) return;
    if (_indicatorAutoMode || _canRepeatIndicator) {
      _indicatorAutoMode = true;
      // 자동 전환 중에는 같은 방향으로 더 끌어도 페이지를 건너뛰지 않는다.
      if (movement.sign == _indicatorDragDirection) {
        _indicatorDragDistance = 0;
        return;
      }
      _indicatorDragDistance = _indicatorDragDistance! + movement;
      if (_indicatorDragDistance!.abs() < _indicatorPageDistance) return;
      final direction = _indicatorDragDistance!.sign.toInt();
      _indicatorDragDistance = 0;
      _stepIndicator(direction);
      _repeatIndicator(direction);
      return;
    }

    // 양 끝 두 페이지는 손가락 이동량만큼만 전환한다.
    _stopIndicatorRepeat();
    _indicatorDragDistance = _indicatorDragDistance! + movement;
    final steps = (_indicatorDragDistance! / _indicatorPageDistance).truncate();
    if (steps != 0) {
      _indicatorDragDistance = _indicatorDragDistance! - steps * _indicatorPageDistance;
      final current = _page.round();
      final target = (current + steps).clamp(0, _pageCount - 1);
      for (var page = current; page != target;) {
        page += steps.sign;
        _stepIndicator(steps.sign);
        if (_canRepeatIndicator) {
          _repeatIndicator(steps.sign);
          break;
        }
      }
    }
    if ((_page <= 0 && _indicatorDragDistance! < 0) || (_page >= _pageCount - 1 && _indicatorDragDistance! > 0)) {
      _indicatorDragDistance = 0;
    }
  }

  void _stepIndicator(int direction) {
    if (!_controller.hasClients || _pageCount < 2) return;
    final current = _page.round().clamp(0, _pageCount - 1);
    final next = (current + direction).clamp(0, _pageCount - 1);
    if (current == next) return;
    _controller.jumpToPage(next);
    if (widget.hapticOnChange) vibrateExtraLight();
  }

  void _endIndicatorDrag() {
    _indicatorRepeat?.cancel();
    _indicatorRepeat = null;
    _indicatorPointerDown = null;
    _indicatorDragDistance = null;
    _indicatorDragDirection = 0;
    _indicatorAutoMode = false;
    widget.onInteraction?.call(false);
  }

  Widget _indicator(BuildContext context) {
    final colors = context.coconutColors;
    const slotWidth = 14.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final current = _page.round().clamp(0, _pageCount - 1);
        final visibleCount = math.min(_pageCount, 5);
        final first = (current - 2).clamp(0, _pageCount - visibleCount).toDouble();
        final width = visibleCount * slotWidth;
        final reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
        return Semantics(
          value: '${current + 1}/$_pageCount',
          child: SizedBox(
            key: Key('${widget.keyPrefix}-indicator-window'),
            width: width,
            height: 5,
            child: ClipRect(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: first, end: first),
                duration: Duration(milliseconds: reduceMotion ? 0 : 300),
                // 선택 표시가 먼저 바뀐 뒤 양 끝의 점이 사라지고 나타나며 한 칸 이동한다.
                curve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
                builder: (context, position, _) {
                  final start = math.max(0, position.floor() - 1);
                  final end = math.min(_pageCount, position.ceil() + visibleCount + 1);
                  double visibility(int index) =>
                      (math.min((index - position + 0.5) * slotWidth, width - (index - position + 0.5) * slotWidth) /
                              (slotWidth / 2))
                          .clamp(0.0, 1.0);
                  return Stack(
                    children: [
                      for (var i = start; i < end; i++)
                        Positioned(
                          key: ValueKey('${widget.keyPrefix}-indicator-slot-$i'),
                          left: (i - position) * slotWidth,
                          width: slotWidth,
                          top: 0,
                          bottom: 0,
                          child: Opacity(
                            opacity: visibility(i),
                            child: Transform.scale(
                              scale: visibility(i),
                              child: Center(
                                child: AnimatedContainer(
                                  key: ValueKey('${widget.keyPrefix}-indicator-dot-$i'),
                                  duration: Duration(milliseconds: reduceMotion ? 0 : 150),
                                  width: i == current ? 12 : 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: i == current ? colors.pageIndicatorActive : colors.pageIndicatorInactive,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  double get _page {
    final position = _controller.hasClients ? _controller.position : null;
    if (position == null || !position.hasContentDimensions || !position.hasPixels) return 0;
    return _controller.page ?? 0;
  }
}
