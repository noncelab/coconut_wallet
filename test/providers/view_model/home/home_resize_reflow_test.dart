import 'dart:convert';

import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/home/shortcut_wallet_context.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

HomeItem _widget(String id, String definitionId, int order, HomeSpan span, int column, int row) => HomeItem(
  id: id,
  definitionId: definitionId,
  kind: HomeItemKind.widget,
  order: order,
  span: span,
  position: HomeGridPosition(column, row),
);

HomeItem _shortcut(String id, String feature, int order, int column, int row) => HomeItem(
  id: id,
  definitionId: HomeItemIds.shortcut(feature),
  kind: HomeItemKind.shortcut,
  order: order,
  span: HomeSpan.shortcut,
  position: HomeGridPosition(column, row),
);

Map<String, HomeGridPosition?> _positions(HomeConfiguration configuration) => {
  for (final item in configuration.items) item.id: item.position,
};

void main() {
  late HomeConfigurationRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPrefsRepository();
    await prefs.init();
    repository = HomeConfigurationRepository(prefs);
  });

  HomeViewModel create() => HomeViewModel(repository: repository, wallets: () => [], onShortcutTap: (_, __) {});

  test('shrinking fills shortcut gaps before a later tall widget', () async {
    await repository.save(
      HomeConfiguration(
        items: [
          _widget('target', HomeItemIds.bitcoinBalanceTrend, 0, HomeSpan.wide, 0, 0),
          _shortcut('a', FeatureIds.receive, 1, 0, 2),
          _widget('following', HomeItemIds.fiatValues, 2, HomeSpan.small, 1, 2),
          _shortcut('b', FeatureIds.send, 3, 3, 2),
          _shortcut('c', FeatureIds.calculator, 4, 0, 3),
          _shortcut('d', FeatureIds.glossary, 5, 3, 3),
          _widget('tail', HomeItemIds.recentTransactions, 6, HomeSpan.wide, 0, 4),
        ],
      ),
    );
    final model = create();
    addTearDown(model.dispose);
    model.resizeItem('target', HomeSpan.small);

    final expected = {
      'target': const HomeGridPosition(0, 0),
      'a': const HomeGridPosition(2, 0),
      'following': const HomeGridPosition(0, 2),
      'b': const HomeGridPosition(3, 0),
      'c': const HomeGridPosition(2, 1),
      'd': const HomeGridPosition(3, 1),
      'tail': const HomeGridPosition(0, 4),
    };
    expect(_positions(model.configuration), expected);
    expect(repository.load(), model.configuration);
  });

  final currentPhone = HomeConfiguration(
    items: [
      _widget('target', HomeItemIds.bitcoinBalanceTrend, 0, HomeSpan.wide, 0, 0),
      _widget('price', HomeItemIds.fiatPriceTrend, 1, HomeSpan.small, 0, 2),
      _widget('utxo', HomeItemIds.utxoStatus, 2, HomeSpan.small, 2, 2),
      _widget('stack', HomeItemIds.allWalletStack, 3, HomeSpan.small, 0, 4),
      _shortcut('receive', FeatureIds.receive, 4, 2, 4),
      _shortcut('send', FeatureIds.send, 5, 3, 4),
      _shortcut('organizer', FeatureIds.utxoOrganizer, 6, 2, 5),
      _shortcut('insights', FeatureIds.hodlInsights, 7, 3, 5),
      _widget('recent', HomeItemIds.recentTransactions, 8, HomeSpan.wide, 0, 6),
    ],
  );

  test('current iPhone nine-item layout shrinks balance and restores its exact layout on grow', () async {
    await repository.save(currentPhone);
    final model = create();
    addTearDown(model.dispose);
    expect(model.configuration, currentPhone);
    model.resizeItem('target', HomeSpan.small);
    expect(_positions(model.configuration), {
      'target': const HomeGridPosition(0, 0),
      'price': const HomeGridPosition(2, 0),
      'utxo': const HomeGridPosition(0, 2),
      'stack': const HomeGridPosition(2, 2),
      'receive': const HomeGridPosition(0, 4),
      'send': const HomeGridPosition(1, 4),
      'organizer': const HomeGridPosition(2, 4),
      'insights': const HomeGridPosition(3, 4),
      'recent': const HomeGridPosition(0, 5),
    });
    _expectIntegrity(currentPhone, model.configuration, HomeSpan.small);
    expect(repository.load(), model.configuration);
    model.resizeItem('target', HomeSpan.wide);
    expect(model.configuration, currentPhone);
    expect(repository.load(), currentPhone);
  });

  test('current iPhone nine-item layout grows and shrinks stack without moving earlier widgets', () async {
    await repository.save(currentPhone);
    final model = create();
    addTearDown(model.dispose);
    model.resizeItem('stack', HomeSpan.wide);
    expect(_positions(model.configuration), {
      'target': const HomeGridPosition(0, 0),
      'price': const HomeGridPosition(0, 2),
      'utxo': const HomeGridPosition(2, 2),
      'stack': const HomeGridPosition(0, 4),
      'receive': const HomeGridPosition(0, 6),
      'send': const HomeGridPosition(1, 6),
      'organizer': const HomeGridPosition(2, 6),
      'insights': const HomeGridPosition(3, 6),
      'recent': const HomeGridPosition(0, 7),
    });
    expect(repository.load(), model.configuration);
    model.resizeItem('stack', HomeSpan.small);
    expect(model.configuration, currentPhone);
    expect(repository.load(), currentPhone);
  });

  final catalog = builtinHomeWidgets();
  final resizable = catalog.where((definition) => definition.supportedSpans.length > 1).toList();
  test('catalog exposes all supported resize transitions and matching settings sizes', () {
    expect(resizable.map((definition) => definition.id).toSet(), {
      HomeItemIds.bitcoinBalanceTrend,
      HomeItemIds.hotWalletStack,
      HomeItemIds.watchOnlyWalletStack,
      HomeItemIds.allWalletStack,
      HomeItemIds.safetyStatus,
    });
    for (final definition in resizable) {
      expect(definition.supportedSpans.toSet(), {HomeSpan.small, HomeSpan.wide});
      expect(definition.settings.sizes.toSet(), definition.supportedSpans.toSet());
    }
  });

  for (final definition in resizable) {
    for (final from in definition.supportedSpans) {
      for (final to in definition.supportedSpans.where((span) => span != from)) {
        for (final scenario in _scenarios) {
          test('${definition.id} ${from.toJson()} to ${to.toJson()} ${scenario.name}', () async {
            final original = scenario.configuration(definition.id, from);
            await repository.save(original);
            final model = create();
            addTearDown(model.dispose);
            expect(model.configuration, original, reason: 'The fixture must already be a valid saved layout');
            final before = model.configuration;
            final visual = HomeGridLayout(before).itemsInVisualOrder;
            final prefix = visual.takeWhile((item) => item.id != 'target').toList();

            void expectResult(HomeSpan span) {
              final expected = scenario.positionsFor(span);
              expect(_positions(model.configuration), expected, reason: 'Exact compact placement, not just validity');
              for (final item in prefix) {
                expect(model.configuration.items.firstWhere((other) => other.id == item.id).position, item.position);
              }
              _expectIntegrity(before, model.configuration, span);
              expect(repository.load(), model.configuration);
              final reloaded = create();
              expect(reloaded.configuration, model.configuration, reason: 'Persisted explicit positions remain stable');
              reloaded.dispose();
            }

            model.resizeItem('target', to);
            expectResult(to);
            for (var cycle = 0; cycle < 3; cycle++) {
              model.resizeItem('target', from);
              expectResult(from);
              model.resizeItem('target', to);
              expectResult(to);
            }
            final unchanged = model.configuration;
            model.resizeItem('target', to);
            expect(model.configuration, same(unchanged), reason: 'Selecting the current size is a true no-op');
          });
        }
      }
    }
  }

  for (final definition in resizable) {
    for (final from in definition.supportedSpans) {
      test(
        '${definition.id} ${from.toJson()} interleaved shortcut and tall suffix fills every reachable hole',
        () async {
          final wide = from == HomeSpan.wide;
          final original = HomeConfiguration(
            items: [
              _widget('target', definition.id, 0, from, 0, 0),
              _shortcut('a', FeatureIds.receive, 1, wide ? 0 : 2, wide ? 2 : 0),
              _widget('following', HomeItemIds.fiatValues, 2, HomeSpan.small, wide ? 1 : 0, 2),
              _shortcut('b', FeatureIds.send, 3, wide ? 3 : 2, 2),
              _shortcut('c', FeatureIds.calculator, 4, wide ? 0 : 3, wide ? 3 : 2),
              _shortcut('d', FeatureIds.glossary, 5, wide ? 3 : 2, 3),
              _widget('tail', HomeItemIds.recentTransactions, 6, HomeSpan.wide, 0, 4),
            ],
          );
          await repository.save(original);
          final model = create();
          addTearDown(model.dispose);
          expect(model.configuration, original);
          final to = wide ? HomeSpan.small : HomeSpan.wide;
          model.resizeItem('target', to);
          final expected =
              wide
                  ? {
                    'target': const HomeGridPosition(0, 0),
                    'a': const HomeGridPosition(2, 0),
                    'following': const HomeGridPosition(0, 2),
                    'b': const HomeGridPosition(3, 0),
                    'c': const HomeGridPosition(2, 1),
                    'd': const HomeGridPosition(3, 1),
                    'tail': const HomeGridPosition(0, 4),
                  }
                  : {
                    'target': const HomeGridPosition(0, 0),
                    'a': const HomeGridPosition(0, 2),
                    'following': const HomeGridPosition(1, 2),
                    'b': const HomeGridPosition(3, 2),
                    'c': const HomeGridPosition(0, 3),
                    'd': const HomeGridPosition(3, 3),
                    'tail': const HomeGridPosition(0, 4),
                  };
          expect(_positions(model.configuration), expected);
          _expectIntegrity(original, model.configuration, to);
          expect(repository.load(), model.configuration);
          final reloaded = create();
          expect(reloaded.configuration, model.configuration);
          reloaded.dispose();
        },
      );
    }
  }

  test('an empty home stays empty when a stale resize action arrives', () async {
    final original = HomeConfiguration(items: const []);
    await repository.save(original);
    final model = create();
    addTearDown(model.dispose);
    model.resizeItem('removed', HomeSpan.small);
    expect(model.configuration, original);
    expect(repository.load(), original);
  });

  for (final definition in catalog) {
    test('${definition.id} rejects unsupported sizes without changing positions or settings', () async {
      final original = HomeConfiguration(
        items: [
          _widget('target', definition.id, 0, definition.supportedSpans.first, 0, 3).copyWith(
            configuration: const {
              'walletIds': [7],
              'period': 'month',
            },
          ),
        ],
      );
      await repository.save(original);
      final model = create();
      addTearDown(model.dispose);
      model.resizeItem('target', HomeSpan.shortcut);
      expect(model.configuration, original);
      expect(repository.load(), original);
      if (definition.supportedSpans.length == 1) {
        final other = definition.supportedSpans.single == HomeSpan.small ? HomeSpan.wide : HomeSpan.small;
        model.resizeItem('target', other);
        expect(model.configuration, original);
      }
    });
  }

  test('resize invalidates a preceding move Undo; unsupported or same-size selection does not', () async {
    await repository.save(_scenarios[1].configuration(HomeItemIds.bitcoinBalanceTrend, HomeSpan.small));
    final model = create();
    addTearDown(model.dispose);
    final original = model.configuration;
    model.moveToCell('a', const HomeGridPosition(3, 0));
    expect(model.canUndoArrangement, isTrue);
    model.resizeItem('target', HomeSpan.small);
    model.resizeItem('target', HomeSpan.shortcut);
    expect(model.canUndoArrangement, isTrue);
    model.undoArrangement();
    expect(model.configuration, original);
    model.moveToCell('a', const HomeGridPosition(3, 0));
    model.resizeItem('target', HomeSpan.wide);
    final resized = model.configuration;
    expect(model.canUndoArrangement, isFalse);
    model.undoArrangement();
    expect(model.configuration, resized);
    expect(repository.load(), resized);
  });

  test('unknown item and definition resize are no-ops', () async {
    final original = HomeConfiguration(items: [_widget('target', 'future-widget', 0, HomeSpan.small, 1, 4)]);
    await repository.save(original);
    final model = create();
    addTearDown(model.dispose);
    model.resizeItem('missing', HomeSpan.wide);
    model.resizeItem('target', HomeSpan.wide);
    expect(model.configuration, original);
    expect(repository.load(), original);
  });
}

class _ResizeScenario {
  final String name;
  final Map<String, HomeGridPosition> small;
  final Map<String, HomeGridPosition> wide;
  const _ResizeScenario(this.name, {required this.small, required this.wide});

  Map<String, HomeGridPosition> positionsFor(HomeSpan span) => span == HomeSpan.small ? small : wide;

  HomeConfiguration configuration(String definitionId, HomeSpan span) {
    final positions = positionsFor(span);
    final ordered =
        positions.keys.toList()..sort((a, b) {
          final row = positions[a]!.row.compareTo(positions[b]!.row);
          return row != 0 ? row : positions[a]!.column.compareTo(positions[b]!.column);
        });
    return HomeConfiguration(
      version: 1,
      shortcutWalletContext: const ShortcutWalletContext.wallet(7),
      items: [
        for (final (order, id) in ordered.indexed)
          (switch (id) {
            'target' => _widget(id, definitionId, order, span, positions[id]!.column, positions[id]!.row),
            'prefix' => _widget(
              id,
              HomeItemIds.fiatPriceTrend,
              order,
              HomeSpan.small,
              positions[id]!.column,
              positions[id]!.row,
            ),
            'following' => _widget(
              id,
              HomeItemIds.fiatValues,
              order,
              HomeSpan.small,
              positions[id]!.column,
              positions[id]!.row,
            ),
            'tail' => _widget(
              id,
              HomeItemIds.recentTransactions,
              order,
              HomeSpan.wide,
              positions[id]!.column,
              positions[id]!.row,
            ),
            _ => _shortcut(
              id,
              switch (id) {
                'a' => FeatureIds.receive,
                'b' => FeatureIds.send,
                'c' => FeatureIds.calculator,
                _ => FeatureIds.glossary,
              },
              order,
              positions[id]!.column,
              positions[id]!.row,
            ),
          }).copyWith(
            configuration: {
              'walletIds': [7, 11],
              'period': 'month',
              'extension': {'item': id},
            },
          ),
      ],
    );
  }
}

const _scenarios = [
  _ResizeScenario('single item', small: {'target': HomeGridPosition(0, 0)}, wide: {'target': HomeGridPosition(0, 0)}),
  _ResizeScenario(
    'four shortcut block',
    small: {
      'target': HomeGridPosition(0, 0),
      'a': HomeGridPosition(2, 0),
      'b': HomeGridPosition(3, 0),
      'c': HomeGridPosition(2, 1),
      'd': HomeGridPosition(3, 1),
      'tail': HomeGridPosition(0, 2),
    },
    wide: {
      'target': HomeGridPosition(0, 0),
      'a': HomeGridPosition(0, 2),
      'b': HomeGridPosition(1, 2),
      'c': HomeGridPosition(2, 2),
      'd': HomeGridPosition(3, 2),
      'tail': HomeGridPosition(0, 3),
    },
  ),
  _ResizeScenario(
    'fixed prefix and right column',
    small: {
      'prefix': HomeGridPosition(0, 0),
      'target': HomeGridPosition(2, 0),
      'a': HomeGridPosition(0, 2),
      'b': HomeGridPosition(1, 2),
      'c': HomeGridPosition(2, 2),
      'd': HomeGridPosition(3, 2),
      'tail': HomeGridPosition(0, 3),
    },
    wide: {
      'prefix': HomeGridPosition(0, 0),
      'target': HomeGridPosition(0, 2),
      'a': HomeGridPosition(0, 4),
      'b': HomeGridPosition(1, 4),
      'c': HomeGridPosition(2, 4),
      'd': HomeGridPosition(3, 4),
      'tail': HomeGridPosition(0, 5),
    },
  ),
  _ResizeScenario(
    'center column with shortcuts on both sides',
    small: {
      'a': HomeGridPosition(0, 0),
      'target': HomeGridPosition(1, 0),
      'b': HomeGridPosition(3, 0),
      'c': HomeGridPosition(0, 1),
      'd': HomeGridPosition(3, 1),
      'tail': HomeGridPosition(0, 2),
    },
    wide: {
      'a': HomeGridPosition(0, 0),
      'target': HomeGridPosition(0, 1),
      'b': HomeGridPosition(0, 3),
      'c': HomeGridPosition(1, 3),
      'd': HomeGridPosition(2, 3),
      'tail': HomeGridPosition(0, 4),
    },
  ),
  _ResizeScenario(
    'last item below an intentional leading space',
    small: {'prefix': HomeGridPosition(0, 4), 'target': HomeGridPosition(2, 4)},
    wide: {'prefix': HomeGridPosition(0, 4), 'target': HomeGridPosition(0, 6)},
  ),
  _ResizeScenario(
    'isolated item keeps its row',
    small: {'target': HomeGridPosition(0, 7)},
    wide: {'target': HomeGridPosition(0, 7)},
  ),
  _ResizeScenario(
    'mixed tall widgets and shortcut block',
    small: {
      'target': HomeGridPosition(0, 0),
      'a': HomeGridPosition(2, 0),
      'b': HomeGridPosition(3, 0),
      'c': HomeGridPosition(2, 1),
      'd': HomeGridPosition(3, 1),
      'following': HomeGridPosition(0, 2),
      'tail': HomeGridPosition(0, 4),
    },
    wide: {
      'target': HomeGridPosition(0, 0),
      'a': HomeGridPosition(0, 2),
      'b': HomeGridPosition(1, 2),
      'c': HomeGridPosition(2, 2),
      'd': HomeGridPosition(3, 2),
      'following': HomeGridPosition(0, 3),
      'tail': HomeGridPosition(0, 5),
    },
  ),
];

void _expectIntegrity(HomeConfiguration before, HomeConfiguration after, HomeSpan targetSpan) {
  expect(after.version, before.version);
  expect(after.shortcutWalletContext, before.shortcutWalletContext);
  expect(after.items.map((item) => item.id).toSet(), before.items.map((item) => item.id).toSet());
  expect(after.items.length, before.items.length);
  final occupied = <(int, int)>{};
  for (final item in after.items) {
    final previous = before.items.firstWhere((other) => other.id == item.id);
    expect(item.definitionId, previous.definitionId);
    expect(item.kind, previous.kind);
    expect(item.configuration, previous.configuration);
    expect(item.span, item.id == 'target' ? targetSpan : previous.span);
    final position = item.position!;
    expect(position.column, greaterThanOrEqualTo(0));
    expect(position.row, greaterThanOrEqualTo(0));
    expect(position.column + item.span.width, lessThanOrEqualTo(4));
    for (var row = position.row; row < position.row + item.span.height; row++) {
      for (var column = position.column; column < position.column + item.span.width; column++) {
        expect(occupied.add((column, row)), isTrue, reason: 'Overlap at $column,$row');
      }
    }
  }
  final firstRow = occupied.map((cell) => cell.$2).reduce((a, b) => a < b ? a : b);
  final bottom = HomeGridLayout(after).rows;
  for (var row = firstRow; row < bottom; row++) {
    expect(occupied.any((cell) => cell.$2 == row), isTrue, reason: 'Unexpected empty row $row');
  }
  expect(HomeConfiguration.fromJson(jsonDecode(jsonEncode(after.toJson()))), after);
  expect(HomeGridLayout(after).positionedConfiguration, after);
}
