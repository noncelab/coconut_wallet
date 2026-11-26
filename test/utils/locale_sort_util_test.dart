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

  test('th puts Thai first, then Latin, then other scripts, then digits and symbols', () {
    expect(_sorted(['tt', 'ขาย', 'Banana', 'กระเป๋า', '가방', '1차', '#แท็ก'], AppLocale.th), [
      'กระเป๋า',
      'ขาย',
      'Banana',
      'tt',
      '가방',
      '#แท็ก',
      '1차',
    ]);
  });

  // 아래 태국어 순서는 ICU 78.3의 태국어 정렬(Intl.Collator('th'))과 같은 결과다.
  group('th follows Thai dictionary order for single words', () {
    test('a leading vowel is filed under its consonant: เงิน under ง, ไก่ under ก', () {
      expect(_sorted(['จ่าย', 'เงิน', 'ไก่', 'คืน', 'กา'], AppLocale.th), ['กา', 'ไก่', 'คืน', 'เงิน', 'จ่าย']);
    });

    test('all five leading vowels stay with their consonant ก, in vowel order, before the next consonant ข', () {
      expect(_sorted(['ขะ', 'ไกะ', 'ใกะ', 'โกะ', 'แกะ', 'เกะ', 'กะ'], AppLocale.th), [
        'กะ',
        'เกะ',
        'แกะ',
        'โกะ',
        'ใกะ',
        'ไกะ',
        'ขะ',
      ]);
    });

    test('a leading vowel in the middle of a word is swapped too: ประเทศ (ท) before ประธาน (ธ)', () {
      expect(_sorted(['ประธาน', 'ประเทศ', 'ประทาน'], AppLocale.th), ['ประทาน', 'ประเทศ', 'ประธาน']);
    });

    test('marks above a letter that are not tones (็ ์) are skipped at first: เก็บ before เกย', () {
      expect(_sorted(['เกย', 'เก็บ'], AppLocale.th), ['เก็บ', 'เกย']);
      expect(_sorted(['สัตวา', 'สัตว์', 'สัตว'], AppLocale.th), ['สัตว', 'สัตว์', 'สัตวา']);
    });

    test('tone marks are skipped at first (ป้า before ปาก) and only order words that are otherwise the same', () {
      expect(_sorted(['ปาก', 'ป้า', 'ปา', 'ป่า'], AppLocale.th), ['ปา', 'ป่า', 'ป้า', 'ปาก']);
    });
  });

  test('th keeps Thai digits and the baht sign with digits and symbols, after every letter', () {
    expect(_sorted(['๑ชุด', '₿1', '฿100', '1ชุด', 'apple', 'กา'], AppLocale.th), [
      'กา',
      'apple',
      '1ชุด',
      '฿100',
      '๑ชุด',
      '₿1',
    ]);
  });

  test('thaiDictionaryKey swaps each leading vowel with its consonant and drops tone marks', () {
    expect(thaiDictionaryKey('เงิน').runes, [0x0E07, 0x0E40, 0x0E34, 0x0E19]);
    expect(thaiDictionaryKey('ไม่').runes, [0x0E21, 0x0E44]);
    expect(thaiDictionaryKey('ประเทศ').runes, [0x0E1B, 0x0E23, 0x0E30, 0x0E17, 0x0E40, 0x0E28]);
    expect(thaiDictionaryKey('เก็บ').runes, [0x0E01, 0x0E40, 0x0E1A]);
    expect(thaiDictionaryKey('Bitcoin 21'), 'Bitcoin 21');
  });

  test('other locales keep Thai names where they were, after every letter', () {
    expect(_sorted(['กา', 'apple', '1차', '가방'], AppLocale.en), ['apple', '가방', '1차', 'กา']);
    expect(_sorted(['กา', 'apple', '1차', '가방'], AppLocale.ko), ['가방', 'apple', '1차', 'กา']);
  });
}
