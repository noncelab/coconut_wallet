import 'dart:math';

import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

HomeItem item(String id, int order, HomeSpan span, HomeItemKind kind) =>
    HomeItem(id: id, definitionId: id, kind: kind, order: order, span: span);

class _SmallDefinition extends HomeItemDefinition {
  const _SmallDefinition(String id)
    : super(
        id: id,
        kind: HomeItemKind.widget,
        supportedSpans: const [HomeSpan.small],
        category: HomeItemCategory.wallets,
      );

  @override
  Widget build(BuildContext context, HomeItem item) => const SizedBox.shrink();
}

HomeConfiguration homeWithShortcutBlock(int widgetColumn) => HomeConfiguration(
  shortcutWalletContext: const ShortcutWalletContext.wallet(7),
  items: [
    for (final (index, (id, span, column, row))
        in [
          ('header', HomeSpan.wide, 0, 0),
          ('wallet', HomeSpan.small, widgetColumn, 2),
          ('near-top', HomeSpan.shortcut, widgetColumn == 0 ? 2 : 1, 2),
          ('far-top', HomeSpan.shortcut, widgetColumn == 0 ? 3 : 0, 2),
          ('near-bottom', HomeSpan.shortcut, widgetColumn == 0 ? 2 : 1, 3),
          ('far-bottom', HomeSpan.shortcut, widgetColumn == 0 ? 3 : 0, 3),
          ('footer', HomeSpan.wide, 0, 4),
        ].indexed)
      HomeItem(
        id: id,
        definitionId: id,
        kind: span == HomeSpan.shortcut ? HomeItemKind.shortcut : HomeItemKind.widget,
        order: index,
        span: span,
        position: HomeGridPosition(column, row),
        configuration: {'label': id},
      ),
  ],
);

HomeConfiguration mixedHome() => HomeConfiguration(
  shortcutWalletContext: const ShortcutWalletContext.wallet(7),
  items: [
    for (final (index, (id, span, column, row))
        in [
          ('balance', HomeSpan.wide, 0, 0),
          ('wallet', HomeSpan.small, 0, 2),
          ('utxo', HomeSpan.small, 2, 2),
          ('price', HomeSpan.small, 0, 4),
          ('receive', HomeSpan.shortcut, 2, 4),
          ('send', HomeSpan.shortcut, 3, 4),
          ('organizer', HomeSpan.shortcut, 3, 5),
          ('hodl', HomeSpan.shortcut, 2, 5),
          ('recent', HomeSpan.wide, 0, 6),
        ].indexed)
      HomeItem(
        id: id,
        definitionId: 'definition-$id',
        kind: span == HomeSpan.shortcut ? HomeItemKind.shortcut : HomeItemKind.widget,
        order: index,
        span: span,
        position: HomeGridPosition(column, row),
        configuration: {'label': id},
      ),
  ],
);

void expectValidLayout(HomeConfiguration configuration) {
  final occupied = <(int, int)>{};
  for (final item in configuration.items) {
    final position = item.position!;
    expect(position.column, greaterThanOrEqualTo(0), reason: item.id);
    expect(position.row, greaterThanOrEqualTo(0), reason: item.id);
    expect(position.column + item.span.width, lessThanOrEqualTo(configuration.columns), reason: item.id);
    for (var row = position.row; row < position.row + item.span.height; row++) {
      for (var column = position.column; column < position.column + item.span.width; column++) {
        expect(occupied.add((column, row)), isTrue, reason: '${item.id} overlaps at ($column, $row)');
      }
    }
  }
  final restored = HomeConfiguration.fromJson(configuration.toJson())!;
  expect(restored, configuration);
  expect(HomeGridLayout(restored).positionedConfiguration, configuration, reason: 'saving must not repair the drop');
}

void expectPositions(HomeConfiguration actual, HomeConfiguration before, Map<String, HomeGridPosition> changes) {
  expect(actual.version, before.version);
  expect(actual.shortcutWalletContext, before.shortcutWalletContext);
  expect(actual.items.map((item) => item.id), before.items.map((item) => item.id));
  for (final item in before.items) {
    expect(actual.items.singleWhere((other) => other.id == item.id), item.copyWith(position: changes[item.id]));
  }
  expectValidLayout(actual);
}

void main() {
  test('projection keeps generic rectangular shortcut offsets and saved edits intact', () {
    final canonical = HomeConfiguration(
      items: [
        item('widget', 0, HomeSpan.small, HomeItemKind.widget).copyWith(position: const HomeGridPosition(0, 0)),
        for (final (index, position)
            in [
              const HomeGridPosition(2, 0),
              const HomeGridPosition(3, 0),
              const HomeGridPosition(2, 1),
              const HomeGridPosition(3, 1),
            ].indexed)
          item(
            'shortcut-$index',
            index + 1,
            HomeSpan.shortcut,
            HomeItemKind.shortcut,
          ).copyWith(position: position, configuration: {'label': 'shortcut-$index'}),
        item('wide', 5, HomeSpan.wide, HomeItemKind.widget).copyWith(position: const HomeGridPosition(0, 4)),
      ],
    );
    final expanded = HomeGridLayout(HomeGridLayout(canonical).reflow(8));
    expect(expanded.positionOf('shortcut-2'), const HomeGridPosition(2, 1));
    expect(expanded.positionOf('wide'), const HomeGridPosition(4, 0));
    expect(expanded.rows, 2);
    expectValidLayout(expanded.positionedConfiguration);
    for (final item in canonical.items) {
      final projected = expanded.configuration.items.singleWhere((other) => other.id == item.id);
      expect(projected.configuration, item.configuration);
      expect(projected.span, item.span);
    }
    final edited = expanded.moveToCell('shortcut-2', const HomeGridPosition(7, 5));
    expect(HomeGridLayout(edited).reflow(8), edited);
    HomeGridLayout(edited).reflow(6);
    expect(HomeGridLayout(edited).reflow(8), edited);
    expect(HomeGridLayout(canonical).reflow(4), canonical);
  });

  test('shortcut blocks wider than the projected grid fall back to ordinary flow', () {
    final canonical = HomeConfiguration(
      columns: 8,
      items: [
        for (var i = 0; i < 16; i++)
          item('s$i', i, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: HomeGridPosition(i % 8, i ~/ 8)),
      ],
    );
    final projected = HomeGridLayout(HomeGridLayout(canonical).reflow(6));
    expect(projected.positionOf('s7'), const HomeGridPosition(1, 1));
    expect(projected.positionOf('s15'), const HomeGridPosition(3, 2));
    expect(projected.rows, 3);
    expectValidLayout(projected.positionedConfiguration);
  });

  test('a single shortcut row still wraps individually into available expanded cells', () {
    final canonical = HomeConfiguration(
      items: [
        item('wide', 0, HomeSpan.wide, HomeItemKind.widget).copyWith(position: const HomeGridPosition(0, 0)),
        for (var i = 0; i < 4; i++)
          item('s$i', i + 1, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: HomeGridPosition(i, 2)),
      ],
    );
    final projected = HomeGridLayout(HomeGridLayout(canonical).reflow(6));
    expect(projected.positionOf('s0'), const HomeGridPosition(4, 0));
    expect(projected.positionOf('s2'), const HomeGridPosition(0, 2));
    expectValidLayout(projected.positionedConfiguration);
  });

  test('incomplete shortcut rectangles retain ordinary projection flow', () {
    final canonical = HomeConfiguration(
      items: [
        for (final (index, position)
            in [const HomeGridPosition(0, 0), const HomeGridPosition(1, 0), const HomeGridPosition(0, 1)].indexed)
          item('s$index', index, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: position),
        item('wide', 3, HomeSpan.wide, HomeItemKind.widget).copyWith(position: const HomeGridPosition(0, 3)),
      ],
    );
    final projected = HomeGridLayout(HomeGridLayout(canonical).reflow(8));
    expect(projected.positionOf('s2'), const HomeGridPosition(2, 0));
    expect(projected.positionOf('wide'), const HomeGridPosition(3, 0));
    expectValidLayout(projected.positionedConfiguration);
  });

  test('expanded mixed edits preserve items, bounds and nonoverlap across folds', () {
    final random = Random(2806);
    var current = mixedHome();
    final originalIds = current.items.map((item) => item.id).toSet();
    for (var step = 0; step < 180; step++) {
      final columns = [4, 6, 8, 10][step % 4];
      current = HomeGridLayout(current).reflow(columns);
      final layout = HomeGridLayout(current);
      final moving = current.items[random.nextInt(current.items.length)];
      if (step % 3 == 0) {
        current = layout.moveToCell(
          moving.id,
          HomeGridLayout.anchorForSpan(
            HomeGridPosition(random.nextInt(columns), random.nextInt(10)),
            moving.span,
            columns: columns,
          ),
        );
      } else if (step % 3 == 1 && moving.kind == HomeItemKind.widget) {
        current = layout.resizeItem(moving.id, moving.span == HomeSpan.wide ? HomeSpan.small : HomeSpan.wide);
      } else {
        current = layout.moveBefore(moving.id, current.items[random.nextInt(current.items.length)].id);
      }
      expect(current.columns, columns);
      expect(current.items.map((item) => item.id).toSet(), originalIds);
      expectValidLayout(current);
      expect(HomeGridLayout(current).positionedConfiguration, current);
    }
  });

  test('reflow is pure and repeated viewport changes recover canonical positions', () {
    final canonical = mixedHome();
    final layout = HomeGridLayout(canonical);
    final originalJson = canonical.toJson();
    for (final columns in [6, 8, 12, 4, 8, 6, 4]) {
      final flowed = layout.reflow(columns);
      expect(flowed.columns, columns);
      expectValidLayout(flowed);
      expect(flowed.items.map((item) => item.id).toSet(), canonical.items.map((item) => item.id).toSet());
      expect(flowed.shortcutWalletContext, canonical.shortcutWalletContext);
      for (final item in flowed.items) {
        final original = canonical.items.firstWhere((other) => other.id == item.id);
        expect(item.span, original.span);
        expect(item.configuration, original.configuration);
      }
      if (columns == 4) expect(flowed, canonical);
      expect(canonical.toJson(), originalJson);
    }
  });

  test('wide tiles share expanded rows and can move to nonzero columns', () {
    final layout = HomeGridLayout(
      HomeConfiguration(
        columns: 8,
        items: [
          item('a', 0, HomeSpan.wide, HomeItemKind.widget),
          item('b', 1, HomeSpan.wide, HomeItemKind.widget),
          item('s', 2, HomeSpan.small, HomeItemKind.widget),
        ],
      ),
    );
    expect(layout.positionOf('b'), const HomeGridPosition(4, 0));
    expect(
      HomeGridLayout.anchorForSpan(const HomeGridPosition(4, 0), HomeSpan.wide, columns: 8),
      const HomeGridPosition(4, 0),
    );
    final moved = layout.moveToCell('a', const HomeGridPosition(3, 4));
    expect(moved.columns, 8);
    expectValidLayout(moved);
    expect(HomeGridLayout(moved).positionOf('a'), const HomeGridPosition(3, 4));
    final resized = HomeGridLayout(moved).resizeItem('s', HomeSpan.wide);
    expect(resized.columns, 8);
    expectValidLayout(resized);
    final inserted = HomeGridLayout(resized).moveBefore('s', 'b');
    expect(inserted.columns, 8);
    expectValidLayout(inserted);
  });

  test('column persistence remains backward compatible and rejects malformed counts', () {
    final compact = mixedHome();
    expect(compact.toJson().containsKey('columns'), isFalse);
    for (final invalid in [null, '6', 3, 5, 0, -2, 6.0]) {
      expect(HomeConfiguration.fromJson({...compact.toJson(), 'columns': invalid})!.columns, 4);
    }
    final wide = HomeGridLayout(compact).reflow(6);
    expect(HomeConfiguration.fromJson(wide.toJson()), wide);
    expect(wide.normalize((_) => null).columns, 6);
    expect(wide.removeItem('receive').columns, 6);
    expect(wide.moveItem('receive', 0).columns, 6);
    expect(wide.addItem(item('extra', 99, HomeSpan.shortcut, HomeItemKind.shortcut)).columns, 6);
    expect(HomeConfiguration(columns: 6, items: compact.items), isNot(compact));
  });

  test('expanded stored grid places six shortcuts in the first row', () {
    final compact = HomeConfiguration(
      items: [for (var i = 0; i < 7; i++) item('s$i', i, HomeSpan.shortcut, HomeItemKind.shortcut)],
    );
    final expanded = HomeConfiguration.fromJson({...compact.toJson(), 'columns': 6})!;
    final layout = HomeGridLayout(expanded);
    expect(layout.positionOf('s5'), const HomeGridPosition(5, 0));
    expect(layout.positionOf('s6'), const HomeGridPosition(0, 1));
    expect(layout.canMoveToCell('s0', const HomeGridPosition(5, 3)), isTrue);
    expect(layout.canMoveToCell('s0', const HomeGridPosition(6, 3)), isFalse);
    expect(layout.positionedConfiguration.toJson()['columns'], 6);
  });

  group('center column', () {
    test('2×2 anchors preserve all valid columns and clamp at both edges', () {
      for (final (column, expected) in [(-2, 0), (-1, 0), (0, 0), (1, 1), (2, 2), (3, 2), (5, 2)]) {
        expect(
          HomeGridLayout.anchorForSpan(HomeGridPosition(column, 3), HomeSpan.small),
          HomeGridPosition(expected, 3),
        );
      }
      expect(HomeGridLayout.anchorForSpan(const HomeGridPosition(1, 3), HomeSpan.wide), const HomeGridPosition(0, 3));
      expect(
        HomeGridLayout.anchorForSpan(const HomeGridPosition(1, 3), HomeSpan.shortcut),
        const HomeGridPosition(1, 3),
      );
    });

    for (final sourceColumn in [0, 2]) {
      test('moving from column $sourceColumn displaces only the near shortcuts and can move back', () {
        final before = homeWithShortcutBlock(sourceColumn);
        final vacatedColumn = sourceColumn == 0 ? 0 : 3;

        final moved = HomeGridLayout(before).moveToCell('wallet', const HomeGridPosition(1, 2));

        expectPositions(moved, before, {
          'wallet': const HomeGridPosition(1, 2),
          'near-top': HomeGridPosition(vacatedColumn, 2),
          'near-bottom': HomeGridPosition(vacatedColumn, 3),
        });
        expect(HomeGridLayout(moved).moveToCell('wallet', HomeGridPosition(sourceColumn, 2)), before);
      });
    }

    test('a saved centered widget survives JSON, definition normalization and repeated layout', () {
      final centered = HomeGridLayout(homeWithShortcutBlock(0)).moveToCell('wallet', const HomeGridPosition(1, 2));
      final decoded = HomeConfiguration.fromJson(centered.toJson())!;
      final normalized = decoded.normalize((id) => id == 'wallet' ? const _SmallDefinition('wallet') : null);

      expect(normalized, centered);
      expect(HomeGridLayout(normalized).positionedConfiguration, centered);
      expect(HomeGridLayout(HomeGridLayout(normalized).positionedConfiguration).positionedConfiguration, centered);
      expect(HomeGridLayout(normalized).positionOf('wallet'), const HomeGridPosition(1, 2));
    });

    test('adding and removing items preserves a centered widget and the other saved positions', () {
      final centered = HomeGridLayout(homeWithShortcutBlock(0)).moveToCell('wallet', const HomeGridPosition(1, 2));
      final added =
          HomeGridLayout(
            centered.addItem(item('new-shortcut', 99, HomeSpan.shortcut, HomeItemKind.shortcut)),
          ).positionedConfiguration;

      for (final original in centered.items) {
        expect(added.items.singleWhere((other) => other.id == original.id), original);
      }
      expectValidLayout(added);
      expect(HomeGridLayout(added.removeItem('new-shortcut')).positionedConfiguration, centered);
      final removed = HomeGridLayout(centered.removeItem('far-top')).positionedConfiguration;
      expect(removed.items.singleWhere((item) => item.id == 'wallet').position, const HomeGridPosition(1, 2));
      for (final original in centered.items.where((item) => item.id != 'far-top')) {
        expect(removed.items.singleWhere((other) => other.id == original.id).position, original.position);
      }
      expectValidLayout(removed);
    });

    test('normalizing a resized widget preserves a valid center anchor', () {
      final before = HomeConfiguration(
        items: [
          item('wallet', 0, HomeSpan.wide, HomeItemKind.widget).copyWith(position: const HomeGridPosition(1, 3)),
          item('left', 1, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: const HomeGridPosition(0, 3)),
          item('right', 2, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: const HomeGridPosition(3, 3)),
        ],
      );
      final resized = before.normalize((id) => id == 'wallet' ? const _SmallDefinition('wallet') : null);
      final layout = HomeGridLayout(resized);

      expect(layout.positionOf('wallet'), const HomeGridPosition(1, 3));
      expect(layout.positionOf('left'), const HomeGridPosition(0, 3));
      expect(layout.positionOf('right'), const HomeGridPosition(3, 3));
      expectValidLayout(layout.positionedConfiguration);
    });

    test('a resized 2×2 can move to the center after automatic placement', () {
      final resized = HomeConfiguration(
        items: [
          item('left', 0, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: const HomeGridPosition(0, 1)),
          item('right', 1, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: const HomeGridPosition(3, 1)),
          item('wallet', 2, HomeSpan.wide, HomeItemKind.widget).copyWith(span: HomeSpan.small),
        ],
      );
      final positioned = HomeGridLayout(resized).positionedConfiguration;
      final moved = HomeGridLayout(positioned).moveToCell('wallet', const HomeGridPosition(1, 1));

      expectPositions(moved, positioned, {'wallet': const HomeGridPosition(1, 1)});
    });

    test('a displaced 2×2 uses a center gap without moving unrelated shortcuts', () {
      final before = HomeConfiguration(
        items: [
          item('left', 0, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: const HomeGridPosition(0, 0)),
          item('right', 1, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: const HomeGridPosition(3, 0)),
          item('wallet', 2, HomeSpan.small, HomeItemKind.widget).copyWith(position: const HomeGridPosition(0, 2)),
          item('moving', 3, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: const HomeGridPosition(3, 4)),
        ],
      );

      final moved = HomeGridLayout(before).moveToCell('moving', const HomeGridPosition(0, 2));

      expectPositions(moved, before, {'moving': const HomeGridPosition(0, 2), 'wallet': const HomeGridPosition(1, 0)});
    });

    for (final positionedPrefix in [false, true]) {
      test('automatic placement retains the previous alignment with a positioned prefix: $positionedPrefix', () {
        final config = HomeConfiguration(
          items: [
            item(
              'first',
              0,
              HomeSpan.shortcut,
              HomeItemKind.shortcut,
            ).copyWith(position: positionedPrefix ? const HomeGridPosition(0, 0) : null),
            item('wallet', 1, HomeSpan.small, HomeItemKind.widget),
            item('last', 2, HomeSpan.shortcut, HomeItemKind.shortcut),
          ],
        );
        final layout = HomeGridLayout(config);

        expect(layout.positionOf('first'), const HomeGridPosition(0, 0));
        expect(layout.positionOf('wallet'), const HomeGridPosition(2, 0));
        expect(layout.positionOf('last'), HomeGridPosition(0, positionedPrefix ? 1 : 2));
      });
    }
  });

  group('spatial drops in a mixed home', () {
    for (final column in [0, 1, 2]) {
      test('a 2×2 at column $column exchanges a 4×2 row with its companion shortcuts', () {
        final before = mixedHome();
        final moved = HomeGridLayout(before).moveToCell('price', HomeGridPosition(column, 0));
        final layout = HomeGridLayout(moved);
        expect(layout.positionOf('price'), HomeGridPosition(column, 0));
        expect(layout.positionOf('balance'), const HomeGridPosition(0, 4));
        expect(layout.rows, 8, reason: 'The two existing row bands can exchange without appending an empty band.');
        for (final id in ['receive', 'send', 'hodl', 'organizer']) {
          expect(layout.positionOf(id)!.row, inInclusiveRange(0, 1));
        }
        for (final id in ['wallet', 'utxo', 'recent']) {
          expect(layout.positionOf(id), HomeGridLayout(before).positionOf(id));
        }
        expectValidLayout(moved);
        for (final original in before.items) {
          expect(
            moved.items.singleWhere((item) => item.id == original.id),
            original.copyWith(position: layout.positionOf(original.id)),
          );
        }
      });
    }
    for (final moving in ['receive', 'send', 'hodl', 'organizer']) {
      for (final target in ['receive', 'send', 'hodl', 'organizer'].where((id) => id != moving)) {
        test('$moving into shortcut $target shifts the intervening visual sequence', () {
          final before = mixedHome();
          final layout = HomeGridLayout(before);
          final order = ['receive', 'send', 'hodl', 'organizer'];
          final targetIndex = order.indexOf(target);
          order.remove(moving);
          order.insert(targetIndex, moving);
          final slots = [
            for (final id in ['receive', 'send', 'hodl', 'organizer']) layout.positionOf(id)!,
          ];
          final expected = {for (var i = 0; i < order.length; i++) order[i]: slots[i]};
          final moved = layout.moveToCell(moving, layout.positionOf(target)!);
          expectPositions(moved, before, expected);
          expect(HomeGridLayout(moved).moveToCell(moving, layout.positionOf(moving)!), before);
        });
      }
    }
    for (final (first, second) in [
      ('receive', 'send'),
      ('hodl', 'organizer'),
      ('wallet', 'utxo'),
      ('wallet', 'price'),
      ('balance', 'recent'),
    ]) {
      for (final (moving, target) in [(first, second), (second, first)]) {
        test('$moving onto $target swaps only those two positions', () {
          final before = mixedHome();
          final layout = HomeGridLayout(before);
          final source = layout.positionOf(moving)!;
          final destination = layout.positionOf(target)!;

          final moved = layout.moveToCell(moving, destination);

          expectPositions(moved, before, {moving: destination, target: source});
          expect(HomeGridLayout(moved).moveToCell(moving, source), before);
        });
      }
    }

    test('a 2×2 exchanges space with four shortcuts while keeping their relative positions', () {
      final before = mixedHome();

      final moved = HomeGridLayout(before).moveToCell('wallet', const HomeGridPosition(2, 4));

      expectPositions(moved, before, {
        'wallet': const HomeGridPosition(2, 4),
        'receive': const HomeGridPosition(0, 2),
        'send': const HomeGridPosition(1, 2),
        'hodl': const HomeGridPosition(0, 3),
        'organizer': const HomeGridPosition(1, 3),
      });
    });

    for (final moving in ['balance', 'recent']) {
      test('$moving exchanges space with two 2×2 widgets without moving the other rows', () {
        final before = mixedHome();
        final layout = HomeGridLayout(before);
        final source = layout.positionOf(moving)!;

        final moved = layout.moveToCell(moving, const HomeGridPosition(0, 2));

        expectPositions(moved, before, {
          moving: const HomeGridPosition(0, 2),
          'wallet': source,
          'utxo': HomeGridPosition(2, source.row),
        });
      });
    }

    for (final target in ['wallet', 'balance']) {
      test('a shortcut onto $target relocates only that larger widget when the old cell cannot fit it', () {
        final before = mixedHome();
        final layout = HomeGridLayout(before);
        final destination = layout.positionOf(target)!;

        final moved = layout.moveToCell('receive', destination);

        expectPositions(moved, before, {'receive': destination, target: const HomeGridPosition(0, 8)});
      });
    }

    test('a displaced group uses the vacated footprint before unrelated gaps above it', () {
      final before = HomeConfiguration(
        items: [
          for (final (index, (id, span, column, row))
              in [
                ('stationary', HomeSpan.shortcut, 3, 0),
                ('small', HomeSpan.small, 0, 2),
                ('top-left', HomeSpan.shortcut, 2, 2),
                ('top-right', HomeSpan.shortcut, 3, 2),
                ('bottom-left', HomeSpan.shortcut, 2, 3),
                ('bottom-right', HomeSpan.shortcut, 3, 3),
                ('wide', HomeSpan.wide, 0, 8),
              ].indexed)
            item(
              id,
              index,
              span,
              span == HomeSpan.shortcut ? HomeItemKind.shortcut : HomeItemKind.widget,
            ).copyWith(position: HomeGridPosition(column, row)),
        ],
      );

      final moved = HomeGridLayout(before).moveToCell('wide', const HomeGridPosition(0, 2));

      expectPositions(moved, before, {
        'wide': const HomeGridPosition(0, 2),
        'small': const HomeGridPosition(0, 8),
        'top-left': const HomeGridPosition(2, 8),
        'top-right': const HomeGridPosition(3, 8),
        'bottom-left': const HomeGridPosition(2, 9),
        'bottom-right': const HomeGridPosition(3, 9),
      });
    });

    test('empty, unchanged and invalid targets preserve all unrelated positions', () {
      final before = mixedHome();
      final layout = HomeGridLayout(before);

      expectPositions(layout.moveToCell('receive', const HomeGridPosition(3, 10)), before, {
        'receive': const HomeGridPosition(3, 10),
      });
      expect(layout.moveToCell('receive', layout.positionOf('receive')!), before);
      expect(layout.moveToCell('missing', const HomeGridPosition(0, 0)), before);
      expect(layout.moveToCell('wallet', const HomeGridPosition(3, 2)), before);
      expect(layout.moveToCell('balance', const HomeGridPosition(1, 0)), before);
      expect(layout.moveToCell('send', const HomeGridPosition(0, -1)), before);
    });

    test('sequences of mixed drops retain every item, its settings and a stable nonoverlapping layout', () {
      final random = Random(752);
      final initial = mixedHome();
      var current = initial;
      for (var step = 0; step < 240; step++) {
        final moving = current.items[random.nextInt(current.items.length)];
        final row = random.nextInt(12);
        final target = HomeGridLayout.anchorForSpan(HomeGridPosition(random.nextInt(4), row), moving.span);
        final moved = HomeGridLayout(current).moveToCell(moving.id, target);

        expect(HomeGridLayout(moved).positionOf(moving.id), target, reason: 'step $step');
        expectValidLayout(moved);
        expect(moved.version, initial.version);
        expect(moved.shortcutWalletContext, initial.shortcutWalletContext);
        expect(moved.items.length, initial.items.length);
        for (final item in initial.items) {
          final actual = moved.items.singleWhere((other) => other.id == item.id);
          expect(actual, item.copyWith(position: actual.position), reason: 'step $step, ${item.id}');
        }
        current = moved;
      }
    });
  });

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

    final moved = HomeGridLayout(config).moveBefore('lower-1', 'wide');
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
  });

  test('moving a 4×2 between shortcut rows preserves shortcuts outside its footprint', () {
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
    expect(layout.positionOf('single'), const HomeGridPosition(0, 4));
    expect(
      layout.positionOf('small'),
      const HomeGridPosition(1, 4),
      reason: 'the center is now the first fitting position in the vacated wide footprint',
    );
    expect(layout.positionOf('lower-a'), const HomeGridPosition(3, 4));
    expect(layout.positionOf('lower-b'), const HomeGridPosition(3, 5));
    expect(layout.positionOf('lower-c'), const HomeGridPosition(2, 3));
    expect(layout.positionOf('lower-d'), const HomeGridPosition(3, 3));
    expectValidLayout(moved);
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

  test('2×2 widgets use all fitting columns while 4×2 may start on an odd row', () {
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

    expect(layout.canMoveToCell('small', const HomeGridPosition(0, 2)), isTrue);
    expect(layout.canMoveToCell('small', const HomeGridPosition(1, 2)), isTrue);
    expect(layout.canMoveToCell('small', const HomeGridPosition(2, 2)), isTrue);
    expect(layout.canMoveToCell('small', const HomeGridPosition(-1, 2)), isFalse);
    expect(layout.canMoveToCell('small', const HomeGridPosition(3, 2)), isFalse);
    expect(layout.canMoveToCell('small', const HomeGridPosition(1, -1)), isFalse);
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

  test('a 2×2 can use the middle columns between two shortcuts', () {
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
    expectPositions(layout.moveToCell('middle', const HomeGridPosition(1, 0)), config, {
      'middle': const HomeGridPosition(1, 0),
    });
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

  test('resize is a pure preview and retains an explicit leading gap', () {
    final configuration = HomeConfiguration(
      items: [
        item('target', 0, HomeSpan.wide, HomeItemKind.widget).copyWith(position: const HomeGridPosition(0, 4)),
        item('a', 1, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: const HomeGridPosition(0, 6)),
        item('b', 2, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: const HomeGridPosition(1, 6)),
      ],
    );
    final before = configuration.toJson();
    final layout = HomeGridLayout(configuration);

    final preview = layout.resizeItem('target', HomeSpan.small);

    expect(configuration.toJson(), before);
    expect(layout.positionOf('a'), const HomeGridPosition(0, 6));
    expect(HomeGridLayout(preview).positionOf('target'), const HomeGridPosition(0, 4));
    expect(HomeGridLayout(preview).positionOf('a'), const HomeGridPosition(2, 4));
    expect(HomeGridLayout(preview).positionOf('b'), const HomeGridPosition(3, 4));
    expect(HomeGridLayout(preview).positionedConfiguration, preview);
  });

  test('resize does not change load or drag preservation of explicit holes', () {
    final configuration = HomeConfiguration(
      items: [
        item('target', 0, HomeSpan.small, HomeItemKind.widget).copyWith(position: const HomeGridPosition(1, 2)),
        item('a', 1, HomeSpan.shortcut, HomeItemKind.shortcut).copyWith(position: const HomeGridPosition(0, 6)),
      ],
    );
    final layout = HomeGridLayout(configuration);

    expect(layout.positionedConfiguration, configuration);
    expect(layout.resizeItem('target', HomeSpan.small), configuration);
    final dragged = layout.moveToCell('a', const HomeGridPosition(3, 6));
    expect(HomeGridLayout(dragged).positionOf('target'), const HomeGridPosition(1, 2));
    expect(HomeGridLayout(dragged).positionOf('a'), const HomeGridPosition(3, 6));
  });

  test('resize rejects missing items and spans that cannot fit a grid', () {
    final configuration = HomeConfiguration(
      items: [item('target', 0, HomeSpan.small, HomeItemKind.widget).copyWith(position: const HomeGridPosition(1, 2))],
    );
    final layout = HomeGridLayout(configuration);
    expect(layout.resizeItem('missing', HomeSpan.wide), configuration);
    for (final span in [const HomeSpan(0, 2), const HomeSpan(5, 2), const HomeSpan(2, 0), const HomeSpan(-1, 2)]) {
      expect(layout.resizeItem('target', span), configuration);
    }
  });
}
