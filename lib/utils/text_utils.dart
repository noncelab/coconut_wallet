import 'package:flutter/widgets.dart';

class TextUtils {
  /// 공백으로 구분된 각 단어 내부에 Unicode Word Joiner를 삽입합니다.
  ///
  /// 한글처럼 렌더러가 글자 단위 줄바꿈을 허용하는 문장에서 단어 중간이
  /// 끊기지 않고 공백 위치에서만 줄바꿈되도록 할 때 사용합니다.
  /// 코드 포인트가 아니라 글자 묶음(grapheme) 사이에 넣습니다. 국기·ZWJ 이모지·피부색·키캡처럼
  /// 여러 코드 포인트로 된 글자 안에 이음 문자가 끼면 기기에서 조각으로 그려집니다.
  static String preventLineBreakInsideWords(String text) {
    return text.split(' ').map((word) => word.characters.join('\u2060')).join(' ');
  }

  static InlineSpan preventLineBreakInsideWordsInSpan(InlineSpan span) {
    if (span is! TextSpan) return span;
    return TextSpan(
      text: span.text == null ? null : preventLineBreakInsideWords(span.text!),
      children: span.children?.map(preventLineBreakInsideWordsInSpan).toList(),
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel ?? span.text,
      locale: span.locale,
      spellOut: span.spellOut,
    );
  }

  /// 글자 묶음(grapheme) 수가 [maxLength]를 넘으면 앞 [maxLength] - 3 묶음 뒤에 "..."를 붙입니다.
  /// UTF-16 단위로 자르면 이름 끝의 이모지가 반쪽(짝 없는 서로게이트)이나 조각으로 남습니다.
  static String ellipsisIfLonger(String text, {int maxLength = 10}) {
    final characters = text.characters;
    return characters.length > maxLength ? '${characters.take(maxLength - 3)}...' : text;
  }

  static String truncate(String name, int maxLength, int leftValidLength, int rightValidLength) {
    if (name.length <= maxLength || leftValidLength + rightValidLength > maxLength) {
      return name;
    }

    return '${name.substring(0, leftValidLength)}...${name.substring(name.length - rightValidLength, name.length)}';
  }
}
