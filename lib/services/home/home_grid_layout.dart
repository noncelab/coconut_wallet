import 'dart:math' as math;

import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';

class HomeGridLayout {
  static const columns = 4;
  static const _origin = HomeGridPosition(0, 0);

  final HomeConfiguration configuration;
  late final Map<String, HomeItem> _itemsById = {for (final item in configuration.items) item.id: item};
  late final Map<String, HomeGridPosition> _positions = _placeItems();

  HomeGridLayout(this.configuration);

  HomeGridPosition? positionOf(String id) => _positions[id];

  int get rows => _bottom(_positions);

  HomeConfiguration get positionedConfiguration => _withPositions(_positions);

  List<HomeItem> get itemsInVisualOrder => [...configuration.items]..sort((a, b) {
    final aPosition = _positions[a.id]!;
    final bPosition = _positions[b.id]!;
    final rowComparison = aPosition.row.compareTo(bPosition.row);
    return rowComparison != 0 ? rowComparison : aPosition.column.compareTo(bPosition.column);
  });

  bool canMoveToCell(String id, HomeGridPosition target) {
    final item = _itemsById[id];
    return item != null && _withinBounds(item.span, target);
  }

  static HomeGridPosition anchorForSpan(HomeGridPosition position, HomeSpan? span) {
    if (span == HomeSpan.small) return HomeGridPosition((position.column ~/ 2) * 2, position.row);
    if (span == HomeSpan.wide) return HomeGridPosition(0, position.row);
    return position;
  }

  HomeConfiguration moveToCell(String id, HomeGridPosition target) {
    final item = _itemsById[id];
    if (item == null || !canMoveToCell(id, target)) return positionedConfiguration;
    final source = _positions[id]!;
    if (source == target) return positionedConfiguration;
    final placed = Map<String, HomeGridPosition>.of(_positions)..remove(id);
    if (item.span == HomeSpan.shortcut && source.row > target.row && _hasWideOnRow(placed, target.row, exceptId: id)) {
      _shiftRowsDown(placed, fromRow: target.row, by: item.span.height);
    } else if (item.span == HomeSpan.wide && target.row < source.row && !_crossesTallItem(placed, target.row, id)) {
      _shiftRowsDown(placed, fromRow: target.row, toRow: source.row, by: item.span.height);
    } else {
      return _placeAndRelocateDisplaced(item, source, target, placed);
    }
    placed[id] = target;
    return _withPositions(placed);
  }

  HomeConfiguration moveBefore(String id, String beforeId) {
    if (id == beforeId) return positionedConfiguration;
    final moving = _itemsById[id];
    final before = _itemsById[beforeId];
    if (moving == null || before == null) return positionedConfiguration;
    if (moving.span == HomeSpan.shortcut &&
        before.span == HomeSpan.wide &&
        _positions[id]!.row > _positions[beforeId]!.row) {
      return moveToCell(id, HomeGridPosition(0, _positions[beforeId]!.row));
    }
    final ordered = itemsInVisualOrder..remove(moving);
    ordered.insert(ordered.indexOf(before), moving);
    final insertionIndex = ordered.indexOf(moving);
    final prefix = ordered.take(insertionIndex).toList();
    final positions = {for (final item in prefix) item.id: _positions[item.id]!};
    final start = _positions[beforeId]!;
    var rowHeight = 0;
    for (final item in prefix) {
      final position = positions[item.id]!;
      if (position.row <= start.row && start.row < position.row + item.span.height) {
        rowHeight = math.max(rowHeight, position.row + item.span.height - start.row);
      }
    }
    _flow(ordered.skip(insertionIndex), positions, prefix, start, rowHeight);
    return HomeConfiguration(
      version: configuration.version,
      items: [
        for (var index = 0; index < ordered.length; index++)
          ordered[index].copyWith(order: index, position: positions[ordered[index].id]),
      ],
      shortcutWalletContext: configuration.shortcutWalletContext,
    );
  }

  bool wideDropKeepsSnappedRow(List<HomeItem> others, int row) {
    bool occupiesRow(HomeItem item) {
      final position = positionOf(item.id);
      return position != null && position.row <= row && row < position.row + item.span.height;
    }

    final crossesTallItem = others.any((item) {
      final position = positionOf(item.id);
      return position != null && position.row < row && occupiesRow(item);
    });
    final shortcutStartsOnRow = others.any((item) => item.span.height == 1 && positionOf(item.id)?.row == row);
    if (!crossesTallItem && shortcutStartsOnRow) return true;
    final rowIsEmpty = !others.any(occupiesRow);
    final itemsEndingAbove =
        others.where((item) {
          final position = positionOf(item.id);
          return position != null && position.row + item.span.height == row;
        }).toList();
    return rowIsEmpty && itemsEndingAbove.isNotEmpty && itemsEndingAbove.every((item) => item.span.height == 1);
  }

  void _flow(
    Iterable<HomeItem> items,
    Map<String, HomeGridPosition> positions,
    List<HomeItem> alreadyPlaced,
    HomeGridPosition start,
    int startRowHeight,
  ) {
    var row = start.row;
    var column = start.column;
    var rowHeight = startRowHeight;
    final placed = [...alreadyPlaced];
    void nextRow() {
      row += math.max(rowHeight, 1);
      column = 0;
      rowHeight = 0;
    }

    var first = true;
    for (final item in items) {
      while (true) {
        final followsStaggeredTallItem =
            !first &&
            item.span.height < rowHeight &&
            placed.any((previous) {
              final position = positions[previous.id]!;
              return position.row == row && position.column > 0 && previous.span.height > item.span.height;
            });
        if (column > 0 && (column + item.span.width > columns || followsStaggeredTallItem)) {
          nextRow();
          continue;
        }
        if (_fits(item.span, HomeGridPosition(column, row), positions)) break;
        column++;
        if (column >= columns) nextRow();
      }
      positions[item.id] = HomeGridPosition(column, row);
      placed.add(item);
      column += item.span.width;
      rowHeight = math.max(rowHeight, item.span.height);
      first = false;
      if (column == columns) {
        row += rowHeight;
        column = 0;
        rowHeight = 0;
      }
    }
  }

  bool _hasWideOnRow(Map<String, HomeGridPosition> placed, int row, {required String exceptId}) => configuration.items
      .any((other) => other.id != exceptId && other.span == HomeSpan.wide && placed[other.id]?.row == row);

  bool _crossesTallItem(Map<String, HomeGridPosition> placed, int row, String exceptId) =>
      configuration.items.any((other) {
        if (other.id == exceptId) return false;
        final position = placed[other.id];
        return position != null && position.row < row && row < position.row + other.span.height;
      });

  void _shiftRowsDown(Map<String, HomeGridPosition> placed, {required int fromRow, int? toRow, required int by}) {
    for (final entry in placed.entries.toList()) {
      final position = entry.value;
      if (position.row >= fromRow && (toRow == null || position.row < toRow)) {
        placed[entry.key] = HomeGridPosition(position.column, position.row + by);
      }
    }
  }

  HomeConfiguration _placeAndRelocateDisplaced(
    HomeItem item,
    HomeGridPosition source,
    HomeGridPosition target,
    Map<String, HomeGridPosition> placed,
  ) {
    final displaced =
        configuration.items.where((other) {
            if (other.id == item.id) return false;
            final position = placed[other.id];
            return position != null &&
                (_overlaps(item.span, target, other.span, position) ||
                    _tallRowConflict(item.span, target, other.span, position));
          }).toList()
          ..sort((a, b) {
            final aPosition = placed[a.id]!;
            final bPosition = placed[b.id]!;
            final rowComparison = aPosition.row.compareTo(bPosition.row);
            return rowComparison != 0 ? rowComparison : aPosition.column.compareTo(bPosition.column);
          });
    for (final other in displaced) {
      placed.remove(other.id);
    }
    placed[item.id] = target;
    for (final other in displaced) {
      placed[other.id] = _fits(other.span, source, placed) ? source : _firstFreeFrom(other.span, placed, _origin);
    }
    return _withPositions(placed);
  }

  Map<String, HomeGridPosition> _placeItems() {
    final placed = <String, HomeGridPosition>{};
    if (!configuration.items.any((item) => item.position != null)) {
      _flowWithoutCollisions(configuration.items, placed);
      return placed;
    }
    HomeItem? previous;
    for (final item in configuration.items) {
      final position = item.position;
      if (position != null && _fits(item.span, position, placed)) {
        placed[item.id] = position;
      } else {
        final previousPosition = previous == null ? null : placed[previous.id];
        final start =
            previousPosition == null
                ? _origin
                : HomeGridPosition(previousPosition.column + previous!.span.width, previousPosition.row);
        placed[item.id] = _firstFreeFrom(item.span, placed, start);
      }
      previous = item;
    }
    return placed;
  }

  void _flowWithoutCollisions(List<HomeItem> items, Map<String, HomeGridPosition> placed) {
    var row = 0;
    var column = 0;
    var rowHeight = 0;
    for (final item in items) {
      while (true) {
        if (column + item.span.width > columns) {
          row += math.max(rowHeight, 1);
          column = 0;
          rowHeight = 0;
          continue;
        }
        if (_withinBounds(item.span, HomeGridPosition(column, row))) break;
        column++;
      }
      placed[item.id] = HomeGridPosition(column, row);
      column += item.span.width;
      rowHeight = math.max(rowHeight, item.span.height);
      if (column == columns) {
        row += rowHeight;
        column = 0;
        rowHeight = 0;
      }
    }
  }

  HomeGridPosition _firstFreeFrom(HomeSpan span, Map<String, HomeGridPosition> placed, HomeGridPosition start) {
    for (var row = start.row; ; row++) {
      for (var column = row == start.row ? start.column : 0; column <= columns - span.width; column++) {
        final candidate = HomeGridPosition(column, row);
        if (_fits(span, candidate, placed)) return candidate;
      }
    }
  }

  int _bottom(Map<String, HomeGridPosition> positions) {
    var bottom = 0;
    for (final item in configuration.items) {
      final position = positions[item.id];
      if (position != null) bottom = math.max(bottom, position.row + item.span.height);
    }
    return bottom;
  }

  bool _fits(HomeSpan span, HomeGridPosition target, Map<String, HomeGridPosition> placed) {
    if (!_withinBounds(span, target)) return false;
    for (final item in configuration.items) {
      final position = placed[item.id];
      if (position != null &&
          (_overlaps(span, target, item.span, position) || _tallRowConflict(span, target, item.span, position))) {
        return false;
      }
    }
    return true;
  }

  bool _withinBounds(HomeSpan span, HomeGridPosition position) =>
      position.column >= 0 &&
      position.row >= 0 &&
      position.column + span.width <= columns &&
      (span != HomeSpan.small || position.column.isEven);

  bool _tallRowConflict(HomeSpan a, HomeGridPosition aPosition, HomeSpan b, HomeGridPosition bPosition) =>
      a.height > 1 &&
      b.height > 1 &&
      aPosition.row != bPosition.row &&
      aPosition.row < bPosition.row + b.height &&
      bPosition.row < aPosition.row + a.height;

  bool _overlaps(HomeSpan a, HomeGridPosition aPosition, HomeSpan b, HomeGridPosition bPosition) =>
      aPosition.column < bPosition.column + b.width &&
      aPosition.column + a.width > bPosition.column &&
      aPosition.row < bPosition.row + b.height &&
      aPosition.row + a.height > bPosition.row;

  HomeConfiguration _withPositions(Map<String, HomeGridPosition> positions) => HomeConfiguration(
    version: configuration.version,
    items: [for (final item in configuration.items) item.copyWith(position: positions[item.id])],
    shortcutWalletContext: configuration.shortcutWalletContext,
  );
}
