import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/goal_reminder/goal_reminder.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart'
    show GoalPlanController, GoalPlanCycle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GoalReminderSchedule.next', () {
    const settings = GoalReminderSettings(hour: 21, minute: 0, weekday: DateTime.monday, dayOfMonth: 15);

    test('daily fires today if the time is still ahead, otherwise tomorrow', () {
      expect(
        GoalReminderSchedule.next(DateTime(2026, 11, 11, 20, 59), settings, GoalPlanCycle.daily),
        DateTime(2026, 11, 11, 21),
      );
      expect(
        GoalReminderSchedule.next(DateTime(2026, 11, 11, 21), settings, GoalPlanCycle.daily),
        DateTime(2026, 11, 12, 21),
      );
    });

    test('weekly fires on the next chosen weekday', () {
      // 2026-11-11 is a Wednesday.
      expect(
        GoalReminderSchedule.next(DateTime(2026, 11, 11, 9), settings, GoalPlanCycle.weekly),
        DateTime(2026, 11, 16, 21),
      );
      // Monday after the time has passed moves to the following Monday.
      expect(
        GoalReminderSchedule.next(DateTime(2026, 11, 16, 22), settings, GoalPlanCycle.weekly),
        DateTime(2026, 11, 23, 21),
      );
    });

    test('monthly fires on the chosen day this month or next month', () {
      expect(
        GoalReminderSchedule.next(DateTime(2026, 11, 11), settings, GoalPlanCycle.monthly),
        DateTime(2026, 11, 15, 21),
      );
      expect(
        GoalReminderSchedule.next(DateTime(2026, 12, 20), settings, GoalPlanCycle.monthly),
        DateTime(2027, 1, 15, 21),
      );
    });
  });

  group('GoalReminderSchedule.upcoming', () {
    const settings = GoalReminderSettings(hour: 9, minute: 30, weekday: DateTime.monday, dayOfMonth: 28);
    final now = DateTime(2026, 11, 12, 10);

    test('stops on the day before the deadline, at the same local time', () {
      final daily = GoalReminderSchedule.upcoming(now, settings, GoalPlanCycle.daily, until: DateTime(2026, 11, 16));
      expect(daily, [
        for (final day in [13, 14, 15]) DateTime(2026, 11, day, 9, 30),
      ]);
      final monthly = GoalReminderSchedule.upcoming(now, settings, GoalPlanCycle.monthly, until: DateTime(2027, 2, 28));
      expect(monthly, [DateTime(2026, 11, 28, 9, 30), DateTime(2026, 12, 28, 9, 30), DateTime(2027, 1, 28, 9, 30)]);
    });

    test('holds at most a month of daily reminders and none once the deadline has come', () {
      final far = GoalReminderSchedule.upcoming(now, settings, GoalPlanCycle.daily, until: DateTime(2027, 11, 12));
      expect(far.length, GoalReminderSchedule.maxScheduled);
      // 서머타임이 끝나는 날(미국 11.1)을 지나도 같은 현지 시각
      final overDst = GoalReminderSchedule.upcoming(DateTime(2026, 10, 30), settings, GoalPlanCycle.daily);
      expect(overDst.every((at) => at.hour == 9 && at.minute == 30), isTrue);
      expect(
        GoalReminderSchedule.upcoming(now, settings, GoalPlanCycle.weekly, until: DateTime(2026, 11, 12)),
        isEmpty,
      );
    });
  });

  group('GoalReminderSettings', () {
    test('round-trips through JSON and falls back on bad values', () {
      const settings = GoalReminderSettings(
        enabled: true,
        hour: 7,
        minute: 30,
        weekday: DateTime.friday,
        dayOfMonth: 28,
        showAmount: true,
      );
      expect(GoalReminderSettings.fromJsonString(jsonEncode(settings.toJson())), settings);
      expect(GoalReminderSettings.fromJsonString(null), const GoalReminderSettings());
      expect(GoalReminderSettings.fromJsonString('not json'), const GoalReminderSettings());
      final broken = GoalReminderSettings.fromJsonString(jsonEncode({'enabled': true, 'hour': 30, 'dayOfMonth': 31}));
      expect(broken.enabled, isTrue);
      expect(broken.hour, const GoalReminderSettings().hour);
      expect(broken.dayOfMonth, const GoalReminderSettings().dayOfMonth);
    });

    test('hides the amount by default', () {
      expect(const GoalReminderSettings().showAmount, isFalse);
    });

    test('keeps why the app turned it off until the user turns it back on', () {
      const off = GoalReminderSettings(offReason: GoalReminderOffReason.reached);
      expect(GoalReminderSettings.fromJsonString(jsonEncode(off.toJson())).offReason, GoalReminderOffReason.reached);
      expect(off.copyWith(hour: 8).offReason, GoalReminderOffReason.reached);
      expect(off.copyWith(enabled: true).offReason, isNull);
      // 켜진 설정에는 이유가 남지 않는다(잘못 저장된 값도)
      final saved = GoalReminderSettings.fromJsonString(jsonEncode({'enabled': true, 'offReason': 'reached'}));
      expect(saved.offReason, isNull);
    });
  });

  group('GoalReminderContent', () {
    setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

    test('gives the planned amount with the date it was checked only when asked, under a neutral title', () {
      final withAmount = GoalReminderContent.of(GoalPlanCycle.weekly, amount: '0.01 BTC', asOf: '2026.11.12');
      final withoutAmount = GoalReminderContent.of(GoalPlanCycle.weekly);
      expect(withAmount.body, contains('0.01 BTC'));
      expect(withAmount.body, contains('2026.11.12'));
      expect(withoutAmount.body, isNot(contains('BTC')));
      expect(withAmount.title, t.hodl_insights.goal_reminder_title);
      expect(withoutAmount.title, t.hodl_insights.goal_reminder_title);
    });
  });

  group('GoalReminderController.sync', () {
    test('never touches the plugin when the reminder was never turned on', () async {
      final scheduler = _CountingScheduler();
      final controller = GoalReminderController(scheduler: scheduler);
      await controller.sync(GoalPlanCycle.weekly, const GoalReminderContent('t', 'b'));
      await controller.sync(GoalPlanCycle.daily, const GoalReminderContent('t', 'b'));
      expect(scheduler.calls, 0);
    });

    test('does not retry on every redraw after a failure', () async {
      final scheduler = _CountingScheduler(fail: true);
      final controller = GoalReminderController(scheduler: scheduler);
      await controller.setEnabled(true);
      const content = GoalReminderContent('t', 'b');
      await controller.sync(GoalPlanCycle.weekly, content);
      await controller.sync(GoalPlanCycle.weekly, content);
      expect(scheduler.calls, 1);
    });

    test('the app turns it off with a reason and only the user turns it back on', () async {
      final controller = GoalReminderController(scheduler: _CountingScheduler());
      // 이미 꺼져 있으면 이유를 남기지 않는다(사용자가 끈 알림)
      controller.turnOff(GoalReminderOffReason.reached);
      expect(controller.settings.offReason, isNull);
      await controller.setEnabled(true);
      controller.turnOff(GoalReminderOffReason.deadlinePassed);
      expect(controller.settings.enabled, isFalse);
      expect(controller.settings.offReason, GoalReminderOffReason.deadlinePassed);
      await controller.setEnabled(true);
      expect(controller.settings.offReason, isNull);
    });

    test('schedules on the plan save day', () async {
      final scheduler = _CountingScheduler();
      final controller = GoalReminderController(scheduler: scheduler);
      await controller.setEnabled(true);
      await controller.sync(
        GoalPlanCycle.weekly,
        const GoalReminderContent('t', 'b'),
        weekday: DateTime.thursday,
        dayOfMonth: 12,
      );
      expect(scheduler.last?.weekday, DateTime.thursday);
      expect(scheduler.last?.dayOfMonth, 12);
    });

    test('a failed reschedule is retried by a later sync, not by every redraw', () async {
      // Astra B2-실패: 수량을 넣은 예약 → 가림으로 수량을 빼는 예약이 한 번 실패 → 같은 상태의 다음 맞춤에서 다시 시도
      var clock = DateTime(2026, 11, 12, 10);
      final scheduler = _CountingScheduler();
      final controller = GoalReminderController(scheduler: scheduler, clock: () => clock);
      await controller.setEnabled(true);
      const amount = GoalReminderContent('t', '0.01 BTC (2026.11.12)');
      const neutral = GoalReminderContent('t', 'saving day');
      await controller.sync(GoalPlanCycle.weekly, amount);
      scheduler.failNext = 1;
      await controller.sync(GoalPlanCycle.weekly, neutral);
      expect(scheduler.scheduled, amount);
      // 바로 다시 그려도 플러그인을 부르지 않는다
      await controller.sync(GoalPlanCycle.weekly, neutral);
      expect(scheduler.calls, 2);
      // 잠시 뒤 앱 복귀·잔액 갱신에서 다시 시도해 수량을 뺀다
      clock = clock.add(GoalReminderController.retryAfter);
      await controller.sync(GoalPlanCycle.weekly, neutral);
      expect((scheduler.calls, scheduler.scheduled), (3, neutral));
      await controller.sync(GoalPlanCycle.weekly, neutral);
      expect(scheduler.calls, 3);
    });

    test('after a partly written schedule fails, going back to the earlier content applies it again', () async {
      // Astra B2-실패: 중립 A 성공 → 수량 B를 쓰다 일부만 쓰고 실패 → 잔액을 가려 A를 다시 맞춤.
      // 9판은 A를 이미 맞춘 것으로 보고 건너뛰어 B 수량이 남았다(F3)
      final scheduler = _CountingScheduler();
      final controller = GoalReminderController(scheduler: scheduler, clock: () => DateTime(2026, 11, 12, 10));
      addTearDown(controller.dispose);
      await controller.setEnabled(true);
      const neutral = GoalReminderContent('t', 'saving day');
      const amount = GoalReminderContent('t', '0.01 BTC (2026.11.12)');
      await controller.sync(GoalPlanCycle.weekly, neutral);
      scheduler.partialFailNext = true;
      await controller.sync(GoalPlanCycle.weekly, amount);
      expect(scheduler.scheduled, amount);
      await controller.sync(GoalPlanCycle.weekly, neutral);
      expect((scheduler.calls, scheduler.scheduled), (3, neutral));
    });

    test('schedules each save day up to the day before the deadline and refills once the next one passes', () async {
      // 11.12(목) 오전, 알림은 목요일 21시, 마감일 12.3(목). 알림은 11.12·11.19·11.26(마감일 당일은 없다)
      var clock = DateTime(2026, 11, 12, 10);
      final scheduler = _CountingScheduler();
      final controller = GoalReminderController(scheduler: scheduler, clock: () => clock);
      await controller.setEnabled(true);
      const content = GoalReminderContent('t', 'b');
      final until = DateTime(2026, 12, 3);
      await controller.sync(GoalPlanCycle.weekly, content, weekday: DateTime.thursday, until: until);
      expect(scheduler.lastTimes, [
        for (final day in [12, 19, 26]) DateTime(2026, 11, day, 21),
      ]);
      // 같은 날 다시 맞춰도 그대로
      await controller.sync(GoalPlanCycle.weekly, content, weekday: DateTime.thursday, until: until);
      expect(scheduler.calls, 1);
      // 첫 알림이 지나면 남은 날로 다시 건다
      clock = DateTime(2026, 11, 13, 8);
      await controller.sync(GoalPlanCycle.weekly, content, weekday: DateTime.thursday, until: until);
      expect(scheduler.calls, 2);
      expect(scheduler.lastTimes, [DateTime(2026, 11, 19, 21), DateTime(2026, 11, 26, 21)]);
    });

    test('cancels once after being turned off', () async {
      final scheduler = _CountingScheduler();
      final controller = GoalReminderController(scheduler: scheduler);
      await controller.setEnabled(true);
      const content = GoalReminderContent('t', 'b');
      await controller.sync(GoalPlanCycle.weekly, content);
      await controller.setEnabled(false);
      await controller.sync(GoalPlanCycle.weekly, content);
      await controller.sync(GoalPlanCycle.daily, content);
      expect(scheduler.cancels, 1);
    });
  });

  // 목표 화면과 앱 전체 알림 맞춤이 같이 쓰는 규칙(리드 11/12)
  group('GoalReminderStatus', () {
    final now = DateTime(2026, 11, 12, 10);
    final lastSync = DateTime(2026, 11, 10, 8);
    const goal = HomeGoalShare(walletId: 1, name: 'w1', balance: 40000000, target: 100000000);

    GoalReminderStatus statusOf(
      HomeGoalSum sum, {
      bool walletsLoaded = true,
      bool hidesBalance = false,
      DateTime? lastSyncedAt,
    }) => GoalReminderStatus.of(
      sum: sum,
      plan: GoalPlanController(),
      now: now,
      walletsLoaded: walletsLoaded,
      hidesBalance: hidesBalance,
      lastSyncedAt: lastSyncedAt,
    );

    test('turns off without a goal only once the wallets are loaded', () {
      final none = HomeGoalSum.of(const []);
      expect(statusOf(none, walletsLoaded: false, lastSyncedAt: lastSync).offReason, isNull);
      expect(statusOf(none, lastSyncedAt: lastSync).offReason, GoalReminderOffReason.noGoal);
    });

    test('dates the planned amount by the last sync, not today, and leaves it out before the first sync', () {
      final status = statusOf(HomeGoalSum.of(const [goal]), lastSyncedAt: lastSync);
      expect(status.amountSats, isNotNull);
      expect(status.asOf, lastSync);
      final body = status.contentFor(GoalPlanCycle.weekly, showAmount: true, amountText: (sats) => '$sats sats').body;
      expect(body, contains('2026.11.10'));
      expect(body, isNot(contains('2026.11.12')));
      final unsynced = statusOf(HomeGoalSum.of(const [goal]));
      expect((unsynced.amountSats, unsynced.asOf, unsynced.block), (null, null, GoalReminderAmountBlock.unsynced));
      expect(
        unsynced.contentFor(GoalPlanCycle.weekly, showAmount: true, amountText: (sats) => '$sats sats').body,
        t.hodl_insights.goal_reminder_body_weekly,
      );
    });

    test('turns off on a reached goal only after a sync and while the wallets of each account agree', () {
      const reached = HomeGoalShare(walletId: 1, name: 'w1', balance: 100000000, target: 100000000, accountKey: 'a');
      expect(statusOf(HomeGoalSum.of(const [reached])).offReason, isNull);
      expect(
        statusOf(HomeGoalSum.of(const [reached]), lastSyncedAt: lastSync).offReason,
        GoalReminderOffReason.reached,
      );
      // 같은 계정의 다른 지갑이 아직 송금을 모르면(잔액이 다름) 어느 쪽이 맞는지 몰라 끄지 않는다
      final unsettled = HomeGoalSum.of(const [
        reached,
        HomeGoalShare(walletId: 2, name: 'w2', balance: 40000000, target: null, accountKey: 'a'),
      ]);
      expect(statusOf(unsettled, lastSyncedAt: lastSync).offReason, isNull);
      // 확인 전 입금으로 넘은 동안에도 끄지 않는다
      const pending = HomeGoalShare(
        walletId: 1,
        name: 'w1',
        balance: 110000000,
        confirmedUnspent: 90000000,
        target: 100000000,
      );
      final status = statusOf(HomeGoalSum.of(const [pending]), lastSyncedAt: lastSync);
      expect((status.offReason, status.block), (null, GoalReminderAmountBlock.pending));
    });

    test('waits to turn off on a reached goal until every goal wallet has finished syncing this time', () {
      const reached = HomeGoalShare(walletId: 1, name: 'w1', balance: 100000000, target: 100000000, synced: false);
      final status = statusOf(HomeGoalSum.of(const [reached]), lastSyncedAt: lastSync);
      // 동기화 전에는 달성이 아니라 잔액 확인 중(결정 ③, 지갑 하나여도)
      expect((status.offReason, status.block), (null, GoalReminderAmountBlock.unsynced));
    });

    test('a goal wallet not synced yet gets no amount from the app-wide sync date', () {
      // Astra B1-a.2: 다른 계정으로 11.10에 동기화, 새 계정은 아직(잔액 0). 앱 전체 날짜로 수량을 만들지 않는다
      const fresh = HomeGoalShare(walletId: 9, name: 'new', balance: 0, target: 100000000, synced: false);
      final status = statusOf(HomeGoalSum.of(const [fresh]), lastSyncedAt: lastSync);
      expect((status.amountSats, status.asOf, status.block), (null, null, GoalReminderAmountBlock.unsynced));
    });

    test('a deposit and a send waiting together do not turn the reminder off as reached', () {
      // Astra B1-a.1: 확인 1.1 가운데 0.3 보내는 중 + 0.2 들어오는 중 → 전체 1.0, 확인되고 남는 것 0.8(목표 1 BTC)
      const mixed = HomeGoalShare(
        walletId: 1,
        name: 'w1',
        balance: 100000000,
        confirmedUnspent: 80000000,
        target: 100000000,
      );
      final status = statusOf(HomeGoalSum.of(const [mixed]), lastSyncedAt: lastSync);
      expect((status.offReason, status.block), (null, GoalReminderAmountBlock.pending));
    });

    test('two wallets of one account that disagree give the balance check as the reason, not a pending deposit', () {
      // 확인 전 입금이 아니라 같은 계정 지갑끼리 잔액이 다름(작은 쪽 1.0 BTC가 이미 목표에 닿음)
      final sum = HomeGoalSum.of(const [
        HomeGoalShare(walletId: 1, name: 'w1', balance: 120000000, target: 100000000, accountKey: 'a'),
        HomeGoalShare(walletId: 2, name: 'w2', balance: 100000000, target: null, accountKey: 'a'),
      ]);
      final status = statusOf(sum, lastSyncedAt: lastSync);
      expect((status.offReason, status.block), (null, GoalReminderAmountBlock.unsynced));
    });

    test('gives one reason for leaving the amount out: hidden, then conflict, then unsynced', () {
      final conflict = HomeGoalSum.of(const [
        HomeGoalShare(walletId: 1, name: 'w1', balance: 1, target: 100000000, accountKey: 'a'),
        HomeGoalShare(walletId: 2, name: 'w2', balance: 1, target: 200000000, accountKey: 'a'),
      ]);
      expect(statusOf(conflict, hidesBalance: true).block, GoalReminderAmountBlock.hidden);
      expect(statusOf(conflict).block, GoalReminderAmountBlock.conflict);
      expect(statusOf(HomeGoalSum.of(const [goal])).block, GoalReminderAmountBlock.unsynced);
    });

    // 저장값을 쓰는 테스트라 마지막에 둔다
    test('turns off once the goal date has come', () async {
      SharedPreferences.setMockInitialValues({SharedPrefKeys.kGoalPlanDeadline: '2026-11-12'});
      SharedPrefsRepository().setSharedPreferencesForTest(await SharedPreferences.getInstance());
      expect(
        statusOf(HomeGoalSum.of(const [goal]), lastSyncedAt: lastSync).offReason,
        GoalReminderOffReason.deadlinePassed,
      );
    });
  });

  // B5 다시 걸기(home-claude Fold 11/16, Fable·Astra 교차): 알림 번호를 날짜에 묶고, 걸어 둔 일정과 같으면 지우지 않고
  // 채우기만 한다. 방금 지난(inexact라 아직 안 울렸을 수 있는) 오늘 알림과 이미 뜬 알림을 지우지 않는다
  group('GoalReminderController keeps today\'s reminder when it refills', () {
    const content = GoalReminderContent('t', 'b');

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        SharedPrefKeys.kGoalReminder: jsonEncode(const GoalReminderSettings(enabled: true).toJson()),
      });
      await SharedPrefsRepository().init();
    });

    List<int> idsOf(List<DateTime> times, GoalPlanCycle cycle) => [
      for (final at in times) LocalGoalReminderScheduler.idOf(at, cycle),
    ];

    test('31 save days in a row get 31 different numbers on every cycle, across daylight saving changes', () {
      // 뉴욕(이 파일을 TZ=America/New_York로도 돌린다)은 2026-11-01(일)과 2027-03-14(일)에 시각이 바뀐다
      const settings = GoalReminderSettings(enabled: true, weekday: DateTime.sunday, dayOfMonth: 1);
      for (final cycle in GoalPlanCycle.values) {
        final days = <DateTime>[];
        var at = GoalReminderSchedule.next(DateTime(2026, 10, 20), settings, cycle);
        while (days.length < LocalGoalReminderScheduler.idSlots) {
          days.add(at);
          at = GoalReminderSchedule.next(at, settings, cycle);
        }
        final ids = idsOf(days, cycle);
        expect(ids.toSet(), hasLength(LocalGoalReminderScheduler.idSlots), reason: cycle.name);
        expect(ids.every((id) => id >= 7101 && id <= 7131), isTrue, reason: cycle.name);
      }
    });

    test('when today\'s reminder time passes it refills without clearing, and leaves today\'s number alone', () async {
      var clock = DateTime(2026, 11, 12, 20);
      final scheduler = _CountingScheduler();
      final controller = GoalReminderController(scheduler: scheduler, clock: () => clock);
      addTearDown(controller.dispose);
      await controller.sync(GoalPlanCycle.daily, content);
      // 처음은 걸어 둔 기록이 없어 전부 지우고 건다
      expect(scheduler.keeps, [false]);
      final today = DateTime(2026, 11, 12, 21);
      expect(scheduler.lastTimes.first, today);
      // 21:01: 오늘 알림 시각이 지났다(아직 안 울렸을 수 있다)
      clock = DateTime(2026, 11, 12, 21, 1);
      await controller.sync(GoalPlanCycle.daily, content);
      expect(scheduler.keeps, [false, true]);
      expect(scheduler.cancels, 0);
      expect(scheduler.lastTimes.first, DateTime(2026, 11, 13, 21));
      expect(
        idsOf(scheduler.lastTimes, GoalPlanCycle.daily),
        isNot(contains(LocalGoalReminderScheduler.idOf(today, GoalPlanCycle.daily))),
      );
    });

    test('opening the app again after the reminder time keeps today\'s reminder too', () async {
      final first = _CountingScheduler();
      final before = GoalReminderController(scheduler: first, clock: () => DateTime(2026, 11, 12, 20));
      await before.sync(GoalPlanCycle.daily, content);
      before.dispose();
      // 21:02에 앱을 다시 연다: 걸어 둔 기록은 저장값에서 읽는다
      final again = _CountingScheduler();
      final after = GoalReminderController(scheduler: again, clock: () => DateTime(2026, 11, 12, 21, 2));
      addTearDown(after.dispose);
      await after.sync(GoalPlanCycle.daily, content);
      expect(again.keeps, [true]);
      expect(again.cancels, 0);
    });

    test('the next day the window moves on by one day, still without clearing', () async {
      var clock = DateTime(2026, 11, 12, 20);
      final scheduler = _CountingScheduler();
      final controller = GoalReminderController(scheduler: scheduler, clock: () => clock);
      addTearDown(controller.dispose);
      await controller.sync(GoalPlanCycle.daily, content);
      final last = scheduler.lastTimes.last;
      clock = DateTime(2026, 11, 13, 8);
      await controller.sync(GoalPlanCycle.daily, content);
      expect(scheduler.keeps.last, isTrue);
      expect(scheduler.lastTimes, hasLength(GoalReminderSchedule.maxScheduled));
      expect(scheduler.lastTimes.first, DateTime(2026, 11, 13, 21));
      expect(scheduler.lastTimes.last, DateTime(last.year, last.month, last.day + 1, 21));
    });

    test('changing the time, cycle or deadline clears everything and books again', () async {
      final scheduler = _CountingScheduler();
      final controller = GoalReminderController(scheduler: scheduler, clock: () => DateTime(2026, 11, 12, 20));
      addTearDown(controller.dispose);
      await controller.sync(GoalPlanCycle.daily, content);
      controller.update(controller.settings.copyWith(hour: 8));
      await controller.sync(GoalPlanCycle.daily, content);
      await controller.sync(GoalPlanCycle.weekly, content);
      await controller.sync(GoalPlanCycle.weekly, content, until: DateTime(2027, 1, 1));
      expect(scheduler.keeps, [false, false, false, false]);
    });

    test('a booking left by a build before date numbers is cleared once', () async {
      final first = _CountingScheduler();
      final before = GoalReminderController(scheduler: first, clock: () => DateTime(2026, 11, 12, 20));
      await before.sync(GoalPlanCycle.daily, content);
      before.dispose();
      // 예전 빌드의 기록: 일정에 번호 방식 표시('ids')가 없었다
      final prefs = SharedPrefsRepository();
      final booked = jsonDecode(prefs.getString(SharedPrefKeys.kGoalReminderBooked)) as Map<String, dynamic>;
      final schedule = jsonDecode(booked['schedule'] as String) as Map<String, dynamic>..remove('ids');
      await prefs.sharedPrefs.setString(
        SharedPrefKeys.kGoalReminderBooked,
        jsonEncode({...booked, 'schedule': jsonEncode(schedule)}),
      );
      final again = _CountingScheduler();
      final after = GoalReminderController(scheduler: again, clock: () => DateTime(2026, 11, 12, 20, 30));
      addTearDown(after.dispose);
      await after.sync(GoalPlanCycle.daily, content);
      expect(again.keeps, [false]);
    });

    test('turning it off still clears everything', () async {
      final scheduler = _CountingScheduler();
      final controller = GoalReminderController(scheduler: scheduler, clock: () => DateTime(2026, 11, 12, 20));
      addTearDown(controller.dispose);
      await controller.sync(GoalPlanCycle.daily, content);
      await controller.setEnabled(false);
      await controller.sync(GoalPlanCycle.daily, content);
      expect(scheduler.cancels, 1);
    });
  });

  // 6-2 A(Max 11/13): 동기화를 기다리는 동안 일정·목표 범위가 걸어 둔 예약과 같으면 그 수량을 기준일과 함께 그대로 두고,
  // 다르면 수량 없이 건다. 처음 확인 전·확인 대기·잔액 가림·같은 계정 충돌에는 수량이 없다
  group('GoalReminderController keeps the last confirmed amount while waiting for a sync', () {
    final now = DateTime(2026, 11, 12, 10);
    final lastSync = DateTime(2026, 11, 10, 8);
    String text(int sats) => '$sats sats';

    Future<void> resetPrefs() async {
      SharedPreferences.setMockInitialValues({
        SharedPrefKeys.kGoalReminder: jsonEncode(const GoalReminderSettings(enabled: true, showAmount: true).toJson()),
      });
      await SharedPrefsRepository().init();
    }

    setUp(() async {
      LocaleSettings.setLocaleSync(AppLocale.ko);
      await resetPrefs();
    });

    /// 목표 1 BTC, 잔액 0.4 BTC. [synced]가 false면 이번 동기화를 기다리는 중
    HomeGoalShare wallet({
      int id = 1,
      int balance = 40000000,
      int? target = 100000000,
      bool synced = true,
      String? account,
    }) => HomeGoalShare(
      walletId: id,
      name: 'w$id',
      balance: balance,
      target: target,
      synced: synced,
      accountKey: account,
    );

    GoalReminderStatus statusOf(List<HomeGoalShare> scope, {bool hidesBalance = false}) => GoalReminderStatus.of(
      sum: HomeGoalSum.of(scope),
      scope: scope,
      plan: GoalPlanController(),
      now: now,
      walletsLoaded: true,
      hidesBalance: hidesBalance,
      lastSyncedAt: lastSync,
    );

    /// 동기화가 끝난 앱에서 수량을 넣어 걸고 닫는다. 걸어 둔 내용을 돌려준다
    Future<GoalReminderContent> bookAndClose(_CountingScheduler scheduler) async {
      final controller = GoalReminderController(scheduler: scheduler, clock: () => now);
      await controller.apply(statusOf([wallet()]), GoalPlanController(), now, amountText: text);
      controller.dispose();
      return scheduler.scheduled!;
    }

    /// 같은 기기 저장값으로 앱을 다시 연다
    GoalReminderController reopen(_CountingScheduler scheduler) {
      final controller = GoalReminderController(scheduler: scheduler, clock: () => now);
      addTearDown(controller.dispose);
      return controller;
    }

    // B5 다시 걸기: 수량이 있던 예약에서 잔액을 가리면(가짜 잔액도 같은 상태) 이미 뜬 알림의 수량도 지우려고 전부 지운다
    test('a new amount refills, but hiding the balance after an amount was booked clears everything', () async {
      final scheduler = _CountingScheduler();
      final controller = reopen(scheduler);
      await controller.apply(statusOf([wallet()]), GoalPlanController(), now, amountText: text);
      await controller.apply(statusOf([wallet(balance: 50000000)]), GoalPlanController(), now, amountText: text);
      expect(scheduler.scheduled!.body, contains('sats'));
      await controller.apply(statusOf([wallet()], hidesBalance: true), GoalPlanController(), now, amountText: text);
      expect(scheduler.scheduled!.body, isNot(contains('sats')));
      expect(scheduler.keeps, [false, true, false]);
    });

    test('a different goal scope clears everything and books again', () async {
      final scheduler = _CountingScheduler();
      final controller = reopen(scheduler);
      await controller.apply(statusOf([wallet()]), GoalPlanController(), now, amountText: text);
      await controller.apply(
        statusOf([wallet(), wallet(id: 2, target: 50000000, account: 'b')]),
        GoalPlanController(),
        now,
        amountText: text,
      );
      expect(scheduler.keeps, [false, false]);
    });

    test('a quick open and close before the sync keeps the booked amount and its date', () async {
      final scheduler = _CountingScheduler();
      final booked = await bookAndClose(scheduler);
      expect(booked.body, allOf(contains('sats'), contains('2026.11.10')));
      for (var open = 0; open < 2; open++) {
        final controller = reopen(scheduler);
        final waiting = statusOf([wallet(synced: false)]);
        // 화면도 같은 수량과 기준일을 보여 준다
        final shown = controller.shown(waiting, GoalPlanController(), now);
        expect((shown.block, shown.asOf), (null, lastSync));
        await controller.apply(waiting, GoalPlanController(), now, amountText: text);
        expect(scheduler.scheduled, booked);
      }
    });

    test('a goal, scope or schedule change while waiting books the reminder without an amount', () async {
      final changes = <String, (List<HomeGoalShare>, void Function(GoalReminderController))>{
        'goal': ([wallet(target: 200000000, synced: false)], (_) {}),
        'scope': ([wallet(synced: false), wallet(id: 2, target: null, synced: false)], (_) {}),
        'time': ([wallet(synced: false)], (controller) => controller.update(controller.settings.copyWith(hour: 8))),
      };
      for (final MapEntry(key: name, value: (scope, change)) in changes.entries) {
        await resetPrefs();
        final scheduler = _CountingScheduler();
        await bookAndClose(scheduler);
        final controller = reopen(scheduler);
        change(controller);
        await controller.apply(statusOf(scope), GoalPlanController(), now, amountText: text);
        expect(scheduler.scheduled!.body, isNot(contains('sats')), reason: name);
        // 아직 동기화 전이면 다시 열어도 수량 없이(새 예약에는 남길 수량이 없다)
        await reopen(scheduler).apply(statusOf(scope), GoalPlanController(), now, amountText: text);
        expect(scheduler.scheduled!.body, isNot(contains('sats')), reason: name);
      }
    });

    test(
      'leaves the amount out before the first confirmed amount, while awaiting confirmation, hidden or in conflict',
      () async {
        // 처음 확인 전: 걸어 둔 수량이 없다
        final first = _CountingScheduler();
        await reopen(first).apply(statusOf([wallet(synced: false)]), GoalPlanController(), now, amountText: text);
        expect(first.scheduled!.body, isNot(contains('sats')));
        // 일정·목표 범위는 같아도 동기화 전 잔액이 목표에 닿았거나(확인 대기) 잔액을 가리면 수량 없이
        for (final (name, status) in [
          ('awaiting', statusOf([wallet(balance: 120000000, synced: false)])),
          ('hidden', statusOf([wallet(synced: false)], hidesBalance: true)),
        ]) {
          await resetPrefs();
          final scheduler = _CountingScheduler();
          await bookAndClose(scheduler);
          await reopen(scheduler).apply(status, GoalPlanController(), now, amountText: text);
          expect(scheduler.scheduled!.body, isNot(contains('sats')), reason: name);
        }
        // 같은 계정 목표 충돌은 수량을 빼는 다른 이유가 먼저다
        final conflict = statusOf([
          wallet(synced: false, account: 'a'),
          wallet(id: 2, target: 200000000, synced: false, account: 'a'),
        ]);
        expect((conflict.block, conflict.waitsForSync), (GoalReminderAmountBlock.conflict, false));
        expect(statusOf([wallet(synced: false)]).waitsForSync, isTrue);
      },
    );

    test('a booking cut off midway leaves no amount to keep on the next run', () async {
      final scheduler = _CountingScheduler();
      final controller = GoalReminderController(scheduler: scheduler, clock: () => now);
      await controller.apply(statusOf([wallet()]), GoalPlanController(), now, amountText: text);
      // 다음 동기화의 새 수량을 쓰다 일부만 쓰고 실패
      scheduler.partialFailNext = true;
      await controller.apply(statusOf([wallet(balance: 50000000)]), GoalPlanController(), now, amountText: text);
      controller.dispose();
      await reopen(scheduler).apply(statusOf([wallet(synced: false)]), GoalPlanController(), now, amountText: text);
      expect(scheduler.scheduled!.body, isNot(contains('sats')));
    });

    // Astra N4: 걸어 둔 수량이 바뀌면(새 수량을 걸거나, 일부만 쓰고 실패해 둘 수량이 없어지면) 화면도 듣는다
    test('the card hears when the booked amount changes', () async {
      final scheduler = _CountingScheduler();
      final controller = reopen(scheduler);
      final plan = GoalPlanController();
      await controller.apply(statusOf([wallet()]), plan, now, amountText: text);
      var heard = 0;
      controller.addListener(() => heard++);
      await controller.apply(statusOf([wallet(balance: 50000000)]), plan, now, amountText: text);
      expect(heard, 1);
      scheduler.partialFailNext = true;
      await controller.apply(statusOf([wallet(balance: 60000000)]), plan, now, amountText: text);
      expect(controller.shown(statusOf([wallet(synced: false)]), plan, now).amountSats, isNull);
      expect(heard, 2);
    });
  });
}

class _CountingScheduler implements GoalReminderScheduler {
  final bool fail;
  int calls = 0;
  int cancels = 0;
  GoalReminderSettings? last;
  List<DateTime> lastTimes = const [];
  GoalReminderContent? scheduled;

  /// 다음 예약 몇 번을 잠깐 실패시킨다(기존 예약은 그대로 남는다)
  int failNext = 0;

  /// 다음 예약 하나를 일부만 쓰고 실패시킨다(날짜별로 쓰다 멈춤)
  bool partialFailNext = false;

  _CountingScheduler({this.fail = false});

  /// 예약마다 [GoalReminderScheduler.schedule]의 keepBooked(참이면 지우지 않고 채우기만)
  final List<bool> keeps = [];

  @override
  Future<void> schedule(
    GoalReminderSettings settings,
    GoalPlanCycle cycle,
    GoalReminderContent content,
    List<DateTime> times, {
    bool keepBooked = false,
  }) async {
    calls++;
    last = settings;
    lastTimes = times;
    keeps.add(keepBooked);
    if (failNext > 0) {
      failNext--;
      throw StateError('temporary platform failure');
    }
    if (partialFailNext) {
      partialFailNext = false;
      scheduled = content;
      throw StateError('failed after writing some reminders');
    }
    if (fail) throw StateError('no plugin');
    scheduled = content;
  }

  @override
  Future<void> cancel() async {
    calls++;
    cancels++;
  }

  @override
  Future<bool?> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> openSettings() async {}

  @override
  Stream<void> get taps => const Stream.empty();

  @override
  Future<bool> consumeLaunchTap() async => false;
}
