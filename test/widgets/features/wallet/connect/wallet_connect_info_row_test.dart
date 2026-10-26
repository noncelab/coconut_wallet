import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/features/wallet/connect/wallet_connect_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:coconut_wallet/widgets/common/text/mfp_text.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 320, double scale = 1}) => MaterialApp(
  theme: buildCoconutThemeData(variant: CoconutThemeVariant.light),
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Center(child: SizedBox(width: width, child: child)),
    ),
  ),
);

void _expectGlyphLineEndsAtRowRight(WidgetTester tester, Text text, List<TextSelection> selections) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.byWidget(text), matching: find.byType(RichText)),
  );
  final lineEnds = <double, double>{};
  for (final selection in selections) {
    for (final box in paragraph.getBoxesForSelection(selection)) {
      final previousEnd = lineEnds[box.bottom];
      if (previousEnd == null || box.right > previousEnd) lineEnds[box.bottom] = box.right;
    }
  }
  expect(lineEnds, isNotEmpty);
  final rowRight = tester.getRect(find.byType(WalletConnectInfoRow)).right;
  for (final end in lineEnds.values) {
    expect(paragraph.localToGlobal(Offset(end, 0)).dx, closeTo(rowRight, .1));
  }
}

List<Rect> _mfpGlyphs(WidgetTester tester) {
  final glyphs = <Rect>[];
  for (final element in find.descendant(of: find.byType(MfpText), matching: find.byType(RichText)).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
    for (var index = 0; index < raw.length; index++) {
      if (raw[index] == '\uFFFC') continue;
      final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: index, extentOffset: index + 1));
      for (final box in boxes) {
        glyphs.add(box.toRect().shift(paragraph.localToGlobal(Offset.zero)));
      }
    }
  }
  return glyphs;
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('SpaceGrotesk');
    loader.addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Bold.ttf'));
    await loader.load();
  });
  for (final direction in Axis.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${direction.name} fingerprint groups four digits and preserves raw semantics at scale $scale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _host(
              WalletConnectInfoRow(label: 'Master fingerprint', value: 'aAbBcCdD', isMfp: true, direction: direction),
              width: scale == 1 ? 320 : 240,
              scale: scale,
            ),
          );
          final glyphs = _mfpGlyphs(tester);
          expect(glyphs, hasLength(8));
          expect(glyphs.take(4).map((rect) => rect.top).toSet(), hasLength(1));
          expect(glyphs.skip(4).map((rect) => rect.top).toSet(), hasLength(1));
          if (glyphs.first.top == glyphs.last.top) {
            expect(glyphs[4].left - glyphs[3].right, closeTo(4 * scale, .1));
          } else {
            expect(glyphs[4].top, greaterThan(glyphs[3].top));
          }
          expect(find.bySemanticsLabel('aAbBcCdD'), findsOneWidget);
          expect(
            tester
                .widgetList<RichText>(find.descendant(of: find.byType(MfpText), matching: find.byType(RichText)))
                .map((text) => text.text.toPlainText(includeSemanticsLabels: false).replaceAll('\uFFFC', ''))
                .join(),
            'aAbBcCdD',
          );
          if (direction == Axis.horizontal) {
            final rowRight = tester.getRect(find.byType(WalletConnectInfoRow)).right;
            for (final line in glyphs.map((rect) => rect.top).toSet()) {
              final lineEnd = glyphs
                  .where((rect) => rect.top == line)
                  .map((rect) => rect.right)
                  .reduce((a, b) => a > b ? a : b);
              expect(lineEnd, closeTo(rowRight, .1));
            }
          }
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }

    testWidgets('${direction.name} ordinary long values wrap without fingerprint formatting', (tester) async {
      const value = 'A long hardware wallet device name';
      await tester.pumpWidget(
        _host(WalletConnectInfoRow(label: 'Device name', value: value, direction: direction), width: 240, scale: 2),
      );
      final text = tester.widget<Text>(find.text(value));
      expect(text.data, value);
      expect(text.textSpan, isNull);
      if (direction == Axis.horizontal) {
        expect(text.textAlign, TextAlign.end);
        _expectGlyphLineEndsAtRowRight(
          tester,
          text,
          RegExp(
            r'\S+',
          ).allMatches(value).map((word) => TextSelection(baseOffset: word.start, extentOffset: word.end)).toList(),
        );
      }
      expect(tester.getSize(find.text(value)).height, greaterThan(28));
      expect(tester.takeException(), isNull);
    });
  }
}
