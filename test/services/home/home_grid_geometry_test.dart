import 'dart:ui';

import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/services/home/home_grid_geometry.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:flutter_test/flutter_test.dart';

HomeItem _placed(String id, HomeSpan span, HomeItemKind kind, int column, int row, int order) =>
    HomeItem(id: id, definitionId: id, kind: kind, order: order, span: span, position: HomeGridPosition(column, row));

void main() {
  const geometry = HomeGridGeometry(cellExtent: 80, gap: 12);
  Offset cell(int column, int row) => Offset(column * 92.0, row * 92.0);

  final layout = HomeGridLayout(
    HomeConfiguration(
      items: [
        _placed('a', HomeSpan.shortcut, HomeItemKind.shortcut, 2, 0, 0),
        _placed('b', HomeSpan.shortcut, HomeItemKind.shortcut, 3, 0, 1),
        _placed('w', HomeSpan.small, HomeItemKind.widget, 0, 1, 2),
        _placed('s', HomeSpan.shortcut, HomeItemKind.shortcut, 2, 1, 3),
      ],
    ),
  );
  final s = layout.positionedConfiguration.items.firstWhere((item) => item.id == 's');

  test('sizes follow the span', () {
    expect(geometry.sizeOf(HomeSpan.shortcut), const Size(80, 80));
    expect(geometry.sizeOf(HomeSpan.small), const Size(172, 172));
    expect(geometry.sizeOf(HomeSpan.wide), const Size(356, 172));
  });

  test('a drop inside the grid snaps to the cell under the finger', () {
    expect(geometry.dropPosition(layout, s, cell(1, 0)), const HomeGridPosition(1, 0));
  });

  test('a drop below the content lands on the cell under the finger', () {
    for (var column = 0; column < 4; column++) {
      expect(geometry.dropPosition(layout, s, cell(column, 7)), HomeGridPosition(column, 7));
    }
  });

  test('a 2×2 dropped below the content snaps one column at a time and stays in bounds', () {
    final w = layout.positionedConfiguration.items.firstWhere((item) => item.id == 'w');

    expect(geometry.dropPosition(layout, w, cell(-1, 6)), const HomeGridPosition(0, 6));
    expect(geometry.dropPosition(layout, w, cell(0, 6)), const HomeGridPosition(0, 6));
    expect(geometry.dropPosition(layout, w, cell(1, 6)), const HomeGridPosition(1, 6));
    expect(geometry.dropPosition(layout, w, cell(2, 6)), const HomeGridPosition(2, 6));
    expect(geometry.dropPosition(layout, w, cell(3, 6)), const HomeGridPosition(2, 6));
  });

  test('a 2×2 changes columns at each half-cell boundary', () {
    expect(geometry.snap(const Offset(45.9, 184), HomeSpan.small), const HomeGridPosition(0, 2));
    expect(geometry.snap(const Offset(46.1, 184), HomeSpan.small), const HomeGridPosition(1, 2));
    expect(geometry.snap(const Offset(137.9, 184), HomeSpan.small), const HomeGridPosition(1, 2));
    expect(geometry.snap(const Offset(138.1, 184), HomeSpan.small), const HomeGridPosition(2, 2));
  });

  test('the center 2×2 rectangle leaves a full shortcut column at either side', () {
    final centered = geometry.rectOf(const HomeGridPosition(1, 2), HomeSpan.small);
    final left = geometry.rectOf(const HomeGridPosition(0, 2), HomeSpan.shortcut);
    final right = geometry.rectOf(const HomeGridPosition(3, 2), HomeSpan.shortcut);

    expect(centered, const Rect.fromLTWH(92, 184, 172, 172));
    expect(centered.left - left.right, geometry.gap);
    expect(right.left - centered.right, geometry.gap);
  });

  test('wide and shortcut snapping retain their bounds and negative rows clamp to zero', () {
    expect(geometry.snap(const Offset(92, -92), HomeSpan.wide), const HomeGridPosition(0, 0));
    expect(geometry.snap(const Offset(92, -92), HomeSpan.shortcut), const HomeGridPosition(1, 0));
    expect(geometry.snap(const Offset(999, 92), HomeSpan.shortcut), const HomeGridPosition(3, 1));
    expect(geometry.snap(const Offset(-92, -92), HomeSpan.small), const HomeGridPosition(0, 0));
  });

  test('moving below the content keeps the empty rows in between', () {
    final moved = HomeGridLayout(layout.moveToCell('s', const HomeGridPosition(3, 5)));

    expect(moved.positionOf('s'), const HomeGridPosition(3, 5));
    expect(moved.positionOf('w'), const HomeGridPosition(0, 1));
    expect(moved.rows, 6);
  });

  test('the home never ends with an empty row', () {
    final spread = HomeGridLayout(layout.moveToCell('s', const HomeGridPosition(3, 5)));
    expect(spread.rows, 6);

    final movedBack = HomeGridLayout(spread.moveToCell('s', const HomeGridPosition(2, 1)));
    expect(movedBack.rows, 3);

    final removed = HomeGridLayout(spread.positionedConfiguration.removeItem('s'));
    expect(removed.rows, 3);
  });
}
