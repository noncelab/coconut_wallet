import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('달성률은 정수로 소수 첫째 자리까지 버린다', () {
    expect(formatGoalPercentOf(0, 100000000), '0.0%');
    expect(formatGoalPercentOf(42390000, 100000000), '42.3%');
    expect(formatGoalPercentOf(99950000, 100000000), '99.9%');
    expect(formatGoalPercentOf(99999999, 100000000), '99.9%');
    expect(formatGoalPercentOf(100000000, 100000000), '100.0%');
    expect(formatGoalPercentOf(150000000, 100000000), '150.0%');
  });

  test('아주 큰 목표도 1 sat 모자라면 100.0%가 아니다', () {
    const target = 1000000000000; // 10,000 BTC
    expect(formatGoalPercentOf(target - 1, target), '99.9%');
    const maxSupply = 2100000000000000; // 2,100만 BTC
    expect(formatGoalPercentOf(maxSupply - 1, maxSupply), '99.9%');
    expect(formatGoalPercentOf(maxSupply, maxSupply), '100.0%');
  });

  test('목표가 없거나 잔액이 음수면 0.0%', () {
    expect(formatGoalPercentOf(5, 0), '0.0%');
    expect(formatGoalPercentOf(-5, 100), '0.0%');
  });
}
