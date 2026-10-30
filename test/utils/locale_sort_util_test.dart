import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/locale_sort_util.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _sorted(List<String> values, AppLocale locale) =>
    [...values]..sort((a, b) => compareByLocaleDictionaryOrder(a, b, locale));

void main() {
  const names = ['tt', '하나', 'Banana', '가방', 'apple', '1차', 'かばん', '#메모'];

  test('ko puts Hangul first, then Latin, then other scripts, then digits and symbols', () {
    expect(_sorted(names, AppLocale.ko), ['가방', '하나', 'apple', 'Banana', 'tt', 'かばん', '#메모', '1차']);
  });

  test('ja puts kana first', () {
    expect(_sorted(names, AppLocale.ja), ['かばん', 'apple', 'Banana', 'tt', '가방', '하나', '#메모', '1차']);
  });

  test('en puts Latin first, ignoring case', () {
    expect(_sorted(names, AppLocale.en), ['apple', 'Banana', 'tt', '가방', '하나', 'かばん', '#메모', '1차']);
  });

  test('accents sort with their base letter', () {
    expect(_sorted(['Zebra', 'Äpfel', 'Apfel', 'Bär'], AppLocale.de), ['Apfel', 'Äpfel', 'Bär', 'Zebra']);
  });

  test('es sorts ñ after every n', () {
    expect(_sorted(['ñandú', 'nube', 'oso', 'nzz'], AppLocale.es), ['nube', 'nzz', 'ñandú', 'oso']);
  });
}
