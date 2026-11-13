import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _nov12 = DateTime(2026, 11, 12);

Future<void> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  await SharedPrefsRepository().init();
}

String? _saved(String key) =>
    SharedPrefsRepository().getString(key).isEmpty ? null : SharedPrefsRepository().getString(key);

void main() {
  setUp(() => LocaleSettings.setLocaleRawSync('ko'));

  group('GoalPlanController', () {
    test('reading the saved plan does not save anything', () async {
      await _prefs({});
      final plan = GoalPlanController();
      expect(plan.savedDeadline, isNull);
      expect(plan.needsSettleOn(_nov12), isTrue);
      expect(plan.periodOn(_nov12), GoalPlanPeriod.threeMonths);
      expect(plan.deadlineOn(_nov12), DateTime(2027, 2, 12));
      expect(_saved(SharedPrefKeys.kGoalPlanDeadline), isNull);
      expect(_saved(SharedPrefKeys.kGoalPlanPeriod), isNull);
    });

    test('an expired plan stays readable until it is renewed, and renewing returns it', () async {
      await _prefs({
        SharedPrefKeys.kGoalPlanPeriod: GoalPlanPeriod.sixMonths.name,
        SharedPrefKeys.kGoalPlanDeadline: '2026-11-12',
      });
      final plan = GoalPlanController();
      // 알림이 있으면 이 사이에 지난 계획의 알림을 먼저 끈다.
      expect(plan.isExpiredOn(_nov12), isTrue);
      expect(plan.isExpiredOn(DateTime(2026, 11, 11)), isFalse);
      expect(plan.savedDeadline, DateTime(2026, 11, 12));
      expect(plan.periodOn(_nov12), GoalPlanPeriod.threeMonths);
      expect(plan.occurrencesOn(_nov12, first: DateTime(2026, 11, 12)), 14);
      expect(_saved(SharedPrefKeys.kGoalPlanDeadline), '2026-11-12');

      expect(plan.settle(_nov12), DateTime(2026, 11, 12));
      expect(plan.savedDeadline, DateTime(2027, 2, 12));
      expect(plan.isExpiredOn(_nov12), isFalse);
      expect(plan.settle(_nov12), isNull);
      await pumpEventQueue();
      expect(_saved(SharedPrefKeys.kGoalPlanDeadline), '2027-02-12');
      expect(_saved(SharedPrefKeys.kGoalPlanPeriod), GoalPlanPeriod.threeMonths.name);
    });

    // 숫자, 날짜가 아닌 글자, 없는 날(2/31), 날짜 선택의 마지막 날(2076-11-13) 뒤
    for (final value in <Object>[17, 'not-a-date', '2027-02-31', '2076-11-14', '2077-01-01', '2090-01-01']) {
      test('a broken or too far saved date counts as no plan ($value)', () async {
        await _prefs({
          SharedPrefKeys.kGoalPlanPeriod: GoalPlanPeriod.custom.name,
          SharedPrefKeys.kGoalPlanDeadline: value,
        });
        final plan = GoalPlanController();
        expect(plan.needsSettleOn(_nov12), isTrue);
        expect(plan.periodOn(_nov12), GoalPlanPeriod.threeMonths);
        expect(plan.deadlineOn(_nov12), DateTime(2027, 2, 12));
      });
    }

    test('the first save weekday is a calendar day, also when summer time ends', () async {
      // 미국 동부는 2026-11-01에 서머타임이 끝나 이날이 25시간이다. 서울 시간대에서는 하루를 Duration으로 더해도
      // 통과하므로, 그 회귀는 New York으로 돌려야 잡힌다:
      //   TZ=America/New_York fvm flutter test test/widgets/features/home/widgets/goal_plan_controller_test.dart
      await _prefs({
        SharedPrefKeys.kGoalPlanPeriod: GoalPlanPeriod.custom.name,
        SharedPrefKeys.kGoalPlanDeadline: '2026-11-02',
        SharedPrefKeys.kGoalPlanCycle: GoalPlanCycle.weekly.name,
        SharedPrefKeys.kGoalPlanWeekday: '${DateTime.monday}',
      });
      final plan = GoalPlanController();
      // 2026-10-31(토)부터 처음 오는 월요일은 11-02이고, 마감일 당일은 세지 않아 0번이다.
      final today = DateTime(2026, 10, 31);
      expect(plan.firstSaveDayOn(today), DateTime(2026, 11, 2));
      expect(plan.occurrencesOn(today), 0);
    });

    test('the last day the date picker allows is kept', () async {
      await _prefs({
        SharedPrefKeys.kGoalPlanPeriod: GoalPlanPeriod.custom.name,
        SharedPrefKeys.kGoalPlanDeadline: '2076-11-13',
      });
      final plan = GoalPlanController();
      expect(plan.needsSettleOn(_nov12), isFalse);
      expect(plan.periodOn(_nov12), GoalPlanPeriod.custom);
      expect(plan.deadlineOn(_nov12), DateTime(2076, 11, 13));
    });

    test('a period or cycle saved as a number counts as not saved', () async {
      await _prefs({SharedPrefKeys.kGoalPlanPeriod: 17, SharedPrefKeys.kGoalPlanCycle: 17});
      final plan = GoalPlanController();
      expect(plan.cycle, GoalPlanCycle.weekly);
      expect(plan.periodOn(_nov12), GoalPlanPeriod.threeMonths);
    });

    test('the old custom date key of earlier builds is not read', () async {
      await _prefs({SharedPrefKeys.kGoalPlanPeriod: GoalPlanPeriod.custom.name, 'GOAL_PLAN_CUSTOM_DATE': '2027-03-01'});
      final plan = GoalPlanController();
      expect(plan.periodOn(_nov12), GoalPlanPeriod.threeMonths);
      expect(plan.deadlineOn(_nov12), DateTime(2027, 2, 12));
    });

    test('picking the period that was left without a deadline still fixes one', () async {
      await _prefs({SharedPrefKeys.kGoalPlanPeriod: GoalPlanPeriod.sixMonths.name});
      final plan = GoalPlanController();
      plan.selectPeriod(GoalPlanPeriod.sixMonths, today: _nov12);
      expect(plan.periodOn(_nov12), GoalPlanPeriod.sixMonths);
      expect(plan.savedDeadline, DateTime(2027, 5, 12));
    });
  });

  group('GoalPlanCard', () {
    Future<void> pump(WidgetTester tester, {required int remainingSats, DateTime? first}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: GoalPlanCard(
                remainingSats: remainingSats,
                clock: () => _nov12,
                first: first,
                amountText: (sats) => '$sats sats',
                fiatText: (_) => '₩ 1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a first saving day on or after the deadline shows no amount', (tester) async {
      await _prefs({SharedPrefKeys.kGoalPlanDeadline: '2027-02-12'});
      await pump(tester, remainingSats: 50000000, first: DateTime(2027, 2, 12));
      expect(find.byKey(const Key('goal-plan-until')), findsOneWidget);
      expect(find.byKey(const Key('goal-plan-per')), findsNothing);
      expect(find.byKey(const Key('goal-plan-count')), findsNothing);
      expect(find.textContaining('50000000'), findsNothing);

      // 마감일 전 월요일부터면 그 날들로 나눈다(11/16, 23, 30, 12/7 … 2/8).
      await pump(tester, remainingSats: 50000000, first: DateTime(2026, 11, 16));
      expect(
        tester.widget<Text>(find.byKey(const Key('goal-plan-count'))).data,
        contains(t.hodl_insights.goal_plan_count(count: 13)),
      );
    });

    testWidgets('a reached goal does not fix a plan', (tester) async {
      await _prefs({});
      await pump(tester, remainingSats: 0);
      expect(find.byKey(const Key('goal-plan-reached')), findsOneWidget);
      expect(_saved(SharedPrefKeys.kGoalPlanDeadline), isNull);
    });
  });
}
