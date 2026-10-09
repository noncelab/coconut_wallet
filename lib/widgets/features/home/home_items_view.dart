import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/services/home/home_grid_geometry.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeItemsView extends StatefulWidget {
  static const double cell = 80;
  static const double gap = 12;

  /// 홈 화면 편집 중 이 시간 동안 아무 입력이 없으면 편집을 끝낸다.
  static const arrangeIdleTimeout = Duration(seconds: 10);

  final HomeConfiguration configuration;
  final HomeItemRegistry registry;
  final void Function(String id, HomeGridPosition position)? onMoveToCell;
  final void Function(String id, String beforeId)? onInsertBefore;
  final double minHeight;

  /// 있으면 길게 눌렀을 때 끌기 대신 메뉴를 띄운다. [isArranging]이면 모든 항목이 흔들리고 바로 끌 수 있다.
  final List<LongPressedMenuItem> Function(HomeItem item)? menuItemsOf;
  final bool isArranging;
  final void Function(HomeItem item)? onRemove;
  final VoidCallback? onArrangeDone;

  /// 있으면 크기를 여러 개 지원하는 위젯의 메뉴 맨 위에 크기 고르기를 띄운다.
  final void Function(HomeItem item, HomeSpan span)? onResize;

  /// 그리드 둘레의 여백. 편집 중 꼭짓점에 걸치는 제거 버튼이 이 안에서 눌리도록 둔다.
  final double badgeInset;

  const HomeItemsView({
    super.key,
    required this.configuration,
    required this.registry,
    this.onMoveToCell,
    this.onInsertBefore,
    this.minHeight = 0,
    this.menuItemsOf,
    this.isArranging = false,
    this.onRemove,
    this.onArrangeDone,
    this.onResize,
    this.badgeInset = 0,
  });

  @override
  State<HomeItemsView> createState() => _HomeItemsViewState();
}

class _HomeItemsViewState extends State<HomeItemsView> {
  static const int dropRowsBelowContent = 2;
  static const double autoScrollEdge = 60;
  static const double autoScrollMaxStep = 14;
  static const Duration _autoScrollInterval = Duration(milliseconds: 16);

  final GlobalKey _surfaceKey = GlobalKey();
  Timer? _autoScrollTimer;
  double _autoScrollStep = 0;
  Timer? _idleTimer;
  HomeConfiguration? _previewConfiguration;
  String? _previewDraggedId;
  String? _previewTargetId;
  HomeGridPosition? _previewCell;
  Offset? _dragGlobalPosition;

  @override
  void initState() {
    super.initState();
    _restartIdleTimer();
  }

  @override
  void didUpdateWidget(covariant HomeItemsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isArranging != widget.isArranging) _restartIdleTimer();
    if (oldWidget.configuration != widget.configuration) {
      _previewConfiguration = null;
      _previewDraggedId = null;
      _previewTargetId = null;
      _previewCell = null;
      _dragGlobalPosition = null;
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _stopAutoScroll();
    super.dispose();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer =
        widget.isArranging ? Timer(HomeItemsView.arrangeIdleTimeout, () => widget.onArrangeDone?.call()) : null;
  }

  void _onDragUpdate(String draggedId, DragUpdateDetails details) {
    _dragGlobalPosition = details.globalPosition;
    _updatePreview(draggedId, details.globalPosition);
    final scrollable = Scrollable.maybeOf(context);
    final box = scrollable?.context.findRenderObject();
    if (scrollable == null || box is! RenderBox) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final y = details.globalPosition.dy;
    double closeness(double distance) => ((autoScrollEdge - distance) / autoScrollEdge).clamp(0.0, 1.0);
    _autoScrollStep =
        y < top + autoScrollEdge
            ? -autoScrollMaxStep * closeness(y - top)
            : y > bottom - autoScrollEdge
            ? autoScrollMaxStep * closeness(bottom - y)
            : 0;
    if (_autoScrollStep == 0) {
      _stopAutoScroll();
      return;
    }
    _autoScrollTimer ??= Timer.periodic(_autoScrollInterval, (_) {
      final position = scrollable.position;
      final next = (position.pixels + _autoScrollStep).clamp(position.minScrollExtent, position.maxScrollExtent);
      if (next != position.pixels) {
        position.jumpTo(next);
        if (_dragGlobalPosition != null) _updatePreview(draggedId, _dragGlobalPosition!);
      }
    });
  }

  void _clearPreview() {
    _dragGlobalPosition = null;
    _previewDraggedId = null;
    _previewTargetId = null;
    _previewCell = null;
    if (_previewConfiguration != null) setState(() => _previewConfiguration = null);
  }

  void _updatePreview(String draggedId, Offset globalPosition) {
    final dragged = _itemById(draggedId);
    final surface = _surfaceKey.currentContext?.findRenderObject();
    if (dragged == null || surface is! RenderBox || !surface.hasSize) return;
    final local = _toSurface(globalPosition);
    final cellExtent = (surface.size.width - widget.badgeInset * 2 - (_columns - 1) * _gap) / _columns;
    final gridWidth = HomeGridGeometry.extent(_columns, cellExtent, _gap);
    if (local.dx < 0 ||
        local.dx >= gridWidth ||
        local.dy < 0 ||
        local.dy >= surface.size.height - widget.badgeInset * 2) {
      if (_previewConfiguration != null) setState(() => _previewConfiguration = null);
      _previewTargetId = null;
      _previewCell = null;
      return;
    }

    final layout = HomeGridLayout(widget.configuration);
    final geometry = HomeGridGeometry(cellExtent: cellExtent, gap: _gap);
    HomeItem? target;
    for (final item in layout.itemsInVisualOrder.reversed) {
      final position = layout.positionOf(item.id)!;
      if (geometry.rectOf(position, item.span).contains(local) && _accepts(item, draggedId)) {
        target = item;
        break;
      }
    }

    String? targetId;
    HomeGridPosition? cell;
    if (target != null &&
        widget.onInsertBefore != null &&
        (dragged.span != HomeSpan.wide || widget.onMoveToCell == null)) {
      targetId = target.id;
    } else if (widget.onMoveToCell != null) {
      cell =
          target == null
              ? geometry.dropPosition(layout, dragged, local)
              : HomeGridLayout.anchorForSpan(layout.positionOf(target.id)!, dragged.span);
    }
    if (_previewDraggedId == draggedId && _previewTargetId == targetId && _previewCell == cell) return;
    _previewDraggedId = draggedId;
    _previewTargetId = targetId;
    _previewCell = cell;
    setState(() {
      _previewConfiguration =
          targetId != null
              ? layout.moveBefore(draggedId, targetId)
              : widget.onMoveToCell != null && cell != null && layout.canMoveToCell(draggedId, cell)
              ? layout.moveToCell(draggedId, cell)
              : null;
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollStep = 0;
  }

  static const double _gap = HomeItemsView.gap;
  static const int _columns = HomeGridLayout.columns;

  bool get _draggable => widget.onMoveToCell != null || widget.onInsertBefore != null;

  HomeItem? _itemById(String id) => widget.configuration.items.where((item) => item.id == id).firstOrNull;

  Offset _toSurface(Offset globalOffset) {
    final box = _surfaceKey.currentContext!.findRenderObject()! as RenderBox;
    return box.globalToLocal(globalOffset) - Offset(widget.badgeInset, widget.badgeInset);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.configuration.items;
    final layout = HomeGridLayout(widget.configuration);
    final previewLayout = _previewConfiguration == null ? layout : HomeGridLayout(_previewConfiguration!);
    final inset = widget.badgeInset;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth - inset * 2;
        final cellExtent =
            maxWidth.isFinite
                ? ((maxWidth - (_columns - 1) * _gap) / _columns).clamp(1.0, HomeItemsView.cell).toDouble()
                : HomeItemsView.cell;
        // Keep the surface fixed while dragging so a centered grid does not move under the pointer.
        final rowCount = math.max(1, layout.rows);
        final geometry = HomeGridGeometry(cellExtent: cellExtent, gap: _gap);
        final gridWidth = HomeGridGeometry.extent(_columns, cellExtent, _gap);
        final sidePadding = maxWidth.isFinite ? math.max(0.0, (maxWidth - gridWidth) / 2) : 0.0;
        final lead =
            widget.isArranging && widget.onRemove != null && widget.menuItemsOf != null ? _RemoveBadge.lead : 0.0;
        HomeGridPosition dropPositionFor(HomeItem dragged, Offset globalOffset) =>
            geometry.dropPosition(layout, dragged, _toSurface(globalOffset));
        final grid = Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          child: SizedBox(
            key: const ValueKey('home-grid-surface'),
            width: gridWidth + inset * 2,
            height:
                math.max(
                  HomeGridGeometry.extent(rowCount + (_draggable ? dropRowsBelowContent : 0), cellExtent, _gap),
                  widget.minHeight,
                ) +
                inset * 2,
            child: SizedBox(
              key: _surfaceKey,
              child: DragTarget<String>(
                onWillAcceptWithDetails: (details) {
                  final item = _itemById(details.data);
                  if (widget.onMoveToCell == null || item == null) return false;
                  return layout.canMoveToCell(item.id, dropPositionFor(item, details.offset));
                },
                onAcceptWithDetails: (details) {
                  final item = _itemById(details.data);
                  if (item == null) return;
                  widget.onMoveToCell?.call(details.data, dropPositionFor(item, details.offset));
                },
                builder:
                    (context, candidates, rejected) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned.fill(child: ColoredBox(color: CupertinoColors.transparent)),
                        for (final item in items)
                          if (widget.registry.byId(item.definitionId) case final definition?)
                            if (layout.positionOf(item.id) case final position?)
                              Positioned(
                                key: ValueKey('home-item-position-${item.id}'),
                                left: inset + position.column * (cellExtent + _gap) - lead,
                                top: inset + position.row * (cellExtent + _gap) - lead,
                                child: TweenAnimationBuilder<Offset>(
                                  tween: Tween(
                                    begin: Offset.zero,
                                    end: Offset(
                                      ((previewLayout.positionOf(item.id)?.column ?? position.column) -
                                              position.column) *
                                          (cellExtent + _gap),
                                      ((previewLayout.positionOf(item.id)?.row ?? position.row) - position.row) *
                                          (cellExtent + _gap),
                                    ),
                                  ),
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  // Paint the preview at its new cell while drop hit testing stays at the original cell.
                                  builder:
                                      (context, offset, child) =>
                                          Transform.translate(offset: offset, transformHitTests: false, child: child),
                                  child: _buildItem(context, item, position, definition, cellExtent, lead),
                                ),
                              ),
                      ],
                    ),
              ),
            ),
          ),
        );
        if (!widget.isArranging) return grid;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _restartIdleTimer(),
          onPointerMove: (_) => _restartIdleTimer(),
          child: GestureDetector(
            key: const ValueKey('home-grid-arranging'),
            behavior: HitTestBehavior.translucent,
            onTap: widget.onArrangeDone,
            child: grid,
          ),
        );
      },
    );
  }

  bool _accepts(HomeItem target, String draggedId) {
    if (!_draggable || draggedId == target.id) return false;
    final dragged = _itemById(draggedId);
    final tooLarge =
        dragged != null && (dragged.span.width > target.span.width || dragged.span.height > target.span.height);
    return !(widget.onMoveToCell != null && tooLarge);
  }

  void _drop(HomeItem target, HomeGridPosition position, String draggedId) {
    final dragged = _itemById(draggedId);
    final onMoveToCell = widget.onMoveToCell;
    final onInsertBefore = widget.onInsertBefore;
    if (onMoveToCell != null && dragged?.span == HomeSpan.wide) {
      onMoveToCell(draggedId, HomeGridLayout.anchorForSpan(position, dragged?.span));
    } else if (onInsertBefore != null) {
      onInsertBefore(draggedId, target.id);
    } else {
      onMoveToCell?.call(draggedId, position);
    }
  }

  Widget _buildItem(
    BuildContext context,
    HomeItem item,
    HomeGridPosition position,
    HomeItemDefinition definition,
    double cellExtent,
    double lead,
  ) {
    final size = HomeGridGeometry(cellExtent: cellExtent, gap: _gap).sizeOf(item.span);
    final content = definition.build(context, item);
    final box = SizedBox(width: size.width, height: size.height, child: content);
    if (!_draggable) return SizedBox(key: ValueKey('home-item-${item.id}'), child: box);

    if (widget.menuItemsOf != null) {
      return DragTarget<String>(
        key: ValueKey('home-item-${item.id}'),
        onWillAcceptWithDetails: (details) => _accepts(item, details.data),
        onAcceptWithDetails: (details) => _drop(item, position, details.data),
        builder: (context, candidates, rejected) {
          final arranging = widget.isArranging;
          final inLeftHalf = position.column + item.span.width / 2 <= _columns / 2;
          return Draggable<String>(
            key: ValueKey('home-item-draggable-${item.id}'),
            data: item.id,
            maxSimultaneousDrags: arranging ? 1 : 0,
            onDragUpdate: (details) => _onDragUpdate(item.id, details),
            onDragEnd: (_) {
              _stopAutoScroll();
              _clearPreview();
            },
            dragAnchorStrategy: (_, __, ___) => Offset(size.width / 2, size.height / 2),
            feedback: Opacity(opacity: 0.7, child: SizedBox(width: size.width, height: size.height, child: content)),
            childWhenDragging: Padding(
              padding: EdgeInsets.only(left: lead, top: lead),
              child: Opacity(opacity: 0.3, child: box),
            ),
            child: _Jiggle(
              enabled: arranging,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: lead, top: lead),
                    child: AbsorbPointer(
                      absorbing: arranging,
                      child: LongPressedMenuWidget(
                        menuItems: widget.menuItemsOf!(item),
                        useGlassOverlay: true,
                        preferMenuBelow: true,
                        alignMenuToChildLeft: inLeftHalf,
                        alignMenuToChildRight: !inLeftHalf,
                        menuBackgroundColor: context.coconutColors.homeSurface,
                        menuIconSize: 20,
                        menuHeaderHeight: _SizePicker.height,
                        menuHeaderBuilder:
                            widget.onResize != null && definition.supportedSpans.length > 1
                                ? (close) => _SizePicker(
                                  itemId: item.id,
                                  spans: definition.supportedSpans,
                                  selected: item.span,
                                  onSelected: (span) {
                                    close();
                                    widget.onResize!(item, span);
                                  },
                                )
                                : null,
                        child: SizedBox(key: ValueKey('home-item-content-${item.id}'), child: box),
                      ),
                    ),
                  ),
                  if (lead > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: _RemoveBadge(
                        key: ValueKey('home-item-remove-${item.id}'),
                        onTap: () => widget.onRemove?.call(item),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    return DragTarget<String>(
      key: ValueKey('home-item-${item.id}'),
      onWillAcceptWithDetails: (details) => _accepts(item, details.data),
      onAcceptWithDetails: (details) => _drop(item, position, details.data),
      builder:
          (context, candidates, rejected) => LongPressDraggable<String>(
            data: item.id,
            onDragUpdate: (details) => _onDragUpdate(item.id, details),
            onDragEnd: (_) {
              _stopAutoScroll();
              _clearPreview();
            },
            dragAnchorStrategy: (_, __, ___) => Offset(size.width / 2, size.height / 2),
            feedback: Opacity(opacity: 0.7, child: SizedBox(width: size.width, height: size.height, child: content)),
            childWhenDragging: Opacity(opacity: 0.3, child: box),
            child: box,
          ),
    );
  }
}

/// 편집 중 항목 왼쪽 위 꼭짓점에 걸치는 제거 버튼. 모양은 기존 홈 편집 모드와 같고 항목과 함께 흔들린다.
class _RemoveBadge extends StatelessWidget {
  static const double extent = 32;
  static const double _visible = 24;

  /// 꼭짓점에서 항목 안쪽으로 들이는 거리(가로·세로 같음)
  static const double inward = 4;

  /// 버튼을 항목 영역 안에 넣으려고 편집 중 항목 왼쪽·위로 넓히는 폭
  static const double lead = extent / 2 - inward;

  final VoidCallback onTap;

  const _RemoveBadge({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: extent,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 200),
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(
                  width: _visible,
                  height: _visible,
                  padding: const EdgeInsets.all(2),
                  color: colors.iconSecondary.withValues(alpha: 0.35),
                  child: SvgPicture.asset(
                    CommonActionIconPath.removeMinus,
                    colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 기존 홈 편집 모드(LongPressedMenuWidget.isEditMode)와 같은 흔들림. 항목마다 시작을 조금씩 늦춰 엇갈리게 흔든다.
class _Jiggle extends StatefulWidget {
  final bool enabled;
  final Widget child;

  const _Jiggle({required this.enabled, required this.child});

  @override
  State<_Jiggle> createState() => _JiggleState();
}

class _JiggleState extends State<_Jiggle> with SingleTickerProviderStateMixin {
  static const _maxAngle = 0.02;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final Animation<double> _angle = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -_maxAngle), weight: 1),
    TweenSequenceItem(tween: Tween(begin: -_maxAngle, end: 0.0), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: _maxAngle), weight: 1),
    TweenSequenceItem(tween: Tween(begin: _maxAngle, end: 0.0), weight: 1),
  ]).animate(_controller);
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _start();
  }

  @override
  void didUpdateWidget(covariant _Jiggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) return;
    if (widget.enabled) {
      _start();
    } else {
      _startTimer?.cancel();
      _controller
        ..stop()
        ..reset();
    }
  }

  void _start() {
    _startTimer?.cancel();
    _startTimer = Timer(Duration(milliseconds: math.Random().nextInt(100)), () {
      if (mounted && widget.enabled) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => Transform.rotate(angle: widget.enabled ? _angle.value : 0, child: child),
    );
  }
}

/// 길게 누르기 메뉴 맨 위의 위젯 크기 고르기. 아이폰 홈 화면처럼 크기 모양 아이콘을 나란히 둔다.
class _SizePicker extends StatelessWidget {
  static const double height = 56;

  final String itemId;
  final List<HomeSpan> spans;
  final HomeSpan selected;
  final ValueChanged<HomeSpan> onSelected;

  const _SizePicker({required this.itemId, required this.spans, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final span in spans)
          GestureDetector(
            key: ValueKey('home-item-size-$itemId-${span.toJson()}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(span),
            child: Container(
              width: 52,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: span == selected ? colors.primaryText.withValues(alpha: 0.08) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: span.width >= 4 ? 30 : 18,
                height: span.height >= 2 ? 16 : 10,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.primaryText, width: 1.6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
