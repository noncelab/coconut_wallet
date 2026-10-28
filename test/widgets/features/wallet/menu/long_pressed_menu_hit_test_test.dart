import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final viewport in [const Size(443, 994), const Size(390, 844)]) {
    for (final elapsed in [16, 100, 220]) {
      for (final selected in [0, 1, 2]) {
        testWidgets('visible menu row $selected at ${elapsed}ms in ${viewport.width}px viewport', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = viewport;
          addTearDown(tester.view.reset);
          final choices = <int>[];
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCoconutThemeData(),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 134, 16, 0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: LongPressedMenuWidget(
                      useGlassOverlay: true,
                      preferMenuBelow: true,
                      alignMenuToChildLeft: true,
                      menuHeaderHeight: 48,
                      menuHeaderBuilder: (_) => const SizedBox(height: 48, child: Text('Widget sizes')),
                      menuItems: [
                        for (var index = 0; index < 3; index++)
                          LongPressedMenuItem(
                            title: ['Configure widget', 'Edit Home Screen', 'Remove widget'][index],
                            iconPath: CommonActionIconPath.editHome,
                            onSelected: () => choices.add(index),
                          ),
                      ],
                      child: SizedBox(
                        key: const Key('held-tile'),
                        width: viewport.width - 32,
                        height: 200,
                        child: const ColoredBox(color: Colors.blue),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.longPress(find.byKey(const Key('held-tile')));
          for (
            var frame = 0;
            frame < 30 && find.byKey(const Key('long-pressed-menu-box')).evaluate().isEmpty;
            frame++
          ) {
            await tester.pump(const Duration(milliseconds: 1));
          }
          expect(find.byKey(const Key('long-pressed-menu-box')), findsOneWidget);
          await tester.pump(Duration(milliseconds: elapsed));
          final label = find.text(['Configure widget', 'Edit Home Screen', 'Remove widget'][selected]).hitTestable();
          expect(label, findsOneWidget);
          await tester.tap(label);
          await tester.pumpAndSettle();
          expect(choices, [selected], reason: 'The painted row under the pointer must own the selection.');
          if (selected == 1) {
            await tester.longPress(find.byKey(const Key('held-tile')));
            for (
              var frame = 0;
              frame < 30 && find.byKey(const Key('long-pressed-menu-box')).evaluate().isEmpty;
              frame++
            ) {
              await tester.pump(const Duration(milliseconds: 1));
            }
            await tester.pump(Duration(milliseconds: elapsed));
            final gesture = await tester.startGesture(tester.getCenter(find.text('Configure widget')));
            await gesture.moveTo(tester.getCenter(find.text('Edit Home Screen')));
            await gesture.up();
            await tester.pumpAndSettle();
            expect(choices, [selected, selected], reason: 'Moving across painted rows must update the hovered action.');
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
