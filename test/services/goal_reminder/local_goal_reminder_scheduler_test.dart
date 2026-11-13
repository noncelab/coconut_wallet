import 'package:coconut_wallet/services/goal_reminder/goal_reminder.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart' show GoalPlanCycle;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 실제 스케줄러: 걸어 둔 일정과 같으면(keepBooked) 지우지 않고 받은 날짜만 그 날짜 번호에 다시 건다.
  // 그래서 방금 지난(아직 안 울렸을 수 있는) 알림과 이미 뜬 알림이 남는다(P1).
  test('the device scheduler refills without cancelling when the booked schedule is kept', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final calls = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const plugin = MethodChannel('dexterous.com/flutter/local_notifications');
    const zone = MethodChannel('flutter_timezone');
    messenger.setMockMethodCallHandler(plugin, (call) async {
      if (call.method == 'zonedSchedule' || call.method == 'cancel') {
        final arguments = call.arguments;
        calls.add('${call.method} ${arguments is Map ? arguments['id'] : arguments}');
      }
      return call.method == 'initialize' ? true : null;
    });
    messenger.setMockMethodCallHandler(zone, (_) async => 'Asia/Seoul');
    addTearDown(() {
      messenger.setMockMethodCallHandler(plugin, null);
      messenger.setMockMethodCallHandler(zone, null);
    });

    // The plugin only accepts dates ahead of the real clock, so the days are counted from today.
    final day = DateTime.now().add(const Duration(days: 2));
    final times = [for (var i = 0; i < 3; i++) DateTime(day.year, day.month, day.day + i, 21)];
    int idOf(DateTime at) => LocalGoalReminderScheduler.idOf(at, GoalPlanCycle.daily);
    const settings = GoalReminderSettings(enabled: true);
    const content = GoalReminderContent('title', 'body');
    final scheduler = LocalGoalReminderScheduler();

    await scheduler.schedule(settings, GoalPlanCycle.daily, content, times);
    expect(calls.where((call) => call.startsWith('cancel')), hasLength(LocalGoalReminderScheduler.idSlots));
    expect(calls.skip(LocalGoalReminderScheduler.idSlots), [for (final at in times) 'zonedSchedule ${idOf(at)}']);

    calls.clear();
    final upcoming = times.skip(1).toList();
    await scheduler.schedule(settings, GoalPlanCycle.daily, content, upcoming, keepBooked: true);
    expect(calls, [for (final at in upcoming) 'zonedSchedule ${idOf(at)}']);
  });
}
