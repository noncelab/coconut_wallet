import 'dart:io';
import 'dart:typed_data';

import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final file in ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf']) {
      loader.addFont(
        Future.value(ByteData.view(Uint8List.fromList(File('assets/fonts/$file').readAsBytesSync()).buffer)),
      );
    }
    await loader.load();
  });
  tearDown(() => LocaleSettings.setLocale(AppLocale.ko));

  for (final locale in [AppLocale.de, AppLocale.es]) {
    testWidgets('a wrapped second menu row never selects Remove in ${locale.languageCode}', (tester) async {
      LocaleSettings.setLocale(locale);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 900);
      addTearDown(tester.view.reset);
      final titles = [t.home_menu.configure_widget, t.home_menu.edit_home_screen, t.home_menu.remove_widget];
      final choices = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          builder:
              (context, child) =>
                  MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)), child: child!),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LongPressedMenuWidget(
                  useGlassOverlay: false,
                  preferMenuBelow: true,
                  alignMenuToChildLeft: true,
                  menuIconSize: 20,
                  menuItems: [
                    for (var index = 0; index < titles.length; index++)
                      LongPressedMenuItem(
                        title: titles[index],
                        iconPath: CommonActionIconPath.editHome,
                        isDanger: index == 2,
                        onSelected: () => choices.add(index),
                      ),
                  ],
                  child: const SizedBox(
                    key: Key('held-tile'),
                    width: 88,
                    height: 88,
                    child: ColoredBox(color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      for (final lowerEdge in [false, true]) {
        await tester.longPress(find.byKey(const Key('held-tile')));
        await tester.pumpAndSettle();
        final title = find.text(titles[1]).last;
        final paragraph = tester.renderObject<RenderParagraph>(title);
        final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: titles[1].length));
        expect(boxes.map((box) => box.top.round()).toSet().length, 2, reason: 'The target must actually wrap.');
        final row = tester.renderObject<RenderBox>(find.ancestor(of: title, matching: find.byType(Row)).first);
        final point = row.localToGlobal(
          lowerEdge ? Offset(row.size.width / 2, row.size.height - 2) : row.size.center(Offset.zero),
        );
        final gesture = await tester.startGesture(point);
        await gesture.moveTo(point);
        await tester.pump(const Duration(milliseconds: 20));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(choices, lowerEdge ? [1, 1] : [1], reason: 'Only the painted Edit row owns this pointer release.');
        expect(tester.takeException(), isNull);
      }
    });
  }
}
