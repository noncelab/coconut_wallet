import 'dart:async';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/svg.dart';

/// 자식을 long press 했을 때, 자식 근처에 dropdown(overlay)을 띄우는 위젯.
/// dropdown은 화면을 벗어나지 않도록 위치를 자동으로 조정한다.
class LongPressedMenuWidget extends StatefulWidget {
  /// long press 대상이 되는 위젯
  final Widget child;

  /// dropdown으로 표시할 위젯을 빌드하는 함수
  final List<LongPressedMenuItem> menuItems;

  final VoidCallback? onMenuOpen;

  /// dropdown 바깥을 탭하면 닫히도록 할지 여부
  final bool dismissOnTapOutside;

  /// dropdown과 child 사이의 기본 간격
  final double spacing;

  /// 편집 모드일 때 표시 여부
  final bool isEditMode;

  /// X 버튼 클릭 시 호출되는 콜백
  final VoidCallback? onRemove;

  /// 선택된 child 영역을 제외한 화면에 블러와 딤 효과를 적용할지 여부
  final bool useGlassOverlay;

  /// 메뉴의 오른쪽 끝을 child의 오른쪽 끝에 맞출지 여부
  final bool alignMenuToChildRight;

  /// 메뉴에 사용할 고정 배경색. null이면 기존 glass 배경을 사용한다.
  final Color? menuBackgroundColor;

  const LongPressedMenuWidget({
    super.key,
    required this.child,
    required this.menuItems,
    this.onMenuOpen,
    this.dismissOnTapOutside = true,
    this.spacing = 8.0,
    this.isEditMode = false,
    this.onRemove,
    this.useGlassOverlay = false,
    this.alignMenuToChildRight = false,
    this.menuBackgroundColor,
  });

  @override
  State<LongPressedMenuWidget> createState() => _LongPressedMenuWidgetState();
}

class _LongPressedMenuWidgetState extends State<LongPressedMenuWidget> with TickerProviderStateMixin {
  final GlobalKey _childKey = GlobalKey();
  final GlobalKey _childRepaintBoundaryKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  ui.Image? _capturedChildImage;
  bool _isCapturingChild = false;
  Rect? _menuRect;
  int? _hoveredMenuIndex;
  bool _isMenuPointerActive = false;
  late AnimationController _menuAnimationController;
  late AnimationController _shakeController;
  late AnimationController _closeButtonController;
  late Animation<double> _shakeAnimation;
  final math.Random _random = math.Random();
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _menuAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

    _closeButtonController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

    // 0.0 ~ 1.0 구간에서: 0 -> -max -> 0 -> +max -> 0 로 한 사이클을 도는 애니메이션
    const maxAngle = 0.02;
    _shakeAnimation = TweenSequence<double>([
      // 0 -> -max
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -maxAngle), weight: 1),
      // -max -> 0
      TweenSequenceItem(tween: Tween(begin: -maxAngle, end: 0.0), weight: 1),
      // 0 -> +max
      TweenSequenceItem(tween: Tween(begin: 0.0, end: maxAngle), weight: 1),
      // +max -> 0
      TweenSequenceItem(tween: Tween(begin: maxAngle, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    // 각기 다른 쉐이킹(동시에 동일한 방향이 아닌)을 하기 위해 랜덤 딜레이 설정
    if (widget.isEditMode) {
      _startShakeWithRandomDelay();
      _closeButtonController.forward();
    }

    _menuAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isClosing) {
        _removeOverlay();
      }
    });
  }

  void _startShakeWithRandomDelay() {
    final delayMs = _random.nextInt(100); // 0 ~ 199ms

    Future.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      if (!widget.isEditMode) return;
      if (_shakeController.isAnimating) return;

      _shakeController.repeat();
    });
  }

  @override
  void didUpdateWidget(covariant LongPressedMenuWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isEditMode != widget.isEditMode) {
      if (widget.isEditMode) {
        // 편집 모드 진입 → 쉐이킹 시작 및 닫기 버튼 표시
        _startShakeWithRandomDelay();
        _closeButtonController.forward();
      } else {
        // 편집 모드 해제 → 쉐이킹 정지 및 닫기 버튼 숨김
        _shakeController.stop();
        _shakeController.reset();
        _closeButtonController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _menuAnimationController.dispose();
    _shakeController.dispose();
    _closeButtonController.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _capturedChildImage?.dispose();
    _capturedChildImage = null;
    _menuRect = null;
    _hoveredMenuIndex = null;
    _isMenuPointerActive = false;
  }

  void _startHideAnimation() {
    if (_overlayEntry == null) {
      return;
    }
    _isClosing = true;
    _menuAnimationController.duration = const Duration(milliseconds: 150);
    _menuAnimationController.forward(from: 0.0);
  }

  Future<void> _showMenu() async {
    if (widget.isEditMode || _isCapturingChild) {
      return;
    }
    _isCapturingChild = true;
    vibrateExtraLight();
    widget.onMenuOpen?.call();
    // 이미 떠 있으면 제거
    if (_overlayEntry != null) {
      _removeOverlay();
    }

    final RenderBox? childRenderBox = _childKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderRepaintBoundary? childRepaintBoundary =
        _childRepaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final OverlayState overlay = Overlay.of(context);

    if (childRenderBox == null || childRepaintBoundary == null) {
      _isCapturingChild = false;
      return;
    }

    final Size screenSize = MediaQuery.of(context).size;
    final Offset childGlobalPosition = childRenderBox.localToGlobal(Offset.zero);
    final Size childSize = childRenderBox.size;
    final highlightedRect = Rect.fromLTWH(
      childGlobalPosition.dx - childSize.width * 0.025,
      childGlobalPosition.dy - childSize.height * 0.025,
      childSize.width * 1.05,
      childSize.height * 1.05,
    ).inflate(widget.useGlassOverlay ? 6 : 0);

    if (widget.useGlassOverlay) {
      try {
        _capturedChildImage = await childRepaintBoundary.toImage(pixelRatio: MediaQuery.devicePixelRatioOf(context));
      } catch (_) {
        _isCapturingChild = false;
        return;
      }
      if (!mounted) {
        _capturedChildImage?.dispose();
        _capturedChildImage = null;
        _isCapturingChild = false;
        return;
      }
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (_menuRect?.contains(event.position) != true) return;
            _isMenuPointerActive = true;
            _updateHoveredMenuItem(event.position);
          },
          onPointerMove: (event) {
            if (_isMenuPointerActive) _updateHoveredMenuItem(event.position);
          },
          onPointerUp: (_) {
            if (!_isMenuPointerActive) return;
            _isMenuPointerActive = false;
            _selectHoveredMenuItem();
          },
          onPointerCancel: (_) {
            _isMenuPointerActive = false;
            _clearHoveredMenuItem();
          },
          child: Stack(
            children: [
              if (widget.dismissOnTapOutside)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _startHideAnimation,
                    child:
                        widget.useGlassOverlay
                            ? BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                              child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
                            )
                            : CustomPaint(
                              painter: _DimExceptRectPainter(
                                highlightRect: highlightedRect,
                                dimColor: Colors.transparent,
                              ),
                            ),
                  ),
                ),
              if (widget.useGlassOverlay && _capturedChildImage != null)
                Positioned(
                  left: childGlobalPosition.dx,
                  top: childGlobalPosition.dy,
                  width: childSize.width,
                  height: childSize.height,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _menuAnimationController,
                      builder:
                          (_, child) =>
                              Transform.scale(scale: _computeChildScale(), alignment: Alignment.center, child: child),
                      child: RawImage(image: _capturedChildImage, fit: BoxFit.fill),
                    ),
                  ),
                ),
              // 실제 dropdown 영역
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                bottom: 0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // 메뉴의 예상 크기를 계산 (실제 RenderBox에 의존하지 않음)
                    const double minMenuWidth = 180;
                    const double maxMenuWidth = 220;
                    const double itemHeight = 44;

                    final maxTitleWidth = widget.menuItems.fold<double>(0, (maxWidth, item) {
                      final textPainter = TextPainter(
                        text: TextSpan(text: item.title, style: CoconutTypography.body2_14),
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                        maxLines: 1,
                      )..layout();
                      return math.max(maxWidth, textPainter.width);
                    });
                    // 바깥 패딩 8 + 아이템 패딩 32 + 아이콘 16 + 아이콘/텍스트 간격 8
                    final double menuWidth = (maxTitleWidth + 64).clamp(minMenuWidth, maxMenuWidth).toDouble();
                    final double menuHeight = widget.menuItems.length * itemHeight + 16;
                    final Size menuSize = Size(menuWidth, menuHeight);
                    bool isAboveChild = false;

                    // 기본 위치: child의 위쪽에 메뉴를 표시
                    double top = childGlobalPosition.dy - menuSize.height - widget.spacing;
                    double left =
                        widget.alignMenuToChildRight
                            ? screenSize.width - 15 - menuSize.width
                            : childGlobalPosition.dx + childSize.width / 2 - menuSize.width / 2;

                    // 세로 방향: 기본은 "위"로 띄우고, 위에 공간이 부족하면 "아래"로 표시
                    if (top < 0) {
                      // 위에 충분한 공간이 없으므로 아래로 표시
                      top = childGlobalPosition.dy + childSize.height + widget.spacing;
                      isAboveChild = false;

                      // 아래로 띄웠을 때 화면을 넘치면 화면 안으로 클램프
                      if (top + menuSize.height > screenSize.height - 100) {
                        top = math.max(0, screenSize.height - 100 - menuSize.height);
                      }
                    } else {
                      // 위에 충분한 공간이 있어서 child 위쪽에 표시
                      isAboveChild = true;
                    }

                    // 가로 방향: 좌우로 넘치지 않도록 클램프
                    if (left < 0) {
                      left = 0;
                    } else if (left + menuSize.width > screenSize.width) {
                      left = screenSize.width - menuSize.width;
                    }
                    _menuRect = Rect.fromLTWH(left, top, menuSize.width, menuSize.height);

                    return Stack(
                      children: [
                        Positioned(
                          top: top,
                          left: left,
                          child: AnimatedBuilder(
                            animation: _menuAnimationController,
                            builder: (context, child) {
                              final scale = _computeMenuScale();
                              final alignment = isAboveChild ? Alignment.bottomCenter : Alignment.topCenter;
                              return Transform.scale(scale: scale, alignment: alignment, child: child);
                            },
                            child: SizedBox(
                              width: menuWidth,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Material(
                                  elevation: 4,
                                  color:
                                      widget.menuBackgroundColor ??
                                      context.coconutColors.surface.withValues(alpha: 0.68),
                                  child: BackdropFilter(
                                    filter:
                                        widget.menuBackgroundColor != null
                                            ? ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1)
                                            : ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color:
                                            widget.menuBackgroundColor == null
                                                ? context.coconutColors.surface.withValues(alpha: 0.1)
                                                : Colors.transparent,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      child: IntrinsicWidth(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(
                                            widget.menuItems.length,
                                            (index) => Semantics(
                                              button: true,
                                              label: widget.menuItems[index].title,
                                              onTap: () {
                                                _startHideAnimation();
                                                widget.menuItems[index].onSelected();
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 80),
                                                decoration: BoxDecoration(
                                                  color:
                                                      _hoveredMenuIndex == index
                                                          ? context.coconutColors.primaryText.withValues(alpha: 0.12)
                                                          : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    SvgPicture.asset(
                                                      widget.menuItems[index].iconPath,
                                                      width: 16,
                                                      height: 16,
                                                      colorFilter: ColorFilter.mode(
                                                        widget.menuItems[index].isDanger
                                                            ? context.coconutColors.danger
                                                            : context.coconutColors.iconPrimary,
                                                        BlendMode.srcIn,
                                                      ),
                                                    ),
                                                    CoconutLayout.spacing_200w,
                                                    Flexible(
                                                      child: Text(
                                                        widget.menuItems[index].title,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: CoconutTypography.body2_14.setColor(
                                                          widget.menuItems[index].isDanger
                                                              ? context.coconutColors.danger
                                                              : context.coconutColors.primaryText,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
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
            ],
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
    _isCapturingChild = false;

    // 메뉴 등장 애니메이션: 30% -> 110% -> 100%
    _isClosing = false;
    _menuAnimationController.duration = const Duration(milliseconds: 220);
    _menuAnimationController.forward(from: 0.0);
  }

  double _computeMenuScale() {
    final t = _menuAnimationController.value;

    if (_isClosing) {
      // 닫힐 때: 100% -> 0%
      return 1.0 * (1.0 - t);
    }

    // 열릴 때: 30% -> 110% -> 100%
    const double startScale = 0.3;
    const double overshootScale = 1.1;
    const double endScale = 1.0;

    if (t < 0.7) {
      final localT = t / 0.7;
      return startScale + (overshootScale - startScale) * localT;
    } else {
      final localT = (t - 0.7) / 0.3;
      return overshootScale + (endScale - overshootScale) * localT;
    }
  }

  void _updateHoveredMenuItem(Offset globalPosition) {
    final menuRect = _menuRect;
    if (menuRect == null) return;

    int? nextIndex;
    if (menuRect.contains(globalPosition)) {
      final localY = globalPosition.dy - menuRect.top - 8;
      if (localY >= 0) {
        final index = (localY / 44).floor();
        if (index >= 0 && index < widget.menuItems.length) nextIndex = index;
      }
    }

    if (_hoveredMenuIndex == nextIndex) return;
    _hoveredMenuIndex = nextIndex;
    if (nextIndex != null) vibrateExtraLight();
    _overlayEntry?.markNeedsBuild();
  }

  void _selectHoveredMenuItem() {
    final selectedIndex = _hoveredMenuIndex;
    if (selectedIndex == null) return;

    _hoveredMenuIndex = null;
    _startHideAnimation();
    widget.menuItems[selectedIndex].onSelected();
  }

  void _clearHoveredMenuItem() {
    if (_hoveredMenuIndex == null) return;
    _hoveredMenuIndex = null;
    _overlayEntry?.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _childKey,
      behavior: HitTestBehavior.opaque,
      onLongPress: _showMenu,
      child: RepaintBoundary(
        key: _childRepaintBoundaryKey,
        child: AnimatedBuilder(
          animation: Listenable.merge([_menuAnimationController, _shakeController, _closeButtonController]),
          builder: (context, child) {
            final scale = _computeChildScale();

            // 전체 카드(메뉴+child)가 살짝 기울어지는 애니메이션
            double angle = 0;
            if (widget.isEditMode) {
              angle = _shakeAnimation.value;
            }

            final menuButtonScale = _closeButtonController.value;

            return Transform.rotate(
              angle: angle,
              child: Transform.scale(
                scale: scale,
                child: Stack(
                  children: [
                    child!,
                    if ((widget.isEditMode || _closeButtonController.value > 0.0) && widget.onRemove != null)
                      Positioned(
                        top: -4,
                        left: 12,
                        child: Transform.scale(
                          scale: menuButtonScale,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: widget.onRemove,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(60),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: context.coconutColors.iconSecondary.withValues(alpha: 0.35),
                                      shape: BoxShape.circle,
                                    ),
                                    child: SvgPicture.asset(
                                      CommonActionIconPath.removeMinus,
                                      colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }

  double _computeChildScale() {
    // 메뉴가 떠 있지 않으면 항상 1.0 유지
    if (_overlayEntry == null) {
      return 1.0;
    }

    final t = _menuAnimationController.value;

    const double baseScale = 1.0;
    const double expandedScale = 1.05; // 5% 확장

    if (_isClosing) {
      // 닫힐 때: 1.1 -> 1.0
      return expandedScale + (baseScale - expandedScale) * t;
    } else {
      // 열릴 때: 1.0 -> 1.1
      return baseScale + (expandedScale - baseScale) * t;
    }
  }
}

/// 화면 전체를 살짝 어둡게 하되, [highlightRect] 주변은 상대적으로 밝게 보이도록 하는 페인터
class _DimExceptRectPainter extends CustomPainter {
  final Rect highlightRect;
  final Color dimColor;

  _DimExceptRectPainter({required this.highlightRect, required this.dimColor});

  @override
  void paint(Canvas canvas, Size size) {
    // highlightRect 바깥만 어둡게 덮는 영역 (안쪽은 그대로 둠)
    final dimPaint = Paint()..color = dimColor;
    final path =
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size) // 전체 화면
          ..addRRect(RRect.fromRectAndRadius(highlightRect, const Radius.circular(12.0))); // 가운데 구멍
    canvas.drawPath(path, dimPaint);

    // 추가적인 색을 입히지 않고, 가운데는 그대로 두고 주변만 dim 처리
  }

  @override
  bool shouldRepaint(covariant _DimExceptRectPainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect;
  }
}

class LongPressedMenuItem {
  final String title;
  final String iconPath;
  final bool isDanger;
  final VoidCallback _onSelected;

  LongPressedMenuItem({
    required this.title,
    required this.iconPath,
    required VoidCallback onSelected,
    this.isDanger = false,
  }) : _onSelected = onSelected;

  void onSelected() => _onSelected();
}
