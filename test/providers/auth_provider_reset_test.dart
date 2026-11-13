import 'dart:async';
import 'dart:io';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/goal_reminder/goal_reminder.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart' show GoalPlanCycle;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 비밀번호 분실로 앱을 초기화하면 모으기 알림 설정 키뿐 아니라 기기에 예약한 알림도 지운다(B⑥ 버그 #2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  const localAuth = MethodChannel('plugins.flutter.io/local_auth');

  /// 초기화가 부르는 플랫폼(문서 폴더·생체 인증·보안 저장소)과 저장소를 준비한다. 모으기 알림은 켜 둔 채다
  Future<void> prepare() async {
    final documents = Directory.systemTemp.createTempSync('coconut-reset-test');
    addTearDown(() => documents.deleteSync(recursive: true));
    messenger.setMockMethodCallHandler(pathProvider, (_) async => documents.path);
    messenger.setMockMethodCallHandler(
      localAuth,
      (call) async => call.method == 'getAvailableBiometrics' ? <String>[] : false,
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(pathProvider, null);
      messenger.setMockMethodCallHandler(localAuth, null);
    });
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({SharedPrefKeys.kGoalReminder: '{"enabled":true}'});
    await SharedPrefsRepository().init();
  }

  test('resetting the app cancels the scheduled saving reminders', () async {
    await prepare();
    final scheduler = _Scheduler();
    final previous = GoalReminderScheduler.instance;
    GoalReminderScheduler.instance = scheduler;
    addTearDown(() => GoalReminderScheduler.instance = previous);

    await AuthProvider().resetPassword();

    expect(scheduler.cancels, 1);
    expect(SharedPrefsRepository().sharedPrefs.getString(SharedPrefKeys.kGoalReminder), isNull);
  });

  // R3(Astra v9 probe): 초기화가 진행 중인 예약을 기다리는 동안 앱이 꺼져도, 다음 실행이 예약을 지울 근거가 남아야 한다.
  // 초기화는 키를 지우기 전에 '다음 실행에 다시 지움' 표시를 먼저 저장한다
  test('a reset cut off while it waits for a booking still leaves the next run a cleanup mark', () async {
    await prepare();
    const content = GoalReminderContent('t', 'b');
    final booking = _Scheduler()..gate = Completer<void>();
    final before = GoalReminderController(scheduler: booking);
    addTearDown(before.dispose);
    final inFlight = before.sync(GoalPlanCycle.weekly, content);
    await pumpEventQueue();
    final reset = AuthProvider().resetPassword();
    await pumpEventQueue();
    // 초기화가 키를 지우고 예약을 기다리는 지금 앱이 꺼진다: 저장된 값만으로 다음 실행을 본다
    expect(SharedPrefsRepository().getStringOrNull(SharedPrefKeys.kGoalReminder), isNull);
    await SharedPrefsRepository().sharedPrefs.reload();
    final next = _Scheduler();
    final after = GoalReminderController(scheduler: next);
    addTearDown(after.dispose);
    expect(after.settings.enabled, isFalse);
    await after.sync(GoalPlanCycle.weekly, content);
    expect(next.cancels, 1);
    booking.gate!.complete();
    await inFlight;
    await reset;
  });
}

class _Scheduler implements GoalReminderScheduler {
  int cancels = 0;

  /// 주면 예약이 이것을 기다린다(초기화가 진행 중인 예약을 기다리는 동안)
  Completer<void>? gate;

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<void> schedule(
    GoalReminderSettings settings,
    GoalPlanCycle cycle,
    GoalReminderContent content,
    List<DateTime> times, {
    bool keepBooked = false,
  }) async => gate?.future;

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
