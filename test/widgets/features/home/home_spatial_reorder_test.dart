import 'dart:convert';

import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _LabelDefinition extends HomeItemDefinition {
  _LabelDefinition(HomeItem item)
    : super(id: item.definitionId, kind: item.kind, supportedSpans: [item.span], category: HomeItemCategory.wallets);

  @override
  Widget build(BuildContext context, HomeItem item) =>
      Center(child: Text('item:${item.id}', maxLines: 1, overflow: TextOverflow.ellipsis));
}

// The mixed 9-item layout observed on iPhone on 2026-10-14, with public feature IDs only.
HomeConfiguration _mixedHome() {
  final placements = <(String, HomeSpan, HomeGridPosition)>[
    ('bitcoin_balance_trend', HomeSpan.wide, const HomeGridPosition(0, 0)),
    ('all_wallet_stack', HomeSpan.small, const HomeGridPosition(0, 2)),
    ('utxo_status_2x2', HomeSpan.small, const HomeGridPosition(2, 2)),
    ('fiat_price_trend_2x2', HomeSpan.small, const HomeGridPosition(0, 4)),
    ('shortcut:receive', HomeSpan.shortcut, const HomeGridPosition(2, 4)),
    ('shortcut:send', HomeSpan.shortcut, const HomeGridPosition(3, 4)),
    ('shortcut:utxo_organizer', HomeSpan.shortcut, const HomeGridPosition(3, 5)),
    ('shortcut:hodl_insights', HomeSpan.shortcut, const HomeGridPosition(2, 5)),
    ('recent_transactions_4x2', HomeSpan.wide, const HomeGridPosition(0, 6)),
  ];
  return HomeConfiguration(
    items: [
      for (var index = 0; index < placements.length; index++)
        HomeItem(
          id: placements[index].$1,
          definitionId: placements[index].$1,
          kind: placements[index].$2 == HomeSpan.shortcut ? HomeItemKind.shortcut : HomeItemKind.widget,
          order: index,
          span: placements[index].$2,
          position: placements[index].$3,
        ),
    ],
  );
}

class _GridHarness extends StatefulWidget {
  const _GridHarness({super.key, required this.withMenus, this.initialConfiguration});

  final bool withMenus;
  final HomeConfiguration? initialConfiguration;

  @override
  State<_GridHarness> createState() => _GridHarnessState();
}

class _GridHarnessState extends State<_GridHarness> {
  final gridKey = GlobalKey<HomeItemsViewState>();
  final scrollController = ScrollController();
  late HomeConfiguration configuration;
  late final HomeItemRegistry registry;
  final cellDrops = <(String, HomeGridPosition)>[];
  final insertionDrops = <(String, String)>[];
  var arranging = false;

  @override
  void initState() {
    super.initState();
    configuration = widget.initialConfiguration ?? _mixedHome();
    registry = HomeItemRegistry();
    for (final item in configuration.items) {
      registry.register(_LabelDefinition(item));
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildCoconutThemeData(),
    home: SingleChildScrollView(
      controller: scrollController,
      child: Center(
        child: SizedBox(
          width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
          child: HomeItemsView(
            key: gridKey,
            configuration: configuration,
            registry: registry,
            isArranging: arranging,
            onArrangeStart: () => setState(() => arranging = true),
            onMoveToCell: (id, position) {
              cellDrops.add((id, position));
              setState(() => configuration = HomeGridLayout(configuration).moveToCell(id, position));
            },
            onInsertBefore: (id, beforeId) {
              insertionDrops.add((id, beforeId));
              setState(() => configuration = HomeGridLayout(configuration).moveBefore(id, beforeId));
            },
            menuItemsOf:
                widget.withMenus
                    ? (item) => [
                      LongPressedMenuItem(
                        title: 'Edit ${item.id}',
                        iconPath: CommonActionIconPath.editHome,
                        onSelected: () => setState(() => arranging = true),
                      ),
                    ]
                    : null,
          ),
        ),
      ),
    ),
  );
}

Finder _item(String id) => find.byKey(ValueKey('home-item-$id'));

Map<String, Offset> _paintedPositions(WidgetTester tester, [HomeConfiguration? configuration]) => {
  for (final item in (configuration ?? _mixedHome()).items) item.id: tester.getTopLeft(_item(item.id)),
};

Map<String, HomeGridPosition> _savedPositions(HomeConfiguration configuration) => {
  for (final item in configuration.items) item.id: item.position!,
};

Map<String, T> _swapped<T>(Map<String, T> positions, String source, String target) => {
  ...positions,
  source: positions[target] as T,
  target: positions[source] as T,
};

void _expectSingleDragCopy(WidgetTester tester, String source, Size originalSize) {
  final label = find.text('item:$source');
  expect(label, findsOneWidget, reason: 'Only the finger-following copy should contain the dragged item.');
  expect(find.descendant(of: _item(source), matching: label), findsNothing);
  expect(tester.getSize(_item(source)), originalSize, reason: 'The empty placeholder must keep its dimensions.');
}

Future<_GridHarnessState> _pumpGrid(
  WidgetTester tester, {
  required bool withMenus,
  HomeConfiguration? initialConfiguration,
}) async {
  tester.view.physicalSize = const Size(414, 896);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final key = GlobalKey<_GridHarnessState>();
  await tester.pumpWidget(_GridHarness(key: key, withMenus: withMenus, initialConfiguration: initialConfiguration));
  return key.currentState!;
}

Future<TestGesture> _holdAndMove(WidgetTester tester, String source, Offset destination) async {
  final gesture = await tester.startGesture(tester.getCenter(_item(source)));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveTo(destination);
  return gesture;
}

List<({String label, Offset point, bool? swapped})> _verticalStops(Rect source, Rect target) {
  final direction = target.center.dy > source.center.dy ? 1.0 : -1.0;
  final sourceEdge = direction > 0 ? source.bottom : source.top;
  final targetEdge = direction > 0 ? target.top : target.bottom;
  Offset inGap(double fraction) => Offset(source.center.dx, sourceEdge + (targetEdge - sourceEdge) * fraction);
  return [
    (label: '30% inside source', point: Offset.lerp(source.center, target.center, 0.3)!, swapped: false),
    (label: '46% inside source', point: Offset.lerp(source.center, target.center, 0.46)!, swapped: false),
    (label: 'source edge', point: Offset(source.center.dx, sourceEdge - direction), swapped: false),
    (label: 'source half of gap', point: inGap(0.25), swapped: false),
    (label: 'gap midpoint', point: inGap(0.5), swapped: null),
    (label: 'target half of gap', point: inGap(0.75), swapped: true),
    (label: 'target edge', point: Offset(target.center.dx, targetEdge + direction), swapped: true),
    (label: 'target center', point: target.center, swapped: true),
  ];
}

Future<void> _settleHover(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 300));
}

HomeConfiguration _smallWidgetAndShortcutColumns(int widgetColumn) {
  final placements = <(String, HomeSpan, HomeGridPosition)>[
    ('bitcoin_balance_trend', HomeSpan.wide, const HomeGridPosition(0, 0)),
    ('all_wallet_stack', HomeSpan.small, HomeGridPosition(widgetColumn, 2)),
    for (final row in [2, 3])
      for (var column = 0; column < 4; column++)
        if (column < widgetColumn || column >= widgetColumn + 2)
          ('shortcut:$column:$row', HomeSpan.shortcut, HomeGridPosition(column, row)),
    ('recent_transactions_4x2', HomeSpan.wide, const HomeGridPosition(0, 4)),
  ];
  return HomeConfiguration(
    items: [
      for (var index = 0; index < placements.length; index++)
        HomeItem(
          id: placements[index].$1,
          definitionId: placements[index].$1,
          kind: placements[index].$2 == HomeSpan.shortcut ? HomeItemKind.shortcut : HomeItemKind.widget,
          order: index,
          span: placements[index].$2,
          position: placements[index].$3,
          configuration: {'fixtureMarker': placements[index].$1},
        ),
    ],
  );
}

Map<String, Offset> _cellOrigins(Offset surface, Map<String, HomeGridPosition> positions) => {
  for (final entry in positions.entries)
    entry.key:
        surface +
        Offset(
          entry.value.column * (HomeItemsView.cell + HomeItemsView.gap),
          entry.value.row * (HomeItemsView.cell + HomeItemsView.gap),
        ),
};

void main() {
  for (final withMenus in [true, false]) {
    final branch = withMenus ? 'with menus' : 'without menus';
    for (final crossing in [
      (column: 0, grabX: 10.0, destinationX: 355.0, name: 'content beyond right while finger inside'),
      (column: 2, grabX: 162.0, destinationX: 1.0, name: 'content beyond left while finger inside'),
      (column: 2, grabX: 10.0, destinationX: -1.0, name: 'finger beyond left while content inside'),
      (column: 0, grabX: 162.0, destinationX: 357.0, name: 'finger beyond right while content inside'),
    ]) {
      testWidgets('${crossing.name} $branch cancels both preview and commit', (tester) async {
        final original = _smallWidgetAndShortcutColumns(crossing.column);
        final harness = await _pumpGrid(tester, withMenus: withMenus, initialConfiguration: original);
        final rect = tester.getRect(_item('all_wallet_stack'));
        final surface = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface')));
        final painted = _paintedPositions(tester, original);
        final gesture = await tester.startGesture(rect.topLeft + Offset(crossing.grabX, 10));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveTo(surface + Offset(crossing.destinationX, 194));
        await _settleHover(tester);
        expect(
          _paintedPositions(tester, original),
          painted,
          reason: 'No destination should be previewed outside the grid.',
        );
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          harness.configuration,
          original,
          reason: 'An invalid preview cannot fall through to another drop policy.',
        );
        expect(harness.cellDrops, isEmpty);
        await tester.pumpWidget(const SizedBox());
      });
    }
    for (final fraction in [const Offset(0.15, 0.15), const Offset(0.85, 0.85)]) {
      for (final move in [(source: 0, target: 1), (source: 2, target: 1)]) {
        testWidgets('off-center grab $fraction column ${move.source} → ${move.target} $branch follows content', (
          tester,
        ) async {
          final harness = await _pumpGrid(
            tester,
            withMenus: withMenus,
            initialConfiguration: _smallWidgetAndShortcutColumns(move.source),
          );
          final rect = tester.getRect(_item('all_wallet_stack'));
          final start = rect.topLeft + Offset(rect.width * fraction.dx, rect.height * fraction.dy);
          final gesture = await tester.startGesture(start);
          await tester.pump(const Duration(milliseconds: 600));
          await gesture.moveTo(start + Offset((move.target - move.source) * 92.0, 0));
          await _settleHover(tester);
          await gesture.up();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(harness.cellDrops, [('all_wallet_stack', HomeGridPosition(move.target, 2))]);
          expect(_savedPositions(harness.configuration)['all_wallet_stack'], HomeGridPosition(move.target, 2));
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    for (final cell in [
      const HomeGridPosition(0, 2),
      const HomeGridPosition(1, 2),
      const HomeGridPosition(0, 3),
      const HomeGridPosition(1, 3),
    ]) {
      testWidgets('shortcut can land at internal cell $cell of a 2×2 widget $branch', (tester) async {
        final harness = await _pumpGrid(tester, withMenus: withMenus);
        final surface = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface')));
        final destination = surface + Offset(cell.column * 92.0 + 40, cell.row * 92.0 + 40);
        final gesture = await _holdAndMove(tester, 'shortcut:receive', destination);
        await _settleHover(tester);
        final preview = _paintedPositions(tester);
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(harness.cellDrops, [('shortcut:receive', cell)]);
        expect(_savedPositions(harness.configuration)['shortcut:receive'], cell);
        expect(_paintedPositions(tester), preview, reason: 'The committed placement must match the visible preview.');
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('quickly dropped item stays at the finger and can be grabbed during neighbor reflow $branch', (
      tester,
    ) async {
      final harness = await _pumpGrid(tester, withMenus: withMenus);
      const source = 'shortcut:receive';
      const target = 'shortcut:send';
      final original = harness.configuration;
      final originalPaint = _paintedPositions(tester);
      for (var step = 0; step < 8; step++) {
        final sourceStart = originalPaint[step.isEven ? source : target]!;
        final targetStart = originalPaint[step.isEven ? target : source]!;
        final gesture = await tester.startGesture(sourceStart + const Offset(40, 40));
        await tester.pump(Duration(milliseconds: step == 0 ? 600 : 16));
        await gesture.moveTo(targetStart + const Offset(40, 40));
        await gesture.up();
        await tester.pump();
        await tester.pump();
        expect(
          tester.getTopLeft(_item(source)),
          targetStart,
          reason: 'The held content must not fly from its old cell.',
        );
        expect(harness.cellDrops.last.$1, source, reason: 'Re-grabbing the visible item must keep the same identity.');
        // Re-grab while the neighbor is still moving through this cell. A second pointer remains
        // down for only one frame here; the next iteration exercises a complete long press.
        final regrab = await tester.startGesture(targetStart + const Offset(40, 40));
        await tester.pump(const Duration(milliseconds: 16));
        await regrab.cancel();
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(harness.configuration, original);
      expect(harness.cellDrops, hasLength(8));
      await tester.pumpWidget(const SizedBox());
    });

    for (final outside in [const Offset(-20, 886), const Offset(434, 886), const Offset(207, 920)]) {
      testWidgets('drag outside viewport at $outside $branch stops edge auto-scroll', (tester) async {
        final harness = await _pumpGrid(tester, withMenus: withMenus);
        final gesture = await _holdAndMove(tester, 'shortcut:receive', outside);
        await tester.pump(const Duration(milliseconds: 600));
        expect(harness.scrollController.offset, 0, reason: 'Outside a scroll viewport is not an active edge zone.');
        await gesture.cancel();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('inside bottom edge $branch still auto-scrolls and stops when crossing the side', (tester) async {
      final harness = await _pumpGrid(tester, withMenus: withMenus);
      final gesture = await _holdAndMove(tester, 'shortcut:receive', const Offset(207, 880));
      await tester.pump(const Duration(milliseconds: 300));
      expect(harness.scrollController.offset, greaterThan(0));
      final offset = harness.scrollController.offset;
      await gesture.moveTo(const Offset(-1, 880));
      await tester.pump(const Duration(milliseconds: 300));
      expect(harness.scrollController.offset, offset);
      await gesture.cancel();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('far shortcut drag $branch shifts the sequence and keeps large widgets still', (tester) async {
      final harness = await _pumpGrid(tester, withMenus: withMenus);
      final before = harness.configuration;
      final slots = _savedPositions(before);
      final gesture = await _holdAndMove(
        tester,
        'shortcut:receive',
        tester.getCenter(_item('shortcut:utxo_organizer')),
      );
      await _settleHover(tester);
      final preview = _paintedPositions(tester);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_savedPositions(harness.configuration), {
        ...slots,
        'shortcut:send': slots['shortcut:receive'],
        'shortcut:hodl_insights': slots['shortcut:send'],
        'shortcut:utxo_organizer': slots['shortcut:hodl_insights'],
        'shortcut:receive': slots['shortcut:utxo_organizer'],
      });
      expect(_paintedPositions(tester), preview);
      await tester.pumpWidget(const SizedBox());
    });

    for (final waitMs in [16, 260]) {
      testWidgets('sparse gap zigzag and corner crossing at ${waitMs}ms $branch cancels without saving', (
        tester,
      ) async {
        final original = _mixedHome().removeItem('fiat_price_trend_2x2');
        final harness = await _pumpGrid(tester, withMenus: withMenus, initialConfiguration: original);
        const source = 'all_wallet_stack';
        final sourceCenter = tester.getCenter(_item(source));
        final surface = tester.getRect(find.byKey(const ValueKey('home-grid-surface')));
        final emptyCenter = sourceCenter + const Offset(0, 184);
        final gesture = await tester.startGesture(sourceCenter);
        await tester.pump(const Duration(milliseconds: 600));
        for (var round = 0; round < 4; round++) {
          for (final point in [
            emptyCenter,
            emptyCenter + const Offset(92, 0),
            sourceCenter,
            Offset(surface.left - 1, surface.top - 1),
            Offset(surface.right + 1, surface.top),
            emptyCenter,
            sourceCenter,
          ]) {
            await gesture.moveTo(point);
            await tester.pump(Duration(milliseconds: waitMs));
            expect(harness.configuration, original, reason: 'A fast or slow hover must never save.');
            expect(harness.cellDrops, isEmpty);
            expect(tester.takeException(), isNull);
          }
        }
        await gesture.cancel();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(harness.configuration, original);
        expect(_paintedPositions(tester, original), _cellOrigins(surface.topLeft, _savedPositions(original)));
        expect(harness.cellDrops, isEmpty);
        await tester.pumpWidget(const SizedBox());
      });
    }

    for (final move in [
      (source: 0, target: 1, displaced: 2, vacated: 0),
      (source: 2, target: 1, displaced: 1, vacated: 3),
      (source: 1, target: 0, displaced: 0, vacated: 2),
      (source: 1, target: 2, displaced: 3, vacated: 1),
    ]) {
      for (final ending in ['hover drop', 'quick drop', 'cancel']) {
        testWidgets('2×2 column ${move.source} → ${move.target} $ending $branch preserves the other column and rows', (
          tester,
        ) async {
          final original = _smallWidgetAndShortcutColumns(move.source);
          final harness = await _pumpGrid(tester, withMenus: withMenus, initialConfiguration: original);
          final surface = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface')));
          final originalPositions = _savedPositions(original);
          final originalPainted = _cellOrigins(surface, originalPositions);
          expect(
            _paintedPositions(tester, original),
            originalPainted,
            reason: 'The saved center column must render as-is.',
          );
          final expectedPositions = {
            ...originalPositions,
            'all_wallet_stack': HomeGridPosition(move.target, 2),
            'shortcut:${move.displaced}:2': HomeGridPosition(move.vacated, 2),
            'shortcut:${move.displaced}:3': HomeGridPosition(move.vacated, 3),
          };
          final expectedPainted = _cellOrigins(surface, expectedPositions);
          final sourceSize = tester.getSize(_item('all_wallet_stack'));
          final destination = expectedPainted['all_wallet_stack']! + sourceSize.center(Offset.zero);
          final gesture = await _holdAndMove(tester, 'all_wallet_stack', destination);

          if (ending != 'quick drop') {
            await _settleHover(tester);
            expect(
              _paintedPositions(tester, original),
              expectedPainted,
              reason: 'Only the widget and the two shortcuts in its target column may move.',
            );
            _expectSingleDragCopy(tester, 'all_wallet_stack', sourceSize);
            expect(harness.configuration, original, reason: 'A preview must not change the saved configuration.');
            expect(harness.cellDrops, isEmpty);
            expect(harness.insertionDrops, isEmpty);
          }

          if (ending == 'cancel') {
            await gesture.cancel();
          } else {
            await gesture.up();
          }
          await tester.pump();
          // A quick release commits in the first frame's post-frame callback.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          final committedPositions = ending == 'cancel' ? originalPositions : expectedPositions;
          final committedPainted = ending == 'cancel' ? originalPainted : expectedPainted;
          expect(_savedPositions(harness.configuration), committedPositions);
          expect(_paintedPositions(tester, original), committedPainted);
          expect(
            harness.cellDrops,
            ending == 'cancel' ? isEmpty : [('all_wallet_stack', HomeGridPosition(move.target, 2))],
          );
          expect(harness.insertionDrops, isEmpty);
          expect(find.text('item:all_wallet_stack'), findsOneWidget);

          final restored = HomeConfiguration.fromJson(jsonDecode(jsonEncode(harness.configuration.toJson())))!;
          final expected = HomeConfiguration(
            version: original.version,
            shortcutWalletContext: original.shortcutWalletContext,
            items: [for (final item in original.items) item.copyWith(position: committedPositions[item.id])],
          );
          expect(restored, expected, reason: 'JSON must preserve positions, item order, metadata and wallet context.');
          await tester.pumpWidget(const SizedBox());
          await _pumpGrid(tester, withMenus: withMenus, initialConfiguration: restored);
          expect(
            _paintedPositions(tester, restored),
            committedPainted,
            reason: 'Reloading must preserve the center column.',
          );
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    for (final (source, target) in [('shortcut:receive', 'shortcut:send'), ('shortcut:send', 'shortcut:receive')]) {
      testWidgets('$source → $target $branch previews and commits only the adjacent pair', (tester) async {
        final harness = await _pumpGrid(tester, withMenus: withMenus);
        final originalConfiguration = harness.configuration;
        final originalPositions = _paintedPositions(tester);
        final expectedPositions = _swapped(originalPositions, source, target);
        final originalSize = tester.getSize(_item(source));
        final gesture = await _holdAndMove(tester, source, tester.getCenter(_item(target)));
        await tester.pump();

        _expectSingleDragCopy(tester, source, originalSize);
        await tester.pump(const Duration(milliseconds: 80));
        expect(_paintedPositions(tester), originalPositions, reason: 'Passing briefly must not move neighbors.');
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 140));
        final moving = tester.getTopLeft(_item(target));
        final start = originalPositions[target]!;
        final end = expectedPositions[target]!;
        expect(moving.dx, greaterThan(start.dx < end.dx ? start.dx : end.dx));
        expect(moving.dx, lessThan(start.dx > end.dx ? start.dx : end.dx));
        for (final id in originalPositions.keys.where((id) => id != source && id != target)) {
          expect(tester.getTopLeft(_item(id)), originalPositions[id], reason: '$id must not move during preview.');
        }
        _expectSingleDragCopy(tester, source, originalSize);
        await tester.pump(const Duration(milliseconds: 160));

        expect(_paintedPositions(tester), expectedPositions);
        expect(harness.configuration, originalConfiguration, reason: 'A hover must not save the preview.');
        expect(harness.cellDrops, isEmpty);
        expect(harness.insertionDrops, isEmpty);
        _expectSingleDragCopy(tester, source, originalSize);

        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(harness.cellDrops, [(source, _savedPositions(originalConfiguration)[target]!)]);
        expect(harness.insertionDrops, isEmpty, reason: 'A cell drop takes precedence when both callbacks exist.');
        expect(
          _savedPositions(harness.configuration),
          _swapped(_savedPositions(originalConfiguration), source, target),
        );
        expect(_paintedPositions(tester), expectedPositions, reason: 'The committed layout must match its preview.');
        expect(find.text('item:$source'), findsOneWidget);
        expect(find.descendant(of: _item(source), matching: find.text('item:$source')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('a quick $source → $target release $branch uses the same cell policy exactly once', (tester) async {
        final harness = await _pumpGrid(tester, withMenus: withMenus);
        final originalConfiguration = harness.configuration;
        final originalPositions = _paintedPositions(tester);
        final gesture = await _holdAndMove(tester, source, tester.getCenter(_item(target)));
        // Release before the first drag frame and before the preview timer fires.
        await gesture.up();
        await tester.pump();
        expect(harness.cellDrops, [(source, _savedPositions(originalConfiguration)[target]!)]);
        expect(harness.insertionDrops, isEmpty);
        expect(
          _savedPositions(harness.configuration),
          _swapped(_savedPositions(originalConfiguration), source, target),
        );

        // The pending release saves in a post-frame callback; build that state before advancing its animation.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 140));
        final moving = tester.getTopLeft(_item(target));
        final start = originalPositions[target]!;
        final end = originalPositions[source]!;
        expect(moving.dx, greaterThan(start.dx < end.dx ? start.dx : end.dx));
        expect(moving.dx, lessThan(start.dx > end.dx ? start.dx : end.dx));
        for (final id in originalPositions.keys.where((id) => id != source && id != target)) {
          expect(tester.getTopLeft(_item(id)), originalPositions[id], reason: '$id must not move after a quick drop.');
        }
        await tester.pump(const Duration(milliseconds: 160));
        expect(_paintedPositions(tester), _swapped(originalPositions, source, target));
        expect(find.text('item:$source'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 500));
        expect(harness.cellDrops, hasLength(1), reason: 'A delayed hover or release must not save twice.');
        await tester.pumpWidget(const SizedBox());
      });
    }

    for (final (source, target) in [
      ('all_wallet_stack', 'fiat_price_trend_2x2'),
      ('fiat_price_trend_2x2', 'all_wallet_stack'),
    ]) {
      testWidgets('a slow $source → $target round trip $branch never creates an intermediate row', (tester) async {
        final harness = await _pumpGrid(tester, withMenus: withMenus);
        final originalConfiguration = harness.configuration;
        final originalPositions = _paintedPositions(tester);
        final swappedPositions = _swapped(originalPositions, source, target);
        final sourceRect = tester.getRect(_item(source));
        final stops = _verticalStops(sourceRect, tester.getRect(_item(target)));
        final gesture = await tester.startGesture(sourceRect.center);
        await tester.pump(const Duration(milliseconds: 600));

        for (final stop in [...stops, ...stops.reversed]) {
          await gesture.moveTo(stop.point);
          await _settleHover(tester);
          expect(
            _paintedPositions(tester),
            stop.swapped == null
                ? anyOf(equals(originalPositions), equals(swappedPositions))
                : stop.swapped!
                ? swappedPositions
                : originalPositions,
            reason: '${stop.label}: only the original layout or the adjacent pair swap may be previewed.',
          );
          expect(harness.configuration, originalConfiguration, reason: '${stop.label}: preview must not save.');
          expect(harness.cellDrops, isEmpty);
          expect(harness.insertionDrops, isEmpty);
          _expectSingleDragCopy(tester, source, sourceRect.size);
        }

        await gesture.moveTo(sourceRect.center);
        await _settleHover(tester);
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(_paintedPositions(tester), originalPositions);
        expect(harness.configuration, originalConfiguration);
        expect(harness.insertionDrops, isEmpty);
        expect(harness.cellDrops.length, lessThanOrEqualTo(1));
        for (final drop in harness.cellDrops) {
          expect(drop, (source, _savedPositions(originalConfiguration)[source]!));
        }
        expect(find.text('item:$source'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });

      for (final stopLabel in ['30% inside source', 'source half of gap']) {
        testWidgets('releasing $source at $stopLabel toward $target $branch keeps the whole layout', (tester) async {
          final harness = await _pumpGrid(tester, withMenus: withMenus);
          final originalConfiguration = harness.configuration;
          final originalPositions = _paintedPositions(tester);
          final sourceRect = tester.getRect(_item(source));
          final stop = _verticalStops(
            sourceRect,
            tester.getRect(_item(target)),
          ).singleWhere((s) => s.label == stopLabel);
          final gesture = await _holdAndMove(tester, source, stop.point);
          await _settleHover(tester);
          expect(
            _paintedPositions(tester),
            originalPositions,
            reason: 'The hover must not create an intermediate row.',
          );
          expect(harness.configuration, originalConfiguration);
          expect(harness.cellDrops, isEmpty);

          await gesture.up();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(_paintedPositions(tester), originalPositions);
          expect(harness.configuration, originalConfiguration);
          expect(harness.insertionDrops, isEmpty);
          expect(harness.cellDrops.length, lessThanOrEqualTo(1));
          for (final drop in harness.cellDrops) {
            expect(drop, (source, _savedPositions(originalConfiguration)[source]!));
          }
          await tester.pumpWidget(const SizedBox());
        });
      }

      testWidgets('a quick $source release in the $target half of the gap $branch swaps only the pair', (tester) async {
        final harness = await _pumpGrid(tester, withMenus: withMenus);
        final originalConfiguration = harness.configuration;
        final originalPositions = _paintedPositions(tester);
        final stop = _verticalStops(
          tester.getRect(_item(source)),
          tester.getRect(_item(target)),
        ).singleWhere((s) => s.label == 'target half of gap');
        final gesture = await _holdAndMove(tester, source, stop.point);
        await gesture.up();
        await tester.pump();
        expect(harness.cellDrops, [(source, _savedPositions(originalConfiguration)[target]!)]);
        expect(harness.insertionDrops, isEmpty);
        expect(
          _savedPositions(harness.configuration),
          _swapped(_savedPositions(originalConfiguration), source, target),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(_paintedPositions(tester), _swapped(originalPositions, source, target));
        await tester.pump(const Duration(milliseconds: 500));
        expect(harness.cellDrops, hasLength(1));
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('leaving the source region for a genuinely empty 2×2 cell $branch still previews and saves', (
      tester,
    ) async {
      final harness = await _pumpGrid(tester, withMenus: withMenus);
      const source = 'all_wallet_stack';
      const destination = HomeGridPosition(0, 8);
      final originalConfiguration = harness.configuration;
      final originalPositions = _paintedPositions(tester);
      final surface = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface')));
      final destinationOrigin = surface + const Offset(0, 8 * (HomeItemsView.cell + HomeItemsView.gap));
      final sourceSize = tester.getSize(_item(source));
      final expectedPositions = {...originalPositions, source: destinationOrigin};
      final gesture = await _holdAndMove(tester, source, destinationOrigin + sourceSize.center(Offset.zero));
      await _settleHover(tester);
      expect(_paintedPositions(tester), expectedPositions);
      expect(harness.configuration, originalConfiguration);
      expect(harness.cellDrops, isEmpty);
      _expectSingleDragCopy(tester, source, sourceSize);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(harness.cellDrops, [(source, destination)]);
      expect(harness.insertionDrops, isEmpty);
      expect(_savedPositions(harness.configuration), {..._savedPositions(originalConfiguration), source: destination});
      expect(_paintedPositions(tester), expectedPositions);
      await tester.pumpWidget(const SizedBox());
    });

    for (final cancelThroughBack in [false, true]) {
      final cancel = cancelThroughBack ? 'Back cancellation and a late release' : 'pointer cancellation';
      testWidgets('$cancel $branch restores all nine positions without saving', (tester) async {
        final harness = await _pumpGrid(tester, withMenus: withMenus);
        final originalConfiguration = harness.configuration;
        final originalPositions = _paintedPositions(tester);
        const source = 'shortcut:receive';
        const target = 'shortcut:send';
        final originalSize = tester.getSize(_item(source));
        final gesture = await _holdAndMove(tester, source, tester.getCenter(_item(target)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 300));
        expect(_paintedPositions(tester), _swapped(originalPositions, source, target));
        _expectSingleDragCopy(tester, source, originalSize);

        if (cancelThroughBack) {
          expect(harness.gridKey.currentState!.cancelActiveDrag(), isTrue);
          await tester.pump();
          await gesture.up();
        } else {
          await gesture.cancel();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(harness.configuration, originalConfiguration);
        expect(harness.cellDrops, isEmpty);
        expect(harness.insertionDrops, isEmpty);
        expect(_paintedPositions(tester), originalPositions);
        expect(find.text('item:$source'), findsOneWidget);
        expect(find.descendant(of: _item(source), matching: find.text('item:$source')), findsOneWidget);
        expect(harness.gridKey.currentState!.cancelActiveDrag(), isFalse);
        expect(harness.arranging, isTrue, reason: 'Canceling the held gesture must preserve edit mode.');
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
