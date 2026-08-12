import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// [SelectableSettingsRow]와 같은 [SelectableSettingsRowContent] 레이아웃을 쓰지만,
/// 왼쪽으로 스와이프하면 오른쪽에 삭제 버튼이 드러나는 행 (예: 코코넛 과육 테마)
///
/// 사용자가 삭제할 수 있는 설정 항목에 사용한다.
class DeletableSettingsRow extends StatefulWidget {
  const DeletableSettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleStyle,
    required this.isSelected,
    required this.isSwiped,
    required this.onSwipeChanged,
    required this.onDelete,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final bool isSelected;
  final bool isSwiped;
  final ValueChanged<bool> onSwipeChanged;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  State<DeletableSettingsRow> createState() => _DeletableSettingsRowState();
}

class _DeletableSettingsRowState extends State<DeletableSettingsRow> with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  late final AnimationController _animationController;
  Animation<double> _animation = const AlwaysStoppedAnimation(0);
  bool _isAnimating = false;
  VoidCallback? _pendingOnComplete;

  // 스와이프로 인식되기 전(=slop 이내)까지는 포인터 이동을 무시해서 _dragOffset을 정확히 0으로 유지
  Offset? _dragStartPosition;
  bool _dragRecognized = false;
  static const double _dragSlop = 18; // kTouchSlop 기본값과 동일

  bool _isPressed = false;

  static const double _swipeThreshold = 0.15; // 15% 이상 스와이프 시 삭제 동작
  static const double _swipeStopPosition = 0.2;
  static const double _borderRadius = 12;
  static const double _deleteButtonSize = 52;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void didUpdateWidget(covariant DeletableSettingsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSwiped != widget.isSwiped && !widget.isSwiped) {
      _animateToOriginalPosition();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _animateTo(double end, {VoidCallback? onComplete}) {
    _isAnimating = true;
    _pendingOnComplete = onComplete;
    _animationController.stop();
    _animationController.reset();
    _animation = Tween<double>(
      begin: _dragOffset,
      end: end,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut))..addListener(() {
      if (mounted) setState(() => _dragOffset = _animation.value);
    });
    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _isAnimating = false;
        if (status == AnimationStatus.completed) {
          final callback = _pendingOnComplete;
          _pendingOnComplete = null;
          callback?.call();
        }
      }
    });
    _animationController.forward();
  }

  void _animateToOriginalPosition() => _animateTo(0);

  void _animateToDeletePosition() {
    final screenWidth = MediaQuery.of(context).size.width;
    _animateTo(-screenWidth * _swipeStopPosition);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final screenWidth = MediaQuery.of(context).size.width;

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(child: Container(color: colors.background)),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: screenWidth * _swipeStopPosition,
            // 스와이프로 실제로 열려있을 때(_dragOffset != 0)만 삭제 버튼이 보인다.
            child: Visibility(
              visible: _dragOffset != 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onDelete,
                  child: Container(
                    width: _deleteButtonSize,
                    height: _deleteButtonSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.danger,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(_borderRadius),
                        bottomRight: Radius.circular(_borderRadius),
                      ),
                    ),
                    child: SvgPicture.asset(
                      CommonActionIconPath.trash,
                      width: 20,
                      colorFilter: ColorFilter.mode(colors.iconOnDanger, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Listener(
            onPointerDown: (event) {
              _dragStartPosition = event.position;
              _dragRecognized = false;
              setState(() => _isPressed = true);
            },
            onPointerMove: (event) {
              if (_isAnimating) return;
              final start = _dragStartPosition;
              if (start == null) return;
              if (!_dragRecognized) {
                final total = event.position - start;
                if (total.dx.abs() <= total.dy.abs() || total.distance < _dragSlop) {
                  return;
                }
                _dragRecognized = true;
                if (_isPressed) setState(() => _isPressed = false);
              }
              final dx = event.delta.dx;
              if (dx < 0 || (dx > 0 && _dragOffset < 0)) {
                setState(() {
                  _dragOffset = (_dragOffset + dx).clamp(-screenWidth, 0);
                });
              }
            },
            onPointerUp: (event) {
              if (_isAnimating) {
                if (_isPressed) setState(() => _isPressed = false);
                return;
              }
              if (_dragRecognized) {
                if (_isPressed) setState(() => _isPressed = false);
                final swipeThresholdPx = screenWidth * _swipeThreshold;
                if (_dragOffset.abs() >= swipeThresholdPx) {
                  widget.onSwipeChanged(true);
                  _animateToDeletePosition();
                } else {
                  widget.onSwipeChanged(false);
                  _animateToOriginalPosition();
                }
                return;
              }
              setState(() => _isPressed = false);
              if (_dragOffset != 0) {
                widget.onSwipeChanged(false);
                _animateToOriginalPosition();
              } else {
                widget.onTap();
              }
            },
            onPointerCancel: (event) {
              if (_isPressed) setState(() => _isPressed = false);
              if (_isAnimating || !_dragRecognized) return;
              widget.onSwipeChanged(false);
              _animateToOriginalPosition();
            },
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              // ShrinkAnimationButton과 같은 파라미터(0.97, 100ms, easeInOut)로
              // shrink 효과를 맞춰서 SelectableSettingsRow와 동일하게 느껴지도록 한다.
              child: AnimatedScale(
                scale: _isPressed ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeInOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  color:
                      _isPressed
                          ? Color.alphaBlend(colors.primaryText.withValues(alpha: 0.12), colors.background)
                          : colors.background,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Sizes.size20),
                    child: SelectableSettingsRowContent(
                      title: widget.title,
                      subtitle: widget.subtitle,
                      subtitleStyle: widget.subtitleStyle,
                      isSelected: widget.isSelected,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
