import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoalPlanMath', () {
    test('deadline keeps the day or falls back to the last day of a shorter month', () {
      expect(GoalPlanMath.deadline(DateTime(2026, 11, 11), GoalPlanPeriod.threeMonths), DateTime(2027, 2, 11));
      expect(GoalPlanMath.deadline(DateTime(2027, 1, 31), GoalPlanPeriod.oneMonth), DateTime(2027, 2, 28));
      expect(GoalPlanMath.deadline(DateTime(2026, 11, 11), GoalPlanPeriod.oneYear), DateTime(2027, 11, 11));
    });

    test('installments count calendar days, full weeks or months', () {
      final today = DateTime(2026, 11, 11);
      expect(GoalPlanMath.installments(today, GoalPlanPeriod.threeMonths, GoalPlanCycle.daily), 92);
      expect(GoalPlanMath.installments(today, GoalPlanPeriod.threeMonths, GoalPlanCycle.weekly), 13);
      expect(GoalPlanMath.installments(today, GoalPlanPeriod.threeMonths, GoalPlanCycle.monthly), 3);
      expect(GoalPlanMath.installments(today, GoalPlanPeriod.oneMonth, GoalPlanCycle.monthly), 1);
    });

    test('a custom date sets the deadline and counts whole months', () {
      final today = DateTime(2026, 11, 11);
      final date = DateTime(2031, 5, 20, 15, 30);
      expect(GoalPlanMath.deadline(today, GoalPlanPeriod.custom, customDate: date), DateTime(2031, 5, 20));
      expect(GoalPlanMath.installments(today, GoalPlanPeriod.custom, GoalPlanCycle.monthly, customDate: date), 54);
      expect(
        GoalPlanMath.installments(
          today,
          GoalPlanPeriod.custom,
          GoalPlanCycle.monthly,
          customDate: DateTime(2031, 5, 10),
        ),
        53,
      );
      expect(
        GoalPlanMath.installments(
          today,
          GoalPlanPeriod.custom,
          GoalPlanCycle.daily,
          customDate: DateTime(2026, 11, 12),
        ),
        1,
      );
    });

    test('each installment rounds up so the total covers the remaining amount', () {
      expect(GoalPlanMath.perInstallment(301697149, 13), 23207473);
      expect(GoalPlanMath.perInstallment(10, 3), 4);
      expect(GoalPlanMath.perInstallment(301697149, 13) * 13, greaterThanOrEqualTo(301697149));
      expect(GoalPlanMath.perInstallment(0, 13), 0);
      expect(GoalPlanMath.perInstallment(-5, 13), 0);
    });
  });
}
