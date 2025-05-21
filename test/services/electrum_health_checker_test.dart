import 'package:flutter_test/flutter_test.dart';
import 'package:coconut_wallet/services/electrum_health_checker.dart';

void main() {
  group('ElectrumHealthChecker', () {
    test('unreachable but valid IP should timeout after 3 seconds', () async {
      final stopwatch = Stopwatch()..start();

      // 10.255.255.1은 사설 IP 대역으로, 실제 연결은 불가능하지만 유효한 IP입니다.
      final result = await ElectrumHealthChecker.checkConnection(
        '10.255.255.1',
        12345,
      );

      final elapsed = stopwatch.elapsedMilliseconds;
      expect(result, false);
      expect(elapsed, greaterThanOrEqualTo(2900)); // 약간의 여유를 둠
      expect(elapsed, lessThan(3500)); // 타임아웃 후 약간의 처리 시간 허용
    });

    test('invalid hostname should fail quickly', () async {
      final stopwatch = Stopwatch()..start();

      final result = await ElectrumHealthChecker.checkConnection(
        'non-existent-server.example',
        12345,
      );

      final elapsed = stopwatch.elapsedMilliseconds;
      expect(result, false);
      expect(elapsed, lessThan(1000)); // DNS 실패는 빠르게 발생해야 함
    });

    test('valid server connection should complete quickly', () async {
      final stopwatch = Stopwatch()..start();

      final result = await ElectrumHealthChecker.checkConnection(
        'blockstream.info',
        700,
      );

      final elapsed = stopwatch.elapsedMilliseconds;
      expect(result, true);
      expect(elapsed, lessThan(3000)); // 정상적인 서버는 3초 이내 응답
    });
  });
}
