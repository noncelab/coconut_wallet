import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/screens/send/broadcasting_complete_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

double _contrast(Color foreground, Color background) {
  final text = Color.alphaBlend(foreground, background).computeLuminance();
  final surface = background.computeLuminance();
  return text > surface ? (text + .05) / (surface + .05) : (surface + .05) / (text + .05);
}

Future<void> _capture(GlobalKey key, String name) async {
  const directory = String.fromEnvironment('MEMO_RENDER_DIR');
  if (directory.isEmpty) return;
  final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}

void main() {
  setUpAll(() async {
    for (final (family, filenames) in {
      'Pretendard': ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf'],
      'SpaceGrotesk': ['SpaceGrotesk-Regular.ttf', 'SpaceGrotesk-Bold.ttf'],
    }.entries.map((entry) => (entry.key, entry.value))) {
      final loader = FontLoader(family);
      for (final filename in filenames) {
        loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$filename').readAsBytesSync())));
      }
      await loader.load();
    }
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });

  for (final variant in CoconutThemeVariant.values) {
    testWidgets('${variant.name} completion memo stays legible while empty, editing and collapsed', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      final theme = buildCoconutThemeData(variant: variant);
      final colors = resolveCoconutThemeExtension(variant: variant).colors;
      await tester.pumpWidget(
        Provider<SendInfoProvider>(
          create: (_) => SendInfoProvider(),
          child: MaterialApp(
            theme: theme,
            home: RepaintBoundary(
              key: boundary,
              child: const BroadcastingCompleteScreen(id: -1, txHash: 'public-fixture-only'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      final surface =
          tester
              .widgetList<Container>(find.ancestor(of: find.byType(TextField), matching: find.byType(Container)))
              .map((widget) => widget.decoration)
              .whereType<BoxDecoration>()
              .firstWhere((decoration) => decoration.color != null)
              .color!;
      expect(
        _contrast(field.decoration!.hintStyle!.color!, surface),
        greaterThanOrEqualTo(4.5),
        reason: 'Empty memo guidance must remain readable against its actual input surface',
      );
      final pencil = tester.widget<SvgPicture>(
        find.byWidgetPredicate((widget) => widget is SvgPicture && widget.width == 12),
      );
      expect(pencil.colorFilter, ColorFilter.mode(colors.secondaryText, BlendMode.srcIn));
      expect(_contrast(colors.secondaryText, surface), greaterThanOrEqualTo(3));
      await tester.runAsync(() => _capture(boundary, '${variant.name}-empty'));

      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '테스트 메모');
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, '테스트 메모');
      expect(_contrast(editable.style.color!, surface), greaterThanOrEqualTo(4.5));
      expect(find.text(t.broadcasting_complete_screen.memo_tags.first), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => _capture(boundary, '${variant.name}-editing'));

      field.focusNode!.unfocus();
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      final collapsed = tester.widget<Text>(find.text('테스트 메모'));
      expect(_contrast(collapsed.style!.color!, surface), greaterThanOrEqualTo(4.5));
      expect(field.controller!.text, '테스트 메모');
      expect(tester.takeException(), isNull);
    });
  }
}
