import 'package:coconut_design_system/coconut_design_system.dart' show CoconutSegmentedControl;
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 마감일 저장 키. 이름이 바뀌면 사용자가 정한 계획을 잃으므로 문자열로 고정한다.
const _deadlineKey = 'GOAL_PLAN_DEADLINE';

final _nov12 = DateTime(2026, 11, 12);

Future<void> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  await SharedPrefsRepository().init();
}

/// 카드를 그린다. [key]가 같으면 같은 카드를 새 날짜로 다시 그리고(화면을 연 채 날짜가 바뀜),
/// 없으면 새 카드를 만든다(화면을 다시 열어 저장된 계획을 다시 읽음).
Future<void> _open(WidgetTester tester, DateTime today, {Key? key}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: GoalPlanCard(
            key: key ?? UniqueKey(),
            remainingSats: 50000000,
            clock: () => today,
            amountText: (sats) => '$sats sats',
            fiatText: (_) => null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _until(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('goal-plan-until'))).data!;

String _count(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('goal-plan-count'))).data!;

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocaleRawSync('ko'));

  testWidgets('a preset keeps the deadline picked that day', (tester) async {
    await _prefs({});
    await _open(tester, _nov12);
    await _tap(tester, 'goal-plan-period-sixMonths');
    final picked = _until(tester);

    // 한 달 뒤에 다시 열어도 그날 정한 마감일 그대로
    await _open(tester, DateTime(2026, 12, 12));
    expect(_until(tester), picked);
    expect(picked, contains('2027.05.12'));
  });

  testWidgets('the default plan is fixed on the day it is first shown', (tester) async {
    await _prefs({});
    await _open(tester, _nov12);
    final first = _until(tester);

    await _open(tester, DateTime(2026, 11, 13));
    expect(_until(tester), first);
    expect(first, contains('2027.02.12'));
    expect(SharedPrefsRepository().getString(_deadlineKey), '2027-02-12');
  });

  testWidgets('a period left without a deadline starts the default plan', (tester) async {
    await _prefs({SharedPrefKeys.kGoalPlanPeriod: GoalPlanPeriod.sixMonths.name});
    await _open(tester, _nov12);
    final first = _until(tester);

    await _open(tester, DateTime(2026, 12, 12));
    expect(_until(tester), first);
    expect(first, contains('2027.02.12'));
    expect(SharedPrefsRepository().getString(SharedPrefKeys.kGoalPlanPeriod), GoalPlanPeriod.threeMonths.name);
  });

  testWidgets('a custom date saved by earlier builds is not used', (tester) async {
    await _prefs({SharedPrefKeys.kGoalPlanPeriod: GoalPlanPeriod.custom.name, 'GOAL_PLAN_CUSTOM_DATE': '2027-03-01'});
    await _open(tester, _nov12);
    expect(_until(tester), contains('2027.02.12'));
    expect(find.byKey(const Key('goal-plan-custom-date')), findsNothing);
  });

  testWidgets('a deadline that has come quietly resets to three months from today', (tester) async {
    // 지난 날과 마감일 당일(남은 날이 없다)
    for (final saved in ['2026-11-11', '2026-11-12']) {
      await _prefs({SharedPrefKeys.kGoalPlanPeriod: GoalPlanPeriod.sixMonths.name, _deadlineKey: saved});
      await _open(tester, _nov12);
      expect(SharedPrefsRepository().getString(SharedPrefKeys.kGoalPlanPeriod), GoalPlanPeriod.threeMonths.name);
      expect(SharedPrefsRepository().getString(_deadlineKey), '2027-02-12', reason: saved);
      expect(_until(tester), contains('2027.02.12'), reason: saved);
    }
  });

  testWidgets('a screen left open across days matches opening it again', (tester) async {
    await _prefs({});
    const card = ValueKey('card');
    await _open(tester, _nov12, key: card);
    final picked = _until(tester);

    // 다음 달이 되어도 같은 카드는 정한 마감일 그대로
    await _open(tester, DateTime(2026, 12, 12), key: card);
    expect(_until(tester), picked);

    // 마감일 당일이 되면 그 자리에서 새 3개월로 정하고 저장한다. 다시 연 화면과 같다.
    await _open(tester, DateTime(2027, 2, 12), key: card);
    final renewed = _until(tester);
    expect(renewed, contains('2027.05.12'));
    expect(SharedPrefsRepository().getString(_deadlineKey), '2027-05-12');
    await _open(tester, DateTime(2027, 2, 12));
    expect(_until(tester), renewed);
  });

  testWidgets('counts the saves from today up to the day before the deadline', (tester) async {
    await _prefs({});
    // 기본 3개월·매주: 11/12부터 2/11까지 14회
    await _open(tester, _nov12);
    expect(_count(tester), t.hodl_insights.goal_plan_count(count: 14));

    // 1개월·매주: 11/12, 11/19, 11/26, 12/3, 12/10
    await _tap(tester, 'goal-plan-period-oneMonth');
    expect(_count(tester), t.hodl_insights.goal_plan_count(count: 5));
    expect(find.text('10000000 sats'), findsOneWidget);

    // 1개월·매월: 마감일 당일은 세지 않는다.
    await _tap(tester, 'goal-plan-cycle-monthly');
    expect(_count(tester), t.hodl_insights.goal_plan_count(count: 1));
    expect(find.text('50000000 sats'), findsOneWidget);
  });

  testWidgets('a preset and a custom date on the same deadline divide the same', (tester) async {
    await _prefs({});
    // 1/31부터 3개월(4/30)·매월: 1/31, 2/28, 3/31
    await _open(tester, DateTime(2027, 1, 31));
    await _tap(tester, 'goal-plan-cycle-monthly');
    expect(_count(tester), t.hodl_insights.goal_plan_count(count: 3));

    // 같은 4/30을 직접 고른다(시트는 지금 마감일로 열린다).
    await _tap(tester, 'goal-plan-period-custom');
    await tester.tap(find.byKey(const Key('goal-plan-date-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-plan-custom-date')), findsOneWidget);
    expect(_count(tester), t.hodl_insights.goal_plan_count(count: 3));
    expect(find.text('16666667 sats'), findsOneWidget);
    expect(_until(tester), contains('2027.04.30'));
  });

  testWidgets('the deadline shows as yyyy.MM.dd', (tester) async {
    await _prefs({});
    await _open(tester, DateTime(2026, 11, 5));
    expect(_until(tester), contains('2027.02.05'));
  });

  testWidgets('the date picker starts the next calendar day, also when summer time ends', (tester) async {
    await _prefs({});
    // 유럽은 2026-10-25에 서머타임이 끝나 이날이 25시간이다. 서울 시간대에서는 하루를 Duration(days: 1)로
    // 더해도 통과하므로, 그 회귀는 Berlin으로 돌려야 잡힌다:
    //   TZ=Europe/Berlin fvm flutter test test/widgets/features/home/widgets/goal_plan_card_test.dart
    await _open(tester, DateTime(2026, 10, 25));
    await _tap(tester, 'goal-plan-period-custom');
    final picker = tester.widget<CupertinoDatePicker>(find.byKey(const Key('goal-plan-date-picker')));
    expect(picker.minimumDate, DateTime(2026, 10, 26));
  });

  testWidgets('closing the date sheet without a date keeps the previous period selected', (tester) async {
    await _prefs({});
    await _open(tester, _nov12);
    double highlight() =>
        tester
            .widget<Positioned>(
              find.descendant(of: find.byType(CoconutSegmentedControl).first, matching: find.byType(Positioned)),
            )
            .left!;
    final before = highlight();

    await _tap(tester, 'goal-plan-period-custom');
    expect(find.byKey(const Key('goal-plan-date-picker')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const Key('goal-plan-date-picker')))).pop();
    await tester.pumpAndSettle();

    expect(highlight(), before);
    expect(_until(tester), contains('2027.02.12'));
    expect(find.byKey(const Key('goal-plan-custom-date')), findsNothing);
  });

  testWidgets('the date sheet confirms with the app action button', (tester) async {
    await _prefs({});
    await _open(tester, _nov12);
    await _tap(tester, 'goal-plan-period-custom');
    expect(find.descendant(of: find.byType(InlineActionButton), matching: find.text(t.complete)), findsOneWidget);

    // 처음 열면 지금 마감일이 골라져 있다.
    await tester.tap(find.byKey(const Key('goal-plan-date-done')));
    await tester.pumpAndSettle();
    expect(SharedPrefsRepository().getString(SharedPrefKeys.kGoalPlanPeriod), GoalPlanPeriod.custom.name);
    expect(SharedPrefsRepository().getString(_deadlineKey), '2027-02-12');
    expect(tester.widget<Text>(find.byKey(const Key('goal-plan-custom-date-text'))).data, '2027.02.12');
  });

  test('a password reset clears the whole saving plan', () {
    expect(SharedPrefKeys.keysToReset, containsAll([SharedPrefKeys.kGoalPlanPeriod, SharedPrefKeys.kGoalPlanCycle]));
    expect(SharedPrefKeys.keysToReset, contains(_deadlineKey));
  });

  testWidgets('a deadline that has passed shows a one-line reason until a new period is picked', (tester) async {
    await _prefs({SharedPrefKeys.kGoalPlanPeriod: GoalPlanPeriod.custom.name, _deadlineKey: '2026-11-01'});
    await _open(tester, _nov12);
    final notice = find.byKey(const Key('goal-plan-reset'));
    expect(notice, findsOneWidget);
    // 보이는 글에는 줄바꿈 막는 문자가 들어가고, 화면 읽기에는 원문이 간다.
    expect(find.bySemanticsLabel(t.hodl_insights.goal_plan_reset_notice(date: '2026.11.01')), findsOneWidget);
    // 날짜 시트를 열었다가 고르지 않고 닫으면 그대로 둔다.
    await _tap(tester, 'goal-plan-period-custom');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(notice, findsOneWidget);
    await _tap(tester, 'goal-plan-period-${GoalPlanPeriod.sixMonths.name}');
    expect(notice, findsNothing);
  });

  testWidgets('a far-future date that cannot be picked is reset without saying it has passed', (tester) async {
    await _prefs({SharedPrefKeys.kGoalPlanPeriod: GoalPlanPeriod.custom.name, _deadlineKey: '2090-01-01'});
    await _open(tester, _nov12);
    expect(find.byKey(const Key('goal-plan-reset')), findsNothing);
  });

  testWidgets('a weekly plan counts from the picked save weekday, today included and the deadline excluded', (
    tester,
  ) async {
    // 2026-11-12는 목요일, 기본 3개월 마감일은 2027-02-12(금)
    await _prefs({SharedPrefKeys.kGoalPlanCycle: GoalPlanCycle.weekly.name});
    await _open(tester, _nov12);
    expect(find.text(t.hodl_insights.goal_plan_weekdays[DateTime.thursday - 1]), findsOneWidget);
    expect(SharedPrefsRepository().getString(SharedPrefKeys.kGoalPlanWeekday), '${DateTime.thursday}');
    expect(_count(tester), contains(t.hodl_insights.goal_plan_count(count: 14)));
    await _tap(tester, 'goal-plan-weekday');
    await _tap(tester, 'goal-plan-weekday-${DateTime.friday}');
    expect(SharedPrefsRepository().getString(SharedPrefKeys.kGoalPlanWeekday), '${DateTime.friday}');
    expect(find.text(t.hodl_insights.goal_plan_weekdays[DateTime.friday - 1]), findsOneWidget);
    // 금요일은 11-13부터, 마감일(02-12) 당일은 빼서 13번
    expect(_count(tester), contains(t.hodl_insights.goal_plan_count(count: 13)));
  });

  testWidgets('the save weekday sheet scrolls with large text on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _prefs({SharedPrefKeys.kGoalPlanCycle: GoalPlanCycle.weekly.name});
    await _open(tester, _nov12);
    await _tap(tester, 'goal-plan-weekday');
    expect(tester.takeException(), isNull);
    // 마지막 일요일 줄까지 내려 고를 수 있다
    await _tap(tester, 'goal-plan-weekday-${DateTime.sunday}');
    expect(SharedPrefsRepository().getString(SharedPrefKeys.kGoalPlanWeekday), '${DateTime.sunday}');
  });

  testWidgets('a monthly plan keeps the picked save day from 1 to 28', (tester) async {
    await _prefs({SharedPrefKeys.kGoalPlanCycle: GoalPlanCycle.monthly.name});
    await _open(tester, _nov12);
    expect(find.text(t.hodl_insights.goal_plan_day_value(day: 12)), findsOneWidget);
    await _tap(tester, 'goal-plan-day');
    await tester.drag(find.byKey(const Key('goal-plan-day-picker')), const Offset(0, -40));
    await tester.pumpAndSettle();
    await _tap(tester, 'goal-plan-day-done');
    expect(SharedPrefsRepository().getString(SharedPrefKeys.kGoalPlanDay), '13');
    expect(find.text(t.hodl_insights.goal_plan_day_value(day: 13)), findsOneWidget);
  });

  testWidgets('a filled goal that is not reached yet says the balance is being checked, whatever the reason', (
    tester,
  ) async {
    await _prefs({});
    String? notice() {
      final notice = tester.widget<Text>(
        find.descendant(of: find.byKey(const Key('goal-plan-pending')), matching: find.byType(Text)).first,
      );
      return notice.semanticsLabel;
    }

    {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: GoalPlanCard(
                key: UniqueKey(),
                remainingSats: 0,
                clock: () => _nov12,
                amountText: (sats) => '$sats sats',
                fiatText: (_) => null,
                awaitingConfirmation: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 입금인지 송금인지·동기화 중인지 가리지 않는 한 문구(F1)
      expect(notice(), t.hodl_insights.goal_plan_pending);
    }
  });
}
