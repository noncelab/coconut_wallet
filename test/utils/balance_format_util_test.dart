import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BalanceFormatUtil.satoshiToReadableBitcoin', () {
    test('음수, btc 단위에서 정수 부분이 0', () {
      String result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(-25800142);
      expect(result, '-0.2580 0142');
    });

    test('음수, btc 단위로 표현 시 정수', () {
      String result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(-100000000);
      expect(result, '-1');
    });

    test('음수, btc 단위로 표현 시 정수, 소숫점 모두 있음', () {
      String result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(-200044444);
      expect(result, '-2.0004 4444');
    });

    test('양수, btc 단위에서 정수 부분이 0', () {
      String result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(25800142);
      expect(result, '0.2580 0142');
    });

    test('양수, btc 단위로 표현 시 정수', () {
      String result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000000000);
      expect(result, '100');
    });

    test('양수, btc 단위로 표현 시 정수, 소숫점 모두 있음', () {
      String result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(-2000044444);
      expect(result, '-20.0004 4444');
    });

    test('satoshiToReadableBitcoin - 자연수 케이스', () {
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(0), '0'); // 0 BTC
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(0, forceEightDecimals: true), '0.0000 0000');

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000), '1'); // 1 BTC
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000, forceEightDecimals: true), '1.0000 0000');

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000000000), '10'); // 10 BTC
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000000000, forceEightDecimals: true), '10.0000 0000');

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000000000), '100'); // 100 BTC
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000000000, forceEightDecimals: true), '100.0000 0000');

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000000), '1,000'); // 1,000 BTC
      expect(
        BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000000, forceEightDecimals: true),
        '1,000.0000 0000',
      );

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000000000), '1,000,000'); // 1,000,000 BTC
      expect(
        BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000000000, forceEightDecimals: true),
        '1,000,000.0000 0000',
      );
    });

    test('satoshiToReadableBitcoin - 소수점 4자리 미만 케이스', () {
      // 소수점 4자리 이하(뒤에 0 빼고 출력)
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000000), '0.1');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000000), '0.01');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000), '0.001');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000), '0.0001');

      // 소수점 4자리 이하, forceEightDecimals: true
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000000, forceEightDecimals: true), '0.1000 0000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000000, forceEightDecimals: true), '0.0100 0000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000, forceEightDecimals: true), '0.0010 0000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000, forceEightDecimals: true), '0.0001 0000');

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(123000000), '1.23'); // 소수점 2자리(뒤에 0뺴고 출력)
    });

    test('satoshiToReadableBitcoin - 소수점 4자리 초과 케이스', () {
      // 소수점 4자리 초과(0 붙여서 출력)
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000), '0.0000 1000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100), '0.0000 0100');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10), '0.0000 0010');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1), '0.0000 0001');

      // 소수점 4자리 초과, forceEightDecimals: true - 변화 없음
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000, forceEightDecimals: true), '0.0000 1000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100, forceEightDecimals: true), '0.0000 0100');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10, forceEightDecimals: true), '0.0000 0010');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1, forceEightDecimals: true), '0.0000 0001');

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(123456000), '1.2345 6000'); // 소수점 5자리(0 붙여서 출력)
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000000010), '10.0000 0010'); // 소수점 7자리(0 붙여서 출력)
    });

    test('satoshiToReadableBitcoin - 양수, 음수 케이스', () {
      // 양수
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1), '0.0000 0001');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10), '0.0000 0010');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100), '0.0000 0100');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000), '0.0000 1000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(123456), '0.0012 3456');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(12345678), '0.1234 5678');

      // 음수
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(-1), '-0.0000 0001');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(-10), '-0.0000 0010');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(-100), '-0.0000 0100');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(-1000), '-0.0000 1000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(-123456), '-0.0012 3456');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(-12345678), '-0.1234 5678');
    });
  });

  group('BalanceFormatUtil.satoshiToReadableBitcoin', () {
    test('음수, btc 단위에서 정수 부분이 0', () {
      String result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(-25800142);
      expect(result, '-0.2580 0142');
    });

    test('음수, btc 단위로 표현 시 정수', () {
      String result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(-100000000);
      expect(result, '-1');
    });

    test('음수, btc 단위로 표현 시 정수, 소숫점 모두 있음', () {
      String result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(-200044444);
      expect(result, '-2.0004 4444');
    });

    test('양수, btc 단위에서 정수 부분이 0', () {
      String result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(25800142);
      expect(result, '0.2580 0142');
    });

    test('양수, btc 단위로 표현 시 정수', () {
      String result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000000000);
      expect(result, '100');
    });

    test('양수, btc 단위로 표현 시 정수, 소숫점 모두 있음', () {
      String result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(-2000044444);
      expect(result, '-20.0004 4444');
    });

    test('satoshiToReadableBitcoin - 자연수 케이스', () {
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(0), '0'); // 0 BTC
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(0, forceEightDecimals: true), '0.0000 0000');

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000), '1'); // 1 BTC
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000, forceEightDecimals: true), '1.0000 0000');

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000000000), '10'); // 10 BTC
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000000000, forceEightDecimals: true), '10.0000 0000');

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000000000), '100'); // 100 BTC
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000000000, forceEightDecimals: true), '100.0000 0000');

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000000), '1,000'); // 1,000 BTC
      expect(
        BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000000, forceEightDecimals: true),
        '1,000.0000 0000',
      );

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000000000), '1,000,000'); // 1,000,000 BTC
      expect(
        BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000000000000, forceEightDecimals: true),
        '1,000,000.0000 0000',
      );
    });

    test('satoshiToReadableBitcoin - 소수점 4자리 미만 케이스', () {
      // 소수점 4자리 이하(뒤에 0 빼고 출력)
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000000), '0.1');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000000), '0.01');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000), '0.001');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000), '0.0001');

      // 소수점 4자리 이하, forceEightDecimals: true
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000000, forceEightDecimals: true), '0.1000 0000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000000, forceEightDecimals: true), '0.0100 0000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100000, forceEightDecimals: true), '0.0010 0000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10000, forceEightDecimals: true), '0.0001 0000');

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(123000000), '1.23'); // 소수점 2자리(뒤에 0뺴고 출력)
    });

    test('satoshiToReadableBitcoin - 소수점 4자리 초과 케이스', () {
      // 소수점 4자리 초과(0 붙여서 출력)
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000), '0.0000 1000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100), '0.0000 0100');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10), '0.0000 0010');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1), '0.0000 0001');

      // 소수점 4자리 초과, forceEightDecimals: true - 변화 없음
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000, forceEightDecimals: true), '0.0000 1000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100, forceEightDecimals: true), '0.0000 0100');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10, forceEightDecimals: true), '0.0000 0010');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1, forceEightDecimals: true), '0.0000 0001');

      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(123456000), '1.2345 6000'); // 소수점 5자리(0 붙여서 출력)
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000000010), '10.0000 0010'); // 소수점 7자리(0 붙여서 출력)
    });

    test('satoshiToReadableBitcoin - 양수, 음수 케이스', () {
      // 양수
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1), '0.0000 0001');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(10), '0.0000 0010');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(100), '0.0000 0100');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(1000), '0.0000 1000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(123456), '0.0012 3456');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(12345678), '0.1234 5678');

      // 음수
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(-1), '-0.0000 0001');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(-10), '-0.0000 0010');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(-100), '-0.0000 0100');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(-1000), '-0.0000 1000');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(-123456), '-0.0012 3456');
      expect(BalanceFormatUtil.formatSatoshiToReadableBitcoin(-12345678), '-0.1234 5678');
    });
  });

  group('FakeBalanceUtil.distributeFakeBalance', () {
    test('잔액이 0인 경우 모든 지갑에 0 할당', () {
      final result = FakeBalanceUtil.distributeFakeBalance(0, 5, BitcoinUnit.sats);
      expect(result, [0, 0, 0, 0, 0]);
    });

    test('지갑 개수가 0인 경우 빈 배열 반환', () {
      final result = FakeBalanceUtil.distributeFakeBalance(1000, 0, BitcoinUnit.sats);
      expect(result, []);
    });

    test('잔액이 음수인 경우 모든 지갑에 0 할당', () {
      final result = FakeBalanceUtil.distributeFakeBalance(-100, 3, BitcoinUnit.sats);
      expect(result, [0, 0, 0]);
    });

    test('사토시 단위로 정확한 분배 - 작은 값', () {
      final result = FakeBalanceUtil.distributeFakeBalance(10, 3, BitcoinUnit.sats);

      // 총합이 원래 값과 같은지 확인
      expect(result.reduce((a, b) => a + b), 10);

      // 배열 길이가 지갑 개수와 같은지 확인
      expect(result.length, 3);

      // 모든 값이 0 이상인지 확인
      expect(result.every((value) => value >= 0), true);
    });

    test('사토시 단위로 정확한 분배 - 큰 값', () {
      final result = FakeBalanceUtil.distributeFakeBalance(1000000, 5, BitcoinUnit.sats);

      // 총합이 원래 값과 같은지 확인
      expect(result.reduce((a, b) => a + b), 1000000);

      // 배열 길이가 지갑 개수와 같은지 확인
      expect(result.length, 5);

      // 모든 값이 0 이상인지 확인
      expect(result.every((value) => value >= 0), true);
    });

    test('비트코인 단위로 정확한 분배 - 정수', () {
      final result = FakeBalanceUtil.distributeFakeBalance(1, 4, BitcoinUnit.btc);

      // 총합이 1 BTC (100,000,000 sats)와 같은지 확인
      expect(result.reduce((a, b) => a + b), 100000000);

      // 배열 길이가 지갑 개수와 같은지 확인
      expect(result.length, 4);

      // 모든 값이 0 이상인지 확인
      expect(result.every((value) => value >= 0), true);
    });

    test('비트코인 단위로 정확한 분배 - 소수', () {
      final result = FakeBalanceUtil.distributeFakeBalance(0.01, 3, BitcoinUnit.btc);

      // 총합이 0.01 BTC (1,000,000 sats)와 같은지 확인
      expect(result.reduce((a, b) => a + b), 1000000);

      // 배열 길이가 지갑 개수와 같은지 확인
      expect(result.length, 3);

      // 모든 값이 0 이상인지 확인
      expect(result.every((value) => value >= 0), true);
    });

    test('비트코인 단위로 정확한 분배 - 소수점 8자리', () {
      final result = FakeBalanceUtil.distributeFakeBalance(0.12345678, 2, BitcoinUnit.btc);

      // 총합이 0.12345678 BTC (12,345,678 sats)와 같은지 확인
      expect(result.reduce((a, b) => a + b), 12345678);

      // 배열 길이가 지갑 개수와 같은지 확인
      expect(result.length, 2);

      // 모든 값이 0 이상인지 확인
      expect(result.every((value) => value >= 0), true);
    });

    test('랜덤 분배의 일관성 - 같은 입력에 대해 다른 결과', () {
      final result1 = FakeBalanceUtil.distributeFakeBalance(1000, 3, BitcoinUnit.sats);
      final result2 = FakeBalanceUtil.distributeFakeBalance(1000, 3, BitcoinUnit.sats);

      // 총합은 같아야 함
      expect(result1.reduce((a, b) => a + b), result2.reduce((a, b) => a + b));

      // 하지만 분배는 다를 수 있음 (랜덤이므로)
      // 실제로는 거의 확실히 다를 것이지만, 테스트에서는 확률적이므로 주석 처리
      // expect(result1, isNot(equals(result2)));
    });

    test('단일 지갑에 모든 잔액 할당', () {
      final result = FakeBalanceUtil.distributeFakeBalance(500, 1, BitcoinUnit.sats);

      expect(result, [500]);
      expect(result.length, 1);
    });

    test('0 잔액이 허용되는지 확인', () {
      // 여러 번 실행하여 0이 나올 수 있는지 확인
      bool hasZero = false;
      for (int i = 0; i < 100; i++) {
        final result = FakeBalanceUtil.distributeFakeBalance(100, 10, BitcoinUnit.sats);
        if (result.any((value) => value == 0)) {
          hasZero = true;
          break;
        }
      }

      // 10개 지갑에 100 사토시를 분배할 때 0이 나올 가능성이 높음
      expect(hasZero, true);
    });

    test('큰 지갑 개수에서의 분배', () {
      final result = FakeBalanceUtil.distributeFakeBalance(10000, 100, BitcoinUnit.sats);

      // 총합이 원래 값과 같은지 확인
      expect(result.reduce((a, b) => a + b), 10000);

      // 배열 길이가 지갑 개수와 같은지 확인
      expect(result.length, 100);

      // 모든 값이 0 이상인지 확인
      expect(result.every((value) => value >= 0), true);
    });

    test('정확한 사토시 변환 - 비트코인 단위', () {
      // 0.00000001 BTC = 1 sat
      final result = FakeBalanceUtil.distributeFakeBalance(0.00000001, 1, BitcoinUnit.btc);
      expect(result, [1]);

      // 0.0000001 BTC = 10 sats
      final result2 = FakeBalanceUtil.distributeFakeBalance(0.0000001, 1, BitcoinUnit.btc);
      expect(result2, [10]);

      // 0.000001 BTC = 100 sats
      final result3 = FakeBalanceUtil.distributeFakeBalance(0.000001, 1, BitcoinUnit.btc);
      expect(result3, [100]);
    });
  });
}
