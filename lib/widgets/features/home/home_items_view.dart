import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutColors;
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/services/home/home_grid_geometry.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:flutter/cupertino.dart';

class HomeItemsView extends StatefulWidget {
  static const double cell = 80;
  static const double gap = 12;

  final HomeConfiguration configuration;
  final HomeItemRegistry registry;
  final void Function(String id, HomeGridPosition position)? onMoveToCell;
  final void Function(String id, String beforeId)? onInsertBefore;
  final double minHeight;

  const HomeItemsView({
    super.key,
    required this.configuration,
    required this.registry,
    this.onMoveToCell,
    this.onInsertBefore,
    this.minHeight = 0,
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

  @override
  void dispose() {
    _stopAutoScroll();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
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
      if (next != position.pixels) position.jumpTo(next);
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
    return box.globalToLocal(globalOffset);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.configuration.items;
    final layout = HomeGridLayout(widget.configuration);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellExtent =
            constraints.maxWidth.isFinite
                ? ((constraints.maxWidth - (_columns - 1) * _gap) / _columns).clamp(1.0, HomeItemsView.cell).toDouble()
                : HomeItemsView.cell;
        final rowCount = layout.rows == 0 ? 1 : layout.rows;
        final geometry = HomeGridGeometry(cellExtent: cellExtent, gap: _gap);
        final gridWidth = HomeGridGeometry.extent(_columns, cellExtent, _gap);
        final sidePadding = constraints.maxWidth.isFinite ? math.max(0.0, (constraints.maxWidth - gridWidth) / 2) : 0.0;
        HomeGridPosition dropPositionFor(HomeItem dragged, Offset globalOffset) =>
            geometry.dropPosition(layout, dragged, _toSurface(globalOffset));
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          child: SizedBox(
            key: const ValueKey('home-grid-surface'),
            width: gridWidth,
            height: math.max(
              HomeGridGeometry.extent(rowCount + (_draggable ? dropRowsBelowContent : 0), cellExtent, _gap),
              widget.minHeight,
            ),
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
                      children: [
                        const Positioned.fill(child: ColoredBox(color: CupertinoColors.transparent)),
                        for (final item in items)
                          if (widget.registry.byId(item.definitionId) case final definition?)
                            if (layout.positionOf(item.id) case final position?)
                              Positioned(
                                left: position.column * (cellExtent + _gap),
                                top: position.row * (cellExtent + _gap),
                                child: _buildItem(context, item, position, definition, cellExtent),
                              ),
                      ],
                    ),
              ),
            ),
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
  ) {
    final size = HomeGridGeometry(cellExtent: cellExtent, gap: _gap).sizeOf(item.span);
    final content = definition.build(context, item);
    final box = SizedBox(width: size.width, height: size.height, child: content);
    if (!_draggable) return SizedBox(key: ValueKey('home-item-${item.id}'), child: box);

    return DragTarget<String>(
      key: ValueKey('home-item-${item.id}'),
      onWillAcceptWithDetails: (details) => _accepts(item, details.data),
      onAcceptWithDetails: (details) => _drop(item, position, details.data),
      builder:
          (context, candidates, rejected) => LongPressDraggable<String>(
            data: item.id,
            onDragUpdate: _onDragUpdate,
            onDragEnd: (_) => _stopAutoScroll(),
            dragAnchorStrategy: (_, __, ___) => Offset(size.width / 2, size.height / 2),
            feedback: Opacity(opacity: 0.7, child: SizedBox(width: size.width, height: size.height, child: content)),
            childWhenDragging: Opacity(opacity: 0.3, child: box),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(item.kind == HomeItemKind.shortcut ? 16 : 20),
                border: candidates.isEmpty ? null : Border.all(color: CoconutColors.gray500, width: 2),
              ),
              child: box,
            ),
          ),
    );
  }
}
