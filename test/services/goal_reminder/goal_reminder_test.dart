import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/goal_reminder/goal_reminder.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart' show GoalPlanCycle;
import 'package:flutter_test/flutter_test.dart';

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
  });

  group('GoalReminderContent', () {
    setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

    test('includes the amount only when given', () {
      final withAmount = GoalReminderContent.of(GoalPlanCycle.weekly, amount: '0.01 BTC');
      final withoutAmount = GoalReminderContent.of(GoalPlanCycle.weekly);
      expect(withAmount.body, contains('0.01 BTC'));
      expect(withoutAmount.body, isNot(contains('BTC')));
      expect(withAmount.title, t.hodl_insights.goal_reminder_notification_title);
      expect(withoutAmount.title, t.hodl_insights.goal_reminder_notification_title);
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
}

class _CountingScheduler implements GoalReminderScheduler {
  final bool fail;
  int calls = 0;
  int cancels = 0;

  _CountingScheduler({this.fail = false});

  @override
  Future<void> schedule(GoalReminderSettings settings, GoalPlanCycle cycle, GoalReminderContent content) async {
    calls++;
    if (fail) throw StateError('no plugin');
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
