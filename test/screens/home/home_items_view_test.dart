import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';

class _LabelDefinition extends HomeItemDefinition {
  _LabelDefinition(String id, HomeItemKind kind, HomeSpan span)
    : super(id: id, kind: kind, supportedSpans: [span], category: HomeItemCategory.wallets);

  @override
  Widget build(BuildContext context, HomeItem item) => Text('built:$id');
}

HomeItem _item(String id, String definitionId, HomeItemKind kind, int order, HomeSpan span) {
  return HomeItem(id: id, definitionId: definitionId, kind: kind, order: order, span: span);
}

void main() {
  testWidgets('a 4×2 can drop between a full shortcut row and a single shortcut row', (tester) async {
    HomeGridPosition? target;
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('shortcut', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('small', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('wide', HomeItemKind.widget, HomeSpan.wide));
    final configuration = HomeConfiguration(
      items: [
        for (var column = 0; column < 4; column++)
          HomeItem(
            id: 'top-$column',
            definitionId: 'shortcut',
            kind: HomeItemKind.shortcut,
            order: column,
            span: HomeSpan.shortcut,
            position: HomeGridPosition(column, 0),
          ),
        const HomeItem(
          id: 'single',
          definitionId: 'shortcut',
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
          id: 'wide',
          definitionId: 'wide',
          kind: HomeItemKind.widget,
          order: 6,
          span: HomeSpan.wide,
          position: HomeGridPosition(0, 4),
        ),
      ],
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: configuration,
              registry: registry,
              onMoveToCell: (_, position) => target = position,
            ),
          ),
        ),
      ),
    );

    final blankCell =
        tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface'))) +
        const Offset(
          3 * (HomeItemsView.cell + HomeItemsView.gap) + HomeItemsView.cell / 2,
          HomeItemsView.cell + HomeItemsView.gap + HomeItemsView.cell / 2,
        );
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-wide'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(blankCell);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(target, const HomeGridPosition(0, 1));
  });

  testWidgets('a saved empty row between a full shortcut row and a 4×2 stays visible', (tester) async {
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('small', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('shortcut', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('wide', HomeItemKind.widget, HomeSpan.wide));
    final configuration = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'small-left',
          definitionId: 'small',
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 0),
        ),
        const HomeItem(
          id: 'small-right',
          definitionId: 'small',
          kind: HomeItemKind.widget,
          order: 1,
          span: HomeSpan.small,
          position: HomeGridPosition(2, 0),
        ),
        for (var column = 0; column < 4; column++)
          HomeItem(
            id: 'shortcut-$column',
            definitionId: 'shortcut',
            kind: HomeItemKind.shortcut,
            order: column + 2,
            span: HomeSpan.shortcut,
            position: HomeGridPosition(column, 2),
          ),
        const HomeItem(
          id: 'wide',
          definitionId: 'wide',
          kind: HomeItemKind.widget,
          order: 6,
          span: HomeSpan.wide,
          position: HomeGridPosition(0, 4),
        ),
      ],
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(configuration: configuration, registry: registry),
          ),
        ),
      ),
    );

    final shortcutRects = [
      for (var column = 0; column < 4; column++) tester.getRect(find.byKey(ValueKey('home-item-shortcut-$column'))),
    ];
    expect(shortcutRects.map((rect) => rect.top).toSet(), hasLength(1));
    final wide = tester.getRect(find.byKey(const ValueKey('home-item-wide')));
    expect(wide.top - shortcutRects.first.bottom, closeTo(HomeItemsView.cell + 2 * HomeItemsView.gap, 0.01));
  });

  testWidgets('a 4×2 can drop on the empty cell below the shortcuts in the next band', (tester) async {
    HomeGridPosition? droppedAt;
    String? insertedBefore;
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('wide', HomeItemKind.widget, HomeSpan.wide))
          ..register(_LabelDefinition('small', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('receive', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('wallet-detail', HomeItemKind.shortcut, HomeSpan.shortcut));
    final configuration = HomeConfiguration(
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
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: configuration,
              registry: registry,
              onMoveToCell: (_, position) => droppedAt = position,
              onInsertBefore: (_, id) => insertedBefore = id,
            ),
          ),
        ),
      ),
    );

    final cellCenter =
        tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface'))) +
        const Offset(
          3 * (HomeItemsView.cell + HomeItemsView.gap) + HomeItemsView.cell / 2,
          3 * (HomeItemsView.cell + HomeItemsView.gap) + HomeItemsView.cell / 2,
        );
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-wide'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(cellCenter);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(droppedAt, const HomeGridPosition(0, 2));
    expect(insertedBefore, isNull);
    final moved = HomeGridLayout(configuration).moveToCell('wide', droppedAt!);
    final layout = HomeGridLayout(moved);
    expect(layout.positionOf('small'), const HomeGridPosition(0, 0));
    expect(layout.positionOf('receive'), const HomeGridPosition(2, 0));
    expect(layout.positionOf('wallet-detail'), const HomeGridPosition(3, 0));
    expect(layout.positionOf('wide'), const HomeGridPosition(0, 2));
  });

  testWidgets('a 1×1 shortcut does not highlight as a 4×2 landing cell', (tester) async {
    HomeGridPosition? droppedAt;
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('wide', HomeItemKind.widget, HomeSpan.wide))
          ..register(_LabelDefinition('shortcut', HomeItemKind.shortcut, HomeSpan.shortcut));
    final configuration = HomeConfiguration(
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
          id: 'shortcut',
          definitionId: 'shortcut',
          kind: HomeItemKind.shortcut,
          order: 1,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(2, 2),
        ),
      ],
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: configuration,
              registry: registry,
              onMoveToCell: (_, position) => droppedAt = position,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-wide'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('home-item-shortcut'))));
    await tester.pump();

    final decorations = tester.widgetList<DecoratedBox>(
      find.descendant(of: find.byKey(const ValueKey('home-item-shortcut')), matching: find.byType(DecoratedBox)),
    );
    expect(
      decorations.where((box) {
        final decoration = box.decoration;
        return decoration is BoxDecoration && decoration.border != null;
      }),
      isEmpty,
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(droppedAt, const HomeGridPosition(0, 2));
  });

  testWidgets('grid has equal left and right spacing when the viewport is wider than four capped cells', (
    tester,
  ) async {
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('left', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('right', HomeItemKind.shortcut, HomeSpan.shortcut));
    final configuration = HomeConfiguration(
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
      ],
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            key: const ValueKey('grid-container'),
            width: 400,
            child: HomeItemsView(configuration: configuration, registry: registry),
          ),
        ),
      ),
    );

    final container = tester.getRect(find.byKey(const ValueKey('grid-container')));
    final left = tester.getRect(find.byKey(const ValueKey('home-item-left')));
    final right = tester.getRect(find.byKey(const ValueKey('home-item-right')));
    expect(left.left - container.left, closeTo(container.right - right.right, 0.01));
  });

  testWidgets('home items are drawn without an outline', (tester) async {
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('widget', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('shortcut:receive', HomeItemKind.shortcut, HomeSpan.shortcut));
    final configuration = HomeConfiguration(
      items: [
        _item('widget', 'widget', HomeItemKind.widget, 0, HomeSpan.small),
        _item('shortcut', 'shortcut:receive', HomeItemKind.shortcut, 1, HomeSpan.shortcut),
      ],
    );

    await tester.pumpWidget(CupertinoApp(home: HomeItemsView(configuration: configuration, registry: registry)));

    expect(find.byKey(const ValueKey('home-item-outline-widget')), findsNothing);
    expect(find.byKey(const ValueKey('home-item-outline-shortcut')), findsNothing);
  });

  testWidgets('a 4×2 item fits a narrow home viewport', (tester) async {
    final registry = HomeItemRegistry()..register(_LabelDefinition('wide', HomeItemKind.widget, HomeSpan.wide));
    final configuration = HomeConfiguration(items: [_item('wide', 'wide', HomeItemKind.widget, 0, HomeSpan.wide)]);
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(width: 328, child: HomeItemsView(configuration: configuration, registry: registry)),
        ),
      ),
    );

    final item = find.byKey(const ValueKey('home-item-wide'));
    expect(tester.getSize(item).width, 328);
    expect(tester.getSize(item).height, 2 * ((328 - 3 * HomeItemsView.gap) / 4) + HomeItemsView.gap);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders every item whose definition is registered, in order', (tester) async {
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('widget', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('shortcut:receive', HomeItemKind.shortcut, HomeSpan.shortcut));
    final configuration = HomeConfiguration(
      items: [
        _item('b', 'shortcut:receive', HomeItemKind.shortcut, 1, HomeSpan.shortcut),
        _item('a', 'widget', HomeItemKind.widget, 0, HomeSpan.small),
      ],
    );

    await tester.pumpWidget(CupertinoApp(home: HomeItemsView(configuration: configuration, registry: registry)));

    expect(find.text('built:widget'), findsOneWidget);
    expect(find.text('built:shortcut:receive'), findsOneWidget);
    final widgetTop = tester.getTopLeft(find.text('built:widget'));
    final shortcutTop = tester.getTopLeft(find.text('built:shortcut:receive'));
    expect(widgetTop.dx <= shortcutTop.dx || widgetTop.dy < shortcutTop.dy, isTrue);
  });

  testWidgets('items whose definition is not registered are skipped without error', (tester) async {
    final configuration = HomeConfiguration(
      items: [_item('x', HomeItemIds.safetyStatusWide, HomeItemKind.widget, 0, HomeSpan.wide)],
    );

    await tester.pumpWidget(
      CupertinoApp(home: HomeItemsView(configuration: configuration, registry: HomeItemRegistry())),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('an item takes the size of its span (2×2 is twice a 1×1 cell plus one gap)', (tester) async {
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('widget', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('shortcut:receive', HomeItemKind.shortcut, HomeSpan.shortcut));
    final configuration = HomeConfiguration(
      items: [
        _item('widget', 'widget', HomeItemKind.widget, 0, HomeSpan.small),
        _item('shortcut', 'shortcut:receive', HomeItemKind.shortcut, 1, HomeSpan.shortcut),
      ],
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(configuration: configuration, registry: registry),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('home-item-shortcut'))), const Size(80, 80));
    expect(
      tester.getSize(find.byKey(const ValueKey('home-item-widget'))),
      const Size(2 * HomeItemsView.cell + HomeItemsView.gap, 2 * HomeItemsView.cell + HomeItemsView.gap),
    );
  });

  HomeConfiguration threeItems() => HomeConfiguration(
    items: [
      _item('a', 'w1', HomeItemKind.widget, 0, HomeSpan.small),
      _item('b', 'w2', HomeItemKind.widget, 1, HomeSpan.small),
      _item('c', 'w3', HomeItemKind.widget, 2, HomeSpan.small),
    ],
  );

  HomeItemRegistry threeRegistry() =>
      HomeItemRegistry()
        ..register(_LabelDefinition('w1', HomeItemKind.widget, HomeSpan.small))
        ..register(_LabelDefinition('w2', HomeItemKind.widget, HomeSpan.small))
        ..register(_LabelDefinition('w3', HomeItemKind.widget, HomeSpan.small));

  testWidgets('long-press dragging an item onto another inserts it before the target', (tester) async {
    String? movedId;
    String? beforeId;
    await tester.pumpWidget(
      CupertinoApp(
        home: SingleChildScrollView(
          child: HomeItemsView(
            configuration: threeItems(),
            registry: threeRegistry(),
            onInsertBefore: (id, target) {
              movedId = id;
              beforeId = target;
            },
          ),
        ),
      ),
    );

    final from = tester.getCenter(find.byKey(const ValueKey('home-item-c')));
    final to = tester.getCenter(find.byKey(const ValueKey('home-item-a')));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedId, 'c');
    expect(beforeId, 'a');
  });

  testWidgets('the empty 1×1 space before a wrapping 2×2 accepts a shortcut', (tester) async {
    String? movedId;
    HomeGridPosition? target;
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('large-a', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('shortcut', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('large-b', HomeItemKind.widget, HomeSpan.small));
    final configuration = HomeConfiguration(
      items: [
        _item('a', 'large-a', HomeItemKind.widget, 0, HomeSpan.small),
        _item('s', 'shortcut', HomeItemKind.shortcut, 1, HomeSpan.shortcut),
        _item('b', 'large-b', HomeItemKind.widget, 2, HomeSpan.small),
      ],
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: configuration,
              registry: registry,
              onMoveToCell: (id, position) {
                movedId = id;
                target = position;
              },
            ),
          ),
        ),
      ),
    );

    final dropPoint = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface'))) + const Offset(316, 40);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-s'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(dropPoint);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedId, 's');
    expect(target, const HomeGridPosition(3, 0));
  });

  testWidgets('a shortcut can drop below another shortcut without moving the next 2×2 widget', (tester) async {
    String? movedId;
    HomeGridPosition? target;
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('large-a', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('shortcut-a', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('shortcut-b', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('large-b', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('shortcut-new', HomeItemKind.shortcut, HomeSpan.shortcut));
    final configuration = HomeConfiguration(
      items: [
        _item('a', 'large-a', HomeItemKind.widget, 0, HomeSpan.small),
        _item('s1', 'shortcut-a', HomeItemKind.shortcut, 1, HomeSpan.shortcut),
        _item('s2', 'shortcut-b', HomeItemKind.shortcut, 2, HomeSpan.shortcut),
        _item('b', 'large-b', HomeItemKind.widget, 3, HomeSpan.small),
        _item('new', 'shortcut-new', HomeItemKind.shortcut, 4, HomeSpan.shortcut),
      ],
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: configuration,
              registry: registry,
              onMoveToCell: (id, cell) {
                movedId = id;
                target = cell;
              },
            ),
          ),
        ),
      ),
    );

    final dropPoint = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface'))) + const Offset(224, 132);
    final largeBefore = tester.getTopLeft(find.byKey(const ValueKey('home-item-b')));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-new'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(dropPoint);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedId, 'new');
    expect(target, const HomeGridPosition(2, 1));
    expect(tester.getTopLeft(find.byKey(const ValueKey('home-item-b'))), largeBefore);
  });

  testWidgets('a 2×2 widget can drop into a free 2×2 region', (tester) async {
    HomeGridPosition? target;
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('large-a', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('large-b', HomeItemKind.widget, HomeSpan.small));
    final configuration = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'a',
          definitionId: 'large-a',
          kind: HomeItemKind.widget,
          order: 0,
          span: HomeSpan.small,
          position: HomeGridPosition(2, 0),
        ),
        const HomeItem(
          id: 'b',
          definitionId: 'large-b',
          kind: HomeItemKind.widget,
          order: 1,
          span: HomeSpan.small,
          position: HomeGridPosition(0, 2),
        ),
      ],
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: configuration,
              registry: registry,
              onMoveToCell: (_, position) => target = position,
            ),
          ),
        ),
      ),
    );

    final dropPoint = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface'))) + const Offset(86, 86);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-b'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(dropPoint);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(target, const HomeGridPosition(0, 0));
  });

  testWidgets('a 2×2 widget snaps to an even column between two 1×1 shortcuts', (tester) async {
    HomeGridPosition? target;
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('left', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('right', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('middle', HomeItemKind.widget, HomeSpan.small));
    final configuration = HomeConfiguration(
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
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: configuration,
              registry: registry,
              onMoveToCell: (_, position) => target = position,
            ),
          ),
        ),
      ),
    );

    final middleCenter = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface'))) + const Offset(178, 86);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-middle'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(middleCenter);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(target, const HomeGridPosition(2, 0));
  });

  testWidgets('a 4×2 widget drops into row zero from its empty side cell', (tester) async {
    HomeGridPosition? target;
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('small', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('shortcut', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('wide', HomeItemKind.widget, HomeSpan.wide));
    final configuration = HomeConfiguration(
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
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: configuration,
              registry: registry,
              onMoveToCell: (_, position) => target = position,
            ),
          ),
        ),
      ),
    );

    final emptySide = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface'))) + const Offset(316, 40);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-wide'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(emptySide);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(target, const HomeGridPosition(0, 0));
  });

  testWidgets('a wide widget moves ahead when its preview just touches the row above', (tester) async {
    HomeGridPosition? target;
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('small', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('shortcut', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('wide', HomeItemKind.widget, HomeSpan.wide));
    final configuration = HomeConfiguration(
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
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: configuration,
              registry: registry,
              onMoveToCell: (_, position) => target = position,
            ),
          ),
        ),
      ),
    );

    final previewTouchesTopRow =
        tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface'))) + const Offset(178, 246);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-wide'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(previewTouchesTopRow);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(target, const HomeGridPosition(0, 0));
  });

  testWidgets('a wide widget dropped over a shortcut moves ahead of that whole row', (tester) async {
    HomeGridPosition? target;
    String? beforeId;
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('small', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('shortcut', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('wide', HomeItemKind.widget, HomeSpan.wide));
    final configuration = HomeConfiguration(
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
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: configuration,
              registry: registry,
              onMoveToCell: (_, position) => target = position,
              onInsertBefore: (_, id) => beforeId = id,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-wide'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('home-item-shortcut'))));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(target, const HomeGridPosition(0, 0));
    expect(beforeId, isNull);
  });

  for (final targetCell in const [HomeGridPosition(3, 0), HomeGridPosition(2, 1), HomeGridPosition(3, 1)]) {
    testWidgets('the last shortcut can drop into blank cell ${targetCell.column},${targetCell.row}', (tester) async {
      HomeGridPosition? droppedAt;
      String? insertedBefore;
      final registry =
          HomeItemRegistry()
            ..register(_LabelDefinition('small', HomeItemKind.widget, HomeSpan.small))
            ..register(_LabelDefinition('shortcut-a', HomeItemKind.shortcut, HomeSpan.shortcut))
            ..register(_LabelDefinition('wide', HomeItemKind.widget, HomeSpan.wide))
            ..register(_LabelDefinition('shortcut-b', HomeItemKind.shortcut, HomeSpan.shortcut));
      final configuration = HomeConfiguration(
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
            definitionId: 'shortcut-a',
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
            definitionId: 'shortcut-b',
            kind: HomeItemKind.shortcut,
            order: 3,
            span: HomeSpan.shortcut,
            position: HomeGridPosition(0, 4),
          ),
        ],
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: SizedBox(
              width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
              child: HomeItemsView(
                configuration: configuration,
                registry: registry,
                onMoveToCell: (_, position) => droppedAt = position,
                onInsertBefore: (_, id) => insertedBefore = id,
              ),
            ),
          ),
        ),
      );

      final cellCenter =
          tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface'))) +
          Offset(
            targetCell.column * (HomeItemsView.cell + HomeItemsView.gap) + HomeItemsView.cell / 2,
            targetCell.row * (HomeItemsView.cell + HomeItemsView.gap) + HomeItemsView.cell / 2,
          );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('home-item-last-shortcut'))),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(cellCenter);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(droppedAt, targetCell);
      expect(insertedBefore, isNull);
    });
  }

  testWidgets('dropping the last shortcut onto the first 2×2 inserts it before that widget', (tester) async {
    String? movedId;
    String? beforeId;
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('small', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('shortcut-a', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('wide', HomeItemKind.widget, HomeSpan.wide))
          ..register(_LabelDefinition('shortcut-b', HomeItemKind.shortcut, HomeSpan.shortcut));
    final configuration = HomeConfiguration(
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
          definitionId: 'shortcut-a',
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
          definitionId: 'shortcut-b',
          kind: HomeItemKind.shortcut,
          order: 3,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 4),
        ),
      ],
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: SingleChildScrollView(
          child: HomeItemsView(
            configuration: configuration,
            registry: registry,
            onInsertBefore: (id, target) {
              movedId = id;
              beforeId = target;
            },
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-last-shortcut'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('home-item-small'))));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedId, 'last-shortcut');
    expect(beforeId, 'small');
  });

  testWidgets('a 1×1 shortcut can occupy an odd-numbered empty column', (tester) async {
    HomeGridPosition? target;
    final registry =
        HomeItemRegistry()..register(_LabelDefinition('shortcut', HomeItemKind.shortcut, HomeSpan.shortcut));
    final configuration = HomeConfiguration(
      items: [
        const HomeItem(
          id: 'shortcut',
          definitionId: 'shortcut',
          kind: HomeItemKind.shortcut,
          order: 0,
          span: HomeSpan.shortcut,
          position: HomeGridPosition(0, 2),
        ),
      ],
    );
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: configuration,
              registry: registry,
              onMoveToCell: (_, position) => target = position,
            ),
          ),
        ),
      ),
    );

    final oddColumn = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface'))) + const Offset(132, 40);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-shortcut'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(oddColumn);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(target, const HomeGridPosition(1, 0));
  });

  testWidgets('dragging over an item previews the positions after insertion without a highlight', (tester) async {
    final configuration = threeItems();
    String? insertedBefore;
    await tester.pumpWidget(
      CupertinoApp(
        home: SingleChildScrollView(
          child: HomeItemsView(
            configuration: configuration,
            registry: threeRegistry(),
            onInsertBefore: (_, id) => insertedBefore = id,
          ),
        ),
      ),
    );
    final originalA = tester.getTopLeft(find.byKey(const ValueKey('home-item-a')));
    final originalB = tester.getTopLeft(find.byKey(const ValueKey('home-item-b')));
    final target = tester.getCenter(find.byKey(const ValueKey('home-item-a')));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-c'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(insertedBefore, isNull);
    final tweenA = tester.widget<TweenAnimationBuilder<Offset>>(
      find.ancestor(
        of: find.byKey(const ValueKey('home-item-a')),
        matching: find.byType(TweenAnimationBuilder<Offset>),
      ),
    );
    expect(tweenA.tween.end, const Offset(184, 0));
    expect(tester.getTopLeft(find.byKey(const ValueKey('home-item-a'))), originalB);
    expect(tester.getTopLeft(find.byKey(const ValueKey('home-item-b'))).dy, greaterThan(originalA.dy));
    final borders = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((box) {
      final decoration = box.decoration;
      return decoration is BoxDecoration && decoration.border != null;
    });
    expect(borders, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(insertedBefore, 'a');
    expect(tester.getTopLeft(find.byKey(const ValueKey('home-item-a'))), originalA);
  });

  testWidgets('the positions shown during a drag match the committed drop', (tester) async {
    var configuration = threeItems();
    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder:
              (context, update) => SingleChildScrollView(
                child: HomeItemsView(
                  configuration: configuration,
                  registry: threeRegistry(),
                  onInsertBefore: (id, target) {
                    update(() => configuration = HomeGridLayout(configuration).moveBefore(id, target));
                  },
                ),
              ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-c'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('home-item-a'))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    final preview = {
      for (final id in ['a', 'b', 'c']) id: tester.getTopLeft(find.byKey(ValueKey('home-item-$id'))),
    };

    await gesture.up();
    await tester.pumpAndSettle();
    for (final id in preview.keys) {
      expect(tester.getTopLeft(find.byKey(ValueKey('home-item-$id'))), preview[id], reason: id);
    }
  });

  testWidgets('dropping below the content lands on the cell under the finger', (tester) async {
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('a', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('b', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('w', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('s', HomeItemKind.shortcut, HomeSpan.shortcut));
    HomeItem at(String id, HomeItemKind kind, HomeSpan span, int order, int column, int row) => HomeItem(
      id: id,
      definitionId: id,
      kind: kind,
      order: order,
      span: span,
      position: HomeGridPosition(column, row),
    );
    final configuration = HomeConfiguration(
      items: [
        at('a', HomeItemKind.shortcut, HomeSpan.shortcut, 0, 2, 0),
        at('b', HomeItemKind.shortcut, HomeSpan.shortcut, 1, 3, 0),
        at('w', HomeItemKind.widget, HomeSpan.small, 2, 0, 1),
        at('s', HomeItemKind.shortcut, HomeSpan.shortcut, 3, 2, 1),
      ],
    );
    String? movedId;
    HomeGridPosition? movedTo;
    await tester.pumpWidget(
      CupertinoApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: configuration,
              registry: registry,
              minHeight: 560,
              onMoveToCell: (id, position) {
                movedId = id;
                movedTo = position;
              },
              onInsertBefore: (_, __) {},
            ),
          ),
        ),
      ),
    );

    final surface = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface')));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-s'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(surface + const Offset(3 * 92 + 40, 5 * 92 + 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedId, 's');
    expect(movedTo, const HomeGridPosition(3, 5));
  });

  testWidgets('dragging near the bottom or top edge scrolls the home', (tester) async {
    final registry = HomeItemRegistry()..register(_LabelDefinition('w', HomeItemKind.widget, HomeSpan.small));
    final configuration = HomeConfiguration(
      items: [
        for (var row = 0; row < 6; row++)
          HomeItem(
            id: 'w$row',
            definitionId: 'w',
            kind: HomeItemKind.widget,
            order: row,
            span: HomeSpan.small,
            position: HomeGridPosition(0, row * 2),
          ),
      ],
    );
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            height: 400,
            child: SingleChildScrollView(
              controller: controller,
              child: HomeItemsView(
                configuration: configuration,
                registry: registry,
                onMoveToCell: (_, __) {},
                onInsertBefore: (_, __) {},
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-w0'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(const Offset(400, 395));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final scrolledDown = controller.offset;
    expect(scrolledDown, greaterThan(0));

    await gesture.moveTo(const Offset(400, 5));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.offset, lessThan(scrolledDown));

    await gesture.moveTo(const Offset(400, 200));
    await tester.pump(const Duration(milliseconds: 16));
    final stopped = controller.offset;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.offset, stopped);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('an item can drop below the last row even when the grid is taller than the screen', (tester) async {
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('a', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('b', HomeItemKind.shortcut, HomeSpan.shortcut))
          ..register(_LabelDefinition('w', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('s', HomeItemKind.shortcut, HomeSpan.shortcut));
    HomeItem at(String id, HomeItemKind kind, HomeSpan span, int order, int column, int row) => HomeItem(
      id: id,
      definitionId: id,
      kind: kind,
      order: order,
      span: span,
      position: HomeGridPosition(column, row),
    );
    final configuration = HomeConfiguration(
      items: [
        at('a', HomeItemKind.shortcut, HomeSpan.shortcut, 0, 0, 0),
        at('b', HomeItemKind.shortcut, HomeSpan.shortcut, 1, 1, 0),
        at('w', HomeItemKind.widget, HomeSpan.small, 2, 2, 1),
        at('s', HomeItemKind.shortcut, HomeSpan.shortcut, 3, 2, 6),
      ],
    );
    HomeGridPosition? movedTo;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            height: 500,
            child: SingleChildScrollView(
              controller: controller,
              child: HomeItemsView(
                configuration: configuration,
                registry: registry,
                onMoveToCell: (_, position) => movedTo = position,
                onInsertBefore: (_, __) {},
              ),
            ),
          ),
        ),
      ),
    );

    final surfaceHeight = tester.getSize(find.byKey(const ValueKey('home-grid-surface'))).height;
    expect(surfaceHeight, 9 * HomeItemsView.cell + 8 * HomeItemsView.gap);

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-s'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('home-item-s'))) + const Offset(-184, 92));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedTo, const HomeGridPosition(0, 7));
  });

  group('home menu', () {
    final registry =
        HomeItemRegistry()
          ..register(_LabelDefinition('small', HomeItemKind.widget, HomeSpan.small))
          ..register(_LabelDefinition('shortcut', HomeItemKind.shortcut, HomeSpan.shortcut));
    final configuration = HomeConfiguration(
      items: [
        _item('a', 'small', HomeItemKind.widget, 0, HomeSpan.small),
        _item('b', 'shortcut', HomeItemKind.shortcut, 1, HomeSpan.shortcut),
      ],
    );

    Future<void> pumpGrid(
      WidgetTester tester, {
      bool isArranging = false,
      void Function(String id, HomeGridPosition position)? onMoveToCell,
      VoidCallback? onArrangeDone,
      void Function(HomeItem item)? onRemove,
      List<String>? selected,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: Center(
            child: SizedBox(
              width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
              child: HomeItemsView(
                configuration: configuration,
                registry: registry,
                onMoveToCell: onMoveToCell ?? (_, __) {},
                menuItemsOf:
                    (item) => [
                      LongPressedMenuItem(
                        title: 'move ${item.id}',
                        iconPath: CommonActionIconPath.editHome,
                        onSelected: () => selected?.add(item.id),
                      ),
                    ],
                isArranging: isArranging,
                onArrangeDone: onArrangeDone,
                onRemove: onRemove,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a long press opens the menu instead of dragging', (tester) async {
      var moved = false;
      await pumpGrid(tester, onMoveToCell: (_, __) => moved = true);

      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-a'))));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(0, 200));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('move a'), findsOneWidget);
      expect(moved, isFalse);
      final item = tester.getRect(find.byKey(const ValueKey('home-item-a')));
      final menuText = tester.getRect(find.text('move a'));
      expect(menuText.top, greaterThan(item.bottom));
      expect(menuText.left, lessThan(item.left + 60));
      final menus = tester.widgetList<LongPressedMenuWidget>(find.byType(LongPressedMenuWidget)).toList();
      expect(menus[0].alignMenuToChildLeft && !menus[0].alignMenuToChildRight, isTrue);
      expect(menus[1].alignMenuToChildRight && !menus[1].alignMenuToChildLeft, isTrue);
      expect(
        find.byWidgetPredicate((w) => w is LongPressedMenuWidget && w.useGlassOverlay && w.preferMenuBelow),
        findsWidgets,
      );
    });

    testWidgets('while arranging, every item shakes with a remove button, drags right away, and a tap ends it', (
      tester,
    ) async {
      HomeGridPosition? target;
      final removed = <String>[];
      var done = 0;
      await pumpGrid(
        tester,
        isArranging: true,
        onMoveToCell: (id, position) => target = position,
        onArrangeDone: () => done++,
        onRemove: (item) => removed.add(item.id),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final menus = tester.widgetList<LongPressedMenuWidget>(find.byType(LongPressedMenuWidget));
      expect(menus.length, 2);

      for (final id in ['a', 'b']) {
        final card = tester.getRect(find.byKey(ValueKey('home-item-content-$id')));
        final badge = tester.getRect(find.byKey(ValueKey('home-item-remove-$id')));
        expect(badge.center.dx, closeTo(card.left + 4, 1), reason: id);
        expect(badge.center.dy, closeTo(card.top + 4, 1), reason: id);
        expect(
          find.ancestor(of: find.byKey(ValueKey('home-item-remove-$id')), matching: find.byType(Transform)),
          findsWidgets,
          reason: id,
        );
      }
      await tester.tap(find.byKey(const ValueKey('home-item-remove-b')));
      expect(removed, ['b']);
      expect(done, 0);

      final surface = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface')));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-b'))));
      await gesture.moveTo(
        surface +
            const Offset(
              3 * (HomeItemsView.cell + HomeItemsView.gap) + HomeItemsView.cell / 2,
              2 * (HomeItemsView.cell + HomeItemsView.gap) + HomeItemsView.cell / 2,
            ),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(target, const HomeGridPosition(3, 2));

      await tester.tap(find.byKey(const ValueKey('home-item-a')), warnIfMissed: false);
      expect(done, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('arranging ends by itself after ten seconds without input', (tester) async {
      var done = 0;
      await pumpGrid(tester, isArranging: true, onArrangeDone: () => done++, onRemove: (_) {});
      await tester.pump(const Duration(seconds: 9));
      await tester.drag(find.byKey(const ValueKey('home-item-a')), const Offset(0, 30));
      await tester.pump(const Duration(seconds: 9));
      expect(done, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(done, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
    });
  });

  testWidgets('a widget with two sizes shows a size picker at the top of its menu', (tester) async {
    final registry =
        HomeItemRegistry()
          ..register(_ResizableDefinition())
          ..register(_LabelDefinition('fixed', HomeItemKind.widget, HomeSpan.small));
    final resized = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Center(
          child: SizedBox(
            width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
            child: HomeItemsView(
              configuration: HomeConfiguration(
                items: [
                  _item('stack', 'resizable', HomeItemKind.widget, 0, HomeSpan.small),
                  _item('fixed', 'fixed', HomeItemKind.widget, 1, HomeSpan.small),
                ],
              ),
              registry: registry,
              onMoveToCell: (_, __) {},
              menuItemsOf:
                  (item) => [
                    LongPressedMenuItem(
                      title: 'remove ${item.id}',
                      iconPath: CommonActionIconPath.editHome,
                      onSelected: () {},
                    ),
                  ],
              onResize: (item, span) => resized.add('${item.id}:${span.toJson()}'),
            ),
          ),
        ),
      ),
    );

    await tester.longPress(find.byKey(const ValueKey('home-item-stack')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('home-item-size-stack-2x2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-item-size-stack-4x2')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(resized, ['stack:4x2']);
    expect(find.text('remove stack'), findsNothing);
  });
}

class _ResizableDefinition extends HomeItemDefinition {
  _ResizableDefinition()
    : super(
        id: 'resizable',
        kind: HomeItemKind.widget,
        supportedSpans: const [HomeSpan.small, HomeSpan.wide],
        category: HomeItemCategory.wallets,
      );

  @override
  Widget build(BuildContext context, HomeItem item) => Text('built:$id');
}
