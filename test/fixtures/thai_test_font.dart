import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 실제 글꼴 배치 테스트에서 태국 글자를 그리는 글꼴.
///
/// 앱 글꼴(Pretendard·SpaceGrotesk)에는 태국 글자가 없어 기기가 자기 글꼴로 대신 그린다(iOS Thonburi, Android Noto Sans
/// Thai). 테스트 엔진은 그 대체가 꺼져 있어, 글꼴을 올리지 않으면 글자마다 1em 빈 칸이 되고 폭이 2~4배로 부푼다.
/// 저장소에는 태국 글꼴이 없으므로 macOS에 있는 Thonburi를 올린다. 이 파일이 없는 환경에서는 [hasThaiTestFont]가
/// false이고, 태국어 경우를 건너뛴다.
const thaiTestFontFamily = 'ThaiTestFont';

const _thonburi = '/System/Library/Fonts/Supplemental/Thonburi.ttc';

bool get hasThaiTestFont => File(_thonburi).existsSync();

/// `setUpAll`에서 부른다. 글꼴 파일이 없으면 아무것도 하지 않는다.
Future<void> loadThaiTestFont() async {
  if (!hasThaiTestFont) return;
  final loader = FontLoader(thaiTestFontFamily)
    ..addFont(Future.value(ByteData.sublistView(File(_thonburi).readAsBytesSync())));
  await loader.load();
}

/// [theme]의 글자에 태국 글꼴을 대체 글꼴로 단다. [before]는 그보다 먼저 볼 대체 글꼴이다.
///
/// 테마의 대체 글꼴은 `Text`에만 닿는다. 글꼴을 직접 정한 `TextSpan`이나 `TextPainter`에는 닿지 않으므로,
/// 태국 글자가 제대로 그려졌는지는 [expectThaiGlyphs]로 확인한다.
ThemeData withThaiFontFallback(ThemeData theme, {List<String> before = const []}) =>
    theme.copyWith(textTheme: theme.textTheme.apply(fontFamilyFallback: [...before, thaiTestFontFamily]));

/// [scope] 안에서 태국 글자 기호가 든 글이 모두 빈 칸이 아니라 태국 글꼴로 그려졌는지 본다. 그런 글이 하나도 없으면 실패한다.
///
/// 태국 글꼴에서 글자 위아래 기호는 폭이 0이라, 기호를 뺀 글과 폭이 같다. 빈 칸으로 그려지면 기호도 한 칸씩 차지한다.
void expectThaiGlyphs(WidgetTester tester, Finder scope) {
  final paragraphs =
      tester
          .renderObjectList<RenderParagraph>(
            find.descendant(of: scope, matching: find.byType(RichText), matchRoot: true),
          )
          .where((paragraph) => paragraph.text.toPlainText().runes.any(_isThaiMark))
          .toList();
  expect(paragraphs, isNotEmpty, reason: '태국 글자 기호가 든 글이 없어 글꼴을 가릴 수 없다');
  for (final paragraph in paragraphs) {
    double widthOf(InlineSpan span) {
      final painter = TextPainter(text: span, textDirection: TextDirection.ltr, textScaler: paragraph.textScaler)
        ..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    expect(
      widthOf(_textOnly(paragraph.text, keepThaiMarks: true)),
      closeTo(widthOf(_textOnly(paragraph.text, keepThaiMarks: false)), 0.5),
      reason: '"${paragraph.text.toPlainText()}"가 태국 글꼴 없이 빈 칸으로 그려졌다',
    );
  }
}

/// 폭이 0인 태국 글자 기호: 위아래 모음(ั ิ-ฺ)과 성조·기호(็-๎).
bool _isThaiMark(int rune) =>
    rune == 0x0E31 || (rune >= 0x0E34 && rune <= 0x0E3A) || (rune >= 0x0E47 && rune <= 0x0E4E);

/// 글자 조각만 남긴 사본. 글 사이에 낀 위젯(아이콘 등)은 폭을 잴 수 없어 뺀다.
InlineSpan _textOnly(InlineSpan span, {required bool keepThaiMarks}) {
  if (span is! TextSpan) return const TextSpan();
  final text = span.text;
  return TextSpan(
    text: text == null || keepThaiMarks ? text : String.fromCharCodes(text.runes.where((rune) => !_isThaiMark(rune))),
    children: span.children?.map((child) => _textOnly(child, keepThaiMarks: keepThaiMarks)).toList(),
    style: span.style,
  );
}
