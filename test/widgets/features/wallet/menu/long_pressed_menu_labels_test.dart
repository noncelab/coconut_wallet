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

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(File('assets/fonts/$file').readAsBytesSync()).buffer)),
    );
  }
  await loader.load();
}

void main() {
  setUpAll(() => _loadFont('Pretendard', ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf']));
  tearDown(() => LocaleSettings.setLocale(AppLocale.ko));

  for (final locale in AppLocale.values)
    for (final bold in [false, true]) {
      testWidgets(
        'home menu labels are not cut off in ${locale.languageCode}${bold ? ' at 1.15x with bold text' : ''}',
        (tester) async {
          LocaleSettings.setLocale(locale);
          tester.view.physicalSize = const Size(384, 856);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final titles = [
            t.home_menu.configure_widget,
            t.home_menu.configure_shortcut,
            t.home_menu.edit_home_screen,
            t.home_menu.remove_widget,
            t.home_menu.remove_shortcut,
          ];
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCoconutThemeData(),
              builder:
                  (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(boldText: bold, textScaler: TextScaler.linear(bold ? 1.15 : 1)),
                    child: child!,
                  ),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LongPressedMenuWidget(
                      preferMenuBelow: true,
                      alignMenuToChildLeft: true,
                      menuIconSize: 20,
                      menuItems: [
                        for (final title in titles)
                          LongPressedMenuItem(title: title, iconPath: CommonActionIconPath.editHome, onSelected: () {}),
                      ],
                      child: const SizedBox(key: Key('target'), width: 80, height: 80),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.longPress(find.byKey(const Key('target')));
          await tester.pumpAndSettle();

          for (final title in titles) {
            final paragraph = tester.renderObject<RenderParagraph>(find.text(title).last);
            expect(
              paragraph.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(paragraph.size.width + 0.5),
              reason: '${locale.languageCode}: $title fits on one line',
            );
          }
        },
      );
    }

  for (final size in [const Size(80, 80), const Size(172, 172), const Size(352, 172)])
    for (final right in [false, true]) {
      testWidgets(
        'a ${size.width.toInt()}x${size.height.toInt()} item grows 4pt on every side and the menu box lines up '
        'with its ${right ? 'right' : 'left'} edge',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCoconutThemeData(),
              home: Scaffold(
                body: Align(
                  alignment: right ? Alignment.topRight : Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(19),
                    child: LongPressedMenuWidget(
                      useGlassOverlay: true,
                      preferMenuBelow: true,
                      alignMenuToChildLeft: !right,
                      alignMenuToChildRight: right,
                      menuIconSize: 20,
                      menuItems: [
                        LongPressedMenuItem(title: 'Edit', iconPath: CommonActionIconPath.editHome, onSelected: () {}),
                      ],
                      child: SizedBox(key: const Key('target'), width: size.width, height: size.height),
                    ),
                  ),
                ),
              ),
            ),
          );
          final before = tester.getRect(find.byKey(const Key('target')));
          await tester.longPress(find.byKey(const Key('target')));
          await tester.pumpAndSettle();

          final grown = tester.getRect(find.byKey(const Key('target')).first);
          expect(grown.width - before.width, closeTo(8, 0.5));
          expect(grown.height - before.height, closeTo(8, 0.5));
          final menu = tester.getRect(find.byKey(const Key('long-pressed-menu-box')));
          if (right) {
            expect(menu.right, closeTo(grown.right, 0.5));
          } else {
            expect(menu.left, closeTo(grown.left, 0.5));
          }
        },
      );
    }
}
