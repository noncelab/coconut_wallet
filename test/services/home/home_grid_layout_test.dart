import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:flutter_test/flutter_test.dart';

HomeItem item(String id, int order, HomeSpan span, HomeItemKind kind) =>
    HomeItem(id: id, definitionId: id, kind: kind, order: order, span: span);

void main() {
  test('moving a 2×2 before another keeps four visually grouped shortcuts ahead of the 4×2', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'small',
          definitionId: 'small',
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 0),
        ),
        for (final (index, position)
            in [const HomeGridPosition(2, 0), const HomeGridPosition(3, 0), const HomeGridPosition(2, 1)].indexed)
          HomeItem(
            id: 'shortcut-$index',
            definitionId: 'shortcut-$index',
            kind: HomeItemKind.shortcut,
            order: index + 1,
            span: HomeSpan.shortcut,
            position: position,
          ),
        const HomeItem(
          id: 'wide',
          definitionId: 'wide',
          kind: HomeItemKind.widget,
          order: 4,
          span: HomeSpan.wide,
          position: HomeGridPosition(0, 2),
        ),
        const HomeItem(
          id: 'shortcut-3',
          definitionId: 'shortcut-3',
          kind: HomeItemKind.shortcut,
          order: 5,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(3, 1),
        ),
        const HomeItem(
          id: 'other-small',
          definitionId: 'other-small',
          kind: HomeItemKind.widget,
          order: 6,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 4),
        ),
      ],
    );

    final moved = HomeGridLayout(config).moveBefore('other-small', 'small');
    final layout = HomeGridLayout(moved);
    final wideRow = layout.positionOf('wide')!.row;
    final shortcutRow = layout.positionOf('shortcut-0')!.row;
    for (var index = 0; index < 4; index++) {
      expect(layout.positionOf('shortcut-$index'), HomeGridPosition(index, shortcutRow));
    }
    expect(shortcutRow, lessThan(wideRow));
    final ids = moved.items.map((item) => item.id).toList();
    expect(ids.indexOf('shortcut-3'), lessThan(ids.indexOf('wide')));
  });

  test('moving a lower shortcut before a 4×2 keeps the 4×2 ahead of the remaining shortcuts', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'small',
          definitionId: 'small',
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 0),
        ),
        for (var row = 0; row < 2; row++)
          for (var column = 2; column < 4; column++)
            HomeItem(
              id: 'upper-$row-$column',
              definitionId: 'upper-$row-$column',
              kind: HomeItemKind.shortcut,
              order: 1 + row * 2 + column - 2,
              span: HomeSpan.shortcut,
              position: HomeGridPosition(column, row),
            ),
        const HomeItem(
          id: 'wide',
          definitionId: 'wide',
          kind: HomeItemKind.widget,
          order: 5,
          span: HomeSpan.wide,
          position: HomeGridPosition(0, 2),
        ),
        for (var column = 0; column < 4; column++)
          HomeItem(
            id: 'lower-$column',
            definitionId: 'lower-$column',
            kind: HomeItemKind.shortcut,
            order: 6 + column,
            span: HomeSpan.shortcut,
            position: HomeGridPosition(column, 4),
          ),
        const HomeItem(
          id: 'last',
          definitionId: 'last',
          kind: HomeItemKind.shortcut,
          order: 10,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 5),
        ),
      ],
    );

    for (final moved in [
      HomeGridLayout(config).moveToCell('lower-1', const HomeGridPosition(0, 2)),
      HomeGridLayout(config).moveBefore('lower-1', 'wide'),
    ]) {
      final layout = HomeGridLayout(moved);
      expect(layout.positionOf('small'), const HomeGridPosition(0, 0));
      for (var row = 0; row < 2; row++) {
        for (var column = 2; column < 4; column++) {
          expect(layout.positionOf('upper-$row-$column'), HomeGridPosition(column, row));
        }
      }
      expect(layout.positionOf('lower-1'), const HomeGridPosition(0, 2));
      expect(layout.positionOf('wide'), const HomeGridPosition(0, 3));
      expect(layout.positionOf('lower-0'), const HomeGridPosition(0, 5));
      expect(layout.positionOf('lower-2'), const HomeGridPosition(2, 5));
      expect(layout.positionOf('lower-3'), const HomeGridPosition(3, 5));
      expect(layout.positionOf('last'), const HomeGridPosition(0, 6));
    }
  });

  test('moving a 4×2 between two shortcut rows shifts the lower row and following group', () {
    final config = HomeConfiguration(
      items: [
        for (var column = 0; column < 4; column++)
          HomeItem(
            id: 'top-$column',
            definitionId: 'top-$column',
            kind: HomeItemKind.shortcut,
            order: column,
            span: HomeSpan.shortcut,
            position: HomeGridPosition(column, 0),
          ),
        const HomeItem(
          id: 'single',
          definitionId: 'single',
          kind: HomeItemKind.shortcut,
          order: 4,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 1),
        ),
        const HomeItem(
          id: 'small',
          definitionId: 'small',
          kind: HomeItemKind.widget,
          order: 5,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 2),
        ),
        const HomeItem(
          id: 'lower-a',
          definitionId: 'lower-a',
          kind: HomeItemKind.shortcut,
          order: 6,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(2, 2),
        ),
        const HomeItem(
          id: 'lower-b',
          definitionId: 'lower-b',
          kind: HomeItemKind.shortcut,
          order: 7,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(3, 2),
        ),
        const HomeItem(
          id: 'lower-c',
          definitionId: 'lower-c',
          kind: HomeItemKind.shortcut,
          order: 8,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(2, 3),
        ),
        const HomeItem(
          id: 'lower-d',
          definitionId: 'lower-d',
          kind: HomeItemKind.shortcut,
          order: 9,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(3, 3),
        ),
        const HomeItem(
          id: 'wide',
          definitionId: 'wide',
          kind: HomeItemKind.widget,
          order: 10,
          span: HomeSpan.wide,
          position: HomeGridPosition(0, 4),
        ),
      ],
    );

    final moved = HomeGridLayout(config).moveToCell('wide', const HomeGridPosition(0, 1));
    final layout = HomeGridLayout(moved);

    for (var column = 0; column < 4; column++) {
      expect(layout.positionOf('top-$column'), HomeGridPosition(column, 0));
    }
    expect(layout.positionOf('wide'), const HomeGridPosition(0, 1));
    expect(layout.positionOf('single'), const HomeGridPosition(0, 3));
    expect(layout.positionOf('small'), const HomeGridPosition(0, 4));
    expect(layout.positionOf('lower-a'), const HomeGridPosition(2, 4));
    expect(layout.positionOf('lower-b'), const HomeGridPosition(3, 4));
    expect(layout.positionOf('lower-c'), const HomeGridPosition(2, 5));
    expect(layout.positionOf('lower-d'), const HomeGridPosition(3, 5));
  });

  test('adding a 4×2 after four shortcuts leaves no completely empty row', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'small-left',
          definitionId: 'small-left',
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 0),
        ),
        const HomeItem(
          id: 'small-right',
          definitionId: 'small-right',
          kind: HomeItemKind.widget,
          order: 1,
          span: HomeSpan.small,
          position: HomeGridPosition(2, 0),
        ),
        for (var column = 0; column < 4; column++)
          HomeItem(
            id: 'shortcut-$column',
            definitionId: 'shortcut-$column',
            kind: HomeItemKind.shortcut,
            order: column + 2,
            span: HomeSpan.shortcut,
            position: HomeGridPosition(column, 2),
          ),
      ],
    );

    final added = HomeGridLayout(config.addItem(item('wide', 99, HomeSpan.wide, HomeItemKind.widget)));
    final wideRow = added.positionOf('wide')!.row;

    expect(wideRow, 3);
    for (var row = 0; row < wideRow; row++) {
      expect(
        config.items.any((homeItem) {
          final position = added.positionOf(homeItem.id)!;
          return position.row <= row && row < position.row + homeItem.span.height;
        }),
        isTrue,
        reason: 'row $row is completely empty',
      );
    }
  });

  test('moving the lower shortcut up leaves the emptied rows and keeps the 4×2 in place', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'first-shortcut',
          definitionId: 'first-shortcut',
          kind: HomeItemKind.shortcut,
          order: 0,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 0),
        ),
        const HomeItem(
          id: 'small',
          definitionId: 'small',
          kind: HomeItemKind.widget,
          order: 1,
          span: HomeSpan.small,
          position: HomeGridPosition(2, 0),
        ),
        const HomeItem(
          id: 'lower-shortcut',
          definitionId: 'lower-shortcut',
          kind: HomeItemKind.shortcut,
          order: 2,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 2),
        ),
        const HomeItem(
          id: 'wide',
          definitionId: 'wide',
          kind: HomeItemKind.widget,
          order: 3,
          span: HomeSpan.wide,
          position: HomeGridPosition(0, 4),
        ),
      ],
    );

    final moved = HomeGridLayout(config).moveToCell('lower-shortcut', const HomeGridPosition(1, 0));
    final layout = HomeGridLayout(moved);

    expect(layout.positionOf('first-shortcut'), const HomeGridPosition(0, 0));
    expect(layout.positionOf('lower-shortcut'), const HomeGridPosition(1, 0));
    expect(layout.positionOf('small'), const HomeGridPosition(2, 0));
    expect(layout.positionOf('wide'), const HomeGridPosition(0, 4));
    expect(
      HomeGridLayout(HomeConfiguration.fromJson(moved.toJson())!).positionOf('wide'),
      const HomeGridPosition(0, 4),
    );
  });

  test('moving a 4×2 down preserves the visual order of displaced items', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'wide',
          definitionId: 'wide',
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.wide,
          position: HomeGridPosition(0, 0),
        ),
        const HomeItem(
          id: 'receive',
          definitionId: 'receive',
          kind: HomeItemKind.shortcut,
          order: 1,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(2, 2),
        ),
        const HomeItem(
          id: 'wallet-detail',
          definitionId: 'wallet-detail',
          kind: HomeItemKind.shortcut,
          order: 2,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(3, 2),
        ),
        const HomeItem(
          id: 'small',
          definitionId: 'small',
          kind: HomeItemKind.widget,
          order: 3,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 2),
        ),
      ],
    );

    final moved = HomeGridLayout(config).moveToCell('wide', const HomeGridPosition(0, 2));
    final layout = HomeGridLayout(moved);

    expect(layout.positionOf('small'), const HomeGridPosition(0, 0));
    expect(layout.positionOf('receive'), const HomeGridPosition(2, 0));
    expect(layout.positionOf('wallet-detail'), const HomeGridPosition(3, 0));
    expect(layout.positionOf('wide'), const HomeGridPosition(0, 2));
  });

  test('inserting a shortcut before the second 2×2 keeps both 2×2 widgets on even rows', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'first-2x2',
          definitionId: 'first-2x2',
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 0),
        ),
        const HomeItem(
          id: 'second-2x2',
          definitionId: 'second-2x2',
          kind: HomeItemKind.widget,
          order: 1,
          span: HomeSpan.small,
          position: HomeGridPosition(2, 0),
        ),
        const HomeItem(
          id: 'moving-shortcut',
          definitionId: 'moving-shortcut',
          kind: HomeItemKind.shortcut,
          order: 2,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 2),
        ),
        const HomeItem(
          id: 'other-shortcut',
          definitionId: 'other-shortcut',
          kind: HomeItemKind.shortcut,
          order: 3,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(1, 2),
        ),
      ],
    );

    final moved = HomeGridLayout(config).moveBefore('moving-shortcut', 'second-2x2');
    final layout = HomeGridLayout(moved);

    expect(layout.positionOf('first-2x2'), const HomeGridPosition(0, 0));
    expect(layout.positionOf('moving-shortcut'), const HomeGridPosition(2, 0));
    expect(layout.positionOf('second-2x2'), const HomeGridPosition(0, 2));
    expect(
      layout.positionOf('other-shortcut'),
      const HomeGridPosition(2, 2),
      reason: '${layout.positionOf('other-shortcut')?.column},${layout.positionOf('other-shortcut')?.row}',
    );
  });

  test('a 2×2 may start on an odd row after a 1×1 row', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'shortcut',
          definitionId: 'shortcut',
          kind: HomeItemKind.shortcut,
          order: 0,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 0),
        ),
        const HomeItem(
          id: 'small',
          definitionId: 'small',
          kind: HomeItemKind.widget,
          order: 1,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 1),
        ),
      ],
    );
    final layout = HomeGridLayout(config);

    expect(layout.canMoveToCell('small', const HomeGridPosition(2, 1)), isTrue);
    expect(
      HomeGridLayout(layout.moveToCell('small', const HomeGridPosition(2, 1))).positionOf('small'),
      const HomeGridPosition(2, 1),
    );
  });

  test('2×2 widgets use even columns while 4×2 may start on an odd row', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'small',
          definitionId: 'small',
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 0),
        ),
        const HomeItem(
          id: 'wide',
          definitionId: 'wide',
          kind: HomeItemKind.widget,
          order: 1,
          span: HomeSpan.wide,
          position: HomeGridPosition(0, 2),
        ),
      ],
    );
    final layout = HomeGridLayout(config);

    expect(layout.canMoveToCell('small', const HomeGridPosition(1, 2)), isFalse);
    expect(layout.canMoveToCell('small', const HomeGridPosition(2, 2)), isTrue);
    expect(layout.canMoveToCell('wide', const HomeGridPosition(0, 3)), isTrue);
    expect(layout.canMoveToCell('wide', const HomeGridPosition(0, 4)), isTrue);
  });

  test('saved staggered layout repairs the following shortcut beside the moved 2×2', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'first-2x2',
          definitionId: 'first-2x2',
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 0),
        ),
        const HomeItem(
          id: 'moved-shortcut',
          definitionId: 'moved-shortcut',
          kind: HomeItemKind.shortcut,
          order: 1,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(2, 0),
        ),
        const HomeItem(
          id: 'second-2x2',
          definitionId: 'second-2x2',
          kind: HomeItemKind.widget,
          order: 2,
          span: HomeSpan.small,
          position: HomeGridPosition(2, 1),
        ),
        const HomeItem(
          id: 'other-shortcut',
          definitionId: 'other-shortcut',
          kind: HomeItemKind.shortcut,
          order: 3,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 3),
        ),
      ],
    );

    final layout = HomeGridLayout(config);
    expect(layout.positionOf('first-2x2'), const HomeGridPosition(0, 0));
    expect(layout.positionOf('moved-shortcut'), const HomeGridPosition(2, 0));
    expect(layout.positionOf('second-2x2'), const HomeGridPosition(0, 2));
    expect(layout.positionOf('other-shortcut'), const HomeGridPosition(2, 2));
  });

  test('inserting the last 1×1 before a 2×2 keeps the following visual order', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'small',
          definitionId: 'small',
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 0),
        ),
        const HomeItem(
          id: 'first-shortcut',
          definitionId: 'first-shortcut',
          kind: HomeItemKind.shortcut,
          order: 1,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(2, 0),
        ),
        const HomeItem(
          id: 'wide',
          definitionId: 'wide',
          kind: HomeItemKind.widget,
          order: 2,
          span: HomeSpan.wide,
          position: HomeGridPosition(0, 2),
        ),
        const HomeItem(
          id: 'last-shortcut',
          definitionId: 'last-shortcut',
          kind: HomeItemKind.shortcut,
          order: 3,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 4),
        ),
      ],
    );

    final moved = HomeGridLayout(config).moveBefore('last-shortcut', 'small');
    final layout = HomeGridLayout(moved);

    expect(moved.items.map((item) => item.id), ['last-shortcut', 'small', 'first-shortcut', 'wide']);
    expect(layout.positionOf('last-shortcut'), const HomeGridPosition(0, 0));
    expect(layout.positionOf('small'), const HomeGridPosition(2, 0));
    expect(layout.positionOf('first-shortcut'), const HomeGridPosition(0, 2));
    expect(layout.positionOf('wide'), const HomeGridPosition(0, 3));
    expect(HomeConfiguration.fromJson(moved.toJson()), moved);
  });

  test('insertion keeps deliberately placed items before the target in their cells', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'prefix',
          definitionId: 'prefix',
          kind: HomeItemKind.shortcut,
          order: 0,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(3, 0),
        ),
        const HomeItem(
          id: 'target',
          definitionId: 'target',
          kind: HomeItemKind.widget,
          order: 1,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 2),
        ),
        const HomeItem(
          id: 'moving',
          definitionId: 'moving',
          kind: HomeItemKind.shortcut,
          order: 2,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 4),
        ),
      ],
    );

    final moved = HomeGridLayout(config).moveBefore('moving', 'target');

    expect(HomeGridLayout(moved).positionOf('prefix'), const HomeGridPosition(3, 0));
    expect(moved.items.map((item) => item.id), ['prefix', 'moving', 'target']);
  });

  test('a 4×2 moved to row zero displaces the 2×2 and 1×1 without overlap', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'small',
          definitionId: 'small',
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 0),
        ),
        const HomeItem(
          id: 'shortcut',
          definitionId: 'shortcut',
          kind: HomeItemKind.shortcut,
          order: 1,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(2, 0),
        ),
        const HomeItem(
          id: 'wide',
          definitionId: 'wide',
          kind: HomeItemKind.widget,
          order: 2,
          span: HomeSpan.wide,
          position: HomeGridPosition(0, 2),
        ),
      ],
    );

    final moved = HomeGridLayout(config).moveToCell('wide', const HomeGridPosition(0, 0));
    expect(HomeGridLayout(config).canMoveToCell('wide', const HomeGridPosition(0, 0)), isTrue);
    final layout = HomeGridLayout(moved);
    expect(layout.positionOf('wide'), const HomeGridPosition(0, 0));
    expect(layout.positionOf('small'), const HomeGridPosition(0, 2));
    expect(layout.positionOf('shortcut'), const HomeGridPosition(2, 2));
    expect(HomeConfiguration.fromJson(moved.toJson()), moved);
  });

  test('a 2×2 cannot use the middle columns between two shortcuts', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'left',
          definitionId: 'left',
          kind: HomeItemKind.shortcut,
          order: 0,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 0),
        ),
        const HomeItem(
          id: 'right',
          definitionId: 'right',
          kind: HomeItemKind.shortcut,
          order: 1,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(3, 0),
        ),
        const HomeItem(
          id: 'middle',
          definitionId: 'middle',
          kind: HomeItemKind.widget,
          order: 2,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 2),
        ),
      ],
    );

    final layout = HomeGridLayout(config);
    expect(
      HomeGridLayout(layout.moveToCell('middle', const HomeGridPosition(1, 0))).positionOf('middle'),
      const HomeGridPosition(0, 2),
    );
  });

  test('legacy row layout keeps the visible gap below two shortcuts', () {
    final config = HomeConfiguration(
      items: [
        item('large-a', 0, HomeSpan.small, HomeItemKind.widget),
        item('shortcut-a', 1, HomeSpan.shortcut, HomeItemKind.shortcut),
        item('shortcut-b', 2, HomeSpan.shortcut, HomeItemKind.shortcut),
        item('large-b', 3, HomeSpan.small, HomeItemKind.widget),
      ],
    );

    final layout = HomeGridLayout(config);
    expect(layout.positionOf('large-a'), const HomeGridPosition(0, 0));
    expect(layout.positionOf('shortcut-a'), const HomeGridPosition(2, 0));
    expect(layout.positionOf('shortcut-b'), const HomeGridPosition(3, 0));
    expect(layout.positionOf('large-b'), const HomeGridPosition(0, 2));
  });

  test('a new shortcut can move into the gap below an existing shortcut and survive JSON', () {
    final config = HomeConfiguration(
      items: [
        item('large-a', 0, HomeSpan.small, HomeItemKind.widget),
        item('shortcut-a', 1, HomeSpan.shortcut, HomeItemKind.shortcut),
        item('shortcut-b', 2, HomeSpan.shortcut, HomeItemKind.shortcut),
        item('large-b', 3, HomeSpan.small, HomeItemKind.widget),
        item('shortcut-new', 4, HomeSpan.shortcut, HomeItemKind.shortcut),
      ],
    );
    final layout = HomeGridLayout(config);

    final moved = layout.moveToCell('shortcut-new', const HomeGridPosition(2, 1));

    expect(HomeGridLayout(moved).positionOf('shortcut-new'), const HomeGridPosition(2, 1));
    expect(HomeGridLayout(moved).positionOf('large-b'), const HomeGridPosition(0, 2));
    expect(HomeConfiguration.fromJson(moved.toJson()), moved);
  });

  test('a 2×2 widget can occupy a 2×2 hole without moving its neighbors', () {
    final config = HomeConfiguration(
      items: [
        item('shortcut-a', 0, HomeSpan.shortcut, HomeItemKind.shortcut),
        item('shortcut-b', 1, HomeSpan.shortcut, HomeItemKind.shortcut),
        item('large-a', 2, HomeSpan.small, HomeItemKind.widget),
        item('large-b', 3, HomeSpan.small, HomeItemKind.widget),
      ],
    );
    final layout = HomeGridLayout(config);
    final withoutFirst = HomeConfiguration(
      items: layout.positionedConfiguration.items.where((item) => item.id != 'large-a').toList(),
    );
    final withNew = withoutFirst.addItem(item('large-new', 3, HomeSpan.small, HomeItemKind.widget));

    final moved = HomeGridLayout(withNew).moveToCell('large-new', const HomeGridPosition(2, 0));

    expect(HomeGridLayout(moved).positionOf('large-new'), const HomeGridPosition(2, 0));
    expect(HomeGridLayout(moved).positionOf('large-b'), layout.positionOf('large-b'));
  });

  test('dropping onto an occupied cell displaces only the overlapping widget', () {
    final config = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'a',
          definitionId: 'a',
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 0),
        ),
        const HomeItem(
          id: 'b',
          definitionId: 'b',
          kind: HomeItemKind.widget,
          order: 1,
          span: HomeSpan.small,
          position: HomeGridPosition(2, 0),
        ),
        const HomeItem(
          id: 'c',
          definitionId: 'c',
          kind: HomeItemKind.shortcut,
          order: 2,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 2),
        ),
      ],
    );

    final moved = HomeGridLayout(config).moveToCell('a', const HomeGridPosition(2, 0));
    final layout = HomeGridLayout(moved);
    expect(layout.positionOf('a'), const HomeGridPosition(2, 0));
    expect(layout.positionOf('b'), const HomeGridPosition(0, 0));
    expect(layout.positionOf('c'), const HomeGridPosition(0, 2));
  });
}
