import 'dart:ui' as ui;

import 'package:coconut_wallet/app/theme/app_cupertino_theme.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/thai_test_font.dart';

Future<void> _pumpField(
  WidgetTester tester, {
  required String text,
  required String family,
  required double scale,
  double fontSize = 14,
  CoconutTextFieldSize size = CoconutTextFieldSize.standard,
  CoconutTextFieldStyle style = CoconutTextFieldStyle.bordered,
  int? maxLines = 1,
  bool obscureText = false,
  ScrollController? scrollController,
  Key? captureKey,
}) async {
  final controller = TextEditingController(text: text)..selection = TextSelection.collapsed(offset: text.length);
  final focusNode = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focusNode.dispose);
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1170, 2532);
  addTearDown(tester.view.reset);
  final cupertino = buildAppCupertinoTheme(variant: CoconutThemeVariant.dark);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: CupertinoTheme(
          data: cupertino.copyWith(
            textTheme: cupertino.textTheme.copyWith(
              textStyle: cupertino.textTheme.textStyle.copyWith(fontFamilyFallback: [thaiTestFontFamily]),
            ),
          ),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: captureKey,
                child: ColoredBox(
                  color: Colors.black,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: 320,
                      child: CoconutTextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (_) {},
                        fontFamily: family,
                        fontSize: fontSize,
                        fontWeight: fontSize == 32 ? FontWeight.bold : FontWeight.normal,
                        height: fontSize == 32 && style != CoconutTextFieldStyle.underline ? 52 : null,
                        padding: fontSize == 32 ? EdgeInsets.zero : null,
                        textAlign: fontSize == 32 ? TextAlign.center : null,
                        isVisibleBorder: fontSize != 32,
                        size: size,
                        style: style,
                        prefix:
                            size == CoconutTextFieldSize.search
                                ? const IconButton(onPressed: null, icon: Icon(Icons.search))
                                : null,
                        maxLines: maxLines,
                        obscureText: obscureText,
                        scrollController: scrollController,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<({Uint8List rgba, int width, int height})> _pixels(WidgetTester tester, GlobalKey key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      return (rgba: data.buffer.asUint8List(), width: image.width, height: image.height);
    } finally {
      image.dispose();
    }
  }))!;
}

void main() {
  final platform = TargetPlatformVariant.only(TargetPlatform.iOS);
  const legacyCases = [
    (name: 'th', text: 'ที่ ฟื้น ชื่อ ผู้', maxLines: 1, obscure: false, lineHeight: 1.0),
    (name: 'ko', text: '나의 비트코인 지갑', maxLines: 1, obscure: false, lineHeight: 1.0),
    (name: 'en', text: 'My Bitcoin wallet', maxLines: 1, obscure: false, lineHeight: 1.0),
    (name: 'ja', text: '私のビットコイン財布', maxLines: 1, obscure: false, lineHeight: 1.0),
    (name: 'es', text: 'Mi monedero, envío', maxLines: 1, obscure: false, lineHeight: 1.0),
    (name: 'de', text: 'Größe für mein Geld', maxLines: 1, obscure: false, lineHeight: 1.0),
    (name: 'obscured Thai', text: 'ฟื้นชื่อที่ผู้', maxLines: 1, obscure: true, lineHeight: 1.0),
    (name: 'multiline Thai', text: 'ฟื้นชื่อที่ผู้\nน้ำ', maxLines: 3, obscure: false, lineHeight: 1.4),
    (name: 'unbounded Thai', text: 'ฟื้นชื่อที่ผู้\nน้ำ', maxLines: null, obscure: false, lineHeight: 1.0),
  ];

  // These contracts run without loading any real font or reading golden files.
  for (final family in ['Pretendard', 'SpaceGrotesk']) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final fontSize in [14.0, 32.0]) {
        for (final sample in legacyCases) {
          testWidgets('preserves ${sample.name} metrics: $family ${fontSize}px at $scale', (tester) async {
            await _pumpField(
              tester,
              text: sample.text,
              family: family,
              scale: scale,
              fontSize: fontSize,
              maxLines: sample.maxLines,
              obscureText: sample.obscure,
            );
            final input = tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));
            final isThai = sample.name == 'th';
            final innerHeight = fontSize == 32 ? 52.0 : 50.0;
            expect(tester.getSize(find.byType(CoconutTextField)), const Size(320, 52));
            expect(input.maxLines, sample.maxLines);
            expect(input.obscureText, sample.obscure);
            expect(
              input.padding,
              fontSize == 32
                  ? EdgeInsets.zero
                  : isThai
                  ? const EdgeInsets.symmetric(horizontal: 16)
                  : const EdgeInsets.all(16),
            );
            expect(input.style!.height, isThai ? kTextHeightNone : sample.lineHeight);
            expect(input.strutStyle!.height, isThai ? innerHeight / (fontSize * scale) : sample.lineHeight);
            expect(input.strutStyle!.fontFamily, family);
            expect(input.strutStyle!.fontSize, fontSize);
            expect(input.strutStyle!.forceStrutHeight, isTrue);
            expect(input.strutStyle!.leadingDistribution, isThai ? TextLeadingDistribution.even : null);
            expect(input.cursorHeight, isThai ? (fontSize * scale).roundToDouble() : null);
            final editable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
            final caret = editable.getLocalRectForCaret(TextPosition(offset: sample.text.length));
            expect(caret.height, (fontSize * scale * (isThai ? 1 : sample.lineHeight)).roundToDouble() + 2);
            await tester.pumpWidget(const SizedBox());
          }, variant: platform);
        }
      }
    }
  }

  for (final layout in [
    (size: CoconutTextFieldSize.compact, style: CoconutTextFieldStyle.bordered, fontSize: 14.0),
    (size: CoconutTextFieldSize.search, style: CoconutTextFieldStyle.bordered, fontSize: 14.0),
    (size: CoconutTextFieldSize.standard, style: CoconutTextFieldStyle.underline, fontSize: 14.0),
    (size: CoconutTextFieldSize.standard, style: CoconutTextFieldStyle.underline, fontSize: 32.0),
  ]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('keeps field size when Thai replaces ASCII: $layout at $scale', (tester) async {
        Future<void> pump(String text) => _pumpField(
          tester,
          text: text,
          family: 'Pretendard',
          scale: scale,
          fontSize: layout.fontSize,
          size: layout.size,
          style: layout.style,
        );
        await pump('input');
        final originalSize = tester.getSize(find.byType(CoconutTextField));
        await pump('ที่ ฟื้น ชื่อ ผู้');
        expect(tester.getSize(find.byType(CoconutTextField)), originalSize);
        await tester.pumpWidget(const SizedBox());
      }, variant: platform);
    }
  }

  var fontsLoaded = false;
  for (final family in ['Pretendard', 'SpaceGrotesk']) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final fontSize in [14.0, 32.0]) {
        testWidgets('Thai clipping within fixed field: $family ${fontSize}px at $scale', (tester) async {
          final fontAvailable = (await tester.runAsync(() async => hasThaiTestFont))!;
          if (!fontAvailable) {
            markTestSkipped('The macOS Thonburi fixture font is unavailable');
            return;
          }
          if (!fontsLoaded) {
            await tester.runAsync(() async {
              for (final family in ['Pretendard', 'SpaceGrotesk']) {
                await (FontLoader(family)
                      ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
                      ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf')))
                    .load();
              }
              await loadThaiTestFont();
            });
            fontsLoaded = true;
          }
          final capture = GlobalKey();
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          await _pumpField(
            tester,
            text: List.filled(8, 'ที่ ฟื้น ชื่อ ผู้ ฎุ ฏู น้ำ').join(' / '),
            family: family,
            scale: scale,
            scrollController: scroll,
            captureKey: capture,
            fontSize: fontSize,
          );
          expect(tester.getSize(find.byType(CoconutTextField)), const Size(320, 52));
          expect(scroll.position.axis, Axis.horizontal);
          expect(scroll.position.maxScrollExtent, greaterThan(0));
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pump();
          expect(scroll.offset, scroll.position.maxScrollExtent);
          final input = tester.widget<EditableText>(find.byType(EditableText));
          final editable = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
          expect(input.focusNode.hasFocus, isFalse);
          double widthOf(String text) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: input.style),
              textDirection: TextDirection.ltr,
              textScaler: editable.textScaler,
            )..layout();
            final width = painter.width;
            painter.dispose();
            return width;
          }

          expect(widthOf('ที่ผู้'), closeTo(widthOf('ทผ'), 0.5), reason: 'Thai marks must use a real Thai font');
          final viewport = (editable.localToGlobal(Offset.zero) & editable.size).shift(
            -tester.getTopLeft(find.byKey(capture)),
          );
          final clipped = await _pixels(tester, capture);
          final originalClip = editable.clipBehavior;
          expect(originalClip, Clip.hardEdge);
          // Repaint without pumping: a rebuild would restore the widget's clip setting.
          editable.clipBehavior = Clip.none;
          tester.binding.rootPipelineOwner.flushPaint();
          final unclipped = await _pixels(tester, capture);
          editable.clipBehavior = originalClip;
          tester.binding.rootPipelineOwner.flushPaint();
          var missingPixels = 0;
          for (var y = 0; y < clipped.height; y++) {
            // Keep the horizontal clip; compare vertical ink only, with no blinking caret.
            for (var x = ((viewport.left + 2) * 3).ceil(); x < ((viewport.right - 2) * 3).floor(); x++) {
              final i = (y * clipped.width + x) * 4;
              if ((clipped.rgba[i] - unclipped.rgba[i]).abs() +
                      (clipped.rgba[i + 1] - unclipped.rgba[i + 1]).abs() +
                      (clipped.rgba[i + 2] - unclipped.rgba[i + 2]).abs() >
                  12) {
                missingPixels++;
              }
            }
          }
          debugPrint('THAI_CLIP family=$family fontSize=$fontSize scale=$scale missingPixels=$missingPixels');
          if (fontSize == 14 && scale < 2) {
            expect(missingPixels, 0, reason: 'Normal-sized Thai marks must fit at 1.0 and 1.3 text scale');
          }
          await tester.pumpWidget(const SizedBox());
        }, variant: platform);
      }
    }
  }
}
