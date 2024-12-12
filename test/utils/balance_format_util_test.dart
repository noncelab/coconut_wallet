import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('satoshiToBitcoinString', () {
    test('음수, btc 단위에서 정수 부분이 0', () {
      String result = satoshiToBitcoinString(-25800142);
      expect(result, '-0.2580 0142');
    });

    test('음수, btc 단위로 표현 시 정수', () {
      String result = satoshiToBitcoinString(-100000000);
      expect(result, '-1');
    });

    test('음수, btc 단위로 표현 시 정수, 소숫점 모두 있음', () {
      String result = satoshiToBitcoinString(-200044444);
      expect(result, '-2.0004 4444');
    });

    test('양수, btc 단위에서 정수 부분이 0', () {
      String result = satoshiToBitcoinString(25800142);
      expect(result, '0.2580 0142');
    });

    test('양수, btc 단위로 표현 시 정수', () {
      String result = satoshiToBitcoinString(10000000000);
      expect(result, '100');
    });

    test('양수, btc 단위로 표현 시 정수, 소숫점 모두 있음', () {
      String result = satoshiToBitcoinString(-2000044444);
      expect(result, '-20.0004 4444');
    });
  });
}
