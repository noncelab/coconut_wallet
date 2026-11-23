import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/nfkd_util.dart';

enum _Script { hangul, kana, han, thai, latin, otherLetter, digitOrSymbol }

/// [locale] 언어의 사전 순서로 [a]와 [b]를 비교한다.
/// 그 언어의 문자, 라틴 문자, 그 밖의 문자, 숫자·기호 순이며 대소문자와 악센트는 구분하지 않는다.
int compareByLocaleDictionaryOrder(String a, String b, AppLocale locale) {
  final rankCompare = _rank(a, locale).compareTo(_rank(b, locale));
  if (rankCompare != 0) return rankCompare;
  final foldedCompare = _fold(a, locale).compareTo(_fold(b, locale));
  if (foldedCompare != 0) return foldedCompare;
  return a.compareTo(b);
}

int _rank(String value, AppLocale locale) {
  final order = switch (locale) {
    AppLocale.ko => const [_Script.hangul, _Script.latin, _Script.kana, _Script.han],
    AppLocale.ja => const [_Script.kana, _Script.han, _Script.latin, _Script.hangul],
    AppLocale.th => const [_Script.thai, _Script.latin, _Script.hangul, _Script.kana, _Script.han],
    _ => const [_Script.latin, _Script.hangul, _Script.kana, _Script.han],
  };
  final script = value.isEmpty ? _Script.digitOrSymbol : _scriptOf(value.runes.first);
  final index = order.indexOf(script);
  if (index >= 0) return index;
  return order.length + (script == _Script.otherLetter ? 0 : 1);
}

_Script _scriptOf(int rune) {
  if ((rune >= 0xAC00 && rune <= 0xD7A3) || (rune >= 0x1100 && rune <= 0x11FF) || (rune >= 0x3130 && rune <= 0x318F)) {
    return _Script.hangul;
  }
  if (rune >= 0x3040 && rune <= 0x30FF) return _Script.kana;
  if (rune >= 0x4E00 && rune <= 0x9FFF) return _Script.han;
  // 태국 글자는 대소문자가 없어 아래 판별로는 기호가 된다. 자음·모음·성조 기호(숫자 ๐-๙와 ฿ 제외)를 따로 잡는다.
  if ((rune >= 0x0E01 && rune <= 0x0E3A) || (rune >= 0x0E40 && rune <= 0x0E4E)) return _Script.thai;
  if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A) || (rune >= 0xC0 && rune <= 0x24F)) {
    return _Script.latin;
  }
  final char = String.fromCharCode(rune);
  return char.toLowerCase() != char.toUpperCase() ? _Script.otherLetter : _Script.digitOrSymbol;
}

/// 태국어 사전 순서에 가깝게 비교할 때 쓰는 열쇠를 만든다. 표준 정렬(CLDR th)을 그대로 옮긴 것은 아니다.
/// 자음 앞에 쓰는 모음(เ แ โ ใ ไ)은 뒤 자음과 자리를 바꾸고, 성조·ไม้ไต่คู้·การันต์(U+0E47–0E4C)은 뺀다.
/// 뺀 기호만 다른 낱말은 열쇠가 같으므로, 순서를 가르려면 원래 글자로 한 번 더 비교한다.
/// 표준과 다른 점: 띄어쓰기와 문장부호를 건너뛰지 않고, ฯ·ๆ와 풀어 쓴 ํา(ำ)를 따로 다루지 않는다.
String thaiDictionaryKey(String value) {
  final runes = [
    for (final rune in value.runes)
      if (rune < 0x0E47 || rune > 0x0E4C) rune,
  ];
  for (var i = 0; i + 1 < runes.length; i++) {
    final isLeadingVowel = runes[i] >= 0x0E40 && runes[i] <= 0x0E44;
    final isConsonant = runes[i + 1] >= 0x0E01 && runes[i + 1] <= 0x0E2E;
    if (isLeadingVowel && isConsonant) {
      final vowel = runes[i];
      runes[i] = runes[i + 1];
      runes[i + 1] = vowel;
      i++;
    }
  }
  return String.fromCharCodes(runes);
}

String _fold(String value, AppLocale locale) {
  final buffer = StringBuffer();
  final source = locale == AppLocale.th ? thaiDictionaryKey(value) : value;
  for (final rune in source.toLowerCase().runes) {
    if (rune == 0xF1 && locale == AppLocale.es) {
      buffer.write('n{');
    } else if (rune == 0xDF) {
      buffer.write('ss');
    } else if (rune >= 0xC0 && rune <= 0x24F) {
      buffer.writeCharCode(NfkdUtil.normalizeNfkd(String.fromCharCode(rune)).runes.first);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}
