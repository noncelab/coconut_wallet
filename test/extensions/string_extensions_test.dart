import 'package:flutter_test/flutter_test.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';

void main() {
  group('StringFormatting', () {
    group('toThousandsSeparatedString', () {
      test('정수 문자열에 대해 천 단위 구분자를 추가한다', () {
        expect('1234'.toThousandsSeparatedString(), '1,234');
        expect('1234567'.toThousandsSeparatedString(), '1,234,567');
        expect('0'.toThousandsSeparatedString(), '0');
        expect('-1234'.toThousandsSeparatedString(), '-1,234');
      });

      test('소수 문자열에 대해 천 단위 구분자와 소수점 2자리를 표시한다', () {
        expect('123124141234.54959454859345'.toThousandsSeparatedString(), '123,124,141,234.54959454859345');
        expect('1234.56'.toThousandsSeparatedString(), '1,234.56');
        expect('1234.567'.toThousandsSeparatedString(), '1,234.567');
        expect('-1234.5'.toThousandsSeparatedString(), '-1,234.5');
      });

      test('숫자가 아닌 문자열은 원래 값을 반환한다', () {
        expect('abc'.toThousandsSeparatedString(), 'abc');
        expect('123abc'.toThousandsSeparatedString(), '123abc');
        expect(''.toThousandsSeparatedString(), '');
      });
    });
  });
}
