import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/nfkd_util.dart';

enum _Script { hangul, kana, han, latin, otherLetter, digitOrSymbol }

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
  if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A) || (rune >= 0xC0 && rune <= 0x24F)) {
    return _Script.latin;
  }
  final char = String.fromCharCode(rune);
  return char.toLowerCase() != char.toUpperCase() ? _Script.otherLetter : _Script.digitOrSymbol;
}

String _fold(String value, AppLocale locale) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
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
