import 'dart:async';

import 'package:coconut_wallet/app/bootstrap/platform_channels.dart';
import 'package:coconut_wallet/app/deep_link/deep_link_listener.dart';
import 'package:coconut_wallet/screens/home/goal_amount_screen.dart';
import 'package:coconut_wallet/services/goal_reminder/goal_reminder.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart' show GoalPlanCycle;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Scheduler implements GoalReminderScheduler {
  final StreamController<void> tapController = StreamController<void>.broadcast();
  bool launchedFromTap;

  _Scheduler({this.launchedFromTap = false});

  @override
  Stream<void> get taps => tapController.stream;

  @override
  Future<bool> consumeLaunchTap() async {
    final launched = launchedFromTap;
    launchedFromTap = false;
    return launched;
  }

  @override
  Future<bool?> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule(GoalReminderSettings settings, GoalPlanCycle cycle, GoalReminderContent content) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> openSettings() async {}
}

void main() {
  late List<NavigatorState> opened;

  setUp(() {
    opened = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel(methodChannelOS),
      (_) async => null,
    );
    DeepLinkListener.openGoalAmount = (navigator, _) async => opened.add(navigator);
  });

  tearDown(() {
    DeepLinkListener.openGoalAmount = GoalAmountScreen.openFromReminder;
  });

  Future<GlobalKey<NavigatorState>> pump(WidgetTester tester, _Scheduler scheduler) async {
    final previous = GoalReminderScheduler.instance;
    GoalReminderScheduler.instance = scheduler;
    addTearDown(() => GoalReminderScheduler.instance = previous);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: key,
        builder: (context, child) => DeepLinkListener(navigatorKey: key, child: child!),
        home: const SizedBox(),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  testWidgets('opens the goal amount screen when a reminder launched the app', (tester) async {
    final key = await pump(tester, _Scheduler(launchedFromTap: true));
    expect(opened, [key.currentState]);
  });

  testWidgets('does nothing at launch when the app was not opened from a reminder', (tester) async {
    await pump(tester, _Scheduler());
    expect(opened, isEmpty);
  });

  testWidgets('opens the goal amount screen for each reminder tap while the app is running', (tester) async {
    final scheduler = _Scheduler();
    await pump(tester, scheduler);
    scheduler.tapController.add(null);
    await tester.pump();
    scheduler.tapController.add(null);
    await tester.pump();
    expect(opened, hasLength(2));
  });
}
