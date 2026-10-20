import 'package:coconut_wallet/widgets/common/text/mfp_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String _renderedFingerprint(WidgetTester tester) =>
    tester
        .widgetList<RichText>(find.byType(RichText))
        .map((text) => text.text.toPlainText(includeSemanticsLabels: false).replaceAll('\uFFFC', ''))
        .join();

List<Rect> _glyphs(WidgetTester tester) {
  final result = <Rect>[];
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final raw = paragraph.text.toPlainText(includeSemanticsLabels: false);
    for (var index = 0; index < raw.length; index++) {
      if (raw[index] == '\uFFFC') continue;
      for (final box in paragraph.getBoxesForSelection(TextSelection(baseOffset: index, extentOffset: index + 1))) {
        result.add(box.toRect().shift(paragraph.localToGlobal(Offset.zero)));
      }
    }
  }
  return result;
}

Widget _host({
  String value = 'aAbBcCdD',
  double? width = 112,
  double scale = 2,
  double gap = 4,
  double fontSize = 14,
  TextAlign inheritedAlign = TextAlign.start,
  TextAlign? explicitAlign,
  TextDirection direction = TextDirection.ltr,
}) => Directionality(
  textDirection: direction,
  child: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: DefaultTextStyle(
      style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: fontSize, fontWeight: FontWeight.bold),
      textAlign: inheritedAlign,
      child: Center(child: SizedBox(width: width, child: MfpText(mfp: value, gap: gap, textAlign: explicitAlign))),
    ),
  ),
);

void main() {
  setUpAll(() async {
    final loader = FontLoader('SpaceGrotesk');
    loader.addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Bold.ttf'));
    await loader.load();
  });

  for (final direction in TextDirection.values) {
    for (final alignment in [TextAlign.start, TextAlign.end, TextAlign.left, TextAlign.right, TextAlign.center]) {
      testWidgets('wrapped groups inherit $alignment under $direction without a trailing gap', (tester) async {
        await tester.pumpWidget(_host(inheritedAlign: alignment, direction: direction));
        final glyphs = _glyphs(tester);
        expect(glyphs, hasLength(8));
        expect(glyphs[4].top, greaterThan(glyphs[3].top));
        final bounds = tester.getRect(find.byType(MfpText));
        final rightAligned =
            alignment == TextAlign.right ||
            alignment == TextAlign.end && direction == TextDirection.ltr ||
            alignment == TextAlign.start && direction == TextDirection.rtl;
        for (final group in [glyphs.take(4), glyphs.skip(4)]) {
          final left = group.map((rect) => rect.left).reduce((a, b) => a < b ? a : b);
          final right = group.map((rect) => rect.right).reduce((a, b) => a > b ? a : b);
          if (alignment == TextAlign.center) {
            expect((left + right) / 2, closeTo(bounds.center.dx, .1));
          } else if (rightAligned) {
            expect(right, closeTo(bounds.right, .1));
          } else {
            expect(left, closeTo(bounds.left, .1));
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final scale in [1.0, 2.0]) {
    for (final direction in TextDirection.values) {
      testWidgets('wide groups retain order and scaled gap at $scale in $direction with one raw semantic label', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _host(width: 320, scale: scale, gap: 6, explicitAlign: TextAlign.end, direction: direction),
          );
          final glyphs = _glyphs(tester);
          expect(glyphs, hasLength(8));
          expect(glyphs.map((rect) => rect.top).toSet(), hasLength(1));
          expect(glyphs[4].left - glyphs[3].right, closeTo(6 * scale, .1));
          expect(find.bySemanticsLabel('aAbBcCdD'), findsOneWidget);
          var rawLabels = 0;
          void countLabels(SemanticsNode node) {
            if (node.getSemanticsData().label == 'aAbBcCdD') rawLabels++;
            node.visitChildren((child) {
              countLabels(child);
              return true;
            });
          }

          countLabels(tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!);
          expect(rawLabels, 1);
          expect(_renderedFingerprint(tester), 'aAbBcCdD');
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }

  testWidgets('zero font size reserves no scaled gap', (tester) async {
    await tester.pumpWidget(_host(width: null, fontSize: 0));
    expect(tester.getSize(find.byType(MfpText)).width, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unbounded row callers retain a single inline fingerprint', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 14, fontWeight: FontWeight.bold),
          child: const Row(children: [MfpText(mfp: 'aAbBcCdD'), Spacer()]),
        ),
      ),
    );
    final glyphs = _glyphs(tester);
    expect(glyphs, hasLength(8));
    expect(glyphs.map((rect) => rect.top).toSet(), hasLength(1));
    expect(glyphs[4].left - glyphs[3].right, closeTo(4, .1));
    expect(tester.takeException(), isNull);
  });

  for (final value in ['', 'aB', 'aBcD']) {
    testWidgets('short fingerprint "$value" has no inserted gap or changed value', (tester) async {
      await tester.pumpWidget(_host(value: value, explicitAlign: TextAlign.end));
      expect(_glyphs(tester), hasLength(value.length));
      expect(_renderedFingerprint(tester), value);
      expect(tester.takeException(), isNull);
    });
  }
}
