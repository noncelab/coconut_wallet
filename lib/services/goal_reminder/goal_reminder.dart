import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart' show HomeGoalShare, HomeGoalSum;
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart'
    show GoalPlanController, GoalPlanCycle;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 앱이 알림을 끈 이유. 사용자가 끈 알림에는 없고, 사용자가 다시 켜면 지운다.
enum GoalReminderOffReason { reached, deadlinePassed, noGoal }

/// 모으기 알림 설정. 주기·요일·날짜는 모으기 계획의 모으는 날을 따른다(예약할 때 계획이 넘겨 준다).
@immutable
class GoalReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;

  /// 매주일 때 요일. 1(월)~7(일)
  final int weekday;

  /// 매월일 때 날짜. 모든 달에 있는 1~28일만 고른다.
  final int dayOfMonth;

  /// 알림에 이번에 모을 수량을 보여 줄지. 잠금 화면에 금액이 보이므로 기본은 숨김.
  final bool showAmount;

  /// 앱이 끈 이유. 켜져 있으면 늘 null
  final GoalReminderOffReason? offReason;

  const GoalReminderSettings({
    this.enabled = false,
    this.hour = 21,
    this.minute = 0,
    this.weekday = DateTime.monday,
    this.dayOfMonth = 1,
    this.showAmount = false,
    this.offReason,
  });

  static const maxDayOfMonth = 28;

  GoalReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    int? weekday,
    int? dayOfMonth,
    bool? showAmount,
    GoalReminderOffReason? offReason,
  }) => GoalReminderSettings(
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    weekday: weekday ?? this.weekday,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    showAmount: showAmount ?? this.showAmount,
    // 켜면 앱이 끈 이유를 지운다
    offReason: (enabled ?? this.enabled) ? null : offReason ?? this.offReason,
  );

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'weekday': weekday,
    'dayOfMonth': dayOfMonth,
    'showAmount': showAmount,
    if (offReason != null) 'offReason': offReason!.name,
  };

  /// 저장값이 없거나 잘못됐으면 기본값을 쓴다.
  static GoalReminderSettings fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return const GoalReminderSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      int clamp(Object? value, int fallback, int min, int max) =>
          value is int && value >= min && value <= max ? value : fallback;
      const defaults = GoalReminderSettings();
      return GoalReminderSettings(
        enabled: json['enabled'] == true,
        hour: clamp(json['hour'], defaults.hour, 0, 23),
        minute: clamp(json['minute'], defaults.minute, 0, 59),
        weekday: clamp(json['weekday'], defaults.weekday, DateTime.monday, DateTime.sunday),
        dayOfMonth: clamp(json['dayOfMonth'], defaults.dayOfMonth, 1, maxDayOfMonth),
        showAmount: json['showAmount'] == true,
        offReason: json['enabled'] == true ? null : GoalReminderOffReason.values.asNameMap()[json['offReason']],
      );
    } catch (_) {
      return const GoalReminderSettings();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GoalReminderSettings &&
      other.enabled == enabled &&
      other.hour == hour &&
      other.minute == minute &&
      other.weekday == weekday &&
      other.dayOfMonth == dayOfMonth &&
      other.showAmount == showAmount &&
      other.offReason == offReason;

  @override
  int get hashCode => Object.hash(enabled, hour, minute, weekday, dayOfMonth, showAmount, offReason);
}

/// 알림 제목과 본문
@immutable
class GoalReminderContent {
  final String title;
  final String body;

  const GoalReminderContent(this.title, this.body);

  /// 수량 기준일·마지막 알림 날. 앱의 날짜 모양(yyyy.MM.dd)
  static String formatDate(DateTime date) =>
      '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  /// 제목은 중립(카드 제목과 같음). [amount]가 있으면 [asOf](마지막으로 확인한 날) 기준 계획 수량을 넣는다.
  factory GoalReminderContent.of(GoalPlanCycle cycle, {String? amount, String asOf = ''}) {
    assert(amount == null || asOf.isNotEmpty, 'the planned amount needs the date it was checked');
    final copy = t.hodl_insights;
    final body =
        amount == null
            ? switch (cycle) {
              GoalPlanCycle.daily => copy.goal_reminder_body_daily,
              GoalPlanCycle.weekly => copy.goal_reminder_body_weekly,
              GoalPlanCycle.monthly => copy.goal_reminder_body_monthly,
            }
            : switch (cycle) {
              GoalPlanCycle.daily => copy.goal_reminder_body_daily_amount(amount: amount, date: asOf),
              GoalPlanCycle.weekly => copy.goal_reminder_body_weekly_amount(amount: amount, date: asOf),
              GoalPlanCycle.monthly => copy.goal_reminder_body_monthly_amount(amount: amount, date: asOf),
            };
    return GoalReminderContent(copy.goal_reminder_title, body);
  }

  @override
  bool operator ==(Object other) => other is GoalReminderContent && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);
}

/// 알림에 수량을 넣지 않는 이유. 여럿이면 앞의 것 하나만 보여 준다.
enum GoalReminderAmountBlock { reached, pending, hidden, conflict, unsynced }

/// 목표·잔액·계획으로 정한 알림 상태. 목표 화면과 앱 전체 알림 맞춤(GoalReminderSync)이 같은 규칙을 쓴다.
@immutable
class GoalReminderStatus {
  /// 앱이 지금 알림을 꺼야 하는 이유. 없으면 null
  final GoalReminderOffReason? offReason;

  /// 알림에 넣을 수 있는 이번 계획 수량. 남은 수량이 없거나 넣을 수 없으면 null([block]에 이유)
  final int? amountSats;
  final GoalReminderAmountBlock? block;

  /// [amountSats]의 기준일. 오늘이 아니라 마지막으로 잔액 동기화가 끝난 때다(B④).
  final DateTime? asOf;

  /// 목표 범위: 범위 안 지갑과 그 목표. 동기화를 기다리는 동안 이것이 걸어 둔 예약과 다르면 수량 없이 건다(6-2 A)
  final String goalScope;

  /// 수량을 뺀 이유가 이번 동기화를 기다리는 것 하나뿐인지(확인 대기·잔액 가림·충돌·달성이 아님). 그러면 일정·목표 범위가
  /// 같은 동안 걸어 둔 예약의 수량을 기준일과 함께 그대로 둔다([GoalReminderController.shown], 6-2 A)
  final bool waitsForSync;

  const GoalReminderStatus._(this.offReason, this.amountSats, this.block, this.asOf, this.goalScope, this.waitsForSync);

  /// [walletsLoaded]가 false면 목표가 없어 보여도 끄지 않는다(지갑을 불러오는 중, UX X6).
  /// 달성은 1차 합계의 [HomeGoalSum.reached](확인된 미사용 잔액 기준, 목표 지갑이 모두 동기화를 성공으로 마치고 같은 계정
  /// 잔액이 같을 때만)를 따른다. 그래서 달성으로 끄는 것도 이번 동기화 뒤에만이다(B③).
  /// 수량은 목표 지갑이 모두 동기화를 성공으로 마쳤고 같은 계정 잔액이 같을 때만 넣는다. [lastSyncedAt](앱 전체의 마지막
  /// 동기화)은 기준일일 뿐, 아직 확인하지 않은 새 계정의 잔액을 확인했다는 뜻이 아니다(Astra B1-a.2).
  /// 동기화를 기다리는 동안은 수량을 새로 만들지 않는다. [scope](범위 안 지갑, 목표 없는 지갑 포함)와 일정이 걸어 둔 예약과
  /// 같으면 그 예약의 수량을 둔다(6-2 A, [GoalReminderController.shown]).
  factory GoalReminderStatus.of({
    required HomeGoalSum sum,
    required GoalPlanController plan,
    required DateTime now,
    required bool walletsLoaded,
    required bool hidesBalance,
    required DateTime? lastSyncedAt,
    Iterable<HomeGoalShare> scope = const [],
  }) {
    final goal = sum.goal;
    final settled = lastSyncedAt != null && sum.allSynced && !sum.hasUnsettledAccounts;
    final GoalReminderOffReason? offReason;
    if (!walletsLoaded) {
      offReason = null;
    } else if (goal == null) {
      offReason = GoalReminderOffReason.noGoal;
    } else if (sum.reached && lastSyncedAt != null) {
      offReason = GoalReminderOffReason.reached;
    } else if (plan.isExpiredOn(now)) {
      offReason = GoalReminderOffReason.deadlinePassed;
    } else {
      offReason = null;
    }
    final GoalReminderAmountBlock? block;
    if (sum.reached) {
      block = GoalReminderAmountBlock.reached;
    } else if (sum.awaitingConfirmation && settled) {
      // 확인 전 입금으로만 넘었을 때. 동기화 중이거나 같은 계정 잔액이 다르면 아래 '잔액 확인'으로 알린다
      block = GoalReminderAmountBlock.pending;
    } else if (hidesBalance) {
      block = GoalReminderAmountBlock.hidden;
    } else if (sum.hasConflictingGoals) {
      block = GoalReminderAmountBlock.conflict;
    } else if (!settled) {
      block = GoalReminderAmountBlock.unsynced;
    } else {
      block = null;
    }
    final remaining = goal == null ? 0 : goal.target - goal.balance;
    final amount = block == null && remaining > 0 ? plan.perInstallment(remaining, now) : null;
    return GoalReminderStatus._(
      offReason,
      amount,
      block,
      amount == null ? null : lastSyncedAt!.toLocal(),
      ([for (final share in scope) '${share.walletId}:${share.target ?? 0}']..sort()).join(','),
      block == GoalReminderAmountBlock.unsynced && !sum.awaitingConfirmation,
    );
  }

  /// 동기화를 기다리는 동안 걸어 둔 예약의 수량을 그 기준일과 함께 둔 상태
  GoalReminderStatus _keeping(int sats, DateTime asOf) =>
      GoalReminderStatus._(offReason, sats, null, asOf, goalScope, false);

  /// 예약할 알림 내용. 수량 넣기를 켰고 넣을 수 있을 때만 수량과 기준일을 넣는다.
  GoalReminderContent contentFor(
    GoalPlanCycle cycle, {
    required bool showAmount,
    required String Function(int sats) amountText,
  }) => GoalReminderContent.of(
    cycle,
    amount: showAmount && amountSats != null ? amountText(amountSats!) : null,
    asOf: asOf == null ? '' : GoalReminderContent.formatDate(asOf!),
  );
}

/// 다음 알림 시각. [now] 이후 처음 오는 설정 시각.
abstract final class GoalReminderSchedule {
  static DateTime next(DateTime now, GoalReminderSettings settings, GoalPlanCycle cycle) {
    DateTime at(DateTime day) => DateTime(day.year, day.month, day.day, settings.hour, settings.minute);
    switch (cycle) {
      case GoalPlanCycle.daily:
        final today = at(now);
        return today.isAfter(now) ? today : at(DateTime(now.year, now.month, now.day + 1));
      case GoalPlanCycle.weekly:
        final shift = (settings.weekday - now.weekday) % 7;
        final candidate = at(DateTime(now.year, now.month, now.day + shift));
        return candidate.isAfter(now) ? candidate : at(DateTime(now.year, now.month, now.day + shift + 7));
      case GoalPlanCycle.monthly:
        final candidate = at(DateTime(now.year, now.month, settings.dayOfMonth));
        return candidate.isAfter(now) ? candidate : at(DateTime(now.year, now.month + 1, settings.dayOfMonth));
    }
  }

  /// 한 번에 걸어 두는 날짜별 알림 수. 앱을 열 때마다 이어서 채운다.
  // ponytail: iOS keeps at most 64 pending notifications per app, so 30 leaves room; raise it if daily plans
  // should keep reminding after a month without opening the app.
  static const maxScheduled = 30;

  /// [now] 뒤로 [until](마감일) 전날까지 오는 알림 시각, 가까운 것부터 [maxScheduled]개까지. 마지막 알림은 마감일
  /// 전날이다(B④ D1). [until]이 없으면 [maxScheduled]개.
  static List<DateTime> upcoming(DateTime now, GoalReminderSettings settings, GoalPlanCycle cycle, {DateTime? until}) {
    final end = until == null ? null : DateTime(until.year, until.month, until.day);
    final times = <DateTime>[];
    for (var at = next(now, settings, cycle); times.length < maxScheduled; at = next(at, settings, cycle)) {
      if (end != null && !at.isBefore(end)) break;
      times.add(at);
    }
    return times;
  }
}

/// 기기 알림 예약. 테스트에서는 [instance]를 바꿔 끼운다.
abstract class GoalReminderScheduler {
  static GoalReminderScheduler instance = LocalGoalReminderScheduler();

  /// 알림 권한이 있는지. 확인할 수 없으면 null
  Future<bool?> hasPermission();

  /// 권한을 요청한다. 이미 거절했으면 OS가 다시 묻지 않고 false를 돌려준다.
  Future<bool> requestPermission();

  /// 이전 예약을 지우고 [times]마다 하나씩 다시 예약한다. [times]는 [settings]·[cycle]의 모으는 날에서 마감일 전날까지다
  /// ([GoalReminderSchedule.upcoming]). 비어 있으면 지우기만 한다.
  /// [keepBooked]면 지우지 않고 [times]만 그 날짜의 번호에 다시 건다. 방금 지난 알림(아직 안 울렸을 수 있음)과 이미 뜬
  /// 알림은 번호가 달라 그대로 남는다.
  Future<void> schedule(
    GoalReminderSettings settings,
    GoalPlanCycle cycle,
    GoalReminderContent content,
    List<DateTime> times, {
    bool keepBooked = false,
  });

  Future<void> cancel();

  /// 기기 설정의 이 앱 알림 화면을 연다.
  Future<void> openSettings();

  /// 앱이 켜져 있는 동안 모으기 알림을 누르면 한 번씩 알린다.
  Stream<void> get taps;

  /// 모으기 알림을 눌러 앱이 처음 켜졌는지. 한 번만 true를 돌려준다.
  Future<bool> consumeLaunchTap();
}

/// flutter_local_notifications로 모으는 날마다 한 번씩 알림을 예약한다(마감일 전날까지, 번호는 날짜에 묶음: [idOf]).
/// Android는 정확한 알람 권한 없이 쓰도록 inexact 모드라 몇 분 늦게 올 수 있다.
class LocalGoalReminderScheduler implements GoalReminderScheduler {
  static const _notificationId = 7101;

  /// 번호 칸 수: 방금 지난 알림 하나 + 앞으로 걸어 두는 것([GoalReminderSchedule.maxScheduled])
  static const idSlots = GoalReminderSchedule.maxScheduled + 1;

  /// 알림 번호(7101 + 차례 % 31). 차례는 매일 = 날짜 일수, 매주 = 날짜 일수 ÷ 7, 매월 = 연×12+월로, 이어지는 모으는 날마다
  /// 1씩 커진다. 그래서 이어지는 31개의 번호가 모두 달라 다시 걸어도 방금 지난 알림의 번호를 쓰지 않는다. 달력 날짜로만
  /// 정해서 서머타임·시간대와 상관없다.
  static int idOf(DateTime at, GoalPlanCycle cycle) {
    final days = DateTime.utc(at.year, at.month, at.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    final order = switch (cycle) {
      GoalPlanCycle.daily => days,
      GoalPlanCycle.weekly => days ~/ 7,
      GoalPlanCycle.monthly => at.year * 12 + at.month,
    };
    return _notificationId + order % idSlots;
  }

  static const _channelId = 'goal_reminder';

  /// 알림을 눌렀을 때 모으기 알림인지 가려내는 표시
  static const payload = 'goal_reminder';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final StreamController<void> _taps = StreamController<void>.broadcast();
  Future<void>? _ready;
  bool _launchTapConsumed = false;

  Future<void> _init() =>
      _ready ??= () async {
        tz_data.initializeTimeZones();
        try {
          final zone = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(zone.identifier));
        } catch (error) {
          // 시간대를 모르면 UTC 기준으로 예약돼 시각이 어긋난다. 로그만 남긴다.
          Logger.error('Failed to read the local time zone for goal reminders: $error');
        }
        await _plugin.initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('ic_stat_goal_reminder'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          ),
          onDidReceiveNotificationResponse: (response) {
            if (response.payload == payload) _taps.add(null);
          },
        );
      }();

  @override
  Stream<void> get taps => _taps.stream;

  @override
  Future<bool> consumeLaunchTap() async {
    if (_launchTapConsumed) return false;
    _launchTapConsumed = true;
    await _init();
    final details = await _plugin.getNotificationAppLaunchDetails();
    return (details?.didNotificationLaunchApp ?? false) && details?.notificationResponse?.payload == payload;
  }

  @override
  Future<bool?> hasPermission() async {
    await _init();
    if (Platform.isAndroid) {
      return _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    }
    if (Platform.isIOS) {
      final options =
          await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.checkPermissions();
      return options?.isEnabled;
    }
    return null;
  }

  @override
  Future<bool> requestPermission() async {
    await _init();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<void> schedule(
    GoalReminderSettings settings,
    GoalPlanCycle cycle,
    GoalReminderContent content,
    List<DateTime> times, {
    bool keepBooked = false,
  }) async {
    if (keepBooked) {
      await _init();
    } else {
      await cancel();
    }
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        t.hodl_insights.goal_reminder_channel,
        channelDescription: t.hodl_insights.goal_reminder_channel_description,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    // 반복 알림이 아니라 날짜마다 한 번: 앱을 열지 않아도 마감일 전날 뒤로는 오지 않는다(B④)
    for (final at in times) {
      await _plugin.zonedSchedule(
        id: idOf(at, cycle),
        title: content.title,
        body: content.body,
        payload: payload,
        scheduledDate: tz.TZDateTime(tz.local, at.year, at.month, at.day, at.hour, at.minute),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// 날짜별 알림을 모두 지운다(7101~7131). 예전 반복 알림과 예전 순서 번호(7101~7130)도 이 안이라 함께 지워진다.
  @override
  Future<void> cancel() async {
    await _init();
    for (var index = 0; index < idSlots; index++) {
      await _plugin.cancel(id: _notificationId + index);
    }
  }

  @override
  Future<void> openSettings() async {
    await _init();
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.openAppNotificationSettings();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.openAppNotificationSettings();
    }
  }
}

/// 기기에 걸어 둔 예약: 일정·목표 범위([GoalReminderController._scheduleOf])와 넣은 수량·기준일(없으면 둘 다 null)
typedef _Booked = ({String schedule, int? sats, DateTime? asOf});

/// 목표 수량 화면의 모으기 알림 상태. 설정은 기기에 저장한다.
class GoalReminderController extends ChangeNotifier {
  final GoalReminderScheduler _scheduler;
  GoalReminderSettings _settings;

  /// 알림 권한. 아직 확인하지 않았으면 null
  bool? _permission;
  bool _busy = false;
  bool _disposed = false;

  /// 마지막으로 예약에 성공한 내용. 같으면 다시 예약하지 않는다. 기기 예약을 바꾸기 시작하면 지운다: 날짜별 예약은 하나씩
  /// 쓰므로 실패하면 무엇이 남았는지 모른다(B2-실패, 부분 예약 뒤 옛 내용으로 돌아가도 다시 맞춘다). 앱을 다시 켜면 비어 있어
  /// 한 번은 다시 건다(Android 강제 종료처럼 기기가 예약을 지웠을 수 있다).
  Object? _applied;

  /// 기기에 걸어 둔 예약. 저장해 두어 앱을 다시 켜도 안다. 예약을 바꾸기 시작하면 저장값을 지우고(바꾸다 앱이 꺼지면 다음
  /// 실행에서 남긴 수량을 쓰지 않게) 성공하면 쓴다. 동기화를 기다리는 동안 일정·목표 범위가 같으면 이 수량을 기준일과 함께
  /// 그대로 둔다(6-2 A). 달성·자동 끄기에는 쓰지 않는다.
  _Booked? _booked;

  /// 마지막으로 실패한 내용과 그때 시각. 같은 내용은 [retryAfter]가 지난 뒤 다음 맞춤(앱 복귀·잔액 갱신 등)에서 다시
  /// 시도한다. 다시 그릴 때마다 시도하지는 않는다(B2-실패: 수량을 빼는 예약이 한 번 실패해도 남지 않게).
  ({Object key, DateTime at})? _failed;
  static const retryAfter = Duration(seconds: 30);

  /// 예약은 한 번에 하나씩 맞춘다(늦게 끝난 옛 예약이 새 예약을 덮지 않게).
  Future<void> _syncing = Future.value();

  /// 기기에 예약된 알림이 있을 수 있는지. 한 번도 켜지 않았으면 지울 것이 없으니 플러그인을 부르지 않는다. 앞 실행의
  /// 걸어 둔 예약 기록이 남았으면 꺼져 있어도 지운다.
  bool _mayHaveScheduled;
  final DateTime Function() _clock;

  GoalReminderController({GoalReminderScheduler? scheduler, DateTime Function()? clock})
    : this._(scheduler ?? GoalReminderScheduler.instance, _loadSettings(), clock ?? DateTime.now, _loadBooked());

  GoalReminderController._(this._scheduler, this._settings, this._clock, this._booked)
    : _mayHaveScheduled = _settings.enabled || _booked != null;

  /// 기기 예약을 모두 지운다.
  Future<bool> _cancelScheduled() async {
    _setBooked(null);
    await _storeBooked(null);
    try {
      await _scheduler.cancel();
    } catch (error) {
      _mayHaveScheduled = true;
      Logger.error('Failed to cancel goal reminders: $error');
      return false;
    }
    _mayHaveScheduled = false;
    return true;
  }

  static GoalReminderSettings _loadSettings() =>
      GoalReminderSettings.fromJsonString(_preferences?.getString(SharedPrefKeys.kGoalReminder));

  static _Booked? _loadBooked() {
    final raw = _preferences?.getStringOrNull(SharedPrefKeys.kGoalReminderBooked);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final sats = json['sats'];
      final asOf = json['asOf'] is String ? DateTime.tryParse(json['asOf'] as String) : null;
      final dated = sats is int && asOf != null;
      return (schedule: json['schedule'] as String, sats: dated ? sats : null, asOf: dated ? asOf : null);
    } catch (_) {
      // 읽을 수 없으면 무엇이 걸렸는지 모른다: 남긴 수량은 쓰지 않고, 꺼져 있으면 지운다
      return (schedule: '', sats: null, asOf: null);
    }
  }

  /// 걸어 둔 예약이 바뀌면 화면(수량 넣기 스위치·미리보기)에 알린다(Astra N4)
  void _setBooked(_Booked? booked) {
    if (booked == _booked) return;
    _booked = booked;
    _notify();
  }

  static Future<void> _storeBooked(_Booked? booked) async {
    final preferences = _preferences;
    if (preferences == null) return;
    try {
      if (booked == null) {
        await preferences.deleteSharedPrefsWithKey(SharedPrefKeys.kGoalReminderBooked);
        return;
      }
      final saved = await preferences.setStringAndConfirm(
        SharedPrefKeys.kGoalReminderBooked,
        jsonEncode({
          'schedule': booked.schedule,
          if (booked.sats != null) 'sats': booked.sats,
          if (booked.asOf != null) 'asOf': booked.asOf!.toIso8601String(),
        }),
      );
      if (!saved) Logger.error('Failed to save the goal reminder booking');
    } catch (error) {
      Logger.error('Failed to save the goal reminder booking: $error');
    }
  }

  static SharedPrefsRepository? get _preferences {
    final preferences = SharedPrefsRepository();
    return preferences.isInitialized ? preferences : null;
  }

  GoalReminderSettings get settings => _settings;
  bool get isBusy => _busy;

  /// 켜 두었는데 기기 설정에서 알림을 끈 상태
  bool get permissionDenied => _permission == false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refreshPermission() async {
    if (!_settings.enabled) return;
    try {
      final permission = await _scheduler.hasPermission();
      if (permission != _permission) {
        _permission = permission;
        _notify();
      }
    } catch (error) {
      Logger.error('Failed to check goal reminder permission: $error');
    }
  }

  /// 켤 때 권한을 묻는다. 거절하면 꺼진 채로 두고 false를 돌려준다.
  Future<bool> setEnabled(bool enabled) async {
    if (_busy || enabled == _settings.enabled) return enabled == _settings.enabled;
    _busy = true;
    _notify();
    try {
      if (enabled) {
        final granted = await _scheduler.requestPermission();
        _permission = granted;
        if (!granted) return false;
      }
      _update(_settings.copyWith(enabled: enabled));
      return true;
    } catch (error) {
      Logger.error('Failed to change goal reminder: $error');
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  void update(GoalReminderSettings settings) => _update(settings.copyWith(enabled: _settings.enabled));

  /// 앱이 알림을 끈다(확인된 잔액으로 목표를 채움·마감일이 지남·목표가 없어짐). 이유를 남기고, 다시 켜는 것은 사용자만 한다.
  void turnOff(GoalReminderOffReason reason) {
    if (!_settings.enabled) return;
    _update(_settings.copyWith(enabled: false, offReason: reason));
  }

  /// [status]대로 맞춘다. 꺼야 할 이유가 있으면 이유와 함께 끄고, 예약은 계획의 모으는 날과 지금 내용으로 맞춘다.
  Future<void> apply(
    GoalReminderStatus status,
    GoalPlanController plan,
    DateTime now, {
    required String Function(int sats) amountText,
  }) {
    if (status.offReason != null) turnOff(status.offReason!);
    final settings = _settingsOn(plan, now);
    final cycle = plan.cycle;
    final until = plan.deadlineOn(now);
    final schedule = _scheduleOf(settings, cycle, until, status.goalScope);
    // 남긴 수량은 줄에서 차례가 왔을 때 정한다(앞 예약이 끝난 뒤 걸려 있는 예약을 본다)
    return _enqueue(() {
      final shown = _keep(status, schedule);
      final sats = settings.showAmount ? shown.amountSats : null;
      return _syncNow(
        settings,
        cycle,
        shown.contentFor(cycle, showAmount: settings.showAmount, amountText: amountText),
        until,
        schedule: schedule,
        sats: sats,
        asOf: sats == null ? null : shown.asOf,
      );
    });
  }

  /// 화면에 보여 줄 수량. 이번 동기화를 기다리는 동안([GoalReminderStatus.waitsForSync]) 일정·목표 범위가 걸어 둔 예약과
  /// 같으면 그 예약의 수량을 기준일과 함께 그대로 보여 준다(6-2 A). 예약을 맞출 때도 같은 규칙을 쓴다([apply]).
  GoalReminderStatus shown(GoalReminderStatus status, GoalPlanController plan, DateTime now) =>
      _keep(status, _scheduleOf(_settingsOn(plan, now), plan.cycle, plan.deadlineOn(now), status.goalScope));

  /// 동기화를 기다리는 동안은 수량을 새로 만들지 않는다: 일정·목표 범위가 같으면 걸어 둔 수량을 그대로, 다르거나 걸어 둔
  /// 수량이 없으면(처음 확인 전) 수량 없이
  GoalReminderStatus _keep(GoalReminderStatus status, String schedule) {
    final booked = _booked;
    final sats = booked?.sats;
    final asOf = booked?.asOf;
    if (!status.waitsForSync || booked?.schedule != schedule || sats == null || asOf == null) return status;
    return status._keeping(sats, asOf);
  }

  GoalReminderSettings _settingsOn(GoalPlanController plan, DateTime now) =>
      _settings.copyWith(weekday: plan.weekdayOn(now), dayOfMonth: plan.dayOn(now));

  /// 걸어 둔 예약을 알아보는 일정·목표 범위: 설정(켜짐·시각·요일·날짜·수량 넣기)·주기·마감일·범위 안 지갑과 그 목표.
  /// `ids`는 알림 번호 방식(2 = 날짜에 묶은 번호). 예전 순서 번호로 걸어 둔 기록과 달라서 그때는 한 번 전부 지우고 다시 건다.
  static String _scheduleOf(GoalReminderSettings settings, GoalPlanCycle cycle, DateTime? until, String goalScope) =>
      jsonEncode({
        'settings': settings.toJson(),
        'cycle': cycle.name,
        'until': until?.toIso8601String(),
        'goal': goalScope,
        'ids': 2,
      });

  void _update(GoalReminderSettings settings) {
    if (settings == _settings) return;
    _settings = settings;
    _notify();
    final preferences = _preferences;
    if (preferences == null) return;
    unawaited(
      preferences.setStringAndConfirm(SharedPrefKeys.kGoalReminder, jsonEncode(settings.toJson())).then((saved) {
        if (!saved) Logger.error('Failed to save goal reminder settings');
      }),
    );
  }

  /// 지금 설정과 계획으로 예약을 맞춘다. 꺼져 있으면 지운다. 켜져 있으면 모으는 날마다 [until](마감일) 전날까지 건다.
  /// [weekday]·[dayOfMonth]는 모으기 계획의 모으는 요일·날짜다(없으면 저장된 값).
  Future<void> sync(
    GoalPlanCycle cycle,
    GoalReminderContent content, {
    int? weekday,
    int? dayOfMonth,
    DateTime? until,
  }) {
    final settings = _settings.copyWith(weekday: weekday, dayOfMonth: dayOfMonth);
    return _enqueue(() => _syncNow(settings, cycle, content, until, schedule: _scheduleOf(settings, cycle, until, '')));
  }

  /// 예약은 한 번에 하나씩 맞춘다.
  Future<void> _enqueue(Future<void> Function() run) => _syncing = _syncing.then((_) => run());

  Future<void> _syncNow(
    GoalReminderSettings settings,
    GoalPlanCycle cycle,
    GoalReminderContent content,
    DateTime? until, {
    required String schedule,
    int? sats,
    DateTime? asOf,
  }) async {
    final now = _clock();
    final times =
        settings.enabled ? GoalReminderSchedule.upcoming(now, settings, cycle, until: until) : const <DateTime>[];
    // 같은 예약인지: 일정·목표 범위(설정·주기·마감일·범위 안 목표)·내용과 다음 알림 시각(다음 알림이 지나면 다시 걸어
    // 날짜별 알림을 이어서 채운다. 걸어 둔 일정과 같으면 지우지 않고 채우기만 해서 방금 지난 알림은 남는다)
    final key = (schedule, content, times.isEmpty ? null : times.first);
    if (key == _applied) return;
    final failed = _failed;
    if (failed != null && failed.key == key && now.difference(failed.at) < retryAfter) return;
    if (!settings.enabled && !_mayHaveScheduled) {
      _applied = key;
      return;
    }
    // 기기 예약을 바꾸기 시작한다: 끝나기 전에는 무엇이 걸려 있는지 모른다(실패하면 다음 맞춤에서 다시 맞춘다)
    _applied = null;
    final bool done;
    if (settings.enabled) {
      _mayHaveScheduled = true;
      // 걸어 둔 일정과 같으면 지우지 않고 앞으로 것만 같은 날짜 번호에 다시 건다: 방금 지난(아직 안 울렸을 수 있는)
      // 알림과 이미 뜬 알림이 남는다. 걸어 둔 알림에 수량이 있었는데 이제 빼야 하면(잔액 가림·가짜 잔액 등) 뜬 알림의
      // 수량도 지우려고 전부 지우고 다시 건다. 걸어 둔 기록이 없거나(처음·지난 예약 실패) 일정이 바뀌어도 전부 다시
      final booked = _booked;
      final keepBooked = booked != null && booked.schedule == schedule && !(booked.sats != null && sats == null);
      // 바꾸다 앱이 꺼지면 무엇이 걸렸는지 모른다: 다음 실행에서 남긴 수량을 쓰지 않게 저장값부터 지운다
      await _storeBooked(null);
      try {
        await _scheduler.schedule(settings, cycle, content, times, keepBooked: keepBooked);
        done = true;
      } catch (error) {
        Logger.error('Failed to schedule goal reminder: $error');
        _setBooked(null);
        _failed = (key: key, at: now);
        return;
      }
      _setBooked((schedule: schedule, sats: sats, asOf: asOf));
      await _storeBooked(_booked);
    } else {
      done = await _cancelScheduled();
    }
    if (done) {
      _applied = key;
      _failed = null;
    } else {
      _failed = (key: key, at: now);
    }
  }

  void openSettings() => unawaited(
    _scheduler.openSettings().catchError((Object error) {
      Logger.error('Failed to open notification settings: $error');
    }),
  );

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
