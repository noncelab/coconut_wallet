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

    test('satoshiToBitcoinString - 자연수 케이스', () {
      expect(satoshiToBitcoinString(0), '0'); // 0 BTC
      expect(satoshiToBitcoinString(0, forceEightDecimals: true), '0.0000 0000');

      expect(satoshiToBitcoinString(100000000), '1'); // 1 BTC
      expect(satoshiToBitcoinString(100000000, forceEightDecimals: true), '1.0000 0000');

      expect(satoshiToBitcoinString(1000000000), '10'); // 10 BTC
      expect(satoshiToBitcoinString(1000000000, forceEightDecimals: true), '10.0000 0000');

      expect(satoshiToBitcoinString(10000000000), '100'); // 100 BTC
      expect(satoshiToBitcoinString(10000000000, forceEightDecimals: true), '100.0000 0000');

      expect(satoshiToBitcoinString(100000000000), '1,000'); // 1,000 BTC
      expect(satoshiToBitcoinString(100000000000, forceEightDecimals: true), '1,000.0000 0000');

      expect(satoshiToBitcoinString(100000000000000), '1,000,000'); // 1,000,000 BTC
      expect(
          satoshiToBitcoinString(100000000000000, forceEightDecimals: true), '1,000,000.0000 0000');
    });

    test('satoshiToBitcoinString - 소수점 4자리 미만 케이스', () {
      // 소수점 4자리 이하(뒤에 0 빼고 출력)
      expect(satoshiToBitcoinString(10000000), '0.1');
      expect(satoshiToBitcoinString(1000000), '0.01');
      expect(satoshiToBitcoinString(100000), '0.001');
      expect(satoshiToBitcoinString(10000), '0.0001');

      // 소수점 4자리 이하, forceEightDecimals: true
      expect(satoshiToBitcoinString(10000000, forceEightDecimals: true), '0.1000 0000');
      expect(satoshiToBitcoinString(1000000, forceEightDecimals: true), '0.0100 0000');
      expect(satoshiToBitcoinString(100000, forceEightDecimals: true), '0.0010 0000');
      expect(satoshiToBitcoinString(10000, forceEightDecimals: true), '0.0001 0000');

      expect(satoshiToBitcoinString(123000000), '1.23'); // 소수점 2자리(뒤에 0뺴고 출력)
    });

    test('satoshiToBitcoinString - 소수점 4자리 초과 케이스', () {
      // 소수점 4자리 초과(0 붙여서 출력)
      expect(satoshiToBitcoinString(1000), '0.0000 1000');
      expect(satoshiToBitcoinString(100), '0.0000 0100');
      expect(satoshiToBitcoinString(10), '0.0000 0010');
      expect(satoshiToBitcoinString(1), '0.0000 0001');

      // 소수점 4자리 초과, forceEightDecimals: true - 변화 없음
      expect(satoshiToBitcoinString(1000, forceEightDecimals: true), '0.0000 1000');
      expect(satoshiToBitcoinString(100, forceEightDecimals: true), '0.0000 0100');
      expect(satoshiToBitcoinString(10, forceEightDecimals: true), '0.0000 0010');
      expect(satoshiToBitcoinString(1, forceEightDecimals: true), '0.0000 0001');

      expect(satoshiToBitcoinString(123456000), '1.2345 6000'); // 소수점 5자리(0 붙여서 출력)
      expect(satoshiToBitcoinString(1000000010), '10.0000 0010'); // 소수점 7자리(0 붙여서 출력)
    });

    test('satoshiToBitcoinString - 양수, 음수 케이스', () {
      // 양수
      expect(satoshiToBitcoinString(1), '0.0000 0001');
      expect(satoshiToBitcoinString(10), '0.0000 0010');
      expect(satoshiToBitcoinString(100), '0.0000 0100');
      expect(satoshiToBitcoinString(1000), '0.0000 1000');
      expect(satoshiToBitcoinString(123456), '0.0012 3456');
      expect(satoshiToBitcoinString(12345678), '0.1234 5678');

      // 음수
      expect(satoshiToBitcoinString(-1), '-0.0000 0001');
      expect(satoshiToBitcoinString(-10), '-0.0000 0010');
      expect(satoshiToBitcoinString(-100), '-0.0000 0100');
      expect(satoshiToBitcoinString(-1000), '-0.0000 1000');
      expect(satoshiToBitcoinString(-123456), '-0.0012 3456');
      expect(satoshiToBitcoinString(-12345678), '-0.1234 5678');
    });
  });
}
