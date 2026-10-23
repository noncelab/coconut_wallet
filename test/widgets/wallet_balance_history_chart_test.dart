import 'package:coconut_wallet/widgets/wallet_balance_history_chart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distant target preserves the balance range', () {
    final range = walletBalanceChartRange([100, 150, 200], 10000);
    expect(range.minimum, 100);
    expect(range.maximum, 200);
    expect(range.targetAbove, isTrue);
  });

  test('nearby target extends the range and remains a real goal line', () {
    final range = walletBalanceChartRange([100, 200], 225);
    expect(range.maximum, 225);
    expect(range.targetAbove, isFalse);
    expect(range.targetBelow, isFalse);
  });

  test('in-range target does not force the axis to zero', () {
    final range = walletBalanceChartRange([100, 200], 150);
    expect(range.minimum, 100);
    expect(range.maximum, 200);
  });

  test('target far below balances preserves the range', () {
    final range = walletBalanceChartRange([100, 200], 1);
    expect(range.minimum, 100);
    expect(range.targetBelow, isTrue);
  });

  test('flat and zero balances have a finite range without fitting a distant target', () {
    for (final balance in [0, 100]) {
      final range = walletBalanceChartRange([balance, balance], 10000);
      expect(range.maximum, greaterThan(range.minimum));
      expect(range.maximum, lessThan(10000));
      expect(range.targetAbove, isTrue);
    }
  });

  test('missing or invalid targets do not change the range', () {
    for (final target in [null, 0, -1]) {
      final range = walletBalanceChartRange([100, 200], target);
      expect(range.minimum, 100);
      expect(range.maximum, 200);
      expect(range.targetAbove || range.targetBelow, isFalse);
    }
  });
}
