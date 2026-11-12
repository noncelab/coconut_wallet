import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoalPlanMath', () {
    int count(DateTime first, DateTime deadline, GoalPlanCycle cycle) =>
        GoalPlanMath.occurrences(first: first, deadline: deadline, cycle: cycle);

    test('a preset deadline keeps the day or falls back to the last day of a shorter month', () {
      expect(GoalPlanMath.presetDeadline(DateTime(2026, 11, 11), GoalPlanPeriod.threeMonths), DateTime(2027, 2, 11));
      expect(GoalPlanMath.presetDeadline(DateTime(2027, 1, 31), GoalPlanPeriod.oneMonth), DateTime(2027, 2, 28));
      expect(
        GoalPlanMath.presetDeadline(DateTime(2026, 11, 11, 23, 59), GoalPlanPeriod.oneYear),
        DateTime(2027, 11, 11),
      );
      expect(GoalPlanMath.presetDeadline(DateTime(2028, 2, 29), GoalPlanPeriod.oneYear), DateTime(2029, 2, 28));
    });

    test('counts from the first day up to the day before the deadline', () {
      final today = DateTime(2026, 11, 12);
      expect(count(today, DateTime(2026, 12, 12), GoalPlanCycle.daily), 30);
      // 11/12, 11/19, 11/26, 12/3, 12/10
      expect(count(today, DateTime(2026, 12, 12), GoalPlanCycle.weekly), 5);
      expect(count(today, DateTime(2026, 12, 12), GoalPlanCycle.monthly), 1);
      expect(count(today, DateTime(2027, 2, 12), GoalPlanCycle.weekly), 14);
      expect(count(today, DateTime(2027, 2, 12), GoalPlanCycle.monthly), 3);
      // 28일짜리 2월의 1개월·매주
      expect(count(DateTime(2027, 1, 31), DateTime(2027, 2, 28), GoalPlanCycle.weekly), 4);
      // 시각은 보지 않는다.
      expect(count(DateTime(2026, 11, 12, 23, 59), DateTime(2026, 11, 19), GoalPlanCycle.weekly), 1);
    });

    test('a 50-year plan counts every calendar day and week', () {
      // 서머타임이 바뀌는 날이 수십 번 끼어도 달력 날짜 수와 같다(TZ=Europe/Berlin으로도 돌린다).
      final first = DateTime(2026, 11, 12);
      final deadline = DateTime(2076, 11, 13);
      final days = DateTime.utc(2076, 11, 13).difference(DateTime.utc(2026, 11, 12)).inDays;
      expect(count(first, deadline, GoalPlanCycle.daily), days);
      expect(count(first, deadline, GoalPlanCycle.weekly), (days + 6) ~/ 7);
      // 2026-11-12부터 2076-11-12까지 매월 12일
      expect(count(first, deadline, GoalPlanCycle.monthly), 601);
      final dates = GoalPlanMath.dates(first: first, deadline: deadline, cycle: GoalPlanCycle.daily);
      expect(dates.last, DateTime(2076, 11, 12));
      // 세는 것은 UTC 날짜로 하지만 내보내는 날짜는 로컬 날짜다.
      expect(dates.every((date) => date == DateTime(date.year, date.month, date.day)), isTrue);
    });

    test('the deadline day is not counted', () {
      final first = DateTime(2026, 11, 12);
      for (final cycle in GoalPlanCycle.values) {
        expect(count(first, first, cycle), 0, reason: '$cycle on the deadline day');
        expect(count(first, DateTime(2026, 11, 11), cycle), 0, reason: '$cycle after the deadline');
        expect(count(first, DateTime(2026, 11, 13), cycle), 1, reason: '$cycle on the day before');
      }
      expect(count(first, DateTime(2026, 11, 19), GoalPlanCycle.weekly), 1);
      expect(count(first, DateTime(2026, 11, 20), GoalPlanCycle.weekly), 2);
    });

    test('monthly dates stay on the first day and use the last day of shorter months', () {
      final first = DateTime(2027, 1, 31);
      expect(GoalPlanMath.dates(first: first, deadline: DateTime(2027, 6, 1), cycle: GoalPlanCycle.monthly).toList(), [
        DateTime(2027, 1, 31),
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 31),
        DateTime(2027, 4, 30),
        DateTime(2027, 5, 31),
      ]);
      expect(count(first, DateTime(2027, 2, 28), GoalPlanCycle.monthly), 1);
      expect(count(first, DateTime(2027, 3, 1), GoalPlanCycle.monthly), 2);
      // 2/28에서 한 달씩 이어 붙이지 않는다(그러면 3/28이 들어간다).
      expect(count(first, DateTime(2027, 3, 30), GoalPlanCycle.monthly), 2);
      expect(count(DateTime(2028, 2, 29), DateTime(2029, 2, 28), GoalPlanCycle.monthly), 12);
    });

    test('a preset and a custom date on the same deadline count the same', () {
      final first = DateTime(2027, 1, 31);
      final preset = GoalPlanMath.presetDeadline(first, GoalPlanPeriod.threeMonths);
      expect(preset, DateTime(2027, 4, 30));
      expect(count(first, preset, GoalPlanCycle.monthly), 3);
      expect(count(first, DateTime(2027, 4, 30), GoalPlanCycle.monthly), 3);
    });

    test('each installment rounds up, and there is none without a day to save on', () {
      expect(GoalPlanMath.perInstallment(301697149, 13), 23207473);
      expect(GoalPlanMath.perInstallment(10, 3), 4);
      expect(GoalPlanMath.perInstallment(301697149, 13)! * 13, greaterThanOrEqualTo(301697149));
      expect(GoalPlanMath.perInstallment(0, 13), 0);
      expect(GoalPlanMath.perInstallment(-5, 13), 0);
      expect(GoalPlanMath.perInstallment(1000, 0), isNull);
    });
  });
}
