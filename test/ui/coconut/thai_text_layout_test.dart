import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/thai_test_font.dart';

/// [paragraph]가 실제로 나눈 줄들. 이음 문자(U+2060)는 빼고 돌려준다.
List<String> _lines(RenderParagraph paragraph) {
  final text = paragraph.text.toPlainText();
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
  )..layout(maxWidth: paragraph.size.width);
  final lines = <String>[];
  var offset = 0;
  while (offset < text.length) {
    final range = painter.getLineBoundary(TextPosition(offset: offset));
    if (range.end <= offset) break;
    lines.add(text.substring(range.start, range.end).replaceAll('\u2060', '').trim());
    offset = range.end;
  }
  painter.dispose();
  return lines;
}

void main() {
  setUpAll(() async {
    await (FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.ttf')))
        .load();
    await loadThaiTestFont();
  });
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  // 홈 힌트·온보딩·지갑 추가 선택지는 언어와 관계없이 TextUtils.preventLineBreakInsideWords를 거친다.
  // 태국어 문장에 이음 문자가 들어가면 엔진이 낱말 사이에서 줄을 나누지 못하고 음절 중간에서 끊는다
  testWidgets('Thai sentences wrap at the same places with and without preventLineBreakInsideWords', (tester) async {
    const sentence = 'ยินดีต้อนรับสู่กระเป๋าบิตคอยน์ของคุณ กรุณาสำรองวลีกู้คืนก่อนเริ่มใช้งาน';
    const style = CoconutTypography.body2_14;
    await tester.pumpWidget(
      MaterialApp(
        theme: withThaiFontFallback(buildCoconutThemeData()),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 160,
              child: Column(
                children: [
                  const Text(sentence, key: Key('plain'), style: style),
                  Text(TextUtils.preventLineBreakInsideWords(sentence), key: const Key('through-util'), style: style),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final plain = _lines(tester.renderObject<RenderParagraph>(find.byKey(const Key('plain'))));
    final throughUtil = _lines(tester.renderObject<RenderParagraph>(find.byKey(const Key('through-util'))));
    expect(plain.length, greaterThan(2), reason: '좁은 폭이라 여러 줄이어야 한다');
    expect(plain.join().replaceAll(' ', ''), sentence.replaceAll(' ', ''), reason: '줄들을 이으면 문장 전체다');
    expect(throughUtil, plain);
    if (hasThaiTestFont) expectThaiGlyphs(tester, find.byType(Column));
  });

  // 앱 공통 팝업은 제목·설명·버튼을 Text로 그린다. 긴 태국어 안내가 작은 화면·큰 글자에서도 버튼을 밀어내지 않아야 한다
  for (final (size, scale) in [(const Size(320, 568), 2.0), (const Size(390, 844), 1.3)]) {
    testWidgets(
      'Thai warning popup at ${size.width.toInt()}x${size.height.toInt()} @${scale}x keeps its button on screen',
      (tester) async {
        LocaleSettings.setLocaleSync(AppLocale.th);
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final strings = t.wallet_home_screen.hot_wallet_create;
        await tester.pumpWidget(
          MaterialApp(
            theme: withThaiFontFallback(buildCoconutThemeData()),
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => TextButton(
                      onPressed:
                          () => showInfoDialog(
                            context,
                            'th',
                            strings.passphrase_not_stored_title,
                            strings.passphrase_not_stored_description,
                            buttonText: t.confirm,
                          ),
                      child: const Text('open'),
                    ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expectThaiGlyphs(tester, find.byType(Dialog));
        // 팝업의 이음 문자 처리는 한국어 전용이다. 태국어 제목과 설명은 그대로 들어간다
        expect(find.text(strings.passphrase_not_stored_title), findsOneWidget);
        expect(find.text(strings.passphrase_not_stored_description), findsOneWidget);
        final button = tester.getRect(find.text(t.confirm));
        expect(button.top, greaterThanOrEqualTo(0));
        expect(button.bottom, lessThanOrEqualTo(size.height));

        await tester.tap(find.text(t.confirm));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
      },
      skip: !hasThaiTestFont,
    );
  }
}
