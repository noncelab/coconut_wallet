import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/utils/nfkd_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('모든 Unicode scalar의 바이트 경로가 String 경로와 동일하다', () {
    for (var rune = 0; rune <= 0x10FFFF; rune++) {
      if (rune >= 0xD800 && rune <= 0xDFFF) continue;
      // prefix로 맨 앞 BOM 제거 규칙의 영향을 배제한다.
      final value = 'a${String.fromCharCode(rune)}';
      final expected = utf8.encode(NfkdUtil.normalizeNfkd(value));
      expect(NfkdUtil.encodeNfkd(value), expected);
      expect(NfkdUtil.normalizeNfkdUtf8(Uint8List.fromList(utf8.encode(value))), expected);
    }
  });

  test('결합 순서, BOM, 짝 없는 surrogate도 기존 인코딩 의미를 유지한다', () {
    for (final value in ['', '\uFEFFabc', 'a\u0315\u0300', '코코넛-Café-🥥', '\uD800', '\uDC00']) {
      expect(NfkdUtil.encodeNfkd(value), utf8.encode(NfkdUtil.normalizeNfkd(value)));
      final input = Uint8List.fromList(utf8.encode(value));
      final original = Uint8List.fromList(input);
      expect(NfkdUtil.normalizeNfkdUtf8(input), utf8.encode(NfkdUtil.normalizeNfkd(utf8.decode(input))));
      expect(input, original);
    }
  });

  test('잘못된 UTF-8은 원본을 변경하거나 예외에 포함하지 않고 거부한다', () {
    for (final value in [
      [0x80],
      [0xC0, 0x80],
      [0xC2],
      [0xC2, 0x41],
      [0xE0, 0x80, 0x80],
      [0xED, 0xA0, 0x80],
      [0xF0, 0x80, 0x80, 0x80],
      [0xF4, 0x90, 0x80, 0x80],
      [0xFF],
    ]) {
      final input = Uint8List.fromList(value);
      expect(
        () => NfkdUtil.normalizeNfkdUtf8(input),
        throwsA(isA<FormatException>().having((e) => e.source, 'source', isNull)),
      );
      expect(input, value);
    }
  });

  group('Bip39PassphraseUtil.normalizeNfkd', () {
    test('한글 음절을 호환 자모가 아닌 표준 자모로 분해한다', () {
      expect(NfkdUtil.normalizeNfkd('가각'), '\u1100\u1161\u1100\u1161\u11A8');
    });

    test('악센트 문자를 기본 문자와 결합 문자로 재귀 분해한다', () {
      expect(NfkdUtil.normalizeNfkd('éÅ'), 'e\u0301A\u030A');
    });

    test('호환 문자를 NFKD 형식으로 분해한다', () {
      expect(NfkdUtil.normalizeNfkd('①ⅣﬁＡ'), '1IVfiA');
    });

    test('결합 문자를 canonical combining class 순서로 정렬한다', () {
      expect(NfkdUtil.normalizeNfkd('a\u0315\u0300\u05AE\u0301'), 'a\u05AE\u0300\u0301\u0315');
    });

    test('ASCII와 일반 이모지는 그대로 유지한다', () {
      const passphrase = r'coconut-123!@#$% 😀';
      expect(NfkdUtil.normalizeNfkd(passphrase), passphrase);
    });

    test('빈 문자열은 그대로 반환한다', () {
      expect(NfkdUtil.normalizeNfkd(''), '');
    });
  });

  group('Bip39PassphraseUtil.isNfkdNormalized', () {
    test('원문과 NFKD 결과가 같으면 true를 반환한다', () {
      expect(NfkdUtil.isNfkdNormalized('coconut-123!'), isTrue);
      expect(NfkdUtil.isNfkdNormalized('\u1100\u1161'), isTrue);
    });

    test('원문과 NFKD 결과가 다르면 false를 반환한다', () {
      expect(NfkdUtil.isNfkdNormalized('가'), isFalse);
      expect(NfkdUtil.isNfkdNormalized('①'), isFalse);
    });
  });

  group('Bip39PassphraseUtil UTF-8 변환', () {
    test('문자열을 NFKD 정규화한 UTF-8 바이트로 인코딩한다', () {
      expect(NfkdUtil.encodeNfkd('코코넛-Café'), utf8.encode('\u110F\u1169\u110F\u1169\u1102\u1165\u11BA-Cafe\u0301'));
    });

    test('기존 UTF-8 바이트도 NFKD 형식으로 변환한다', () {
      expect(NfkdUtil.normalizeNfkdUtf8(Uint8List.fromList(utf8.encode('Café'))), NfkdUtil.encodeNfkd('Café'));
    });
  });
}
