import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/deletable_settings_row.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingRow extends DeletableSettingsRow {
  _CountingRow()
    : super(title: 'Theme', isSelected: true, isSwiped: false, onSwipeChanged: (_) {}, onDelete: () {}, onTap: () {});
  static int updates = 0;
  @override
  StatefulElement createElement() => _CountingElement(this);
}

class _CountingElement extends StatefulElement {
  _CountingElement(super.widget);
  @override
  void markNeedsBuild() {
    _CountingRow.updates++;
    super.markNeedsBuild();
  }
}

Widget host(Widget child, {CoconutThemeExtension? theme}) => MaterialApp(
  theme: ThemeData(extensions: [theme ?? CoconutThemeExtension.coconutTheme()]),
  home: MediaQuery(
    data: const MediaQueryData(size: Size(320, 600)),
    child: Scaffold(
      body: Center(child: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [child]))),
    ),
  ),
);
void main() {
  testWidgets('repeated swipe animations dispatch one update per frame', (tester) async {
    await tester.pumpWidget(host(_CountingRow()));
    final counts = <int>[];
    for (var cycle = 0; cycle < 5; cycle++) {
      await tester.drag(find.byType(_CountingRow), const Offset(-100, 0));
      await tester.pump(const Duration(milliseconds: 16));
      _CountingRow.updates = 0;
      await tester.pump(const Duration(milliseconds: 16));
      counts.add(_CountingRow.updates);
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(_CountingRow)));
      await tester.pumpAndSettle();
    }
    await tester.runAsync(() async {
      final file = File('.omo/evidence/theme-deletable-row/frame-update-counts.txt');
      await file.parent.create(recursive: true);
      await file.writeAsString('markNeedsBuild calls per animation frame over five open/close cycles: $counts\n');
    });
    expect(counts, everyElement(1), reason: 'one controller must not retain another listener per swipe');
  });

  testWidgets('vertical pointer movement cannot select the row', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        DeletableSettingsRow(
          title: 'Theme',
          isSelected: true,
          isSwiped: false,
          onSwipeChanged: (_) {},
          onDelete: () {},
          onTap: () => taps++,
        ),
      ),
    );
    await tester.drag(find.byType(DeletableSettingsRow), const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(taps, 0);
  });
  testWidgets('parent close interrupts a swipe without selecting or retaining animation work', (tester) async {
    var swiped = false;
    var visible = true;
    var taps = 0;
    final notifications = <bool>[];
    late StateSetter update;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return visible
                ? DeletableSettingsRow(
                  title: 'Theme',
                  isSelected: true,
                  isSwiped: swiped,
                  onSwipeChanged: (value) {
                    notifications.add(value);
                    setState(() => swiped = value);
                  },
                  onDelete: () {},
                  onTap: () {
                    taps++;
                    setState(() => visible = false);
                  },
                )
                : const SizedBox();
          },
        ),
      ),
    );
    await tester.drag(find.byType(DeletableSettingsRow), const Offset(-100, 0));
    await tester.pump(const Duration(milliseconds: 50));
    expect(swiped, isTrue);
    update(() => swiped = false);
    await tester.pumpAndSettle();
    expect(find.byType(IconButton), findsNothing);
    expect(notifications, [true]);
    expect(taps, 0);
    await tester.tap(find.byType(DeletableSettingsRow));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.byType(DeletableSettingsRow), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final theme
      in {
        'dark': CoconutThemeExtension.dark(),
        'light': CoconutThemeExtension.light(),
        'coconut': CoconutThemeExtension.coconutTheme(),
      }.entries) {
    const label = 'Coconut\nAuthor';
    testWidgets('${theme.key}: closed row supports semantic dismiss and Delete key with safe callback unmount', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      for (final keyboard in [false, true]) {
        var deletes = 0;
        var taps = 0;
        var visible = true;
        await tester.pumpWidget(
          host(
            StatefulBuilder(
              builder: (context, setState) {
                return visible
                    ? DeletableSettingsRow(
                      title: 'Coconut',
                      subtitle: 'Author',
                      isSelected: true,
                      isSwiped: false,
                      onSwipeChanged: (_) {},
                      onTap: () => taps++,
                      onDelete: () {
                        deletes++;
                        setState(() => visible = false);
                      },
                    )
                    : const SizedBox.shrink();
              },
            ),
            theme: theme.value,
          ),
        );
        await tester.pumpAndSettle();
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        expect(node.getSemanticsData().hasAction(SemanticsAction.dismiss), isTrue);
        expect(find.byType(IconButton), findsNothing);
        expect(find.bySemanticsLabel(t.delete), findsNothing);
        if (keyboard) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pumpAndSettle();
          expect(
            tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData().flagsCollection.isFocused,
            isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        } else {
          tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(node.id, SemanticsAction.dismiss);
        }
        await tester.pumpAndSettle();
        expect(deletes, 1);
        expect(taps, 0);
        expect(find.byType(DeletableSettingsRow), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      semantics.dispose();
    });

    testWidgets('${theme.key}: one labeled selected button accepts semantics and keyboard activation', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      Widget row(bool selected) => DeletableSettingsRow(
        title: 'Coconut',
        subtitle: 'Author',
        isSelected: selected,
        isSwiped: false,
        onSwipeChanged: (_) {},
        onDelete: () {},
        onTap: () => taps++,
      );
      await tester.pumpWidget(host(row(true), theme: theme.value));
      await tester.pumpAndSettle();
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      final data = node.getSemanticsData();
      expect(data.label, label);
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.hasEnabledState, isTrue);
      expect(data.flagsCollection.isEnabled, isTrue);
      expect(data.flagsCollection.isSelected, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      var selectedNodes = 0;
      void visit(SemanticsNode node) {
        if (node.getSemanticsData().flagsCollection.isSelected) selectedNodes++;
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!);
      expect(selectedNodes, 1);
      expect(find.bySemanticsLabel(t.delete), findsNothing);
      await tester.runAsync(() async {
        final file = File('.omo/evidence/theme-deletable-row/${theme.key}-semantics.txt');
        await file.parent.create(recursive: true);
        await file.writeAsString(
          tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!.toStringDeep(),
        );
      });
      tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(taps, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData().flagsCollection.isFocused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(taps, 3);
      await tester.pumpWidget(host(row(false), theme: theme.value));
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData().flagsCollection.isSelected, isFalse);
      semantics.dispose();
    });

    testWidgets('${theme.key}: swipe closes before selecting and delete action is visible only when open', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      var deletes = 0;
      final swipes = <bool>[];
      await tester.pumpWidget(
        host(
          DeletableSettingsRow(
            title: 'Coconut',
            subtitle: 'Author',
            isSelected: true,
            isSwiped: false,
            onSwipeChanged: swipes.add,
            onDelete: () => deletes++,
            onTap: () => taps++,
          ),
          theme: theme.value,
        ),
      );
      final row = find.byType(DeletableSettingsRow);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(taps, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.drag(row, const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(swipes.last, isTrue);
      expect(taps, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(swipes.last, isFalse);
      expect(taps, 1, reason: 'keyboard activation of an open row only closes it');
      expect(find.bySemanticsLabel(t.delete), findsNothing);
      await tester.drag(row, const Offset(-100, 0));
      await tester.pumpAndSettle();
      final delete = tester.getSemantics(find.bySemanticsLabel(t.delete));
      expect(delete.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(delete.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(tester.getSize(find.byType(IconButton)), const Size(52, 52));
      tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(delete.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(deletes, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(tester.getSemantics(find.bySemanticsLabel(t.delete)).getSemanticsData().flagsCollection.isFocused, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(deletes, 2);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(deletes, 3);
      await tester.runAsync(() async {
        final file = File('.omo/evidence/theme-deletable-row/${theme.key}-open-semantics.txt');
        await file.writeAsString(
          tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!.toStringDeep(),
        );
      });
      final rowNode = tester.getSemantics(find.bySemanticsLabel(label));
      tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(rowNode.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'accessibility activation of an open row only closes it');
      expect(find.bySemanticsLabel(t.delete), findsNothing);
      await tester.drag(row, const Offset(-100, 0));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(row));
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'pointer tap of an open row only closes it');
      await tester.tapAt(tester.getCenter(row));
      await tester.pumpAndSettle();
      expect(taps, 2);
      semantics.dispose();
    });

    testWidgets('${theme.key}: focus is visible and press cancel vertical drag and swipe restore pixels', (
      tester,
    ) async {
      final key = GlobalKey();
      var taps = 0;
      await tester.pumpWidget(
        host(
          RepaintBoundary(
            key: key,
            child: DeletableSettingsRow(
              title: 'Coconut',
              subtitle: 'Author',
              isSelected: true,
              isSwiped: false,
              onSwipeChanged: (_) {},
              onDelete: () {},
              onTap: () => taps++,
            ),
          ),
          theme: theme.value,
        ),
      );
      await tester.pumpAndSettle();
      Future<Uint8List> capture(String state) async =>
          (await tester.runAsync(() async {
            final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(
              pixelRatio: 1,
            );
            try {
              final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
              final png = await image.toByteData(format: ui.ImageByteFormat.png);
              final file = File('.omo/evidence/theme-deletable-row/${theme.key}-$state.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(png!.buffer.asUint8List());
              return data!.buffer.asUint8List();
            } finally {
              image.dispose();
            }
          }))!;
      final normal = await capture('normal');
      final row = find.byType(DeletableSettingsRow);
      final bounds = tester.getRect(row);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final focus = await capture('focused');
      Color pixel(Uint8List data, int y) {
        final offset = (320 * y + 160) * 4;
        return Color.fromARGB(data[offset + 3], data[offset], data[offset + 1], data[offset + 2]);
      }

      final a = pixel(focus, 0).computeLuminance() + .05;
      final b = pixel(focus, 5).computeLuminance() + .05;
      final contrast = a > b ? a / b : b / a;
      expect(contrast, greaterThanOrEqualTo(3));
      await tester.runAsync(
        () => File('.omo/evidence/theme-deletable-row/${theme.key}-focus-contrast.txt').writeAsString(
          'ring=${pixel(focus, 0).toARGB32().toRadixString(16)} fill=${pixel(focus, 5).toARGB32().toRadixString(16)} ratio=$contrast\n',
        ),
      );
      expect(focus, isNot(orderedEquals(normal)));
      expect(tester.getRect(row), bounds);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(await capture('unfocused'), orderedEquals(normal));
      final pointer = await tester.startGesture(bounds.center);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<ScaleTransition>(find.descendant(of: row, matching: find.byType(ScaleTransition))).scale.value,
        closeTo(.97, .001),
      );
      expect(await capture('pressed'), isNot(orderedEquals(normal)));
      await pointer.cancel();
      await tester.pumpAndSettle();
      expect(await capture('cancelled'), orderedEquals(normal));
      await tester.drag(row, const Offset(0, 80));
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(await capture('vertical-restored'), orderedEquals(normal));
      final drag = await tester.startGesture(bounds.center);
      await drag.moveBy(const Offset(-70, 0));
      await tester.pump();
      await drag.cancel();
      await tester.pumpAndSettle();
      expect(await capture('drag-cancelled'), orderedEquals(normal));
      await tester.drag(row, const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(await capture('swiped'), isNot(orderedEquals(normal)));
      await tester.tapAt(bounds.center);
      await tester.pumpAndSettle();
      expect(await capture('swipe-closed'), orderedEquals(normal));
      expect(taps, 0);
    });
  }
}
